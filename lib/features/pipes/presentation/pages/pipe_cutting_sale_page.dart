import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../data/services/pipe_category_service.dart';
import '../../domain/entities/pipe_category.dart';

class PipeCuttingSalePage extends StatefulWidget {
  final Product? initialPipe;
  const PipeCuttingSalePage({super.key, this.initialPipe});

  @override
  State<PipeCuttingSalePage> createState() => _PipeCuttingSalePageState();
}

class _PipeCuttingSalePageState extends State<PipeCuttingSalePage> {
  Product? _selectedPipe;
  double _requestedMeters = 1.0;
  int _pipeQuantity = 1; // Number of full pipes to sell
  bool _isPerMeterMode = true; // true = per meter, false = full pipe(s)
  String? _selectedCategoryFilter;

  final List<double> _presets = [0.25, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0];

  @override
  void initState() {
    super.initState();
    _selectedPipe = widget.initialPipe;
  }

  double get _calculatedTotal {
    if (_selectedPipe == null) return 0.0;
    if (_isPerMeterMode) {
      if (_requestedMeters <= 0) return 0.0;
      return _requestedMeters * _selectedPipe!.calculatedPricePerMeter;
    } else {
      // Full pipe(s) mode
      return _pipeQuantity * (_selectedPipe!.fullPrice ?? _selectedPipe!.price);
    }
  }

  void _adjustMeters(double delta) {
    setState(() {
      _requestedMeters = (_requestedMeters + delta).clamp(0.25, 100.0);
      // Round to 2 decimal places
      _requestedMeters = double.parse(_requestedMeters.toStringAsFixed(2));
    });
  }

  void _setPreset(double meters) => setState(() => _requestedMeters = meters);

  void _addToCart() {
    if (_selectedPipe == null) return;
    final pipe = _selectedPipe!;

    if (_isPerMeterMode) {
      if (_requestedMeters <= 0) return;
      final total = _calculatedTotal;
      final metersStr = _requestedMeters == _requestedMeters.truncateToDouble()
          ? _requestedMeters.toInt().toString()
          : _requestedMeters.toStringAsFixed(2);
      final cutName = '${pipe.name.split('(').first.trim()} ($metersStr م)';

      final cutProduct = Product(
        id: 'CUT-${pipe.id}-${DateTime.now().millisecondsSinceEpoch}',
        name: cutName,
        barcode: pipe.barcode,
        price: total,
        stock: pipe.stock,
        category: pipe.category,
        size: pipe.size,
        brand: pipe.brand,
        isPipe: true,
        pipeType: pipe.pipeType,
        fullLength: pipe.fullLength,
        fullPrice: pipe.fullPrice,
        diameter: pipe.diameter,
        origin: pipe.origin,
        color: pipe.color,
      );
      context.read<BillingBloc>().add(AddProductToCartEvent(cutProduct));
      _showSuccessSnack(cutName, total);
    } else {
      // Full pipe(s) mode — add as regular product with quantity
      if (_pipeQuantity <= 0) return;
      final unitPrice = pipe.fullPrice ?? pipe.price;
      final total = unitPrice * _pipeQuantity;
      final pipeName = pipe.name.split('(').first.trim();

      for (int i = 0; i < _pipeQuantity; i++) {
        final p = Product(
          id: 'PIPE-${pipe.id}-${DateTime.now().millisecondsSinceEpoch}-$i',
          name: pipeName,
          barcode: pipe.barcode,
          price: unitPrice,
          stock: pipe.stock,
          category: pipe.category,
          size: pipe.size,
          brand: pipe.brand,
          isPipe: true,
          pipeType: pipe.pipeType,
          fullLength: pipe.fullLength,
          fullPrice: pipe.fullPrice,
          diameter: pipe.diameter,
          origin: pipe.origin,
          color: pipe.color,
        );
        context.read<BillingBloc>().add(AddProductToCartEvent(p));
      }
      _showSuccessSnack('$_pipeQuantity × $pipeName', total);
    }
  }

  void _showSuccessSnack(String name, double total) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$name — ${AppConstants.formatPrice(total)}',
            style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('قطع وبيع الأنابيب ✂️',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'إضافة أنبوب',
            onPressed: () => context.push('/pipes/add'),
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final allPipes = state.products.where((p) => p.isPipe).toList();
          final categories = PipeCategoryService.getCategories();

          // Filter by category
          final pipes = _selectedCategoryFilter == null
              ? allPipes
              : allPipes.where((p) {
                  final pt = (p.pipeType ?? '').toLowerCase();
                  final sel = _selectedCategoryFilter!.toLowerCase();
                  return pt == sel || pt.contains(sel) || sel.contains(pt);
                }).toList();

          // Auto-select first pipe when filter changes
          if (pipes.isNotEmpty &&
              (_selectedPipe == null || !pipes.contains(_selectedPipe))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedPipe = pipes.first);
            });
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Mode Toggle ──────────────────────────────────
                      _buildSectionTitle('وضع البيع'),
                      const SizedBox(height: 8),
                      _buildModeToggle(),
                      const SizedBox(height: 14),

                      // ── Category Filter Chips ──────────────────────
                      _buildSectionTitle('نوع المادة'),
                      const SizedBox(height: 8),
                      _buildCategoryChips(categories),
                      const SizedBox(height: 14),

                      // ── Pipe Selection Cards ───────────────────────
                      _buildSectionTitle('اختر الأنبوب'),
                      const SizedBox(height: 8),
                      pipes.isEmpty
                          ? _buildNoPipesWarning()
                          : _buildPipeCards(pipes, cardColor),
                      const SizedBox(height: 14),

                      // ── Selected Pipe Info ─────────────────────────
                      if (_selectedPipe != null) ...[
                        _buildPipeInfoCard(_selectedPipe!, cardColor, theme),
                        const SizedBox(height: 14),
                      ],

                      // ── Per-Meter or Full-Pipe Input ───────────────
                      if (_isPerMeterMode) ...[
                        _buildSectionTitle('الطول المطلوب بالمتر'),
                        const SizedBox(height: 8),
                        _buildMetersInput(theme),
                        const SizedBox(height: 10),
                        _buildPresetButtons(),
                      ] else ...[
                        _buildSectionTitle('عدد الأنابيب الكاملة'),
                        const SizedBox(height: 8),
                        _buildQuantitySelector(theme),
                        const SizedBox(height: 4),
                        if (_selectedPipe != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'سعر أنبوب كامل: ${AppConstants.formatPrice(_selectedPipe!.fullPrice ?? _selectedPipe!.price)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),

                      // ── Total Card ─────────────────────────────────
                      if (_selectedPipe != null)
                        _buildTotalCard(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ── Bottom Add Button ──────────────────────────────────
              if (_selectedPipe != null)
                _buildAddButton(),
            ],
          );
        },
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPerMeterMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isPerMeterMode ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.straighten,
                        size: 18,
                        color: _isPerMeterMode ? Colors.white : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'قطع بالمتر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isPerMeterMode ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPerMeterMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isPerMeterMode ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2,
                        size: 18,
                        color: !_isPerMeterMode ? Colors.white : Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'أنابيب كاملة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_isPerMeterMode ? Colors.white : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            color: Colors.red.shade400,
            onTap: () => setState(() => _pipeQuantity = (_pipeQuantity - 1).clamp(1, 99)),
            onLongPress: () => setState(() => _pipeQuantity = (_pipeQuantity - 5).clamp(1, 99)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$_pipeQuantity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor),
                ),
                Text('أنبوب', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            color: Colors.green.shade600,
            onTap: () => setState(() => _pipeQuantity = (_pipeQuantity + 1).clamp(1, 99)),
            onLongPress: () => setState(() => _pipeQuantity = (_pipeQuantity + 5).clamp(1, 99)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
    ),
  );

  Widget _buildCategoryChips(List<PipeCategory> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _CategoryChip(
          label: 'الكل',
          selected: _selectedCategoryFilter == null,
          color: AppTheme.primaryColor,
          onTap: () => setState(() => _selectedCategoryFilter = null),
        ),
        ...categories.map((cat) {
          final color = _categoryColor(cat.id);
          return _CategoryChip(
            label: cat.name,
            selected: _selectedCategoryFilter == cat.id,
            color: color,
            subtitle: '${cat.defaultLength}م',
            onTap: () => setState(() => _selectedCategoryFilter =
                _selectedCategoryFilter == cat.id ? null : cat.id),
          );
        }),
      ],
    );
  }

  Widget _buildPipeCards(List<Product> pipes, Color cardColor) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final pipe = pipes[i];
          final isSelected = _selectedPipe?.id == pipe.id;
          final color = _categoryColor(pipe.pipeType ?? '');
          return GestureDetector(
            onTap: () => setState(() => _selectedPipe = pipe),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.25),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
                    : null,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pipe.pipeType?.toUpperCase() ?? '—',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    pipe.name.split('(').first.trim(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '${AppConstants.formatPrice(pipe.calculatedPricePerMeter)}/م',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPipeInfoCard(Product pipe, Color cardColor, ThemeData theme) {
    final color = _categoryColor(pipe.pipeType ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.architecture, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  'طول كامل: ${pipe.fullLength ?? 6}م  |  سعر أنبوب: ${AppConstants.formatPrice(pipe.fullPrice ?? pipe.price)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('سعر المتر', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              Text(
                AppConstants.formatPrice(pipe.calculatedPricePerMeter),
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetersInput(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Minus
          _StepButton(
            icon: Icons.remove,
            color: Colors.red.shade400,
            onTap: () => _adjustMeters(-0.25),
            onLongPress: () => _adjustMeters(-1.0),
          ),
          // Value display
          Expanded(
            child: GestureDetector(
              onTap: () => _showCustomInputDialog(),
              child: Column(
                children: [
                  Text(
                    _requestedMeters == _requestedMeters.truncateToDouble()
                        ? _requestedMeters.toInt().toString()
                        : _requestedMeters.toStringAsFixed(2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor),
                  ),
                  Text('متر', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          // Plus
          _StepButton(
            icon: Icons.add,
            color: Colors.green.shade600,
            onTap: () => _adjustMeters(0.25),
            onLongPress: () => _adjustMeters(1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButtons() {
    final fullLength = _selectedPipe?.fullLength;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ..._presets.map((m) {
          final isSelected = (_requestedMeters - m).abs() < 0.01;
          return _PresetBtn(
            label: m == m.truncateToDouble() ? '${m.toInt()}م' : '${m}م',
            selected: isSelected,
            onTap: () => _setPreset(m),
          );
        }),
        if (fullLength != null)
          _PresetBtn(
            label: 'كامل (${fullLength}م)',
            selected: (_requestedMeters - fullLength).abs() < 0.01,
            onTap: () => _setPreset(fullLength),
            isFullPipe: true,
          ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الإجمالي', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${_requestedMeters.toStringAsFixed(2)} م × ${AppConstants.formatPrice(_selectedPipe!.calculatedPricePerMeter)}',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          Text(
            AppConstants.formatPrice(_calculatedTotal),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: ElevatedButton.icon(
          onPressed: _calculatedTotal > 0 ? _addToCart : null,
          icon: const Icon(Icons.shopping_cart_checkout, size: 22),
          label: Text(
            'إضافة للفاتورة  ${_calculatedTotal > 0 ? AppConstants.formatPrice(_calculatedTotal) : ""}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildNoPipesWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        children: [
          const Text('لا توجد أنابيب من هذا النوع',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/pipes/add'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('إضافة أنبوب'),
          ),
        ],
      ),
    );
  }

  void _showCustomInputDialog() {
    final ctrl = TextEditingController(text: _requestedMeters.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أدخل الطول بالمتر'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'متر',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) setState(() => _requestedMeters = v);
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String pipeType) {
    switch (pipeType.toLowerCase()) {
      case 'pvc': return const Color(0xFF1976D2);
      case 'copper': return const Color(0xFFE65100);
      case 'pprc':
      case 'pp': return const Color(0xFF388E3C);
      case 'iron':
      case 'steel': return const Color(0xFF546E7A);
      case 'hdpe': return const Color(0xFF6A1B9A);
      default: return const Color(0xFF37474F);
    }
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : color),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Text(
                subtitle!,
                style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.white70 : color.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFullPipe;

  const _PresetBtn({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isFullPipe = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFullPipe ? Colors.amber.shade800 : AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : color),
        ),
      ),
    );
  }
}
