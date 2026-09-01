import '../../domain/entities/ocr_result.dart';
import '../../domain/entities/ranked_product.dart';
import '../../../product/domain/entities/product.dart';
import 'ocr_service.dart';
import 'vector_search_service.dart';
import 'embedding_service.dart';

/// Multi-signal ranking engine v2.0
///
/// ADAPTIVE WEIGHT SYSTEM:
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Scenario                   │ OCR  │ Visual │ pHash │ Meta  │
/// ├────────────────────────────┼──────┼────────┼───────┼───────┤
/// │ Text detected + embeddings │ 40%  │  25%   │  15%  │  20%  │
/// │ Text only (no embeddings)  │ 65%  │   0%   │   0%  │  35%  │
/// │ No text + embeddings       │  0%  │  55%   │  35%  │  10%  │
/// │ No text + pHash only       │  0%  │   0%   │  80%  │  20%  │
/// │ No text, no embeddings     │  0%  │   0%   │   0%  │ 100%  │
/// └─────────────────────────────────────────────────────────────┘
class RankingService {
  final OcrService _ocrService;
  final VectorSearchService _vectorSearchService;

  RankingService({
    required OcrService ocrService,
    required VectorSearchService vectorSearchService,
  })  : _ocrService = ocrService,
        _vectorSearchService = vectorSearchService;

  /// Rank candidate products using all available signals adaptively.
  List<RankedProduct> rankCandidates({
    required OcrResult ocrResult,
    List<double>? queryEmbedding,
    int? queryPHash,
    required List<Product> allProducts,
    int topK = 5,
  }) {
    if (allProducts.isEmpty) return [];

    final hasOcr = ocrResult.hasText;
    final hasEmbedding = queryEmbedding != null;
    final hasPHash = queryPHash != null;

    final results = <RankedProduct>[];

    for (final product in allProducts) {
      // ── 1. OCR Score ─────────────────────────────────────────────
      final ocrScore = hasOcr
          ? _ocrService.matchOcrWithProduct(ocrResult, product)
          : 0.0;

      // ── 2. Visual (Cosine) Score ──────────────────────────────────
      double visualScore = 0.0;
      if (hasEmbedding && product.embedding != null && product.embedding!.isNotEmpty) {
        visualScore = _vectorSearchService
            .cosineSimilarity(queryEmbedding, product.embedding!)
            .clamp(0.0, 1.0);
      }

      // ── 3. pHash Similarity Score ─────────────────────────────────
      double pHashScore = 0.0;
      if (hasPHash && product.pHash != null) {
        pHashScore = EmbeddingService.pHashSimilarity(queryPHash, product.pHash!);
      }

      // ── 4. Metadata Score ─────────────────────────────────────────
      final metaScore = _matchMetadata(ocrResult, product);

      // ── 5. Adaptive weighting ─────────────────────────────────────
      final double finalScore;

      if (hasOcr && hasEmbedding) {
        // Full signals
        finalScore = ocrScore * 0.40 +
            visualScore * 0.25 +
            pHashScore * 0.15 +
            metaScore * 0.20;
      } else if (hasOcr && !hasEmbedding) {
        // Only text
        finalScore = ocrScore * 0.65 + metaScore * 0.35;
      } else if (!hasOcr && hasEmbedding && hasPHash) {
        // No text, both visual signals → visual dominates
        finalScore = visualScore * 0.55 + pHashScore * 0.35 + metaScore * 0.10;
      } else if (!hasOcr && hasEmbedding && !hasPHash) {
        // No text, embedding only
        finalScore = visualScore * 0.85 + metaScore * 0.15;
      } else if (!hasOcr && !hasEmbedding && hasPHash) {
        // No text, pHash only
        finalScore = pHashScore * 0.80 + metaScore * 0.20;
      } else {
        // Nothing — only metadata (fallback)
        finalScore = metaScore;
      }

      // Minimum threshold: only include meaningful matches
      final threshold = (hasOcr || hasEmbedding || hasPHash) ? 0.05 : 0.15;
      if (finalScore > threshold) {
        results.add(RankedProduct(
          product: product,
          finalScore: finalScore.clamp(0.0, 1.0),
          ocrScore: ocrScore,
          visualScore: visualScore,
          metaScore: metaScore,
        ));
      }
    }

    results.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return results.take(topK).toList();
  }

  /// Match OCR-detected information against product metadata.
  double _matchMetadata(OcrResult ocr, Product product) {
    if (!ocr.hasText) return 0.0;

    double score = 0.0;
    int checks = 0;
    final ocrLower = ocr.fullText.toLowerCase();

    if (product.brand != null && product.brand!.isNotEmpty) {
      checks++;
      if (ocrLower.contains(product.brand!.toLowerCase())) score += 1.0;
    }

    if (product.category != null && product.category!.isNotEmpty) {
      checks++;
      if (ocrLower.contains(product.category!.toLowerCase())) score += 0.5;
    }

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
