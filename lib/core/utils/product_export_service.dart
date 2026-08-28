import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

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
  /// Base64-encoded image data keyed by image key
  final Map<String, String> imageData;
  /// Maps product ID -> list of image keys from the export file
  final Map<String, List<String>> productImageKeys;

  ImportAnalysisResult({
    required this.newProducts,
    required this.identicalProducts,
    required this.conflicts,
    this.imageData = const {},
    this.productImageKeys = const {},
  });

  int get totalInFile => newProducts.length + identicalProducts.length + conflicts.length;
  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Service for exporting and importing product catalogs via JSON files
/// with smart conflict resolution and embedded image support.
class ProductExportService {

  /// Safe helper to get temporary directory without crashing on MissingPluginException/Desktop
  static Future<Directory> _getSafeTempDir() async {
    try {
      if (!kIsWeb) {
        return await getTemporaryDirectory();
      }
    } catch (e) {
      debugPrint('getTemporaryDirectory error: $e, using Directory.systemTemp');
    }
    return Directory.systemTemp;
  }

  /// Safe helper to get app documents directory without crashing on MissingPluginException/Desktop
  static Future<Directory> _getSafeAppDocsDir() async {
    try {
      if (!kIsWeb) {
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('getApplicationDocumentsDirectory error: $e, using Directory.systemTemp');
    }
    return Directory.systemTemp;
  }

  /// Convert list of products into a structured JSON string.
  /// Images are encoded as base64 in the JSON for full portability between devices.
  static Future<String> exportToJson(List<Product> products) async {
    final List<Map<String, dynamic>> productMaps = [];
    final Map<String, String> imageDataMap = {};

    for (final p in products) {
      final model = ProductModel.fromEntity(p);
      final map = model.toMap();

      // Encode images as base64 for portability
      if (!kIsWeb && model.imagePaths.isNotEmpty) {
        final List<String> encodedImageKeys = [];
        for (int i = 0; i < model.imagePaths.length; i++) {
          final path = model.imagePaths[i];
          try {
            final file = File(path);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final base64Str = base64Encode(bytes);
              final key = '${model.id}_img_$i';
              imageDataMap[key] = base64Str;
              encodedImageKeys.add(key);
            }
          } catch (e) {
            debugPrint('Export: Could not read image $path: $e');
          }
        }
        if (encodedImageKeys.isNotEmpty) {
          map['_imageKeys'] = encodedImageKeys;
        }
      }

      productMaps.add(map);
    }

    final data = {
      'app': 'Flutter Billing POS',
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'count': products.length,
      'products': productMaps,
      if (imageDataMap.isNotEmpty) 'images': imageDataMap,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Export products and open share sheet
  static Future<bool> shareProducts(List<Product> products) async {
    try {
      final jsonStr = await exportToJson(products);
      final tempDir = await _getSafeTempDir();
      final dateStr = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/products_export_$dateStr.json');
      await file.writeAsString(jsonStr);

      try {
        final xFile = XFile(file.path, mimeType: 'application/json');
        await SharePlus.instance.share(
          ShareParams(
            files: [xFile],
            text: 'تصدير المنتجات (${products.length} منتج)',
          ),
        );
      } catch (shareErr) {
        debugPrint('SharePlus failed on platform: $shareErr. File saved at ${file.path}');
      }
      return true;
    } catch (e) {
      debugPrint('ProductExportService: shareProducts error: $e');
      return false;
    }
  }

  /// Parse JSON string and analyze products against existing local Hive database.
  static ImportAnalysisResult analyzeImport(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List<dynamic> rawList = data['products'] as List<dynamic>? ?? [];
    final Map<String, dynamic> rawImages = (data['images'] as Map<String, dynamic>?) ?? {};

    // Convert image data to string map
    final Map<String, String> imageData = rawImages.map((k, v) => MapEntry(k, v.toString()));

    final List<ProductModel> existingList = Hive.isBoxOpen('products')
        ? HiveDatabase.productBox.values.toList()
        : [];

    final List<ProductModel> newProducts = [];
    final List<ProductModel> identicalProducts = [];
    final List<ProductImportConflict> conflicts = [];
    final Map<String, List<String>> productImageKeys = {};

    for (final raw in rawList) {
      if (raw is Map) {
        final rawMap = raw.cast<String, dynamic>();
        final imported = ProductModel.fromMap(rawMap);

        // Extract image keys from raw JSON (not in the model)
        final imgKeys = (rawMap['_imageKeys'] as List<dynamic>?)?.cast<String>() ?? [];
        if (imgKeys.isNotEmpty) {
          productImageKeys[imported.id] = imgKeys;
        }

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
              existingMatch.costPrice == imported.costPrice &&
              existingMatch.name == imported.name &&
              existingMatch.fullPrice == imported.fullPrice &&
              existingMatch.fullLength == imported.fullLength &&
              existingMatch.diameter == imported.diameter &&
              existingMatch.stock == imported.stock &&
              existingMatch.isPipe == imported.isPipe &&
              existingMatch.description == imported.description &&
              existingMatch.usageInstructions == imported.usageInstructions;

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
      imageData: imageData,
      productImageKeys: productImageKeys,
    );
  }

  /// Restore images from base64 data embedded in the export file.
  /// Returns list of new local file paths.
  static Future<List<String>> _restoreImages(
    Map<String, String> imageData,
    String productId,
    List<String> imageKeys,
  ) async {
    if (imageData.isEmpty || imageKeys.isEmpty || kIsWeb) return [];

    final List<String> restoredPaths = [];

    try {
      final appDir = await _getSafeAppDocsDir();
      final imgDir = Directory('${appDir.path}/product_images/$productId');
      if (!await imgDir.exists()) {
        await imgDir.create(recursive: true);
      }

      for (final key in imageKeys) {
        final base64Str = imageData[key];
        if (base64Str == null || base64Str.isEmpty) continue;

        try {
          final bytes = base64Decode(base64Str);
          final imgFile = File('${imgDir.path}/$key.jpg');
          await imgFile.writeAsBytes(bytes);
          restoredPaths.add(imgFile.path);
        } catch (e) {
          debugPrint('Import: Could not restore image $key: $e');
        }
      }
    } catch (e) {
      debugPrint('Import: Image restoration error for $productId: $e');
    }

    return restoredPaths;
  }

  /// Build a complete ProductModel with restored images from an import
  static Future<ProductModel> _buildImportedProduct(
    ProductModel source,
    String useId,
    ImportAnalysisResult analysis,
    {ProductModel? fallback}
  ) async {
    // Restore images if available
    final imageKeys = analysis.productImageKeys[source.id] ?? [];
    List<String> finalImagePaths = source.imagePaths;

    if (imageKeys.isNotEmpty && analysis.imageData.isNotEmpty) {
      final restored = await _restoreImages(analysis.imageData, useId, imageKeys);
      if (restored.isNotEmpty) {
        finalImagePaths = restored;
      }
    } else if (finalImagePaths.isEmpty && fallback != null) {
      finalImagePaths = fallback.imagePaths;
    }

    return ProductModel(
      id: useId,
      name: source.name,
      barcode: source.barcode.isNotEmpty ? source.barcode : (fallback?.barcode ?? ''),
      price: source.price,
      costPrice: source.costPrice,
      stock: source.stock,
      sku: source.sku ?? fallback?.sku,
      category: source.category ?? fallback?.category,
      brand: source.brand ?? fallback?.brand,
      size: source.size ?? fallback?.size,
      imagePaths: finalImagePaths,
      embedding: source.embedding ?? fallback?.embedding,
      ocrText: source.ocrText ?? fallback?.ocrText,
      isPipe: source.isPipe,
      pipeType: source.pipeType ?? fallback?.pipeType,
      fullLength: source.fullLength ?? fallback?.fullLength,
      fullPrice: source.fullPrice ?? fallback?.fullPrice,
      diameter: source.diameter ?? fallback?.diameter,
      origin: source.origin ?? fallback?.origin,
      color: source.color ?? fallback?.color,
      description: source.description ?? fallback?.description,
      usageInstructions: source.usageInstructions ?? fallback?.usageInstructions,
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
      final finalProduct = await _buildImportedProduct(product, product.id, analysis);
      await box.put(finalProduct.id, finalProduct);
      addedCount++;
    }

    // 2. Process conflicts based on chosen actions
    for (final conflict in analysis.conflicts) {
      if (conflict.action == ConflictAction.overwrite) {
        final finalProduct = await _buildImportedProduct(
          conflict.importedProduct,
          conflict.existingProduct.id, // Keep existing ID for database continuity
          analysis,
          fallback: conflict.existingProduct,
        );
        await box.put(finalProduct.id, finalProduct);
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
        withData: true, // Always populate file.bytes across Web, Desktop, & Mobile
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      String? jsonContent;

      // 1. Try reading raw bytes first (most reliable on Web & Desktop)
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        jsonContent = utf8.decode(file.bytes!);
      } 
      // 2. Fallback to path reading if path is a valid file
      else if (file.path != null && file.path!.isNotEmpty) {
        try {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            jsonContent = await ioFile.readAsString();
          }
        } catch (e) {
          debugPrint('ProductExportService: File path read error: $e');
        }
      }

      if (jsonContent == null || jsonContent.trim().isEmpty) {
        throw Exception('تعذر قراءة بيانات ملف JSON المحدد');
      }

      return analyzeImport(jsonContent);
    } catch (e) {
      debugPrint('ProductExportService: pickAndAnalyze error: $e');
      rethrow;
    }
  }
}
