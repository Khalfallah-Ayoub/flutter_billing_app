import 'package:equatable/equatable.dart';
import 'invoice_item.dart';
import 'payment_record.dart';

enum PaymentStatus {
  paid, // مدفوعة بالكامل
  partial, // دين جزئي
  unpaid, // غير مدفوعة (دين كامل)
}

class Invoice extends Equatable {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final List<InvoiceItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final PaymentStatus paymentStatus;
  final String paymentMethod; // 'cash', 'debt', 'card'
  final List<PaymentRecord> paymentHistory;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  const Invoice({
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
    required this.paymentStatus,
    this.paymentMethod = 'cash',
    this.paymentHistory = const [],
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get hasDebt => remainingAmount > 0;

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    List<InvoiceItem>? items,
    double? subtotal,
    double? discount,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    List<PaymentRecord>? paymentHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        customerId,
        customerName,
        customerPhone,
        items,
        subtotal,
        discount,
        totalAmount,
        paidAmount,
        remainingAmount,
        paymentStatus,
        paymentMethod,
        paymentHistory,
        createdAt,
        updatedAt,
        notes,
      ];
}
