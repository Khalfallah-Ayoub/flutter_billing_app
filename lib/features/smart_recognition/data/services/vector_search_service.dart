import 'dart:math';
import '../../domain/entities/similarity_result.dart';
import '../../../product/domain/entities/product.dart';
import '../../../../core/data/hive_database.dart';

/// Local brute-force vector search using cosine similarity.
/// Sufficient for ≤1000 products — takes <20ms on any modern phone.
/// Fully offline, no external database needed.
class VectorSearchService {
  /// Compute cosine similarity between two vectors.
  /// Returns a value between -1.0 and 1.0 (1.0 = identical).
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;

    return dot / denominator;
  }

  /// Search for the most similar products based on embedding vectors.
  /// [queryEmbedding] — the embedding vector of the query image
  /// [topK] — number of top results to return (default 5)
  ///
  /// Only searches products that have a non-null embedding.
  /// Returns results sorted by similarity score (descending).
  List<SimilarityResult> searchSimilar(
    List<double> queryEmbedding, {
    int topK = 5,
    List<Product>? products,
  }) {
    // Get products either from parameter or from Hive directly
    final allProducts = products ?? _getProductsFromHive();

    final results = <SimilarityResult>[];

    for (final product in allProducts) {
      if (product.embedding == null || product.embedding!.isEmpty) continue;

      final score = cosineSimilarity(queryEmbedding, product.embedding!);

      // Only include products with positive similarity
      if (score > 0.0) {
        results.add(SimilarityResult(
          product: product,
          score: score,
        ));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.score.compareTo(a.score));

    // Return top K
    return results.take(topK).toList();
  }

  /// Get all products from Hive database
  List<Product> _getProductsFromHive() {
    try {
      return HiveDatabase.productBox.values
          .map((model) => model.toEntity())
          .toList();
    } catch (e) {
      return [];
    }
  }
}
