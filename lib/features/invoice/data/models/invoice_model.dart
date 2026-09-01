import 'package:hive/hive.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_item_model.dart';
import 'payment_record_model.dart';

part 'invoice_model.g.dart';

@HiveType(typeId: 5)
class InvoiceModel extends Invoice {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String invoiceNumber;

  @HiveField(2)
  @override
  final String? customerId;

  @HiveField(3)
  @override
  final String customerName;

  @HiveField(4)
  @override
  final String? customerPhone;

  @HiveField(5)
  @override
  final List<InvoiceItemModel> items;

  @HiveField(6)
  @override
  final double subtotal;

  @HiveField(7)
  @override
  final double discount;

  @HiveField(8)
  @override
  final double totalAmount;

  @HiveField(9)
  @override
  final double paidAmount;

  @HiveField(10)
  @override
  final double remainingAmount;

  @HiveField(11)
  final String statusString; // 'paid', 'partial', 'unpaid'

  @HiveField(12)
  @override
  final String paymentMethod;

  @HiveField(13)
  @override
  final DateTime createdAt;

  @HiveField(14)
  @override
  final DateTime updatedAt;

  @HiveField(15)
  @override
  final String? notes;

  @HiveField(16)
  @override
  final List<PaymentRecordModel> paymentHistory;

  @HiveField(17)
  @override
  final String? craftsmanId;

  @HiveField(18)
  @override
  final String? craftsmanName;

  @HiveField(19)
  @override
  final List<String> returnIds;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.statusString,
    this.paymentMethod = 'cash',
    this.paymentHistory = const [],
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.craftsmanId,
    this.craftsmanName,
    this.returnIds = const [],
  }) : super(
          id: id,
          invoiceNumber: invoiceNumber,
          customerId: customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          items: items,
          subtotal: subtotal,
          discount: discount,
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          remainingAmount: remainingAmount,
          paymentStatus: _parseStatus(statusString),
          paymentMethod: paymentMethod,
          paymentHistory: paymentHistory,
          createdAt: createdAt,
          updatedAt: updatedAt,
          notes: notes,
          craftsmanId: craftsmanId,
          craftsmanName: craftsmanName,
          returnIds: returnIds,
        );

  static PaymentStatus _parseStatus(String status) {
    switch (status) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }

  static String _statusToString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.unpaid:
        return 'unpaid';
    }
  }

  factory InvoiceModel.fromEntity(Invoice entity) {
    return InvoiceModel(
      id: entity.id,
      invoiceNumber: entity.invoiceNumber,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      items: entity.items.map((e) => InvoiceItemModel.fromEntity(e)).toList(),
      subtotal: entity.subtotal,
      discount: entity.discount,
      totalAmount: entity.totalAmount,
      paidAmount: entity.paidAmount,
      remainingAmount: entity.remainingAmount,
      statusString: _statusToString(entity.paymentStatus),
      paymentMethod: entity.paymentMethod,
      paymentHistory: entity.paymentHistory.map((p) => PaymentRecordModel.fromEntity(p)).toList(),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      notes: entity.notes,
      craftsmanId: entity.craftsmanId,
      craftsmanName: entity.craftsmanName,
      returnIds: entity.returnIds,
    );
  }

  Invoice toEntity() {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items.map((e) => e.toEntity()).toList(),
      subtotal: subtotal,
      discount: discount,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      paymentStatus: _parseStatus(statusString),
      paymentMethod: paymentMethod,
      paymentHistory: paymentHistory.map((p) => p.toEntity()).toList(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      notes: notes,
      craftsmanId: craftsmanId,
      craftsmanName: craftsmanName,
      returnIds: returnIds,
    );
  }
}
