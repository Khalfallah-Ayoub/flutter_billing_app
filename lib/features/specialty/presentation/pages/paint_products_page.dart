import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/category_color_service.dart';
import '../../../../core/utils/fuzzy_search.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../billing/presentation/bloc/billing_bloc.dart';

/// Specialized page for browsing and selling paint/coating products.
/// Shows ALL products, filterable by category, with smart fuzzy search.
class PaintProductsPage extends StatefulWidget {
  const PaintProductsPage({super.key});

  @override
  State<PaintProductsPage> createState() => _PaintProductsPageState();
}

class _PaintProductsPageState extends State<PaintProductsPage> {
  String _searchQuery = '';
  String? _selectedCategory; // null = show all paint-related by keyword
  final TextEditingController _searchController = TextEditingController();

  // Keywords that suggest a product is paint-related
  static const _paintKeywords = [
    'طلاء', 'دهان', 'بويا', 'صبغ', 'اصباغ', 'أصباغ', 'صباغة',
    'paint', 'فرشاة', 'رولو', 'معجون', 'بريمر', 'primer',
    'لكة', 'لكيه', 'لاك', 'تخفيف', 'سقف', 'جدار',
  ];

  bool _isPaintProduct(Product p) {
    final cat = (p.category ?? '').toLowerCase();
    final name = p.name.toLowerCase();
    final desc = (p.description ?? '').toLowerCase();
    return _paintKeywords.any((kw) =>
        cat.contains(kw) || name.contains(kw) || desc.contains(kw));
  }

  List<Product> _getFilteredProducts(List<Product> all) {
    List<Product> base;

    if (_selectedCategory != null) {
      base = all.where((p) => p.category == _selectedCategory).toList();
    } else {
      base = all.where(_isPaintProduct).toList();
    }

    if (_searchQuery.trim().isEmpty) return base;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<ProductBloc>().state.products;
    final filtered = _getFilteredProducts(allProducts);
    final allCategories = _getAllCategories(allProducts);
    final catColor = _selectedCategory != null
        ? CategoryColorService.getColor(_selectedCategory)
        : CategoryColorService.getColor('طلاء');

    return Scaffold(
      appBar: AppBar(
        title: const Text('منتجات الطلاء 🎨',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'إضافة منتج',
            onPressed: () => context.push('/products/add'),
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
                const Icon(Icons.format_paint, color: Colors.white, size: 26),
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
                            : 'جميع منتجات الطلاء والدهان',
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
                          style: TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  label: 'الطلاء (افتراضي)',
                  selected: _selectedCategory == null,
                  color: CategoryColorService.getColor('طلاء'),
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ...allCategories.map((cat) => _buildFilterChip(
                      label: cat,
                      selected: _selectedCategory == cat,
                      color: CategoryColorService.getColor(cat),
                      onTap: () => setState(() =>
                          _selectedCategory = _selectedCategory == cat ? null : cat),
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
          Icon(Icons.format_paint, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('لا توجد منتجات',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 6),
          const Text(
            'غيّر الفئة أو اضف منتجات جديدة\nبفئة تحتوي على كلمة "طلاء" أو "دهان"',
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
              // Top accent
              Container(height: 5, color: catColor),

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
                            Icons.format_paint,
                            color: catColor.withValues(alpha: 0.5),
                            size: 36),
                      )
                    : Icon(Icons.format_paint,
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
                            child: Text(
                              AppConstants.formatPrice(product.price),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 18),
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
