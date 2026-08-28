import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/category_color_service.dart';

class CategoryColorsPage extends StatefulWidget {
  const CategoryColorsPage({super.key});

  @override
  State<CategoryColorsPage> createState() => _CategoryColorsPageState();
}

class _CategoryColorsPageState extends State<CategoryColorsPage> {
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = CategoryColorService.getAllCategories();
  }

  void _pickColor(String category) {
    final currentColor = CategoryColorService.getColor(category);
    showDialog(
      context: context,
      builder: (ctx) {
        return _ColorPickerDialog(
          category: category,
          initialColor: currentColor,
          onColorPicked: (color) async {
            await CategoryColorService.setColor(category, color);
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ألوان الفئات'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: _categories.isEmpty
          ? const Center(
              child: Text('لا توجد فئات بعد — أضف منتجات لإنشاء فئات'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final color = CategoryColorService.getColor(cat);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: GestureDetector(
                      onTap: () => _pickColor(cat),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: TextButton.icon(
                      onPressed: () => _pickColor(cat),
                      icon: const Icon(Icons.palette, size: 18),
                      label: const Text('تغيير اللون'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final String category;
  final Color initialColor;
  final ValueChanged<Color> onColorPicked;

  const _ColorPickerDialog({
    required this.category,
    required this.initialColor,
    required this.onColorPicked,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;

  static const List<Color> _palette = [
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF78909C), // Light Blue Grey
    Color(0xFF455A64), // Dark Blue Grey
    Color(0xFF2196F3), // Blue
    Color(0xFF03A9F4), // Light Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFF8BC34A), // Light Green
    Color(0xFFCDDC39), // Lime
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFF44336), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
    Color(0xFF212121), // Dark
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('لون فئة: ${widget.category}'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _palette.map((color) {
            final isSelected = _selected.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selected = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                      : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorPicked(_selected);
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
