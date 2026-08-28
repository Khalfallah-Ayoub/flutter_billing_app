import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/cart_item.dart';
import '../../../../core/data/hive_database.dart';
import '../../../product/domain/entities/product.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/fuzzy_search.dart';
import '../../../../core/utils/category_color_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  bool _isSearchOpen = false;
  bool _showBarcodeHint = false;
  Timer? _barcodeHintTimer;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];

  // Cooldown mapping to prevent rapid firing of the same barcode
  final Map<String, DateTime> _lastScanTimes = {};

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      _isCameraOn = false;
    }
    _startBarcodeHintTimer();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    _barcodeHintTimer?.cancel();
    super.dispose();
  }

  void _startBarcodeHintTimer() {
    _barcodeHintTimer?.cancel();
    _showBarcodeHint = false;
    _barcodeHintTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isCameraOn) {
        setState(() => _showBarcodeHint = true);
      }
    });
  }

  void _resetBarcodeHintTimer() {
    if (_showBarcodeHint) {
      setState(() => _showBarcodeHint = false);
    }
    _startBarcodeHintTimer();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    // Smart fuzzy search: name, barcode, brand, category, size, diameter, pipeType, SKU, description
    final allProducts = HiveDatabase.productBox.values
        .map((m) => m.toEntity())
        .toList();

    final fuzzyResults = FuzzySearch.search<Product>(
      query: query,
      items: allProducts,
      getSearchableFields: (p) => [
        p.name,
        p.barcode,
        if (p.brand != null) p.brand!,
        if (p.category != null) p.category!,
        if (p.size != null) p.size!,
        if (p.diameter != null) p.diameter!,
        if (p.pipeType != null) p.pipeType!,
        if (p.sku != null) p.sku!,
        if (p.description != null) p.description!,
        if (p.origin != null) p.origin!,
        if (p.color != null) p.color!,
        // Also add numeric representations for measurements
        if (p.fullLength != null) p.fullLength!.toString(),
        if (p.fullPrice != null) p.fullPrice!.toString(),
      ],
      threshold: 0.28,
      maxResults: 12,
    );

    setState(() {
      _searchResults = fuzzyResults.map((e) => allProducts[e.key]).toList();
    });
  }

  void _addProductFromSearch(Product product) {
    context.read<BillingBloc>().add(AddProductToCartEvent(product));
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _isSearchOpen = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${product.name} added'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final rawValue = barcode.rawValue!;

        // Cooldown logic: 2 seconds per identical barcode
        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inSeconds < 2) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;
        _resetBarcodeHintTimer();

        // Vibrate
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate();
        }

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
        break; // Process one barcode at a time per frame
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Stack(
          children: [
            // SCANNER VIEW (TOP 50%)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: _buildScannerSection(),
            ),

            // BOTTOM PANEL (BOTTOM 50% + OVERLAP)
            Positioned(
              top: (MediaQuery.of(context).size.height * 0.4) - 24, // overlap
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
      bottomSheet:
          BlocBuilder<BillingBloc, BillingState>(builder: (context, state) {
        return PrimaryButton(
          onPressed: state.cartItems.isEmpty
              ? null
              : () async {
                  _scannerController.stop();
                  await context.push('/checkout');
                  if (_isCameraOn && mounted) _scannerController.start();
                },
          icon: Icons.payment,
          label: 'مراجعة الطلب والدفع',
        );
      }),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraOn)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return _buildCameraOffState();
              },
            )
          else
            _buildCameraOffState(),

          // Overlay Actions (Top Left - Financial Hub & Shop)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.account_balance_wallet,
                  color: Colors.indigo.shade700,
                  onPressed: () async {
                    _scannerController.stop();
                    await context.push('/financial-hub');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                _buildOverlayButton(
                  icon: Icons.storefront,
                  color: Colors.blue.shade800,
                  onPressed: () async {
                    _scannerController.stop();
                    await context.push('/shop');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
              ],
            ),
          ),

          // Overlay Actions (Top Right — essential controls only)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.settings,
                  onPressed: () async {
                    _scannerController.stop();
                    await context.push('/settings');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon:
                        _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: () {
                    setState(() {
                      _isCameraOn = !_isCameraOn;
                    });
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
                // Smart Recognition (AI) overlay button
                _buildOverlayButton(
                  icon: Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  onPressed: _openSmartRecognition,
                ),
              ],
            ),
          ),

          // Central Overlay Bounding Box
          if (_isCameraOn)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corners
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),

          // Primary AI Recognition Action Button (Prominent Floating Pill)
          if (_isCameraOn)
            Positioned(
              bottom: 28,
              left: 32,
              right: 32,
              child: ElevatedButton.icon(
                onPressed: _openSmartRecognition,
                icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                label: const Text(
                  '✨ بحث ذكي بالصورة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 8,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSmartRecognition() async {
    _scannerController.stop();
    _barcodeHintTimer?.cancel();
    setState(() => _showBarcodeHint = false);
    final result = await context.push('/recognize');
    if (result != null && result is Product && mounted) {
      context.read<BillingBloc>().add(
            AddProductToCartEvent(result),
          );
    }
    if (_isCameraOn && mounted) {
      _scannerController.start();
      _startBarcodeHintTimer();
    }
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B), // slate-800
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF334155), // slate-700
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.videocam_off, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'الكاميرا مطفأة',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'شغّل الكاميرا لمسح الباركود تلقائياً',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.videocam),
            label: const Text('تشغيل الكاميرا',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverlayButton(
      {required IconData icon, required VoidCallback onPressed, Color? color}) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildQuickNavChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
            right: (alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight)
                ? const BorderSide(color: Colors.greenAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          // Drag handle indicator
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Quick Navigation — Specialty Shortcuts Only
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildQuickNavChip(
                  icon: Icons.content_cut,
                  label: '✂️ قطع الأنابيب',
                  color: Colors.blue.shade700,
                  onTap: () async {
                    _scannerController.stop();
                    await context.push('/pipe-sales');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickNavChip(
                  icon: Icons.electrical_services,
                  label: '⚡ الكهرباء',
                  color: Colors.orange.shade700,
                  onTap: () async {
                    _scannerController.stop();
                    await context.push('/electrical-products');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickNavChip(
                  icon: Icons.format_paint,
                  label: '🎨 الطلاء',
                  color: Colors.green.shade700,
                  onTap: () async {
                    _scannerController.stop();
                    await context.push('/paint-products');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickNavChip(
                  icon: Icons.view_list,
                  label: '📦 الأنابيب',
                  color: Colors.blueGrey.shade600,
                  onTap: () async {
                    _scannerController.stop();
                    await context.push('/pipes');
                    if (_isCameraOn && mounted) _scannerController.start();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Header with search toggle
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              final totalItems =
                  state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سلة المشتريات',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          Text('$totalItems منتج',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    // Pipe POS Shortcut Button
                    Material(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => context.push('/pipe-sales'),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.content_cut, size: 18, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'قطع أنبوب',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Search toggle button
                    Material(
                      color: _isSearchOpen
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              _searchController.clear();
                              _searchResults = [];
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            _isSearchOpen ? Icons.close : Icons.search,
                            size: 20,
                            color: _isSearchOpen
                                ? Colors.white
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2)),
                        Text(
                          AppConstants.formatPrice(state.totalAmount),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Search bar (animated expand/collapse)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isSearchOpen
                ? _buildSearchSection()
                : const SizedBox.shrink(),
          ),

          const Divider(height: 1),

          // List View
          Expanded(
            child: Stack(children: [
              BlocBuilder<BillingBloc, BillingState>(
                builder: (context, state) {
                  if (state.cartItems.isEmpty && !_isSearchOpen) {
                    return _buildEmptyCart();
                  }

                  if (state.cartItems.isEmpty && _isSearchOpen) {
                    return _buildSearchHint();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(
                        left: 15, right: 15, top: 16, bottom: 100),
                    itemCount: state.cartItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return _buildCartItemCard(context, item);
                    },
                  );
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الماركة، الباركود...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty) ..._buildSearchResults(),

          // No results message
          if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'لم يتم العثور على "${_searchController.text}" — جرب كلمة قريبة',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSearchResults() {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor.withValues(alpha: 0.3);
    final onSurfaceColor = theme.colorScheme.onSurface;

    return [
      const SizedBox(height: 6),
      Container(
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
          itemBuilder: (context, index) {
            final product = _searchResults[index];
            final catColor = CategoryColorService.getColor(product.category);
            return InkWell(
              onTap: () => _addProductFromSearch(product),
              borderRadius: index == 0
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : index == _searchResults.length - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(12))
                      : BorderRadius.zero,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: catColor, width: 3),
                  ),
                  borderRadius: index == 0
                      ? const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12))
                      : index == _searchResults.length - 1
                          ? const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))
                          : BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Product image or colored icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: product.imagePaths.isNotEmpty && !kIsWeb
                          ? Image.file(
                              File(product.imagePaths.first),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: catColor),
                            )
                          : Icon(Icons.inventory_2_outlined,
                              size: 20,
                              color: catColor),
                    ),
                    const SizedBox(width: 10),
                    // Product details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13, color: onSurfaceColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(AppConstants.formatPrice(product.price),
                                  style: TextStyle(
                                      color: onSurfaceColor.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                              if (product.category != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    product.category!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: product.stock > 0
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.stock} وحدة',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: product.stock > 0 ? Colors.green.shade700 : Colors.red.shade400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Add button
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add, size: 18, color: Colors.green),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildSearchHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('ابحث عن المنتجات',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text('اكتب اسم المنتج أو الماركة أو الباركود — البحث يتحمل الأخطاء الإملائية ✨',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                Icon(Icons.shopping_basket, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          const Text('السلة فارغة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'امسح الباركود بالكاميرا أو ابحث عن المنتج باسمه لإضافته هنا',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    CartItem item,
  ) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = theme.dividerColor.withValues(alpha: 0.2);
    final onSurfaceColor = theme.colorScheme.onSurface;

    final catColor = CategoryColorService.getColor(item.product.category);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Colored left accent border for category
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: catColor,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [catColor, catColor.withValues(alpha: 0.6)],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 1,
                  children: [
                    // Product thumbnail with category color
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.product.imagePaths.isNotEmpty && !kIsWeb
                          ? Image.file(
                              File(item.product.imagePaths.first),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_outlined,
                                  color: catColor,
                                  size: 20),
                            )
                          : Icon(Icons.inventory_2_outlined,
                              color: catColor, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14, color: onSurfaceColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                AppConstants.formatPrice(item.product.price),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: onSurfaceColor.withValues(alpha: 0.6)),
                              ),
                              if (item.product.category != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: catColor.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    item.product.category!,
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: catColor),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _circularIconButton(
                              icon: Icons.remove,
                              color: onSurfaceColor,
                              onPressed: () {
                                if (item.quantity > 1) {
                                  context.read<BillingBloc>().add(UpdateQuantityEvent(
                                      item.product.id, item.quantity - 1));
                                } else {
                                  context
                                      .read<BillingBloc>()
                                      .add(RemoveProductFromCartEvent(item.product.id));
                                }
                              }),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor),
                            ),
                          ),
                          _circularIconButton(
                              icon: Icons.add,
                              color: onSurfaceColor,
                              onPressed: () {
                                context.read<BillingBloc>().add(UpdateQuantityEvent(
                                    item.product.id, item.quantity + 1));
                              }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularIconButton(
      {required IconData icon, required VoidCallback onPressed, Color? color}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 20, color: color ?? Colors.grey[600]),
      ),
    );
  }
}
