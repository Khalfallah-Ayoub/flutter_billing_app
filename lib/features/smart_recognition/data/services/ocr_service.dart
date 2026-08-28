import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/entities/ocr_result.dart';
import '../../../product/domain/entities/product.dart';

/// On-device OCR service using Google ML Kit.
/// Works offline, no internet required, completely free.
class OcrService {
  TextRecognizer? _textRecognizer;

  /// Initialize the text recognizer (lazy — called on first use)
  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  // --- Regex patterns for extracting product-relevant information ---

  /// Matches measurements: 30mm, 10cm, 5m, 100kg, 500g, 250ml, 1.5l
  static final RegExp _measurementPattern = RegExp(
    r'(\d+(?:\.\d+)?)\s*(mm|cm|m|kg|g|ml|l|inch|in)\b',
    caseSensitive: false,
  );

  /// Matches bolt/screw sizes: M8, M10, M12
  static final RegExp _metricSizePattern = RegExp(
    r'\bM(\d+)\b',
    caseSensitive: false,
  );

  /// Matches dimension patterns: 8x30, 10 x 40, M8x30
  static final RegExp _dimensionPattern = RegExp(
    r'(\d+)\s*[xX×]\s*(\d+)',
  );

  /// Matches grade/class patterns: 8.8, 10.9, A2, A4
  static final RegExp _gradePattern = RegExp(
    r'\b(\d+\.\d+|[A-Z]\d)\b',
  );

  /// Extract text from an image file using on-device ML Kit OCR.
  /// Returns [OcrResult] with parsed text, numbers, and patterns.
  /// Returns empty result on web or if OCR fails.
  Future<OcrResult> extractText(String imagePath) async {
    // ML Kit doesn't work on web
    if (kIsWeb) {
      return const OcrResult(fullText: '');
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);

      final fullText = recognizedText.text;
      final textBlocks =
          recognizedText.blocks.map((b) => b.text).toList();

      // Extract numbers and measurements
      final numbers = _extractNumbers(fullText);
      final detectedSize = _extractSize(fullText);

      return OcrResult(
        fullText: fullText,
        numbers: numbers,
        detectedBrand: null, // Brand detection is done via matchOcrWithProduct
        detectedSize: detectedSize,
        textBlocks: textBlocks,
      );
    } catch (e) {
      debugPrint('OcrService: extractText error: $e');
      return const OcrResult(fullText: '');
    }
  }

  /// Extract numbers, measurements, and dimension patterns from text.
  List<String> _extractNumbers(String text) {
    final results = <String>{};

    // Measurements (30mm, 10cm, etc.)
    for (final match in _measurementPattern.allMatches(text)) {
      results.add(match.group(0)!);
    }

    // Metric sizes (M8, M10)
    for (final match in _metricSizePattern.allMatches(text)) {
      results.add(match.group(0)!);
    }

    // Dimensions (8x30, 10x40)
    for (final match in _dimensionPattern.allMatches(text)) {
      results.add(match.group(0)!);
    }

    // Grades (8.8, 10.9, A2)
    for (final match in _gradePattern.allMatches(text)) {
      final g = match.group(0)!;
      // Avoid adding pure numbers that are already measurements
      if (!results.any((r) => r.contains(g))) {
        results.add(g);
      }
    }

    return results.toList();
  }

  /// Extract a size/dimension string from OCR text.
  /// Looks for patterns like "M8 x 30mm", "M10x40", "30mm"
  String? _extractSize(String text) {
    // Try "M8 x 30mm" style first
    final mDim = RegExp(r'M\d+\s*[xX×]\s*\d+(?:\.\d+)?\s*(?:mm|cm)?',
            caseSensitive: false)
        .firstMatch(text);
    if (mDim != null) return mDim.group(0);

    // Try "30 x 40" dimension style
    final dim = _dimensionPattern.firstMatch(text);
    if (dim != null) return dim.group(0);

    // Try single measurement
    final meas = _measurementPattern.firstMatch(text);
    if (meas != null) return meas.group(0);

    // Try metric size alone (M8, M10)
    final metric = _metricSizePattern.firstMatch(text);
    if (metric != null) return metric.group(0);

    return null;
  }

  /// Match OCR result against a product's stored data.
  /// Returns a score between 0.0 (no match) and 1.0 (perfect match).
  double matchOcrWithProduct(OcrResult ocr, Product product) {
    if (!ocr.hasText) return 0.0;

    final ocrLower = ocr.fullText.toLowerCase();
    double totalScore = 0.0;
    int checks = 0;

    // 1. Match against product name
    final nameScore = _fuzzyContains(ocrLower, product.name.toLowerCase());
    totalScore += nameScore;
    checks++;

    // 2. Match against product ocrText (previously stored OCR)
    if (product.ocrText != null && product.ocrText!.isNotEmpty) {
      final ocrTextScore =
          _fuzzyContains(ocrLower, product.ocrText!.toLowerCase());
      totalScore += ocrTextScore;
      checks++;
    }

    // 3. Match against brand
    if (product.brand != null && product.brand!.isNotEmpty) {
      final brandScore =
          _fuzzyContains(ocrLower, product.brand!.toLowerCase());
      totalScore += brandScore * 1.2; // Bonus weight for brand match
      checks++;
    }

    // 4. Match against size
    if (product.size != null && product.size!.isNotEmpty) {
      final sizeScore = _fuzzyContains(ocrLower, product.size!.toLowerCase());
      totalScore += sizeScore * 1.5; // Higher weight — size differentiates similar products
      checks++;
    }

    // 5. Match extracted numbers against product data
    if (ocr.hasNumbers) {
      final productText =
          '${product.name} ${product.size ?? ''} ${product.ocrText ?? ''}'
              .toLowerCase();
      int matchedNumbers = 0;
      for (final num in ocr.numbers) {
        if (productText.contains(num.toLowerCase())) {
          matchedNumbers++;
        }
      }
      if (ocr.numbers.isNotEmpty) {
        final numberScore = matchedNumbers / ocr.numbers.length;
        totalScore += numberScore * 1.5; // High weight for number matches
        checks++;
      }
    }

    return checks > 0 ? (totalScore / checks).clamp(0.0, 1.0) : 0.0;
  }

  /// Simple fuzzy containment score.
  /// Checks if words from [query] appear in [text].
  /// Returns 0.0 to 1.0 based on how many words match.
  double _fuzzyContains(String text, String query) {
    if (query.isEmpty) return 0.0;

    final queryWords =
        query.split(RegExp(r'[\s,.\-/]+'))
            .where((w) => w.length > 1)
            .toList();

    if (queryWords.isEmpty) return 0.0;

    int matched = 0;
    for (final word in queryWords) {
      if (text.contains(word)) {
        matched++;
      }
    }

    return matched / queryWords.length;
  }

  /// Detect brand from OCR text by matching against known brands in the database.
  /// Call this after extractText to fill in the detectedBrand field.
  OcrResult detectBrandFromProducts(OcrResult ocr, List<Product> products) {
    if (!ocr.hasText) return ocr;

    final ocrLower = ocr.fullText.toLowerCase();

    // Collect unique brands from products
    final brands = products
        .where((p) => p.brand != null && p.brand!.isNotEmpty)
        .map((p) => p.brand!)
        .toSet();

    for (final brand in brands) {
      if (ocrLower.contains(brand.toLowerCase())) {
        return OcrResult(
          fullText: ocr.fullText,
          numbers: ocr.numbers,
          detectedBrand: brand,
          detectedSize: ocr.detectedSize,
          textBlocks: ocr.textBlocks,
        );
      }
    }

    return ocr;
  }

  /// Release resources
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
