import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/category_color_service.dart';
import '../../../../core/utils/fuzzy_search.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';

/// Specialized page for browsing and selling electrical products.
/// Shows ALL products, filterable by category, with smart fuzzy search.
class ElectricalProductsPage extends StatefulWidget {
  const ElectricalProductsPage({super.key});

  @override
  State<ElectricalProductsPage> createState() => _ElectricalProductsPageState();
}

class _ElectricalProductsPageState extends State<ElectricalProductsPage> {
  String _searchQuery = '';
  String? _selectedCategory; // null = show all
  final TextEditingController _searchController = TextEditingController();

  // Keywords that suggest a product is electrical — used for smart default filter
  static const _electricalKeywords = [
    'كهرباء', 'كهربائي', 'كهربائية', 'electric', 'electrical',
    'كابل', 'سلك', 'أسلاك', 'قاطع', 'مفتاح', 'مفاتيح',
    'فيش', 'لمبة', 'إضاءة', 'اضاءة', 'led', 'cable', 'wire',
    'تمديد', 'لوحة', 'محول', 'فيوز', 'درج', 'مقبس',
  ];

  bool _isElectricalProduct(Product p) {
    final cat = (p.category ?? '').toLowerCase();
    final name = p.name.toLowerCase();
    final desc = (p.description ?? '').toLowerCase();
    return _electricalKeywords.any((kw) =>
        cat.contains(kw) || name.contains(kw) || desc.contains(kw));
  }

  List<Product> _getFilteredProducts(List<Product> all) {
    List<Product> base;

    if (_selectedCategory != null) {
      // Specific category chosen
      base = all.where((p) => p.category == _selectedCategory).toList();
    } else {
      // Default: smart filter for electrical products
      base = all.where(_isElectricalProduct).toList();
    }

    if (_searchQuery.trim().isEmpty) return base;

    // Smart fuzzy search within filtered set
    final results = FuzzySearch.search<Product>(
      query: _searchQuery,
      items: base,
      getSearchableFields: (p) => [
        p.name,
        p.barcode,
        if (p.category != null) p.category!,
        if (p.brand != null) p.brand!,
        if (p.size != null) p.size!,
        if (p.description != null) p.description!,
      ],
      threshold: 0.28,
      maxResults: 50,
    );
    return results.map((e) => base[e.key]).toList();
  }

  List<String> _getAllCategories(List<Product> all) {
    final cats = <String>{};
    for (final p in all) {
      if (p.category != null && p.category!.isNotEmpty) {
        cats.add(p.category!);
      }
    }
    return cats.toList()..sort();
  }

  void _addToCart(Product product) {
    if (product.isPipe) {
      // Wire/cable sold by meter — show cutting modal
      _showMeterCuttingSheet(product);
    } else {
      // Regular product — add directly
      context.read<BillingBloc>().add(AddProductToCartEvent(product));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${product.name} أُضيف للسلة',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 700),
          margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showMeterCuttingSheet(Product product) {
    double meters = 1.0;
    final pricePerMeter = product.calculatedPricePerMeter;
    final fullLength = product.fullLength ?? 100.0;
    final presets = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, fullLength];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final total = meters * pricePerMeter;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cable, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${AppConstants.formatPrice(pricePerMeter)}/متر — اللفة: ${fullLength.toStringAsFixed(0)} متر',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick meter presets
                  const Text('اختيار سريع:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: presets.map((m) {
                      final isSelected = meters == m;
                      final isFullRoll = m == fullLength;
                      return ChoiceChip(
                        label: Text(
                          isFullRoll ? 'لفة كاملة (${m.toStringAsFixed(0)}م)' : '${m.toStringAsFixed(0)} متر',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : null,
                            fontWeight: isFullRoll ? FontWeight.bold : null,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: isFullRoll ? Colors.orange : AppTheme.primaryColor,
                        onSelected: (_) => setSheetState(() => meters = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Custom meter input
                  const Text('أو أدخل عدد الأمتار:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: meters > 0.5
                            ? () => setSheetState(() => meters = (meters - 0.5).clamp(0.5, fullLength))
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red,
                      ),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: meters.toString()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                          decoration: InputDecoration(
                            suffixText: 'متر',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) {
                            final val = double.tryParse(v) ?? 0;
                            setSheetState(() => meters = val.clamp(0.0, fullLength));
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: meters < fullLength
                            ? () => setSheetState(() => meters = (meters + 0.5).clamp(0.5, fullLength))
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${meters.toStringAsFixed(1)} متر × ${AppConstants.formatPrice(pricePerMeter)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('الإجمالي', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                        Text(AppConstants.formatPrice(total),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 22, color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Add to cart button
                  ElevatedButton.icon(
                    onPressed: meters > 0
                        ? () {
                            final cutProduct = Product(
                              id: 'CUT-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
                              name: '${product.name} (${meters.toStringAsFixed(1)} م)',
                              barcode: product.barcode,
                              price: total,
                              costPrice: product.costPrice > 0 && product.fullLength != null && product.fullLength! > 0
                                  ? (product.costPrice / product.fullLength!) * meters
                                  : 0,
                              isPipe: true,
                              fullLength: meters,
                              fullPrice: total,
                              category: product.category,
                              diameter: product.diameter,
                            );
                            context.read<BillingBloc>().add(AddProductToCartEvent(cutProduct));
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} — ${meters.toStringAsFixed(1)} متر أُضيف للسلة'),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                    label: const Text('أضف للسلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddWireSheet() {
    final nameCtrl = TextEditingController();
    final lengthCtrl = TextEditingController(text: '100');
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final diameterCtrl = TextEditingController();
    final meterPriceCtrl = TextEditingController();
    const uuid = Uuid();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final length = double.tryParse(lengthCtrl.text) ?? 0;
          final fullPrice = double.tryParse(priceCtrl.text) ?? 0;
          final autoPrice = (length > 0 && fullPrice > 0) ? fullPrice / length : 0.0;
          final customMeterPrice = double.tryParse(meterPriceCtrl.text);

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cable, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('إضافة سلك / كابل كهربائي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _wireField(nameCtrl, 'اسم السلك/الكابل *', Icons.cable,
                      hint: 'مثلاً: سلك نحاس 2.5mm'),
                  const SizedBox(height: 12),
                  _wireField(diameterCtrl, 'المقطع / القطر (اختياري)', Icons.straighten,
                      hint: 'مثلاً: 1.5mm², 2.5mm², 4mm²'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _wireField(lengthCtrl, 'طول اللفة (متر) *', Icons.straighten,
                            keyboard: TextInputType.number,
                            onChanged: (_) => setSheetState(() {})),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _wireField(priceCtrl, 'سعر اللفة كاملة *', Icons.attach_money,
                            keyboard: TextInputType.number,
                            onChanged: (_) => setSheetState(() {})),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _wireField(costCtrl, 'سعر التكلفة (اختياري)', Icons.money_off,
                      keyboard: TextInputType.number,
                      hint: 'سعر الشراء للفة كاملة'),
                  const SizedBox(height: 12),
                  _wireField(meterPriceCtrl, 'سعر المتر (اختياري)', Icons.price_change,
                      keyboard: TextInputType.number,
                      hint: autoPrice > 0
                          ? 'تلقائي: ${autoPrice.toStringAsFixed(1)} دج/م — أدخل سعر مختلف إن أردت'
                          : 'إن لم تُدخله يُحسب تلقائياً من سعر اللفة',
                      onChanged: (_) => setSheetState(() {})),
                  if (autoPrice > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (customMeterPrice != null ? Colors.orange : Colors.blue)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            customMeterPrice != null ? Icons.edit : Icons.auto_awesome,
                            size: 16,
                            color: customMeterPrice != null ? Colors.orange : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customMeterPrice != null
                                  ? 'سعر المتر المخصص: ${customMeterPrice.toStringAsFixed(1)} دج (بدل ${autoPrice.toStringAsFixed(1)} دج)'
                                  : 'سعر المتر التلقائي: ${autoPrice.toStringAsFixed(1)} دج',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: customMeterPrice != null ? Colors.orange.shade800 : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final length = double.tryParse(lengthCtrl.text) ?? 0;
                      final fullPrice = double.tryParse(priceCtrl.text) ?? 0;
                      if (name.isEmpty || length <= 0 || fullPrice <= 0) return;

                      final autoCalc = fullPrice / length;
                      final customPrice = double.tryParse(meterPriceCtrl.text);
                      final finalPricePerMeter = (customPrice != null && customPrice > 0)
                          ? customPrice
                          : autoCalc;
                      final costPrice = double.tryParse(costCtrl.text) ?? 0;

                      final product = Product(
                        id: uuid.v4(),
                        name: name,
                        barcode: 'WIRE-${DateTime.now().millisecondsSinceEpoch}',
                        price: finalPricePerMeter,
                        costPrice: costPrice,
                        isPipe: true,
                        fullLength: length,
                        fullPrice: fullPrice,
                        category: 'كهرباء',
                        diameter: diameterCtrl.text.trim().isEmpty ? null : diameterCtrl.text.trim(),
                      );
                      context.read<ProductBloc>().add(AddProduct(product));
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم إضافة $name — ${finalPricePerMeter.toStringAsFixed(1)} دج/متر'),
                          backgroundColor: Colors.green.shade700,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('حفظ السلك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _wireField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard, String? hint, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<ProductBloc>().state.products;
    final filtered = _getFilteredProducts(allProducts);
    final allCategories = _getAllCategories(allProducts);
    final catColor = _selectedCategory != null
        ? CategoryColorService.getColor(_selectedCategory)
        : CategoryColorService.getColor('كهرباء');

    return Scaffold(
      appBar: AppBar(
        title: const Text('منتجات الكهرباء ⚡',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'إضافة منتج',
            onSelected: (val) {
              if (val == 'product') {
                context.push('/products/add');
              } else if (val == 'wire') {
                _showAddWireSheet();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'product',
                child: Row(children: [
                  Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('منتج عادي (مصباح، مفتاح...)'),
                ]),
              ),
              const PopupMenuItem(
                value: 'wire',
                child: Row(children: [
                  Icon(Icons.cable, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('سلك / كابل (يباع بالمتر)'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor, catColor.withValues(alpha: 0.75)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.electrical_services, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${filtered.length} منتج معروض',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        _selectedCategory != null
                            ? 'فئة: $_selectedCategory'
                            : 'جميع المنتجات الكهربائية',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_selectedCategory != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategory = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('الكل',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث ذكي: اسم، فئة، ماركة...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Category filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildFilterChip(
                  label: 'الكهربائية (افتراضي)',
                  selected: _selectedCategory == null,
                  color: CategoryColorService.getColor('كهرباء'),
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ...allCategories.map((cat) => _buildFilterChip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      color: CategoryColorService.getColor(cat),
                      onTap: () => setState(
                          () => _selectedCategory = _selectedCategory == cat ? null : cat),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Products Grid
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildProductCard(filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.electrical_services, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد منتجات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text(
            'غيّر الفئة أو اضف منتجات جديدة\nبفئة تحتوي على كلمة "كهرباء"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/products/add'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة منتج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final catColor = CategoryColorService.getColor(product.category);

    return Material(
      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: catColor.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () => _addToCart(product),
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top color accent bar
              Container(
                height: 5,
                color: catColor,
              ),

              // Image or icon area
              Container(
                height: 70,
                width: double.infinity,
                color: catColor.withValues(alpha: 0.06),
                child: product.imagePaths.isNotEmpty && !kIsWeb
                    ? Image.file(
                        File(product.imagePaths.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.electrical_services,
                            color: catColor.withValues(alpha: 0.5),
                            size: 36),
                      )
                    : Icon(Icons.electrical_services,
                        color: catColor.withValues(alpha: 0.5), size: 36),
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.category != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: catColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            product.category!,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: catColor),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.isPipe
                                      ? '${AppConstants.formatPrice(product.calculatedPricePerMeter)}/م'
                                      : AppConstants.formatPrice(product.price),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                if (product.isPipe && product.fullLength != null)
                                  Text(
                                    'لفة ${product.fullLength!.toStringAsFixed(0)}م',
                                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: product.isPipe ? Colors.orange.shade600 : Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              product.isPipe ? Icons.cable : Icons.add,
                              color: Colors.white, size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
