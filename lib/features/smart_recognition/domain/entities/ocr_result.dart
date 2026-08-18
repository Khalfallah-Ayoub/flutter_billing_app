import 'package:equatable/equatable.dart';

/// Represents the result of OCR text extraction from a product image.
class OcrResult extends Equatable {
  /// The full extracted text from the image.
  final String fullText;

  /// Extracted numbers and measurements (e.g., "30mm", "M8", "8.8").
  final List<String> numbers;

  /// Detected brand name if it matches a known brand in the database.
  final String? detectedBrand;

  /// Detected size/dimension pattern if found.
  final String? detectedSize;

  /// All individual text blocks found in the image.
  final List<String> textBlocks;

  const OcrResult({
    required this.fullText,
    this.numbers = const [],
    this.detectedBrand,
    this.detectedSize,
    this.textBlocks = const [],
  });

  /// Returns true if meaningful text was extracted.
  bool get hasText => fullText.trim().isNotEmpty;

  /// Returns true if any numeric/measurement pattern was found.
  bool get hasNumbers => numbers.isNotEmpty;

  @override
  List<Object?> get props => [
        fullText,
        numbers,
        detectedBrand,
        detectedSize,
        textBlocks,
      ];

  @override
  String toString() =>
      'OcrResult(text: "${fullText.length > 50 ? '${fullText.substring(0, 50)}...' : fullText}", '
      'numbers: $numbers, brand: $detectedBrand, size: $detectedSize)';
}
