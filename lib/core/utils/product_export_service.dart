import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/product/domain/entities/product.dart';
import '../../features/product/data/models/product_model.dart';
import '../data/hive_database.dart';

/// Service for exporting and importing product catalogs via JSON files.
class ProductExportService {
  /// Convert list of products into a structured JSON string
  static String exportToJson(List<Product> products) {
    final data = {
      'app': 'Flutter Billing POS',
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'count': products.length,
      'products': products.map((p) => ProductModel.fromEntity(p).toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export products and open share sheet
  static Future<bool> shareProducts(List<Product> products) async {
    try {
      final jsonStr = exportToJson(products);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/products_export_$dateStr.json');
      await file.writeAsString(jsonStr);

      final xFile = XFile(file.path, mimeType: 'application/json');
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Product Catalog Export (${products.length} products)',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('ProductExportService: shareProducts error: $e');
      return false;
    }
  }

  /// Import products from a JSON string into Hive database.
  /// Returns the count of newly added or updated products.
  static Future<int> importFromJsonString(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final List<dynamic> rawList = data['products'] as List<dynamic>? ?? [];

      int importedCount = 0;
      final box = HiveDatabase.productBox;

      for (final raw in rawList) {
        if (raw is Map) {
          final model = ProductModel.fromMap(raw.cast<String, dynamic>());
          await box.put(model.id, model);
          importedCount++;
        }
      }
      return importedCount;
    } catch (e) {
      debugPrint('ProductExportService: importFromJson error: $e');
      rethrow;
    }
  }

  /// Open file picker to choose a JSON file and import products
  static Future<int?> pickAndImport() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      String jsonContent;

      if (file.path != null) {
        jsonContent = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        jsonContent = utf8.decode(file.bytes!);
      } else {
        return null;
      }

      return await importFromJsonString(jsonContent);
    } catch (e) {
      debugPrint('ProductExportService: pickAndImport error: $e');
      rethrow;
    }
  }
}
