import 'package:hive/hive.dart';
import '../../domain/entities/invoice_item.dart';

part 'invoice_item_model.g.dart';

@HiveType(typeId: 4)
class InvoiceItemModel extends InvoiceItem {
  @HiveField(0)
  @override
  final String productId;

  @HiveField(1)
  @override
  final String productName;

  @HiveField(2)
  @override
  final String barcode;

  @HiveField(3)
  @override
  final double unitPrice;

  @HiveField(4)
  @override
  final double quantity;

  @HiveField(5)
  @override
  final String unit;

  @HiveField(6)
  @override
  final double subtotal;

  @HiveField(7)
  @override
  final bool isPipe;

  @HiveField(8)
  @override
  final double? lengthCut;

  @HiveField(9)
  @override
  final double costPrice;

  const InvoiceItemModel({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.unitPrice,
    this.costPrice = 0.0,
    required this.quantity,
    this.unit = 'قطعة',
    required this.subtotal,
    this.isPipe = false,
    this.lengthCut,
  }) : super(
          productId: productId,
          productName: productName,
          barcode: barcode,
          unitPrice: unitPrice,
          costPrice: costPrice,
          quantity: quantity,
          unit: unit,
          subtotal: subtotal,
          isPipe: isPipe,
          lengthCut: lengthCut,
        );

  factory InvoiceItemModel.fromEntity(InvoiceItem entity) {
    return InvoiceItemModel(
      productId: entity.productId,
      productName: entity.productName,
      barcode: entity.barcode,
      unitPrice: entity.unitPrice,
      costPrice: entity.costPrice,
      quantity: entity.quantity,
      unit: entity.unit,
      subtotal: entity.subtotal,
      isPipe: entity.isPipe,
      lengthCut: entity.lengthCut,
    );
  }

  InvoiceItem toEntity() {
    return InvoiceItem(
      productId: productId,
      productName: productName,
      barcode: barcode,
      unitPrice: unitPrice,
      costPrice: costPrice,
      quantity: quantity,
      unit: unit,
      subtotal: subtotal,
      isPipe: isPipe,
      lengthCut: lengthCut,
    );
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String? ?? 'قطعة',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      isPipe: map['isPipe'] as bool? ?? false,
      lengthCut: (map['lengthCut'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'quantity': quantity,
      'unit': unit,
      'subtotal': subtotal,
      'isPipe': isPipe,
      'lengthCut': lengthCut,
    };
  }
}
