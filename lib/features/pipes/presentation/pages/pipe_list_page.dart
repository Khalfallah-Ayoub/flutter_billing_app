import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';

class PipeListPage extends StatefulWidget {
  const PipeListPage({super.key});

  @override
  State<PipeListPage> createState() => _PipeListPageState();
}

class _PipeListPageState extends State<PipeListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMaterial = 'all'; // 'all', 'pvc', 'copper', 'other'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addSamplePipes(BuildContext context) {
    final samplePipes = [
      const Product(
        id: 'PIPE-PVC-110',
        name: 'أنبوب PVC Ø110 (أبيض) [الجزائر]',
        barcode: 'PIPE-PVC-110',
        price: 200.0, // 1200 / 6
        stock: 25,
        isPipe: true,
        pipeType: 'pvc',
        fullLength: 6.0,
        fullPrice: 1200.0,
        diameter: '110',
        origin: 'الجزائر',
        color: 'أبيض',
        category: 'أنابيب (Pipes)',
        size: '110',
      ),
      const Product(
        id: 'PIPE-PVC-50',
        name: 'أنبوب PVC Ø50 (أسود) [الجزائر]',
        barcode: 'PIPE-PVC-50',
        price: 150.0, // 900 / 6
        stock: 40,
        isPipe: true,
        pipeType: 'pvc',
        fullLength: 6.0,
        fullPrice: 900.0,
        diameter: '50',
        origin: 'الجزائر',
        color: 'أسود',
        category: 'أنابيب (Pipes)',
        size: '50',
      ),
      const Product(
        id: 'PIPE-COPPER-16',
        name: 'أنبوب نحاس Ø16 (إيطاليا)',
        barcode: 'PIPE-COPPER-16',
        price: 700.0, // 3500 / 5
        stock: 15,
        isPipe: true,
        pipeType: 'copper',
        fullLength: 5.0,
        fullPrice: 3500.0,
        diameter: '16',
        origin: 'إيطاليا',
        color: 'نحاسي',
        category: 'أنابيب (Pipes)',
        size: '16',
      ),
    ];

    for (final pipe in samplePipes) {
      context.read<ProductBloc>().add(AddProduct(pipe));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الأنابيب والمقاييس',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_cut, color: AppTheme.primaryColor),
            tooltip: 'قص وبيع بالمتر',
            onPressed: () => context.push('/pipe-sales'),
          ),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          final allPipes = state.products.where((p) => p.isPipe).toList();

          // Filter by material & search query
          final filteredPipes = allPipes.where((pipe) {
            final matchesType = _selectedMaterial == 'all' || pipe.pipeType == _selectedMaterial;
            if (!matchesType) return false;

            if (_searchQuery.isEmpty) return true;

            final q = _searchQuery;
            final nameMatch = pipe.name.toLowerCase().contains(q);
            final diaMatch = (pipe.diameter ?? '').toLowerCase().contains(q);
            final colorMatch = (pipe.color ?? '').toLowerCase().contains(q);
            final originMatch = (pipe.origin ?? '').toLowerCase().contains(q);
            return nameMatch || diaMatch || colorMatch || originMatch;
          }).toList();

          return Column(
            children: [
              // Top Action Header & Quick Cut Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    // Search Bar
                    TextFormField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'بحث بنوع الأنبوب، المقياس، اللون، بلد الصنع...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Material Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'الكل (${allPipes.length})', Icons.border_all),
                          const SizedBox(width: 8),
                          _buildFilterChip('pvc', 'PVC (${allPipes.where((p) => p.pipeType == 'pvc').length})', Icons.square, color: Colors.blue),
                          const SizedBox(width: 8),
                          _buildFilterChip('copper', 'نحاس (${allPipes.where((p) => p.pipeType == 'copper').length})', Icons.circle, color: Colors.orange),
                          const SizedBox(width: 8),
                          _buildFilterChip('other', 'أخرى (${allPipes.where((p) => p.pipeType == 'other').length})', Icons.category, color: Colors.purple),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content List or Empty State
              Expanded(
                child: filteredPipes.isEmpty
                    ? _buildEmptyState(context, allPipes.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredPipes.length,
                        itemBuilder: (context, index) {
                          final pipe = filteredPipes[index];
                          return _buildPipeCard(context, pipe);
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pipes/add'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة أنبوب جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, {Color? color}) {
    final isSelected = _selectedMaterial == value;
    final theme = Theme.of(context);
    final activeColor = color ?? AppTheme.primaryColor;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : activeColor),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _selectedMaterial = value;
        });
      },
    );
  }

  Widget _buildPipeCard(BuildContext context, Product pipe) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    Color badgeColor;
    String typeLabel;
    switch (pipe.pipeType) {
      case 'pvc':
        badgeColor = Colors.blue;
        typeLabel = 'PVC';
        break;
      case 'copper':
        badgeColor = Colors.orange;
        typeLabel = 'نحاس';
        break;
      default:
        badgeColor = Colors.purple;
        typeLabel = 'أخرى';
        break;
    }

    final pricePerMeter = pipe.calculatedPricePerMeter;
    final fullLen = pipe.fullLength ?? 6.0;
    final fullPrice = pipe.fullPrice ?? pipe.price;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type Badge + Name + Actions
            Row(
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Spec
                Expanded(
                  child: Text(
                    pipe.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                // Popup Options
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (val) {
                    if (val == 'edit') {
                      context.push('/pipes/add', extra: pipe);
                    } else if (val == 'delete') {
                      _confirmDelete(context, pipe);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('تعديل البيانات'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف الأنبوب'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Spec Chips (Diameter, Origin, Color)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pipe.diameter != null && pipe.diameter!.isNotEmpty)
                  _buildSpecBadge(Icons.architecture, 'Ø ${pipe.diameter}'),
                if (pipe.color != null && pipe.color!.isNotEmpty)
                  _buildSpecBadge(Icons.palette_outlined, pipe.color!),
                if (pipe.origin != null && pipe.origin!.isNotEmpty)
                  _buildSpecBadge(Icons.flag_outlined, pipe.origin!),
                _buildSpecBadge(Icons.straighten, 'الطول: ${fullLen}م'),
              ],
            ),
            const SizedBox(height: 14),

            // Bottom Pricing Breakdown Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سعر الأنبوب الكامل (${fullLen}م):',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        AppConstants.formatPrice(fullPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),

                  // Divider
                  Container(height: 28, width: 1, color: Colors.grey[300]),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سعر المتر الواحد:',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '${AppConstants.formatPrice(pricePerMeter)} / متر',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),

                  // Quick Cut & Sell Button
                  ElevatedButton.icon(
                    onPressed: () => context.push('/pipe-sales', extra: pipe),
                    icon: const Icon(Icons.content_cut, size: 16),
                    label: const Text('بيع بالمتر'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTotalEmpty) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.architecture, size: 64, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              isTotalEmpty ? 'لا توجد أنابيب مسجلة حتى الآن' : 'لا توجد نتائج تطابق بحثك',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              isTotalEmpty
                  ? 'يمكنك إضافة أنابيب البلاستيك (PVC)، النحاس، وغيرها وتحديد الأطوال والأسعار للحساب التلقائي.'
                  : 'جرب تغيير تصفية البحث أو اختيار نوع أنبوب آخر.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (isTotalEmpty)
              ElevatedButton.icon(
                onPressed: () => _addSamplePipes(context),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('إضافة عينة من الأنابيب للاختبار السريع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product pipe) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت أخيرًا متاكد من حذف الأنبوب "${pipe.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProductBloc>().add(DeleteProduct(pipe.id));
              dialogContext.pop();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
