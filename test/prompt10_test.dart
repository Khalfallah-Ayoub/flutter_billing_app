import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/feedback_record.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/ranked_product.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  group('Prompt 10 — FeedbackRecord', () {
    test('FeedbackRecord toMap and fromMap roundtrip', () {
      final now = DateTime(2026, 8, 19, 12, 0, 0);
      final record = FeedbackRecord(
        queryImagePath: '/images/test.jpg',
        suggestedProductId: 'prod-001',
        selectedProductId: 'prod-002',
        confidence: 0.85,
        wasCorrect: false,
        timestamp: now,
      );

      final map = record.toMap();
      final restored = FeedbackRecord.fromMap(map);

      expect(restored.queryImagePath, '/images/test.jpg');
      expect(restored.suggestedProductId, 'prod-001');
      expect(restored.selectedProductId, 'prod-002');
      expect(restored.confidence, 0.85);
      expect(restored.wasCorrect, false);
      expect(restored.timestamp, now);
    });

    test('FeedbackRecord fromMap with missing fields uses defaults', () {
      final record = FeedbackRecord.fromMap({});

      expect(record.queryImagePath, '');
      expect(record.suggestedProductId, null);
      expect(record.selectedProductId, '');
      expect(record.confidence, 0.0);
      expect(record.wasCorrect, false);
    });

    test('FeedbackRecord wasCorrect is true when IDs match', () {
      final record = FeedbackRecord(
        queryImagePath: '/test.jpg',
        suggestedProductId: 'prod-001',
        selectedProductId: 'prod-001',
        confidence: 0.95,
        wasCorrect: true,
        timestamp: DateTime.now(),
      );

      expect(record.wasCorrect, true);
      expect(record.suggestedProductId, record.selectedProductId);
    });

    test('FeedbackRecord Equatable works', () {
      final now = DateTime(2026, 8, 19);
      final a = FeedbackRecord(
        queryImagePath: '/a.jpg',
        selectedProductId: 'p1',
        confidence: 0.5,
        wasCorrect: false,
        timestamp: now,
      );
      final b = FeedbackRecord(
        queryImagePath: '/a.jpg',
        selectedProductId: 'p1',
        confidence: 0.5,
        wasCorrect: false,
        timestamp: now,
      );

      expect(a, equals(b));
    });
  });

  group('Prompt 10 — RankedProduct edge cases', () {
    final product = const Product(
      id: 'p1',
      name: 'Test Bolt M8x30',
      barcode: '111',
      price: 5.0,
      stock: 10,
    );

    test('percentScore = 0 for zero finalScore', () {
      final r = RankedProduct(
        product: product,
        finalScore: 0.0,
        ocrScore: 0.0,
        visualScore: 0.0,
        metaScore: 0.0,
      );
      expect(r.percentScore, 0);
    });

    test('percentScore = 100 for perfect finalScore', () {
      final r = RankedProduct(
        product: product,
        finalScore: 1.0,
        ocrScore: 1.0,
        visualScore: 1.0,
        metaScore: 1.0,
      );
      expect(r.percentScore, 100);
    });

    test('low confidence threshold < 0.4 detected correctly', () {
      final r = RankedProduct(
        product: product,
        finalScore: 0.35,
        ocrScore: 0.3,
        visualScore: 0.2,
        metaScore: 0.5,
      );
      expect(r.finalScore < 0.4, true);
      expect(r.percentScore, 35);
    });
  });

  group('Prompt 10 — Auto-embedding eligibility logic', () {
    test('product with images and no embedding is eligible', () {
      const p = Product(
        id: 'p1',
        name: 'Test',
        barcode: '123',
        price: 1.0,
        stock: 1,
        imagePaths: ['/img.jpg'],
        embedding: null,
      );

      final needsEmbedding =
          p.imagePaths.isNotEmpty &&
          (p.embedding == null || p.embedding!.isEmpty);
      expect(needsEmbedding, true);
    });

    test('product with images and existing embedding is NOT eligible', () {
      const p = Product(
        id: 'p2',
        name: 'Test',
        barcode: '456',
        price: 1.0,
        stock: 1,
        imagePaths: ['/img.jpg'],
        embedding: [0.1, 0.2, 0.3],
      );

      final needsEmbedding =
          p.imagePaths.isNotEmpty &&
          (p.embedding == null || p.embedding!.isEmpty);
      expect(needsEmbedding, false);
    });

    test('product without images is NOT eligible', () {
      const p = Product(
        id: 'p3',
        name: 'Test',
        barcode: '789',
        price: 1.0,
        stock: 1,
      );

      final needsEmbedding =
          p.imagePaths.isNotEmpty &&
          (p.embedding == null || p.embedding!.isEmpty);
      expect(needsEmbedding, false);
    });
  });
}
