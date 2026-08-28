import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/core/utils/product_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductExportService Tests', () {
    final sampleProduct = Product(
      id: 'prod_1001',
      name: 'أنبوب PVC 110 مم',
      barcode: '1234567890123',
      price: 1500.0,
      costPrice: 1000.0,
      stock: 50,
      sku: 'PVC-110-3M',
      category: 'أنابيب (Pipes)',
      brand: 'Chiali',
      size: '110mm',
      imagePaths: const ['/dummy/path/img1.jpg'],
      isPipe: true,
      pipeType: 'pvc',
      fullLength: 6.0,
      fullPrice: 1500.0,
      diameter: '110',
      origin: 'الجزائر',
      color: 'رمادي',
      description: 'أنبوب رمادي رمادي عالي الجودة لمياه الصرف الصحي',
      usageInstructions: 'يستخدم الغراء الخاص بـ PVC للصق الأجزاء',
    );

    test('exportToJson serializes all product fields including costPrice, description, and pipe properties', () async {
      final jsonStr = await ProductExportService.exportToJson([sampleProduct]);
      expect(jsonStr, isNotEmpty);

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      expect(data['app'], equals('Flutter Billing POS'));
      expect(data['count'], equals(1));

      final products = data['products'] as List;
      expect(products.length, equals(1));

      final p = products.first as Map<String, dynamic>;
      expect(p['id'], equals('prod_1001'));
      expect(p['name'], equals('أنبوب PVC 110 مم'));
      expect(p['barcode'], equals('1234567890123'));
      expect(p['price'], equals(1500.0));
      expect(p['costPrice'], equals(1000.0));
      expect(p['stock'], equals(50));
      expect(p['isPipe'], isTrue);
      expect(p['pipeType'], equals('pvc'));
      expect(p['fullLength'], equals(6.0));
      expect(p['fullPrice'], equals(1500.0));
      expect(p['diameter'], equals('110'));
      expect(p['origin'], equals('الجزائر'));
      expect(p['color'], equals('رمادي'));
      expect(p['description'], equals('أنبوب رمادي رمادي عالي الجودة لمياه الصرف الصحي'));
      expect(p['usageInstructions'], equals('يستخدم الغراء الخاص بـ PVC للصق الأجزاء'));
    });

    test('analyzeImport parses JSON correctly and identifies fields', () async {
      final jsonStr = await ProductExportService.exportToJson([sampleProduct]);
      final analysis = ProductExportService.analyzeImport(jsonStr);

      expect(analysis.totalInFile, equals(1));
      expect(analysis.newProducts.length, equals(1));
      
      final imported = analysis.newProducts.first;
      expect(imported.id, equals('prod_1001'));
      expect(imported.costPrice, equals(1000.0));
      expect(imported.description, equals('أنبوب رمادي رمادي عالي الجودة لمياه الصرف الصحي'));
      expect(imported.usageInstructions, equals('يستخدم الغراء الخاص بـ PVC للصق الأجزاء'));
      expect(imported.isPipe, isTrue);
      expect(imported.diameter, equals('110'));
    });
  });
}
