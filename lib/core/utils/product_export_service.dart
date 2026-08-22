import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/product/domain/entities/product.dart';
import '../../features/product/data/models/product_model.dart';
import '../data/hive_database.dart';

enum ConflictAction { overwrite, keepExisting }

/// Holds details of a conflict between an existing local product and an imported product.
class ProductImportConflict {
  final ProductModel existingProduct;
  final ProductModel importedProduct;
  ConflictAction action;

  ProductImportConflict({
    required this.existingProduct,
    required this.importedProduct,
    this.action = ConflictAction.overwrite,
  });
}

/// Analysis summary of an import JSON file before performing database changes.
class ImportAnalysisResult {
  final List<ProductModel> newProducts;
  final List<ProductModel> identicalProducts;
  final List<ProductImportConflict> conflicts;

  ImportAnalysisResult({
    required this.newProducts,
    required this.identicalProducts,
    required this.conflicts,
  });

  int get totalInFile => newProducts.length + identicalProducts.length + conflicts.length;
  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Service for exporting and importing product catalogs via JSON files with smart conflict resolution.
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

  /// Parse JSON string and analyze products against existing local Hive database.
  /// Categorizes products into: New, Identical (auto-skipped), and Conflicting (price/spec mismatch).
  static ImportAnalysisResult analyzeImport(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List<dynamic> rawList = data['products'] as List<dynamic>? ?? [];

    final box = HiveDatabase.productBox;
    final existingList = box.values.toList();

    final List<ProductModel> newProducts = [];
    final List<ProductModel> identicalProducts = [];
    final List<ProductImportConflict> conflicts = [];

    for (final raw in rawList) {
      if (raw is Map) {
        final imported = ProductModel.fromMap(raw.cast<String, dynamic>());

        // Find existing match by barcode, ID, or normalized name
        ProductModel? existingMatch;
        for (final item in existingList) {
          final barcodeMatch = item.barcode.isNotEmpty && imported.barcode.isNotEmpty && item.barcode == imported.barcode;
          final idMatch = item.id == imported.id;
          final nameMatch = item.name.trim().toLowerCase() == imported.name.trim().toLowerCase();

          if (barcodeMatch || idMatch || nameMatch) {
            existingMatch = item;
            break;
          }
        }

        if (existingMatch == null) {
          newProducts.add(imported);
        } else {
          final isIdentical = existingMatch.price == imported.price &&
              existingMatch.name == imported.name &&
              existingMatch.fullPrice == imported.fullPrice &&
              existingMatch.fullLength == imported.fullLength &&
              existingMatch.diameter == imported.diameter &&
              existingMatch.stock == imported.stock &&
              existingMatch.isPipe == imported.isPipe;

          if (isIdentical) {
            identicalProducts.add(imported);
          } else {
            conflicts.add(ProductImportConflict(
              existingProduct: existingMatch,
              importedProduct: imported,
            ));
          }
        }
      }
    }

    return ImportAnalysisResult(
      newProducts: newProducts,
      identicalProducts: identicalProducts,
      conflicts: conflicts,
    );
  }

  /// Commit the import result into Hive database based on conflict resolutions.
  /// Returns a map with summary counts of added, updated, and skipped items.
  static Future<Map<String, int>> executeImport(ImportAnalysisResult analysis) async {
    final box = HiveDatabase.productBox;

    int addedCount = 0;
    int updatedCount = 0;
    int skippedCount = analysis.identicalProducts.length;

    // 1. Add all brand new products
    for (final product in analysis.newProducts) {
      await box.put(product.id, product);
      addedCount++;
    }

    // 2. Process conflicts based on chosen actions
    for (final conflict in analysis.conflicts) {
      if (conflict.action == ConflictAction.overwrite) {
        // Overwrite using the existing product's ID to maintain database key continuity
        final updatedModel = ProductModel(
          id: conflict.existingProduct.id,
          name: conflict.importedProduct.name,
          barcode: conflict.importedProduct.barcode.isNotEmpty ? conflict.importedProduct.barcode : conflict.existingProduct.barcode,
          price: conflict.importedProduct.price,
          stock: conflict.importedProduct.stock,
          sku: conflict.importedProduct.sku ?? conflict.existingProduct.sku,
          category: conflict.importedProduct.category ?? conflict.existingProduct.category,
          brand: conflict.importedProduct.brand ?? conflict.existingProduct.brand,
          size: conflict.importedProduct.size ?? conflict.existingProduct.size,
          imagePaths: conflict.importedProduct.imagePaths.isNotEmpty ? conflict.importedProduct.imagePaths : conflict.existingProduct.imagePaths,
          embedding: conflict.importedProduct.embedding ?? conflict.existingProduct.embedding,
          ocrText: conflict.importedProduct.ocrText ?? conflict.existingProduct.ocrText,
          isPipe: conflict.importedProduct.isPipe,
          pipeType: conflict.importedProduct.pipeType ?? conflict.existingProduct.pipeType,
          fullLength: conflict.importedProduct.fullLength ?? conflict.existingProduct.fullLength,
          fullPrice: conflict.importedProduct.fullPrice ?? conflict.existingProduct.fullPrice,
          diameter: conflict.importedProduct.diameter ?? conflict.existingProduct.diameter,
          origin: conflict.importedProduct.origin ?? conflict.existingProduct.origin,
          color: conflict.importedProduct.color ?? conflict.existingProduct.color,
        );
        await box.put(updatedModel.id, updatedModel);
        updatedCount++;
      } else {
        skippedCount++;
      }
    }

    return {
      'added': addedCount,
      'updated': updatedCount,
      'skipped': skippedCount,
      'total': analysis.totalInFile,
    };
  }

  /// Open file picker, analyze JSON contents, and return the analysis result.
  static Future<ImportAnalysisResult?> pickAndAnalyze() async {
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

      return analyzeImport(jsonContent);
    } catch (e) {
      debugPrint('ProductExportService: pickAndAnalyze error: $e');
      rethrow;
    }
  }
}
