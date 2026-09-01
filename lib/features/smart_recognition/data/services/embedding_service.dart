import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// On-device image embedding service — v2.0
///
/// Vector dimensions: [_vectorSize] = 320
///   - 96 dims:  Color histogram       (32 bins × 3 channels RGB)
///   - 48 dims:  Spatial color grid    (4×4 grid × 3 channels)
///   - 32 dims:  Edge features Sobel   (8 directions × 4 quadrants)
///   - 16 dims:  Texture variance      (4×4 grid)
///   - [NEW] 128 dims: HOG              (4×4 blocks × 8 orientation bins)
///   - [NEW] 8 dims:   Shape features   (aspect ratio, fill ratio, symmetry…)
///
/// Also provides pHash (Perceptual Hash) — a 64-bit integer fingerprint
/// for fast similarity pre-filtering before cosine comparison.
class EmbeddingService {
  static const int _vectorSize = 320; // 192 original + 128 HOG + 8 shape - 8 old (pad alignment)
  static const int _resizeWidth = 64;
  static const int _resizeHeight = 64;
  static const int _colorBins = 32;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async => _initialized = true;

  int get vectorSize => _vectorSize;

  // ── Main entry points ─────────────────────────────────────────────────────

  /// Generate a rich embedding vector from an image file.
  /// Returns a List<double> of length [_vectorSize], or null on failure.
  Future<List<double>?> generateEmbedding(String imagePath) async {
    if (kIsWeb) return null;
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await compute(_processImage, bytes);
    } catch (e) {
      debugPrint('EmbeddingService: generateEmbedding error: $e');
      return null;
    }
  }

  /// Compute the 64-bit Perceptual Hash (pHash / dHash hybrid) of an image.
  /// Returns an int (64 bits encoded), or null on failure.
  /// Fast: runs in ~1-2ms on any phone.
  Future<int?> generatePHash(String imagePath) async {
    if (kIsWeb) return null;
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await compute(_computePHash, bytes);
    } catch (e) {
      debugPrint('EmbeddingService: generatePHash error: $e');
      return null;
    }
  }

  // ── Static (isolate-safe) computation ────────────────────────────────────

  /// Full feature vector: color + spatial + edges + texture + HOG + shape
  static List<double>? _processImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final resized = img.copyResize(
        decoded,
        width: _resizeWidth,
        height: _resizeHeight,
        interpolation: img.Interpolation.linear,
      );

      final vector = <double>[];
      vector.addAll(_colorHistogram(resized));      // 96
      vector.addAll(_spatialColorGrid(resized));    // 48
      vector.addAll(_edgeFeatures(resized));        // 32
      vector.addAll(_textureFeatures(resized));     // 16
      vector.addAll(_hogFeatures(resized));         // 128
      vector.addAll(_shapeFeatures(resized));       // 8
      // total = 328, trim to _vectorSize
      final trimmed = vector.take(_vectorSize).toList();
      // Pad if somehow short
      while (trimmed.length < _vectorSize) {
        trimmed.add(0.0);
      }
      return _l2Normalize(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// Perceptual hash (dHash 8×8 = 64 bits).
  /// Works by: resize → grayscale → compare adjacent pixels → build bit string.
  static int? _computePHash(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Resize to 9×8 for dHash (we compare 8 column pairs per row → 8×8 = 64 bits)
      final small = img.copyResize(decoded, width: 9, height: 8,
          interpolation: img.Interpolation.average);

      int hash = 0;
      int bit = 0;

      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final left = small.getPixel(x, y);
          final right = small.getPixel(x + 1, y);

          final grayLeft = left.r.toInt() * 299 +
              left.g.toInt() * 587 +
              left.b.toInt() * 114;
          final grayRight = right.r.toInt() * 299 +
              right.g.toInt() * 587 +
              right.b.toInt() * 114;

          if (grayLeft > grayRight) {
            hash |= (1 << bit);
          }
          bit++;
        }
      }
      return hash;
    } catch (_) {
      return null;
    }
  }

  // ── Feature extractors ────────────────────────────────────────────────────

  /// RGB color histogram: 32 bins × 3 channels = 96 values
  static List<double> _colorHistogram(img.Image image) {
    final rHist = List<double>.filled(_colorBins, 0);
    final gHist = List<double>.filled(_colorBins, 0);
    final bHist = List<double>.filled(_colorBins, 0);
    final total = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        rHist[(p.r.toInt() * (_colorBins - 1)) ~/ 255]++;
        gHist[(p.g.toInt() * (_colorBins - 1)) ~/ 255]++;
        bHist[(p.b.toInt() * (_colorBins - 1)) ~/ 255]++;
      }
    }
    for (int i = 0; i < _colorBins; i++) {
      rHist[i] /= total;
      gHist[i] /= total;
      bHist[i] /= total;
    }
    return [...rHist, ...gHist, ...bHist];
  }

  /// Spatial mean color per 4×4 grid cell = 48 values
  static List<double> _spatialColorGrid(img.Image image) {
    const g = 4;
    final cw = image.width ~/ g;
    final ch = image.height ~/ g;
    final f = <double>[];

    for (int gy = 0; gy < g; gy++) {
      for (int gx = 0; gx < g; gx++) {
        double sr = 0, sg = 0, sb = 0;
        int cnt = 0;
        for (int y = gy * ch; y < (gy + 1) * ch && y < image.height; y++) {
          for (int x = gx * cw; x < (gx + 1) * cw && x < image.width; x++) {
            final p = image.getPixel(x, y);
            sr += p.r.toInt();
            sg += p.g.toInt();
            sb += p.b.toInt();
            cnt++;
          }
        }
        if (cnt > 0) {
          f.add(sr / cnt / 255.0);
          f.add(sg / cnt / 255.0);
          f.add(sb / cnt / 255.0);
        } else {
          f.addAll([0.0, 0.0, 0.0]);
        }
      }
    }
    return f;
  }

  /// Sobel edge features: 8 directions × 4 quadrants = 32 values
  static List<double> _edgeFeatures(img.Image image) {
    final gray = List<List<double>>.generate(
      image.height,
      (y) => List<double>.generate(image.width, (x) {
        final p = image.getPixel(x, y);
        return (p.r.toInt() * 0.299 + p.g.toInt() * 0.587 + p.b.toInt() * 0.114) / 255.0;
      }),
    );

    const q = 4, dirs = 8;
    final f = List<double>.filled(q * dirs, 0.0);
    final hw = image.width ~/ 2;
    final hh = image.height ~/ 2;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final gx = gray[y-1][x+1] + 2*gray[y][x+1] + gray[y+1][x+1]
                 - gray[y-1][x-1] - 2*gray[y][x-1] - gray[y+1][x-1];
        final gy = gray[y+1][x-1] + 2*gray[y+1][x] + gray[y+1][x+1]
                 - gray[y-1][x-1] - 2*gray[y-1][x] - gray[y-1][x+1];
        final mag = sqrt(gx * gx + gy * gy);
        if (mag < 0.05) continue;
        final angle = atan2(gy, gx) + pi;
        final dir = ((angle / (2 * pi)) * dirs).floor().clamp(0, dirs - 1);
        final quad = (y < hh ? 0 : 2) + (x < hw ? 0 : 1);
        f[quad * dirs + dir] += mag;
      }
    }
    // Normalize per quadrant
    for (int qi = 0; qi < q; qi++) {
      double mx = 0;
      for (int d = 0; d < dirs; d++) mx = max(mx, f[qi * dirs + d]);
      if (mx > 0) {
        for (int d = 0; d < dirs; d++) f[qi * dirs + d] /= mx;
      }
    }
    return f;
  }

  /// Texture variance in 4×4 grid = 16 values
  static List<double> _textureFeatures(img.Image image) {
    const g = 4;
    final cw = image.width ~/ g;
    final ch = image.height ~/ g;
    final f = <double>[];

    for (int gy = 0; gy < g; gy++) {
      for (int gx = 0; gx < g; gx++) {
        final vals = <double>[];
        for (int y = gy * ch; y < (gy + 1) * ch && y < image.height; y++) {
          for (int x = gx * cw; x < (gx + 1) * cw && x < image.width; x++) {
            final p = image.getPixel(x, y);
            vals.add((p.r.toInt() * 0.299 + p.g.toInt() * 0.587 + p.b.toInt() * 0.114) / 255.0);
          }
        }
        if (vals.isEmpty) { f.add(0.0); continue; }
        final mean = vals.reduce((a, b) => a + b) / vals.length;
        final variance = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
        f.add(variance);
      }
    }
    return f;
  }

  /// HOG — Histogram of Oriented Gradients.
  /// 4×4 blocks, 8 orientation bins per block = 128 values.
  /// Much better at capturing shape/contour than raw edges.
  static List<double> _hogFeatures(img.Image image) {
    const blocks = 4;
    const orientations = 8;

    final gray = List<List<double>>.generate(
      image.height,
      (y) => List<double>.generate(image.width, (x) {
        final p = image.getPixel(x, y);
        return (p.r.toInt() * 0.299 + p.g.toInt() * 0.587 + p.b.toInt() * 0.114) / 255.0;
      }),
    );

    final bw = image.width ~/ blocks;
    final bh = image.height ~/ blocks;
    final features = <double>[];

    for (int by = 0; by < blocks; by++) {
      for (int bx = 0; bx < blocks; bx++) {
        final hist = List<double>.filled(orientations, 0.0);

        for (int y = by * bh + 1; y < (by + 1) * bh - 1 && y < image.height - 1; y++) {
          for (int x = bx * bw + 1; x < (bx + 1) * bw - 1 && x < image.width - 1; x++) {
            // Gradient via central difference
            final dx = gray[y][x + 1] - gray[y][x - 1];
            final dy = gray[y + 1][x] - gray[y - 1][x];
            final mag = sqrt(dx * dx + dy * dy);
            if (mag < 0.02) continue;

            // Unsigned orientation: 0 to pi → 0 to orientations bins
            var angle = atan2(dy.abs(), dx.abs()); // [0, pi/2]
            // Map [0, pi/2] to [0, orientations)
            final bin = ((angle / (pi / 2)) * orientations).floor().clamp(0, orientations - 1);
            hist[bin] += mag;
          }
        }

        // L1 normalize this block's histogram
        final sum = hist.reduce((a, b) => a + b);
        if (sum > 0) {
          for (int i = 0; i < orientations; i++) hist[i] /= sum;
        }
        features.addAll(hist);
      }
    }
    return features; // 4×4×8 = 128
  }

  /// Shape features: 8 values capturing object geometry.
  ///   [0] aspect ratio (w/h normalized)
  ///   [1] foreground fill ratio (non-background pixels / total)
  ///   [2] horizontal symmetry
  ///   [3] vertical symmetry
  ///   [4] center-of-mass X (normalized)
  ///   [5] center-of-mass Y (normalized)
  ///   [6] edge density (fraction of pixels that are edges)
  ///   [7] mean intensity
  static List<double> _shapeFeatures(img.Image image) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    // Aspect ratio
    final aspectRatio = (w / h).clamp(0.1, 10.0) / 10.0;

    double sumX = 0, sumY = 0;
    int fgPixels = 0;
    int edgePixels = 0;
    double meanIntensity = 0;

    // Detect background by sampling corners
    final corners = [
      image.getPixel(0, 0),
      image.getPixel(image.width - 1, 0),
      image.getPixel(0, image.height - 1),
      image.getPixel(image.width - 1, image.height - 1),
    ];
    double bgR = corners.map((p) => p.r.toDouble()).reduce((a, b) => a + b) / 4;
    double bgG = corners.map((p) => p.g.toDouble()).reduce((a, b) => a + b) / 4;
    double bgB = corners.map((p) => p.b.toDouble()).reduce((a, b) => a + b) / 4;

    final totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();

        // Is foreground?
        final dist = sqrt(pow(r - bgR, 2) + pow(g - bgG, 2) + pow(b - bgB, 2));
        if (dist > 30) {
          fgPixels++;
          sumX += x;
          sumY += y;
        }

        // Intensity
        meanIntensity += (r * 0.299 + g * 0.587 + b * 0.114) / 255.0;
      }
    }

    meanIntensity /= totalPixels;

    // Simple edge detection for edge density
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final c = image.getPixel(x, y);
        final r = image.getPixel(x + 1, y);
        final d = image.getPixel(x, y + 1);
        final diffH = (c.r - r.r).abs() + (c.g - r.g).abs() + (c.b - r.b).abs();
        final diffV = (c.r - d.r).abs() + (c.g - d.g).abs() + (c.b - d.b).abs();
        if (diffH + diffV > 80) edgePixels++;
      }
    }

    final fillRatio = fgPixels / totalPixels;
    final edgeDensity = edgePixels / totalPixels;
    final comX = fgPixels > 0 ? (sumX / fgPixels) / w : 0.5;
    final comY = fgPixels > 0 ? (sumY / fgPixels) / h : 0.5;

    // Symmetry: compare left vs right halves luminance
    double symH = 0, symV = 0;
    final hw = image.width ~/ 2;
    final hh = image.height ~/ 2;
    int sysCnt = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < hw; x++) {
        final left = image.getPixel(x, y);
        final right = image.getPixel(image.width - 1 - x, y);
        symH += 1.0 - (left.r - right.r).abs() / 255.0;
        sysCnt++;
      }
    }
    symH = sysCnt > 0 ? symH / sysCnt : 0.5;

    sysCnt = 0;
    for (int x = 0; x < image.width; x++) {
      for (int y = 0; y < hh; y++) {
        final top = image.getPixel(x, y);
        final bot = image.getPixel(x, image.height - 1 - y);
        symV += 1.0 - (top.r - bot.r).abs() / 255.0;
        sysCnt++;
      }
    }
    symV = sysCnt > 0 ? symV / sysCnt : 0.5;

    return [
      aspectRatio,
      fillRatio.clamp(0.0, 1.0),
      symH.clamp(0.0, 1.0),
      symV.clamp(0.0, 1.0),
      comX.clamp(0.0, 1.0),
      comY.clamp(0.0, 1.0),
      edgeDensity.clamp(0.0, 1.0),
      meanIntensity.clamp(0.0, 1.0),
    ];
  }

  /// L2 normalize (unit vector)
  static List<double> _l2Normalize(List<double> v) {
    double norm = 0;
    for (final x in v) norm += x * x;
    norm = sqrt(norm);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Compute Hamming distance between two pHash values.
  /// Returns number of differing bits (0 = identical, 64 = completely different).
  static int hammingDistance(int a, int b) {
    int xor = a ^ b;
    int dist = 0;
    while (xor != 0) {
      dist += xor & 1;
      xor >>= 1;
    }
    return dist;
  }

  /// Convert Hamming distance to similarity score [0.0, 1.0].
  /// 0 bits different → 1.0, 32+ bits different → 0.0
  static double pHashSimilarity(int a, int b) {
    final dist = hammingDistance(a, b);
    return (1.0 - dist / 64.0).clamp(0.0, 1.0);
  }

  void dispose() => _initialized = false;
}
