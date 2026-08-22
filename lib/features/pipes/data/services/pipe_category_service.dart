import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/pipe_category.dart';

class PipeCategoryService {
  static const String _categoriesKey = 'custom_pipe_categories_v1';

  static const List<PipeCategory> defaultCategories = [
    PipeCategory(
      id: 'pvc',
      name: 'PVC',
      defaultLength: 6.0,
      description: 'أنابيب PVC البلاستيكية ذات الطول الأصلي 6 أمتار',
      isSystem: true,
    ),
    PipeCategory(
      id: 'copper',
      name: 'نحاس',
      defaultLength: 5.0,
      description: 'أنابيب النحاس الصلبة أو المرنة ذات الطول الأصلي 5 أمتار',
      isSystem: true,
    ),
    PipeCategory(
      id: 'other',
      name: 'أخرى',
      defaultLength: 4.0,
      description: 'أنابيب ومواد أخرى تباع بالمتر بطول افتراضي 4 أمتار',
      isSystem: true,
    ),
  ];

  /// Retrieves all pipe categories (system + user defined)
  static List<PipeCategory> getCategories() {
    try {
      final box = Hive.box('settings');
      final jsonString = box.get(_categoriesKey) as String?;

      if (jsonString == null || jsonString.isEmpty) {
        return defaultCategories;
      }

      final List<dynamic> list = jsonDecode(jsonString);
      final categories = list
          .map((e) => PipeCategory.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (categories.isEmpty) {
        return defaultCategories;
      }
      return categories;
    } catch (_) {
      return defaultCategories;
    }
  }

  /// Saves or updates a pipe category
  static Future<void> saveCategory(PipeCategory category) async {
    final categories = getCategories().toList();
    final index = categories.indexWhere((c) => c.id == category.id || c.name.trim().toLowerCase() == category.name.trim().toLowerCase());

    if (index >= 0) {
      categories[index] = category;
    } else {
      categories.add(category);
    }

    await _persist(categories);
  }

  /// Deletes a user-defined category (system categories cannot be deleted)
  static Future<bool> deleteCategory(String id) async {
    final categories = getCategories().toList();
    final target = categories.firstWhere((c) => c.id == id, orElse: () => const PipeCategory(id: '', name: '', defaultLength: 0));
    
    if (target.isSystem || target.id.isEmpty) {
      return false; // Cannot delete system category
    }

    categories.removeWhere((c) => c.id == id);
    await _persist(categories);
    return true;
  }

  static Future<void> _persist(List<PipeCategory> categories) async {
    final box = Hive.box('settings');
    final jsonString = jsonEncode(categories.map((c) => c.toMap()).toList());
    await box.put(_categoriesKey, jsonString);
  }

  /// Returns default length for a given category name (or 6.0 if not found)
  static double getDefaultLengthForType(String pipeType) {
    final categories = getCategories();
    final match = categories.firstWhere(
      (c) => c.name.trim().toLowerCase() == pipeType.trim().toLowerCase() || c.id.toLowerCase() == pipeType.trim().toLowerCase(),
      orElse: () => const PipeCategory(id: '', name: '', defaultLength: 6.0),
    );
    return match.defaultLength > 0 ? match.defaultLength : 6.0;
  }
}
