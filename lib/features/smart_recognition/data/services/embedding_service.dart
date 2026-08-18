import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// On-device image embedding service.
/// Generates feature vectors from product images using color histogram
/// and spatial features — no internet, no API, no cost.
///
/// For ≤1000 products, this approach provides sufficient discriminative
/// power when combined with OCR and metadata matching.
///
/// Vector dimensions: [_vectorSize] (192)
///   - 96 dims: Color histogram (32 bins × 3 channels RGB)
///   - 48 dims: Spatial color grid (4×4 grid × 3 channels)
///   - 32 dims: Edge/gradient features (8 directions × 4 regions)
///   - 16 dims: Texture features (variance in 4×4 grid)
class EmbeddingService {
  static const int _vectorSize = 192;
  static const int _resizeWidth = 64;
  static const int _resizeHeight = 64;
  static const int _colorBins = 32;

  bool _initialized = false;

  /// Lazy initialization
  Future<void> initialize() async {
    _initialized = true;
  }

  /// Returns the expected embedding vector size
  int get vectorSize => _vectorSize;

  /// Generate an embedding vector from an image file.
  /// Returns a List<double> of length [_vectorSize], or null on failure.
  Future<List<double>?> generateEmbedding(String imagePath) async {
    if (kIsWeb) return null;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      // Run in isolate to avoid blocking the UI thread
      return await compute(_processImage, bytes);
    } catch (e) {
      debugPrint('EmbeddingService: generateEmbedding error: $e');
      return null;
    }
  }

  /// Static method for compute isolate — processes image bytes into vector.
  static List<double>? _processImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Resize to standard dimensions
      final resized = img.copyResize(
        decoded,
        width: _resizeWidth,
        height: _resizeHeight,
        interpolation: img.Interpolation.linear,
      );

      final vector = <double>[];

      // 1. Color Histogram (96 dims: 32 bins × 3 channels)
      vector.addAll(_colorHistogram(resized));

      // 2. Spatial Color Grid (48 dims: 4×4 grid × 3 channels)
      vector.addAll(_spatialColorGrid(resized));

      // 3. Edge Features (32 dims: 8 directions × 4 regions)
      vector.addAll(_edgeFeatures(resized));

      // 4. Texture Features (16 dims: variance in 4×4 grid)
      vector.addAll(_textureFeatures(resized));

      // L2 normalize the vector
      return _l2Normalize(vector);
    } catch (e) {
      return null;
    }
  }

  /// Extract color histogram: 32 bins per channel (R, G, B)
  static List<double> _colorHistogram(img.Image image) {
    final rHist = List<double>.filled(_colorBins, 0);
    final gHist = List<double>.filled(_colorBins, 0);
    final bHist = List<double>.filled(_colorBins, 0);

    final totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        rHist[(r * (_colorBins - 1)) ~/ 255]++;
        gHist[(g * (_colorBins - 1)) ~/ 255]++;
        bHist[(b * (_colorBins - 1)) ~/ 255]++;
      }
    }

    // Normalize
    for (int i = 0; i < _colorBins; i++) {
      rHist[i] /= totalPixels;
      gHist[i] /= totalPixels;
      bHist[i] /= totalPixels;
    }

    return [...rHist, ...gHist, ...bHist];
  }

  /// Divide image into 4×4 grid, compute mean color per cell
  static List<double> _spatialColorGrid(img.Image image) {
    const gridSize = 4;
    final cellW = image.width ~/ gridSize;
    final cellH = image.height ~/ gridSize;
    final features = <double>[];

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        double sumR = 0, sumG = 0, sumB = 0;
        int count = 0;

        for (int y = gy * cellH; y < (gy + 1) * cellH && y < image.height; y++) {
          for (int x = gx * cellW; x < (gx + 1) * cellW && x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            sumR += pixel.r.toInt();
            sumG += pixel.g.toInt();
            sumB += pixel.b.toInt();
            count++;
          }
        }

        if (count > 0) {
          features.add(sumR / count / 255.0);
          features.add(sumG / count / 255.0);
          features.add(sumB / count / 255.0);
        } else {
          features.addAll([0.0, 0.0, 0.0]);
        }
      }
    }

    return features;
  }

  /// Compute edge/gradient features using simple Sobel-like filter
  /// 8 directions × 4 quadrants = 32 features
  static List<double> _edgeFeatures(img.Image image) {
    // Convert to grayscale values
    final gray = List<List<double>>.generate(
      image.height,
      (y) => List<double>.generate(image.width, (x) {
        final p = image.getPixel(x, y);
        return (p.r.toInt() * 0.299 + p.g.toInt() * 0.587 + p.b.toInt() * 0.114) / 255.0;
      }),
    );

    const quadrants = 4; // 2×2 quadrants
    const directions = 8; // 8 edge directions
    final features = List<double>.filled(quadrants * directions, 0);

    final halfW = image.width ~/ 2;
    final halfH = image.height ~/ 2;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        // Sobel gradients
        final gx = gray[y - 1][x + 1] + 2 * gray[y][x + 1] + gray[y + 1][x + 1]
            - gray[y - 1][x - 1] - 2 * gray[y][x - 1] - gray[y + 1][x - 1];
        final gy = gray[y + 1][x - 1] + 2 * gray[y + 1][x] + gray[y + 1][x + 1]
            - gray[y - 1][x - 1] - 2 * gray[y - 1][x] - gray[y - 1][x + 1];

        final magnitude = sqrt(gx * gx + gy * gy);
        if (magnitude < 0.05) continue; // Skip weak edges

        // Direction (0-7, quantized angle)
        var angle = atan2(gy, gx) + pi; // 0 to 2*pi
        final dir = ((angle / (2 * pi)) * directions).floor().clamp(0, directions - 1);

        // Quadrant
        final qx = x < halfW ? 0 : 1;
        final qy = y < halfH ? 0 : 1;
        final quadrant = qy * 2 + qx;

        features[quadrant * directions + dir] += magnitude;
      }
    }

    // Normalize per quadrant
    for (int q = 0; q < quadrants; q++) {
      double maxVal = 0;
      for (int d = 0; d < directions; d++) {
        maxVal = max(maxVal, features[q * directions + d]);
      }
      if (maxVal > 0) {
        for (int d = 0; d < directions; d++) {
          features[q * directions + d] /= maxVal;
        }
      }
    }

    return features;
  }

  /// Texture features: variance of pixel intensity in 4×4 grid cells
  static List<double> _textureFeatures(img.Image image) {
    const gridSize = 4;
    final cellW = image.width ~/ gridSize;
    final cellH = image.height ~/ gridSize;
    final features = <double>[];

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final values = <double>[];

        for (int y = gy * cellH; y < (gy + 1) * cellH && y < image.height; y++) {
          for (int x = gx * cellW; x < (gx + 1) * cellW && x < image.width; x++) {
            final p = image.getPixel(x, y);
            final gray = (p.r.toInt() * 0.299 + p.g.toInt() * 0.587 + p.b.toInt() * 0.114) / 255.0;
            values.add(gray);
          }
        }

        if (values.isEmpty) {
          features.add(0.0);
          continue;
        }

        // Compute variance
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
        features.add(variance);
      }
    }

    return features;
  }

  /// L2 normalize the vector (unit length)
  static List<double> _l2Normalize(List<double> vector) {
    double norm = 0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);

    if (norm == 0) return vector;

    return vector.map((v) => v / norm).toList();
  }

  /// Release resources
  void dispose() {
    _initialized = false;
  }
}
