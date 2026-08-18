import '../../domain/entities/ocr_result.dart';
import '../../domain/entities/ranked_product.dart';
import '../../../product/domain/entities/product.dart';
import 'ocr_service.dart';
import 'vector_search_service.dart';

/// Multi-signal ranking engine that combines OCR, visual similarity,
/// and metadata matching to rank candidate products.
///
/// Weights:
///   - OCR Match:        45% (critical for differentiating similar products)
///   - Visual Similarity: 30% (useful for general shape/color matching)
///   - Metadata Match:    25% (brand + category narrow down candidates)
class RankingService {
  static const double _ocrWeight = 0.45;
  static const double _visualWeight = 0.30;
  static const double _metaWeight = 0.25;

  final OcrService _ocrService;
  final VectorSearchService _vectorSearchService;

  RankingService({
    required OcrService ocrService,
    required VectorSearchService vectorSearchService,
  })  : _ocrService = ocrService,
        _vectorSearchService = vectorSearchService;

  /// Rank candidate products using all available signals.
  ///
  /// [ocrResult] — text extracted from query image
  /// [queryEmbedding] — feature vector of query image (nullable if embedding failed)
  /// [allProducts] — all products from the database
  /// [topK] — number of top results to return
  List<RankedProduct> rankCandidates({
    required OcrResult ocrResult,
    List<double>? queryEmbedding,
    required List<Product> allProducts,
    int topK = 5,
  }) {
    if (allProducts.isEmpty) return [];

    final results = <RankedProduct>[];

    for (final product in allProducts) {
      // 1. OCR Score (0.0 - 1.0)
      final ocrScore = _ocrService.matchOcrWithProduct(ocrResult, product);

      // 2. Visual Score (0.0 - 1.0)
      double visualScore = 0.0;
      if (queryEmbedding != null &&
          product.embedding != null &&
          product.embedding!.isNotEmpty) {
        visualScore = _vectorSearchService.cosineSimilarity(
          queryEmbedding,
          product.embedding!,
        );
        // Clamp to 0-1 range (cosine similarity can be negative)
        visualScore = visualScore.clamp(0.0, 1.0);
      }

      // 3. Metadata Score (0.0 - 1.0)
      final metaScore = _matchMetadata(ocrResult, product);

      // Compute final weighted score
      double finalScore;
      if (queryEmbedding != null &&
          product.embedding != null &&
          product.embedding!.isNotEmpty) {
        // Full scoring with all 3 signals
        finalScore = (ocrScore * _ocrWeight) +
            (visualScore * _visualWeight) +
            (metaScore * _metaWeight);
      } else {
        // No embedding available — redistribute visual weight
        // OCR gets 65%, metadata gets 35%
        finalScore = (ocrScore * 0.65) + (metaScore * 0.35);
      }

      // Only include products with some match
      if (finalScore > 0.05) {
        results.add(RankedProduct(
          product: product,
          finalScore: finalScore.clamp(0.0, 1.0),
          ocrScore: ocrScore,
          visualScore: visualScore,
          metaScore: metaScore,
        ));
      }
    }

    // Sort by final score descending
    results.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    return results.take(topK).toList();
  }

  /// Match OCR-detected information against product metadata.
  /// Checks brand and category matches.
  double _matchMetadata(OcrResult ocr, Product product) {
    if (!ocr.hasText) return 0.0;

    double score = 0.0;
    int checks = 0;

    final ocrLower = ocr.fullText.toLowerCase();

    // Brand match
    if (product.brand != null && product.brand!.isNotEmpty) {
      checks++;
      if (ocrLower.contains(product.brand!.toLowerCase())) {
        score += 1.0;
      }
    }

    // Category match (less reliable from OCR, lower contribution)
    if (product.category != null && product.category!.isNotEmpty) {
      checks++;
      if (ocrLower.contains(product.category!.toLowerCase())) {
        score += 0.5;
      }
    }

    // Size/dimension match from OCR detection
    if (ocr.detectedSize != null &&
        product.size != null &&
        product.size!.isNotEmpty) {
      checks++;
      if (product.size!.toLowerCase().contains(ocr.detectedSize!.toLowerCase())) {
        score += 1.0;
      }
    }

    return checks > 0 ? (score / checks).clamp(0.0, 1.0) : 0.0;
  }
}
