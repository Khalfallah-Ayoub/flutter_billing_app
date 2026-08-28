import 'package:flutter/material.dart';
import '../../../core/data/hive_database.dart';

/// Service that maps product categories to colors.
/// Colors are saved in Hive settings box so users can customize them.
class CategoryColorService {
  static const String _settingsKey = 'category_colors';

  /// Default color palette for known categories.
  static final Map<String, int> _defaultColors = {
    'أنابيب (Pipes)': 0xFF607D8B, // Blue Grey
    'PVC': 0xFF78909C,
    'كهرباء': 0xFFFF9800, // Orange
    'طلاء': 0xFF4CAF50, // Green
    'أدوات يدوية': 0xFF795548, // Brown
    'براغي ومسامير': 0xFF9E9E9E, // Grey
    'سباكة': 0xFF2196F3, // Blue
    'لوازم بناء': 0xFFE91E63, // Pink
    'إكسسوارات': 0xFF9C27B0, // Purple
    'عامة': 0xFF455A64, // Default
  };

  /// Get the color for a category. Falls back to default grey if not set.
  static Color getColor(String? category) {
    if (category == null || category.isEmpty) {
      return const Color(0xFF455A64);
    }

    // Check saved custom color first
    final box = HiveDatabase.settingsBox;
    final savedColors = box.get(_settingsKey);
    if (savedColors is Map) {
      final saved = savedColors[category];
      if (saved is int) return Color(saved);
    }

    // Check defaults
    for (final entry in _defaultColors.entries) {
      if (category.toLowerCase().contains(entry.key.toLowerCase())) {
        return Color(entry.value);
      }
    }

    // Generate a consistent color from the category name hash
    final hash = category.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.5, 0.4).toColor();
  }

  /// Save a custom color for a category.
  static Future<void> setColor(String category, Color color) async {
    final box = HiveDatabase.settingsBox;
    final Map<dynamic, dynamic> existing = box.get(_settingsKey) ?? {};
    final updated = Map<String, int>.from(
      existing.map((k, v) => MapEntry(k.toString(), v as int)),
    );
    updated[category] = color.toARGB32();
    await box.put(_settingsKey, updated);
  }

  /// Get all known categories from products + any custom colors saved.
  static List<String> getAllCategories() {
    final categories = <String>{};

    // From products
    for (final model in HiveDatabase.productBox.values) {
      if (model.category != null && model.category!.isNotEmpty) {
        categories.add(model.category!);
      }
    }

    // From saved color map
    final box = HiveDatabase.settingsBox;
    final savedColors = box.get(_settingsKey);
    if (savedColors is Map) {
      for (final key in savedColors.keys) {
        categories.add(key.toString());
      }
    }

    return categories.toList()..sort();
  }
}
