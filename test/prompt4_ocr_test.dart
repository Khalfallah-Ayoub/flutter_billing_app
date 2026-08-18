import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/smart_recognition/domain/entities/ocr_result.dart';
import 'package:billing_app/features/smart_recognition/data/services/ocr_service.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  group('Prompt 4 — OcrResult Entity', () {
    test('should create empty OcrResult', () {
      const result = OcrResult(fullText: '');
      expect(result.hasText, isFalse);
      expect(result.hasNumbers, isFalse);
      expect(result.numbers, isEmpty);
      expect(result.detectedBrand, isNull);
      expect(result.detectedSize, isNull);
    });

    test('should create OcrResult with text and numbers', () {
      const result = OcrResult(
        fullText: 'Bosch M8 30mm 8.8',
        numbers: ['M8', '30mm', '8.8'],
        detectedBrand: 'Bosch',
        detectedSize: 'M8',
      );
      expect(result.hasText, isTrue);
      expect(result.hasNumbers, isTrue);
      expect(result.numbers, hasLength(3));
      expect(result.detectedBrand, 'Bosch');
    });

    test('two OcrResults with same data should be equal', () {
      const a = OcrResult(fullText: 'test', numbers: ['1']);
      const b = OcrResult(fullText: 'test', numbers: ['1']);
      expect(a, equals(b));
    });

    test('toString should truncate long text', () {
      final longText = 'A' * 100;
      final result = OcrResult(fullText: longText);
      expect(result.toString(), contains('...'));
    });
  });

  group('Prompt 4 — OcrService Pattern Extraction', () {
    late OcrService service;

    setUp(() {
      service = OcrService();
    });

    tearDown(() {
      service.dispose();
    });

    test('matchOcrWithProduct — exact name match gives high score', () {
      const ocr = OcrResult(
        fullText: 'Vis M8 x 30mm Bosch Grade 8.8',
        numbers: ['M8', '30mm', '8.8'],
        detectedSize: 'M8 x 30mm',
      );
      const product = Product(
        id: '1',
        name: 'Vis M8 x 30mm',
        barcode: '111',
        price: 1.0,
        brand: 'Bosch',
        size: 'M8 x 30mm',
        ocrText: 'Vis M8 30mm 8.8 Bosch',
      );

      final score = service.matchOcrWithProduct(ocr, product);
      expect(score, greaterThan(0.7));
    });

    test('matchOcrWithProduct — partial match gives positive score', () {
      const ocr = OcrResult(
        fullText: 'M8 Bosch',
        numbers: ['M8'],
      );
      const product = Product(
        id: '1',
        name: 'Vis M8 x 30mm',
        barcode: '111',
        price: 1.0,
        brand: 'Bosch',
      );

      final score = service.matchOcrWithProduct(ocr, product);
      expect(score, greaterThan(0.2));
      // Should not be 0 since M8 and Bosch both match
      expect(score, greaterThan(0.0));
    });

    test('matchOcrWithProduct — no match gives low score', () {
      const ocr = OcrResult(
        fullText: 'XYZ Connector 50A',
        numbers: ['50A'],
      );
      const product = Product(
        id: '1',
        name: 'Vis M8 x 30mm',
        barcode: '111',
        price: 1.0,
        brand: 'Bosch',
        size: 'M8 x 30mm',
      );

      final score = service.matchOcrWithProduct(ocr, product);
      expect(score, lessThan(0.3));
    });

    test('matchOcrWithProduct — empty OCR returns 0', () {
      const ocr = OcrResult(fullText: '');
      const product = Product(
        id: '1',
        name: 'Test',
        barcode: '111',
        price: 1.0,
      );

      final score = service.matchOcrWithProduct(ocr, product);
      expect(score, equals(0.0));
    });

    test('matchOcrWithProduct — size difference should affect score', () {
      const ocr = OcrResult(
        fullText: 'M8 x 30mm',
        numbers: ['M8', '30mm'],
        detectedSize: 'M8 x 30mm',
      );

      const product30 = Product(
        id: '1',
        name: 'Vis M8 x 30',
        barcode: '111',
        price: 1.0,
        size: 'M8 x 30mm',
        ocrText: 'M8 30mm',
      );

      const product35 = Product(
        id: '2',
        name: 'Vis M8 x 35',
        barcode: '222',
        price: 1.0,
        size: 'M8 x 35mm',
        ocrText: 'M8 35mm',
      );

      final score30 = service.matchOcrWithProduct(ocr, product30);
      final score35 = service.matchOcrWithProduct(ocr, product35);

      // Product with matching size (30mm) should score higher than 35mm
      expect(score30, greaterThan(score35));
    });

    test('detectBrandFromProducts — should detect known brand', () {
      const ocr = OcrResult(
        fullText: 'Premium Bosch Bolt M10',
        numbers: ['M10'],
      );

      const products = [
        Product(id: '1', name: 'A', barcode: '1', price: 1.0, brand: 'Bosch'),
        Product(id: '2', name: 'B', barcode: '2', price: 1.0, brand: 'Fischer'),
      ];

      final result = service.detectBrandFromProducts(ocr, products);
      expect(result.detectedBrand, 'Bosch');
    });

    test('detectBrandFromProducts — no match returns null brand', () {
      const ocr = OcrResult(
        fullText: 'Unknown Brand XYZ',
        numbers: [],
      );

      const products = [
        Product(id: '1', name: 'A', barcode: '1', price: 1.0, brand: 'Bosch'),
      ];

      final result = service.detectBrandFromProducts(ocr, products);
      expect(result.detectedBrand, isNull);
    });
  });
}
