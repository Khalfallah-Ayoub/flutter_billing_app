import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/pipe_category.dart';
import '../../data/services/pipe_category_service.dart';

class PipeCategoriesPage extends StatefulWidget {
  const PipeCategoriesPage({super.key});

  @override
  State<PipeCategoriesPage> createState() => _PipeCategoriesPageState();
}

class _PipeCategoriesPageState extends State<PipeCategoriesPage> {
  late List<PipeCategory> _categories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    setState(() {
      _categories = PipeCategoryService.getCategories();
    });
  }

  void _openAddEditDialog([PipeCategory? category]) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final lengthController = TextEditingController(
        text: category != null ? category.defaultLength.toString() : '6.0');
    final descController =
        TextEditingController(text: category?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.category, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'تعديل فئة الأنابيب' : 'إضافة فئة أنابيب جديدة',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفئة / المادة *',
                      hintText: 'مثلاً: PPR، PEX، حديد مجلفن، خرطوم',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'يرجى إدخال اسم الفئة' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: lengthController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الطول الافتراضي للقطعة (متر) *',
                      hintText: 'مثلاً: 6.0 أو 5.0 أو 100',
                      border: OutlineInputBorder(),
                      suffixText: 'متر',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال الطول الافتراضي';
                      }
                      final num = double.tryParse(val.trim());
                      if (num == null || num <= 0) {
                        return 'أدخل طولاً صحيحاً أكبر من 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'وصف أو ملاحظة (اختياري)',
                      hintText: 'معلومات حول المادة أو الاستخدام',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newCategory = PipeCategory(
                    id: isEditing
                        ? category.id
                        : DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    defaultLength: double.parse(lengthController.text.trim()),
                    description: descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null,
                    isSystem: category?.isSystem ?? false,
                  );

                  await PipeCategoryService.saveCategory(newCategory);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing
                            ? '✅ تم تحديث الفئة بنجاح'
                            : '✅ تم إضافة الفئة الجديدة بنجاح'),
                        backgroundColor: Colors.green[700],
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الفئة'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(PipeCategory category) {
    if (category.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ لا يمكن حذف الفئات الأساسية للسيستم.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت أخصائي في حذف فئة "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final success =
                  await PipeCategoryService.deleteCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ تم حذف الفئة بنجاح'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final borderColor = theme.dividerColor.withValues(alpha: 0.2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فئات المواد المباعة بالمتر'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة فئة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تتيح لك هذه الصفحة إضافة وتحديد أنواع وفئات الأنابيب والمواد المباعة بالمتر (مثل PVC، نحاس، PPR) مع تحديد طول القطعة الكاملة الافتراضي لكل فئة.',
                    style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'فئات الأنابيب والمتر المتاحة (${_categories.length}):',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: onSurface),
          ),
          const SizedBox(height: 12),

          ..._categories.map((cat) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: onSurface,
                    ),
                  ),
                  if (cat.isSystem) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'أساسي',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.straighten,
                          size: 16,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(
                        'الطول الافتراضي للقطعة الكاملة: ${cat.defaultLength} متر',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  if (cat.description != null && cat.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      cat.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                    onPressed: () => _openAddEditDialog(cat),
                  ),
                  if (!cat.isSystem)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(cat),
                    ),
                ],
              ),
            ),
          );
          }),
        ],
      ),
    );
  }
}
