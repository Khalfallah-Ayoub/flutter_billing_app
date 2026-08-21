import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';

class PipeCuttingSalePage extends StatefulWidget {
  final Product? initialPipe;

  const PipeCuttingSalePage({super.key, this.initialPipe});

  @override
  State<PipeCuttingSalePage> createState() => _PipeCuttingSalePageState();
}

class _PipeCuttingSalePageState extends State<PipeCuttingSalePage> {
  Product? _selectedPipe;
  final TextEditingController _metersController = TextEditingController(text: '1.0');
  String _selectedMaterialFilter = 'all';

  double _requestedMeters = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedPipe = widget.initialPipe;
    _metersController.addListener(_updateMeters);
  }

  @override
  void dispose() {
    _metersController.removeListener(_updateMeters);
    _metersController.dispose();
    super.dispose();
  }

  void _updateMeters() {
    final val = double.tryParse(_metersController.text.trim());
    setState(() {
      _requestedMeters = (val != null && val > 0) ? val : 0.0;
    });
  }

  void _setPresetMeters(double meters) {
    _metersController.text = meters.toString();
    setState(() {
      _requestedMeters = meters;
    });
  }

  double get _calculatedTotal {
    if (_selectedPipe == null || _requestedMeters <= 0) return 0.0;
    return _requestedMeters * _selectedPipe!.calculatedPricePerMeter;
  }

  void _addToCart() {
    if (_selectedPipe == null || _requestedMeters <= 0) return;

    final pipe = _selectedPipe!;
    final totalAmount = _calculatedTotal;

    // Format cut item name e.g. "أنبوب PVC Ø110 (1.5 متر)"
    final cutItemName = '${pipe.name.split('(').first.trim()} (${_requestedMeters.toStringAsFixed(_requestedMeters.truncateToDouble() == _requestedMeters ? 0 : 2)} متر)';

    final cutProduct = Product(
      id: 'CUT-${pipe.id}-${DateTime.now().millisecondsSinceEpoch}',
      name: cutItemName,
      barcode: pipe.barcode,
      price: totalAmount, // Exact total calculated price
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تمت إضافة "$cutItemName" إلى الفاتورة بمبلغ ${AppConstants.formatPrice(totalAmount)}'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'عرض الفاتورة',
          textColor: Colors.white,
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'حاسبة بيع الأنابيب بالمتر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final pipes = state.products.where((p) => p.isPipe).toList();

          if (_selectedPipe == null && pipes.isNotEmpty) {
            _selectedPipe = pipes.first;
          }

          final filteredPipes = pipes.where((p) {
            if (_selectedMaterialFilter == 'all') return true;
            return p.pipeType == _selectedMaterialFilter;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Pipe Selection Dropdown & Filter
                Text(
                  'اختر الأنبوب المراد قطعه وبيعه:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),

                // Material Filters
                Row(
                  children: [
                    _buildFilterChip('all', 'الكل'),
                    const SizedBox(width: 6),
                    _buildFilterChip('pvc', 'PVC', color: Colors.blue),
                    const SizedBox(width: 6),
                    _buildFilterChip('copper', 'نحاس', color: Colors.orange),
                    const SizedBox(width: 6),
                    _buildFilterChip('other', 'أخرى', color: Colors.purple),
                  ],
                ),
                const SizedBox(height: 12),

                // Pipe Dropdown / Selector
                if (filteredPipes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text(
                      'لا توجد أنابيب من هذا النوع. يرجى إضافة أنبوب أولاً من صفحة إدارة الأنابيب.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Product>(
                        value: filteredPipes.contains(_selectedPipe) ? _selectedPipe : filteredPipes.first,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryColor),
                        items: filteredPipes.map((pipe) {
                          return DropdownMenuItem<Product>(
                            value: pipe,
                            child: Row(
                              children: [
                                Icon(
                                  pipe.pipeType == 'copper'
                                      ? Icons.circle
                                      : pipe.pipeType == 'pvc'
                                          ? Icons.square
                                          : Icons.category,
                                  size: 16,
                                  color: pipe.pipeType == 'copper'
                                      ? Colors.orange
                                      : pipe.pipeType == 'pvc'
                                          ? Colors.blue
                                          : Colors.purple,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pipe.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${AppConstants.formatPrice(pipe.calculatedPricePerMeter)}/متر',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newPipe) {
                          setState(() {
                            _selectedPipe = newPipe;
                          });
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Section 2: Selected Pipe Rate Details Card
                if (_selectedPipe != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الطول الكامل للأنبوب الأصلي:',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            Text(
                              '${_selectedPipe!.fullLength ?? 6.0} متر',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سعر الأنبوب الكامل:',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            Text(
                              AppConstants.formatPrice(_selectedPipe!.fullPrice ?? _selectedPipe!.price),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.flash_on, color: AppTheme.primaryColor, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'معدل سعر المتر الواحد:',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                            Text(
                              '${AppConstants.formatPrice(_selectedPipe!.calculatedPricePerMeter)} / متر',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Length Input & Presets
                  Text(
                    'الطول المطلـوب قطعه بالمتر (Meters requested):',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _metersController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            suffixText: 'متر',
                            prefixIcon: const Icon(Icons.straighten, color: AppTheme.primaryColor),
                            hintText: '0.0',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Preset Meter Buttons (e.g. 0.5m, 1m, 1.5m, 2.75m, full length)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(0.5, '0.5 متر'),
                      _buildPresetChip(1.0, '1 متر'),
                      _buildPresetChip(1.5, '1.5 متر'),
                      _buildPresetChip(2.0, '2 متر'),
                      _buildPresetChip(2.5, '2.5 متر'),
                      _buildPresetChip(2.75, '2.75 متر'),
                      if (_selectedPipe != null && _selectedPipe!.fullLength != null)
                        _buildPresetChip(_selectedPipe!.fullLength!, 'أنبوب كامل (${_selectedPipe!.fullLength}م)', isFull: true),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 4: Live Dynamic Calculation Result Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'معادلة الحساب التلقائي:',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              '${_requestedMeters.toStringAsFixed(2)} م × ${AppConstants.formatPrice(_selectedPipe!.calculatedPricePerMeter)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'المبلغ الإجمالي المطلـوب:',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              AppConstants.formatPrice(_calculatedTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add to Cart Button
                  ElevatedButton.icon(
                    onPressed: _calculatedTotal > 0 ? _addToCart : null,
                    icon: const Icon(Icons.shopping_cart_checkout, size: 22),
                    label: const Text(
                      'إضافة الأنبوب إلى الفاتورة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, {Color? color}) {
    final isSelected = _selectedMaterialFilter == value;
    final activeColor = color ?? AppTheme.primaryColor;

    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _selectedMaterialFilter = value;
        });
      },
    );
  }

  Widget _buildPresetChip(double meters, String label, {bool isFull = false}) {
    final isSelected = (_requestedMeters - meters).abs() < 0.01;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isFull ? Colors.amber[900] : AppTheme.primaryColor),
          fontWeight: isSelected || isFull ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: isSelected
          ? AppTheme.primaryColor
          : (isFull ? Colors.amber.withValues(alpha: 0.15) : AppTheme.primaryColor.withValues(alpha: 0.08)),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : (isFull ? Colors.amber : AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      onPressed: () => _setPresetMeters(meters),
    );
  }
}
