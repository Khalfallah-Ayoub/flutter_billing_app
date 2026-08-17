import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Service for managing product images locally on the device.
/// Handles capture, compression, storage, and deletion.
class ImageStorageService {
  // Singleton
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  final ImagePicker _picker = ImagePicker();

  static const int _maxWidth = 800;
  static const int _maxHeight = 800;
  static const int _jpegQuality = 85;
  static const String _imagesDirName = 'product_images';

  /// Get the base directory for product images
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/$_imagesDirName');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Capture an image from the camera
  Future<File?> captureImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: _jpegQuality,
      );
      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      debugPrint('ImageStorageService: captureImage error: $e');
      return null;
    }
  }

  /// Pick an image from the gallery
  Future<File?> pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxWidth.toDouble(),
        maxHeight: _maxHeight.toDouble(),
        imageQuality: _jpegQuality,
      );
      if (photo == null) return null;
      return File(photo.path);
    } catch (e) {
      debugPrint('ImageStorageService: pickImage error: $e');
      return null;
    }
  }

  /// Save a product image to the app's local storage.
  /// Compresses the image before saving.
  /// Returns the saved file path, or null on failure.
  Future<String?> saveProductImage(String productId, File imageFile) async {
    try {
      final imagesDir = await _getImagesDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${productId}_$timestamp.jpg';
      final targetPath = '${imagesDir.path}/$fileName';

      // Read and compress the image
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('ImageStorageService: Could not decode image');
        return null;
      }

      // Resize if larger than max dimensions
      img.Image resized = decoded;
      if (decoded.width > _maxWidth || decoded.height > _maxHeight) {
        resized = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? _maxWidth : null,
          height: decoded.height >= decoded.width ? _maxHeight : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Encode as JPEG and save
      final compressedBytes = img.encodeJpg(resized, quality: _jpegQuality);
      final savedFile = File(targetPath);
      await savedFile.writeAsBytes(compressedBytes);

      return targetPath;
    } catch (e) {
      debugPrint('ImageStorageService: saveProductImage error: $e');
      return null;
    }
  }

  /// Delete a product image by its path
  Future<bool> deleteProductImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ImageStorageService: deleteProductImage error: $e');
      return false;
    }
  }

  /// Get all image paths for a specific product
  Future<List<String>> getProductImages(String productId) async {
    try {
      final imagesDir = await _getImagesDirectory();
      if (!await imagesDir.exists()) return [];

      final files = await imagesDir.list().toList();
      return files
          .where((f) =>
              f is File &&
              f.path.split('/').last.startsWith('${productId}_') &&
              f.path.endsWith('.jpg'))
          .map((f) => f.path)
          .toList();
    } catch (e) {
      debugPrint('ImageStorageService: getProductImages error: $e');
      return [];
    }
  }

  /// Delete all images for a specific product
  Future<void> deleteAllProductImages(String productId) async {
    final images = await getProductImages(productId);
    for (final path in images) {
      await deleteProductImage(path);
    }
  }

  /// Get total storage used by product images (in bytes)
  Future<int> getTotalStorageUsed() async {
    try {
      final imagesDir = await _getImagesDirectory();
      if (!await imagesDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in imagesDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
