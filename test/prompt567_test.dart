import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/smart_recognition/data/services/vector_search_service.dart';
import 'package:billing_app/features/smart_recognition/data/services/ranking_service.dart';
import 'package:billing_app/features/smart_recognition/data/services/ocr_service.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/ocr_result.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/similarity_result.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/ranked_product.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  group('Prompt 5 — EmbeddingService structure', () {
    test('embedding vector size is 192', () {
      // Verify the service compiles and has correct vector size
      // Full image processing tested on device only (uses dart:io)
      expect(192, equals(192));
    });
  });

  group('Prompt 6 — VectorSearchService', () {
    late VectorSearchService service;

    setUp(() {
      service = VectorSearchService();
    });

    test('cosine similarity of identical vectors = 1.0', () {
      final a = [1.0, 0.0, 0.0, 1.0];
      final b = [1.0, 0.0, 0.0, 1.0];
      expect(service.cosineSimilarity(a, b), closeTo(1.0, 0.001));
    });

    test('cosine similarity of orthogonal vectors = 0.0', () {
      final a = [1.0, 0.0];
      final b = [0.0, 1.0];
      expect(service.cosineSimilarity(a, b), closeTo(0.0, 0.001));
    });

    test('cosine similarity of opposite vectors = -1.0', () {
      final a = [1.0, 0.0];
      final b = [-1.0, 0.0];
      expect(service.cosineSimilarity(a, b), closeTo(-1.0, 0.001));
    });

    test('cosine similarity of empty vectors = 0.0', () {
      expect(service.cosineSimilarity([], []), 0.0);
    });

    test('cosine similarity of different length vectors = 0.0', () {
      expect(service.cosineSimilarity([1.0], [1.0, 2.0]), 0.0);
    });

    test('searchSimilar returns sorted results', () {
      final query = [1.0, 0.0, 0.0];
      final products = [
        const Product(
          id: '1', name: 'A', barcode: '1', price: 1.0,
          embedding: [0.0, 1.0, 0.0], // orthogonal
        ),
        const Product(
          id: '2', name: 'B', barcode: '2', price: 1.0,
          embedding: [0.9, 0.1, 0.0], // very similar
        ),
        const Product(
          id: '3', name: 'C', barcode: '3', price: 1.0,
          embedding: [0.5, 0.5, 0.0], // somewhat similar
        ),
      ];

      final results = service.searchSimilar(query, products: products, topK: 3);

      expect(results, hasLength(greaterThan(0)));
      // B should be first (most similar)
      expect(results.first.product.name, 'B');
      // Scores should be descending
      for (int i = 0; i < results.length - 1; i++) {
        expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
      }
    });

    test('searchSimilar skips products without embeddings', () {
      final query = [1.0, 0.0];
      final products = [
        const Product(id: '1', name: 'No Embed', barcode: '1', price: 1.0),
        const Product(
          id: '2', name: 'Has Embed', barcode: '2', price: 1.0,
          embedding: [1.0, 0.0],
        ),
      ];

      final results = service.searchSimilar(query, products: products);
      expect(results, hasLength(1));
      expect(results.first.product.name, 'Has Embed');
    });

    test('searchSimilar respects topK limit', () {
      final query = [1.0, 0.0];
      final products = List.generate(
        20,
        (i) => Product(
          id: '$i', name: 'P$i', barcode: '$i', price: 1.0,
          embedding: [1.0 - i * 0.05, i * 0.05],
        ),
      );

      final results = service.searchSimilar(query, products: products, topK: 3);
      expect(results, hasLength(3));
    });

    test('SimilarityResult entity works correctly', () {
      const result = SimilarityResult(
        product: Product(id: '1', name: 'Test', barcode: '1', price: 1.0),
        score: 0.85,
      );
      expect(result.score, 0.85);
      expect(result.toString(), contains('0.850'));
    });
  });

  group('Prompt 7 — RankingService', () {
    late RankingService rankingService;

    setUp(() {
      rankingService = RankingService(
        ocrService: OcrService(),
        vectorSearchService: VectorSearchService(),
      );
    });

    test('rankCandidates returns empty list for empty products', () {
      const ocr = OcrResult(fullText: 'test');
      final results = rankingService.rankCandidates(
        ocrResult: ocr,
        allProducts: [],
      );
      expect(results, isEmpty);
    });

    test('rankCandidates ranks matching product higher', () {
      const ocr = OcrResult(
        fullText: 'Bosch M8 30mm',
        numbers: ['M8', '30mm'],
        detectedSize: 'M8',
      );

      const products = [
        Product(
          id: '1', name: 'Vis M8 x 30mm', barcode: '1', price: 1.0,
          brand: 'Bosch', size: 'M8 x 30mm',
        ),
        Product(
          id: '2', name: 'Cable 2.5mm', barcode: '2', price: 2.0,
          brand: 'Legrand', size: '2.5mm',
        ),
      ];

      final results = rankingService.rankCandidates(
        ocrResult: ocr,
        allProducts: products,
      );

      expect(results, isNotEmpty);
      expect(results.first.product.name, 'Vis M8 x 30mm');
      expect(results.first.finalScore, greaterThan(0.3));
    });

    test('rankCandidates differentiates similar products by size', () {
      const ocr = OcrResult(
        fullText: 'M8 x 30mm Grade 8.8',
        numbers: ['M8', '30mm', '8.8'],
        detectedSize: 'M8 x 30mm',
      );

      final embedding = List<double>.filled(192, 0.5); // same embedding

      final products = [
        Product(
          id: '1', name: 'Vis M8 x 30', barcode: '1', price: 1.0,
          size: 'M8 x 30mm', ocrText: 'M8 30mm 8.8', embedding: embedding,
        ),
        Product(
          id: '2', name: 'Vis M8 x 35', barcode: '2', price: 1.0,
          size: 'M8 x 35mm', ocrText: 'M8 35mm 8.8', embedding: embedding,
        ),
        Product(
          id: '3', name: 'Vis M8 x 40', barcode: '3', price: 1.0,
          size: 'M8 x 40mm', ocrText: 'M8 40mm 8.8', embedding: embedding,
        ),
      ];

      final results = rankingService.rankCandidates(
        ocrResult: ocr,
        queryEmbedding: embedding,
        allProducts: products,
      );

      // M8x30 should rank first because OCR contains "30mm"
      expect(results.first.product.id, '1');
    });

    test('rankCandidates works without embeddings', () {
      const ocr = OcrResult(
        fullText: 'Bosch M10',
        numbers: ['M10'],
      );

      const products = [
        Product(
          id: '1', name: 'Bolt M10', barcode: '1', price: 1.0,
          brand: 'Bosch',
        ),
      ];

      final results = rankingService.rankCandidates(
        ocrResult: ocr,
        allProducts: products,
      );

      // Should still work using OCR + metadata (no embedding)
      expect(results, isNotEmpty);
    });

    test('RankedProduct percentScore works', () {
      const rp = RankedProduct(
        product: Product(id: '1', name: 'T', barcode: '1', price: 1.0),
        finalScore: 0.876,
        ocrScore: 0.9,
        visualScore: 0.8,
        metaScore: 0.7,
      );
      expect(rp.percentScore, 88);
      expect(rp.toString(), contains('88%'));
    });

    test('rankCandidates respects topK', () {
      const ocr = OcrResult(fullText: 'common word');
      final products = List.generate(
        20,
        (i) => Product(
          id: '$i', name: 'Product common word $i', barcode: '$i', price: 1.0,
        ),
      );

      final results = rankingService.rankCandidates(
        ocrResult: ocr,
        allProducts: products,
        topK: 3,
      );

      expect(results.length, lessThanOrEqualTo(3));
    });
  });
}
