import '../../../../core/data/hive_database.dart';
import '../models/invoice_model.dart';
import '../../domain/entities/invoice.dart';

import 'package:uuid/uuid.dart';
import '../../domain/entities/payment_record.dart';

class InvoiceService {
  static const _uuid = Uuid();

  static List<Invoice> getInvoices() {
    final box = HiveDatabase.invoiceBox;
    return box.values.map((model) => model.toEntity()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Invoice? getInvoiceById(String id) {
    final box = HiveDatabase.invoiceBox;
    final model = box.get(id);
    return model?.toEntity();
  }

  static Future<void> saveInvoice(Invoice invoice) async {
    final box = HiveDatabase.invoiceBox;
    final model = InvoiceModel.fromEntity(invoice);
    await box.put(invoice.id, model);
  }

  static Future<void> deleteInvoice(String id) async {
    final box = HiveDatabase.invoiceBox;
    await box.delete(id);
  }

  static Future<Invoice?> payInvoiceDebt(
    String invoiceId,
    double paymentAmount, {
    String? note,
  }) async {
    final invoice = getInvoiceById(invoiceId);
    if (invoice == null) return null;

    final newRecord = PaymentRecord(
      id: _uuid.v4(),
      amount: paymentAmount,
      date: DateTime.now(),
      note: note ?? 'دفعة تسديد من الدين المعلق',
    );

    final updatedHistory = List<PaymentRecord>.from(invoice.paymentHistory)..add(newRecord);

    final newPaid = (invoice.paidAmount + paymentAmount).clamp(0.0, invoice.totalAmount);
    final newRemaining = (invoice.totalAmount - newPaid).clamp(0.0, double.infinity);

    PaymentStatus newStatus = PaymentStatus.unpaid;
    if (newRemaining <= 0) {
      newStatus = PaymentStatus.paid;
    } else if (newPaid > 0) {
      newStatus = PaymentStatus.partial;
    }

    final updated = invoice.copyWith(
      paidAmount: newPaid,
      remainingAmount: newRemaining,
      paymentStatus: newStatus,
      paymentHistory: updatedHistory,
      updatedAt: DateTime.now(),
    );

    await saveInvoice(updated);
    return updated;
  }

  static String generateNextInvoiceNumber() {
    final box = HiveDatabase.invoiceBox;
    final count = box.length + 1;
    final year = DateTime.now().year;
    final formattedNum = count.toString().padLeft(4, '0');
    return 'INV-$year-$formattedNum';
  }
}
