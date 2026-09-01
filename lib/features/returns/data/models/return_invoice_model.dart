import 'package:hive/hive.dart';
import '../../domain/entities/return_invoice.dart';

part 'return_invoice_model.g.dart';

@HiveType(typeId: 9)
class ReturnItemModel {
  @HiveField(0) final String productId;
  @HiveField(1) final String productName;
  @HiveField(2) final double quantity;
  @HiveField(3) final double unitPrice;
  @HiveField(4) final double subtotal;
  @HiveField(5) final String unit;

  const ReturnItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.unit = 'قطعة',
  });

  factory ReturnItemModel.fromEntity(ReturnItem e) => ReturnItemModel(
        productId: e.productId,
        productName: e.productName,
        quantity: e.quantity,
        unitPrice: e.unitPrice,
        subtotal: e.subtotal,
        unit: e.unit,
      );

  ReturnItem toEntity() => ReturnItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
        unit: unit,
      );
}

@HiveType(typeId: 10)
class ReturnInvoiceModel {
  @HiveField(0) final String id;
  @HiveField(1) final String returnNumber;
  @HiveField(2) final String originalInvoiceId;
  @HiveField(3) final String originalInvoiceNumber;
  @HiveField(4) final String customerId;
  @HiveField(5) final String customerName;
  @HiveField(6) final String? craftsmanId;
  @HiveField(7) final String? craftsmanName;
  @HiveField(8) final List<ReturnItemModel> items;
  @HiveField(9) final double totalReturnAmount;
  @HiveField(10) final String? notes;
  @HiveField(11) final DateTime createdAt;

  const ReturnInvoiceModel({
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

  factory ReturnInvoiceModel.fromEntity(ReturnInvoice e) => ReturnInvoiceModel(
        id: e.id,
        returnNumber: e.returnNumber,
        originalInvoiceId: e.originalInvoiceId,
        originalInvoiceNumber: e.originalInvoiceNumber,
        customerId: e.customerId,
        customerName: e.customerName,
        craftsmanId: e.craftsmanId,
        craftsmanName: e.craftsmanName,
        items: e.items.map((i) => ReturnItemModel.fromEntity(i)).toList(),
        totalReturnAmount: e.totalReturnAmount,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  ReturnInvoice toEntity() => ReturnInvoice(
        id: id,
        returnNumber: returnNumber,
        originalInvoiceId: originalInvoiceId,
        originalInvoiceNumber: originalInvoiceNumber,
        customerId: customerId,
        customerName: customerName,
        craftsmanId: craftsmanId,
        craftsmanName: craftsmanName,
        items: items.map((i) => i.toEntity()).toList(),
        totalReturnAmount: totalReturnAmount,
        notes: notes,
        createdAt: createdAt,
      );
}
