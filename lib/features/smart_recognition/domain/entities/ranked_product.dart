import 'package:equatable/equatable.dart';
import '../../../product/domain/entities/product.dart';

/// A product scored by the multi-signal ranking engine.
class RankedProduct extends Equatable {
  final Product product;
  final double finalScore;
  final double ocrScore;
  final double visualScore;
  final double metaScore;

  const RankedProduct({
    required this.product,
    required this.finalScore,
    required this.ocrScore,
    required this.visualScore,
    required this.metaScore,
  });

  /// Final score as a percentage (0-100)
  int get percentScore => (finalScore * 100).round();

  @override
  List<Object?> get props =>
      [product, finalScore, ocrScore, visualScore, metaScore];

  @override
  String toString() =>
      'RankedProduct(${product.name}: ${percentScore}% '
      '[ocr=${ocrScore.toStringAsFixed(2)}, '
      'vis=${visualScore.toStringAsFixed(2)}, '
      'meta=${metaScore.toStringAsFixed(2)}])';
}
