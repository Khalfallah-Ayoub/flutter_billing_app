import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/invoice.dart';
import '../bloc/invoice_bloc.dart';
import '../../data/services/invoice_pdf_service.dart';

class InvoiceDetailPage extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailPage({super.key, required this.invoice});

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  late Invoice _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  void _showPayDebtDialog() {
    final amountController = TextEditingController(text: _invoice.remainingAmount.toStringAsFixed(0));
    final noteController = TextEditingController(text: 'تسديد دفعة من الدين');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments, color: Colors.green),
              SizedBox(width: 8),
              Text('تسديد جزء/كل الدين'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الدين المتبقي الحالي: ${_invoice.remainingAmount.toStringAsFixed(2)} دج',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المستلم الآن (دج) *',
                  prefixIcon: Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الدفعة (مثلاً: دفعة كاش، تحويل...)',
                  prefixIcon: Icon(Icons.note_alt),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0) return;

                final note = noteController.text.trim();

                context.read<InvoiceBloc>().add(
                      PayInvoiceDebtEvent(
                        invoiceId: _invoice.id,
                        paymentAmount: amount,
                        note: note.isEmpty ? null : note,
                      ),
                    );

                final newPaid = (_invoice.paidAmount + amount).clamp(0.0, _invoice.totalAmount);
                final newRem = (_invoice.totalAmount - newPaid).clamp(0.0, double.infinity);
                
                // Fetch updated invoice from service/Hive
                final updatedFromDb = context.read<InvoiceBloc>().state.allInvoices.firstWhere(
                  (i) => i.id == _invoice.id,
                  orElse: () => _invoice,
                );

                setState(() {
                  _invoice = updatedFromDb.copyWith(
                    paidAmount: newPaid,
                    remainingAmount: newRem,
                    paymentStatus: newRem <= 0
                        ? PaymentStatus.paid
                        : (newPaid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid),
                  );
                });

                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تسديد الدفعة وحفظ السجل الفاتورة بنجاح!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('تسجيل الدفعة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    Color statusColor = Colors.green;
    String statusText = 'مدفوعة بالكامل ✅';
    if (_invoice.paymentStatus == PaymentStatus.unpaid) {
      statusColor = Colors.red;
      statusText = 'غير مدفوعة ❌';
    } else if (_invoice.paymentStatus == PaymentStatus.partial) {
      statusColor = Colors.orange;
      statusText = 'دين جزئي ⚠️';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الفاتورة ${_invoice.invoiceNumber}'),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryColor),
            tooltip: 'طباعة الفاتورة',
            onPressed: () => InvoicePdfService.printInvoice(_invoice),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primaryColor),
            tooltip: 'مشاركة PDF عبر واتساب',
            onPressed: () => InvoicePdfService.shareInvoicePdf(_invoice),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoice.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'التاريخ: ${dateFormat.format(_invoice.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer Info Box
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('معلومات الزبون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.person, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          _invoice.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    if (_invoice.customerPhone != null && _invoice.customerPhone!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.green, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _invoice.customerPhone!,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: () => InvoicePdfService.callCustomer(_invoice.customerPhone!),
                            icon: const Icon(Icons.call, size: 18, color: Colors.green),
                            tooltip: 'اتصال مباشر',
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            onPressed: () => InvoicePdfService.sendInvoiceToWhatsApp(_invoice),
                            icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                            tooltip: 'واتساب',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Breakdown Table
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تفاصيل المنتجات والأنابيب المباعة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 12),
                    ..._invoice.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.isPipe
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.isPipe ? Icons.architecture : Icons.shopping_bag,
                                color: item.isPipe ? Colors.blue : AppTheme.primaryColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    item.isPipe
                                        ? '${item.quantity} متر × ${item.unitPrice} دج'
                                        : '${item.quantity.toInt()} ${item.unit} × ${item.unitPrice} دج',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${item.subtotal.toStringAsFixed(2)} دج',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Totals & Debt Breakdown Box
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow('المجموع الصافي', '${_invoice.subtotal.toStringAsFixed(2)} دج'),
                    if (_invoice.discount > 0)
                      _buildRow('الخصم', '-${_invoice.discount.toStringAsFixed(2)} دج', isDiscount: true),
                    const Divider(),
                    _buildRow('المبلغ الإجمالي', '${_invoice.totalAmount.toStringAsFixed(2)} دج', isBold: true),
                    _buildRow('المبلغ المدفوع', '${_invoice.paidAmount.toStringAsFixed(2)} دج', color: Colors.green),
                    const Divider(),
                    _buildRow(
                      'المتبقي (الدين)',
                      '${_invoice.remainingAmount.toStringAsFixed(2)} دج',
                      isBold: true,
                      color: _invoice.remainingAmount > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Installment Payment History Card
            if (_invoice.paymentHistory.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'سجل الأقساط والدفعات السابقة (${_invoice.paymentHistory.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ..._invoice.paymentHistory.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final p = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                                    child: Text(
                                      '$idx',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.note ?? 'تسديد دفعة دين',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        dateFormat.format(p.date),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                '+${p.amount.toStringAsFixed(2)} دج',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Debt Payment Action Button
            if (_invoice.hasDebt)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showPayDebtDialog,
                  icon: const Icon(Icons.payments, color: Colors.white),
                  label: const Text(
                    'تسجيل دفعة جديدة من الدين',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value,
      {bool isBold = false, bool isDiscount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.red : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isDiscount ? Colors.red : null),
            ),
          ),
        ],
      ),
    );
  }
}
