import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  final String productId;
  final String productName;
  final String barcode;
  final double unitPrice;
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
    required this.quantity,
    this.unit = 'قطعة',
    required this.subtotal,
    this.isPipe = false,
    this.lengthCut,
  });

  InvoiceItem copyWith({
    String? productId,
    String? productName,
    String? barcode,
    double? unitPrice,
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
        quantity,
        unit,
        subtotal,
        isPipe,
        lengthCut,
      ];
}
