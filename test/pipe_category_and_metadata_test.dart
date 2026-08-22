import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/pipes/domain/entities/pipe_category.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  group('PipeCategory Entity Tests', () {
    test('PipeCategory toMap and fromMap roundtrip', () {
      final category = const PipeCategory(
        id: 'ppr',
        name: 'أنابيب PPR',
        defaultLength: 4.0,
        isSystem: false,
      );

      final map = category.toMap();
      final restored = PipeCategory.fromMap(map);

      expect(restored.id, 'ppr');
      expect(restored.name, 'أنابيب PPR');
      expect(restored.defaultLength, 4.0);
      expect(restored.isSystem, false);
    });

    test('PipeCategory JSON serialization roundtrip', () {
      final category = const PipeCategory(
        id: 'pex',
        name: 'أنابيب PEX',
        defaultLength: 3.5,
        isSystem: false,
      );

      final jsonStr = category.toJson();
      final restored = PipeCategory.fromJson(jsonStr);

      expect(restored.id, 'pex');
      expect(restored.name, 'أنابيب PEX');
      expect(restored.defaultLength, 3.5);
    });
  });

  group('Product Entity AI Metadata Tests', () {
    test('Product supports optional description and usageInstructions', () {
      const product = Product(
        id: 'p1',
        name: 'أنبوب PVC Ø110',
        barcode: 'PIPE-110',
        price: 200.0,
        stock: 10,
        description: 'أنبوب مائي عالي التحمل للحرارة والضغط',
        usageInstructions: 'يتم التلحيم بالحرارة أو التوصيل بالضغط',
      );

      expect(product.description, 'أنبوب مائي عالي التحمل للحرارة والضغط');
      expect(product.usageInstructions, 'يتم التلحيم بالحرارة أو التوصيل بالضغط');
    });

    test('Product copyWith preserves or updates AI metadata', () {
      const original = Product(
        id: 'p2',
        name: 'مضخة ماء',
        barcode: 'PUMP-001',
        price: 8500.0,
        stock: 5,
        description: 'مضخة 1 حصان',
      );

      final updated = original.copyWith(
        usageInstructions: 'توصيل بالكهرباء 220V ومنع التشغيل الجاف',
      );

      expect(updated.description, 'مضخة 1 حصان');
      expect(updated.usageInstructions, 'توصيل بالكهرباء 220V ومنع التشغيل الجاف');
    });
  });

  group('Dynamic Category Filtering Logic Tests', () {
    final pipes = [
      const Product(
        id: '1',
        name: 'PVC 110',
        barcode: '1',
        price: 200.0,
        stock: 5,
        isPipe: true,
        pipeType: 'pvc',
        fullLength: 6.0,
      ),
      const Product(
        id: '2',
        name: 'Copper 16',
        barcode: '2',
        price: 700.0,
        stock: 3,
        isPipe: true,
        pipeType: 'copper',
        fullLength: 5.0,
      ),
      const Product(
        id: '3',
        name: 'PPR 25',
        barcode: '3',
        price: 300.0,
        stock: 8,
        isPipe: true,
        pipeType: 'PPR',
        fullLength: 4.0,
      ),
    ];

    test('Filter by exact category name case-insensitively', () {
      final pprPipes = pipes.where((p) {
        return (p.pipeType ?? '').trim().toLowerCase() == 'ppr';
      }).toList();

      expect(pprPipes.length, 1);
      expect(pprPipes.first.name, 'PPR 25');
    });

    test('Filter all pipes when filter is all', () {
      const selectedFilter = 'all';
      final filtered = pipes.where((p) {
        if (selectedFilter == 'all') return true;
        return (p.pipeType ?? '').trim().toLowerCase() == selectedFilter;
      }).toList();

      expect(filtered.length, 3);
    });
  });
}
