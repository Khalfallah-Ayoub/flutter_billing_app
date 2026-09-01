import 'package:equatable/equatable.dart';

/// A single item in a return invoice
class ReturnItem extends Equatable {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String unit; // 'قطعة', 'متر', 'kg', etc.

  const ReturnItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.unit = 'قطعة',
  });

  @override
  List<Object?> get props => [productId, productName, quantity, unitPrice, subtotal, unit];
}

/// Full return invoice linked to the original invoice
class ReturnInvoice extends Equatable {
  final String id;
  final String returnNumber;      // e.g. RET-001
  final String originalInvoiceId;
  final String originalInvoiceNumber;
  final String customerId;
  final String customerName;
  final String? craftsmanId;
  final String? craftsmanName;
  final List<ReturnItem> items;
  final double totalReturnAmount;   // amount credited back
  final String? notes;
  final DateTime createdAt;

  const ReturnInvoice({
    required this.id,
    required this.returnNumber,
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    required this.customerId,
    required this.customerName,
    this.craftsmanId,
    this.craftsmanName,
    required this.items,
    required this.totalReturnAmount,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        returnNumber,
        originalInvoiceId,
        originalInvoiceNumber,
        customerId,
        customerName,
        craftsmanId,
        craftsmanName,
        items,
        totalReturnAmount,
        notes,
        createdAt,
      ];
}
