import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  final String productId;
  final String productName;
  final String barcode;
  final double unitPrice; // Selling Price (سعر البيع)
  final double costPrice; // Cost Price / Purchase Price (سعر الشراء / التكلفة)
  final double quantity; // count or meters
  final String unit; // 'قطعة' or 'متر'
  final double subtotal;
  final bool isPipe;
  final double? lengthCut; // cut length in meters if pipe

  const InvoiceItem({
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
  });

  /// Calculates total cost of this line item
  double get itemCostTotal => costPrice * quantity;

  /// Calculates gross profit of this line item
  double get itemGrossProfit => subtotal - itemCostTotal;

  InvoiceItem copyWith({
    String? productId,
    String? productName,
    String? barcode,
    double? unitPrice,
    double? costPrice,
    double? quantity,
    String? unit,
    double? subtotal,
    bool? isPipe,
    double? lengthCut,
  }) {
    return InvoiceItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      subtotal: subtotal ?? this.subtotal,
      isPipe: isPipe ?? this.isPipe,
      lengthCut: lengthCut ?? this.lengthCut,
    );
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        barcode,
        unitPrice,
        costPrice,
        quantity,
        unit,
        subtotal,
        isPipe,
        lengthCut,
      ];
}
