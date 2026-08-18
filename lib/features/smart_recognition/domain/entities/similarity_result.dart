import 'package:equatable/equatable.dart';
import '../../../product/domain/entities/product.dart';

/// Represents a product matched by vector similarity search.
class SimilarityResult extends Equatable {
  /// The matched product
  final Product product;

  /// Cosine similarity score (0.0 to 1.0)
  final double score;

  const SimilarityResult({
    required this.product,
    required this.score,
  });

  @override
  List<Object?> get props => [product, score];

  @override
  String toString() =>
      'SimilarityResult(product: ${product.name}, score: ${score.toStringAsFixed(3)})';
}
