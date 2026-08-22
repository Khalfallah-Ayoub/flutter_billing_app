import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/ai_chat/data/services/local_ai_chat_service.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

void main() {
  final sampleProducts = [
    const Product(
      id: 'p1',
      name: 'أنبوب PVC 110',
      barcode: 'PVC-110',
      price: 1200.0,
      stock: 15,
      isPipe: true,
      pipeType: 'pvc',
      fullLength: 6.0,
      fullPrice: 1200.0,
      diameter: '110',
      description: 'أنبوب مائي عالي المقاومة للصرف والمياه الباردة',
      usageInstructions: 'التلحيم بالغراء المخصص للضغط',
    ),
    const Product(
      id: 'p2',
      name: 'أنبوب نحاس 16',
      barcode: 'COPPER-16',
      price: 3500.0,
      stock: 2, // low stock!
      isPipe: true,
      pipeType: 'copper',
      fullLength: 5.0,
      fullPrice: 3500.0,
      diameter: '16',
      description: 'أنبوب نحاس ممتازة للتدفئة والغاز والمياه الساخنة',
      usageInstructions: 'التلحيم بالحرارة أو التوصيل بالضغط',
    ),
    const Product(
      id: 'p3',
      name: 'غراء PVC ممتازة',
      barcode: 'GLUE-001',
      price: 450.0,
      stock: 20,
    ),
  ];

  group('LocalAIChatService Tests', () {
    test('Process low stock query returns warning for low stock items', () {
      final response = LocalAIChatService.processQuery('المنتجات قريبة النفاد', sampleProducts);

      expect(response.isUser, false);
      expect(response.text.contains('أنبوب نحاس 16'), true);
      expect(response.relatedProducts?.length, 1);
    });

    test('Process meter calculation query calculates total price correctly', () {
      // 2.5 meters of Copper 16 (price per meter = 3500 / 5 = 700 DA/m => 2.5 * 700 = 1750 DA)
      final response = LocalAIChatService.processQuery('احسب 2.5 متر نحاس 16', sampleProducts);

      expect(response.isUser, false);
      expect(response.text.contains('1750.00'), true);
      expect(response.quickActions?.first.actionType, 'pipe_sale');
    });

    test('Process usage/advice query extracts description and usage instructions', () {
      final response = LocalAIChatService.processQuery('كيف يتم تركيب وتلحيم أنبوب نحاس؟', sampleProducts);

      expect(response.isUser, false);
      expect(response.text.contains('التلحيم بالحرارة أو التوصيل بالضغط'), true);
    });

    test('Process product search query returns exact details and meter prices', () {
      final response = LocalAIChatService.processQuery('كم سعر أنبوب PVC 110؟', sampleProducts);

      expect(response.isUser, false);
      expect(response.text.contains('1200.00'), true); // full price
      expect(response.text.contains('200.00'), true); // price per meter (1200 / 6)
    });
  });
}
