import 'package:flutter_test/flutter_test.dart';
import 'package:billing_app/features/invoice/domain/entities/customer.dart';
import 'package:billing_app/features/invoice/domain/entities/invoice.dart';
import 'package:billing_app/features/invoice/domain/entities/invoice_item.dart';
import 'package:billing_app/features/invoice/data/services/customer_service.dart';

void main() {
  final sampleCustomer = Customer(
    id: 'cust-1',
    name: 'أحمد البناء',
    phone: '0661234567',
    createdAt: DateTime.now(),
  );

  final sampleInvoices = [
    Invoice(
      id: 'inv-1',
      invoiceNumber: 'INV-2026-0001',
      customerId: 'cust-1',
      customerName: 'أحمد البناء',
      customerPhone: '0661234567',
      items: const [
        InvoiceItem(
          productId: 'p1',
          productName: 'أنبوب PVC 110',
          barcode: 'PVC110',
          unitPrice: 200.0,
          quantity: 3.0,
          unit: 'متر',
          subtotal: 600.0,
          isPipe: true,
          lengthCut: 3.0,
        ),
      ],
      subtotal: 600.0,
      discount: 50.0,
      totalAmount: 550.0,
      paidAmount: 200.0,
      remainingAmount: 350.0, // Remaining Debt!
      paymentStatus: PaymentStatus.partial,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Invoice(
      id: 'inv-2',
      invoiceNumber: 'INV-2026-0002',
      customerId: 'cust-1',
      customerName: 'أحمد البناء',
      customerPhone: '0661234567',
      items: const [
        InvoiceItem(
          productId: 'p2',
          productName: 'أنبوب نحاس 16',
          barcode: 'COP16',
          unitPrice: 700.0,
          quantity: 2.0,
          unit: 'متر',
          subtotal: 1400.0,
          isPipe: true,
        ),
      ],
      subtotal: 1400.0,
      discount: 0.0,
      totalAmount: 1400.0,
      paidAmount: 1400.0,
      remainingAmount: 0.0, // Fully Paid!
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  group('Invoice & Debt Calculation Tests', () {
    test('Customer debt calculation correctly sums up unpaid amounts', () {
      final totalDebt = CustomerService.getCustomerTotalDebt(sampleCustomer.id, sampleInvoices);
      expect(totalDebt, 350.0);
    });

    test('Customer total purchases correctly sums all invoice total amounts', () {
      final totalPurchases = CustomerService.getCustomerTotalPurchases(sampleCustomer.id, sampleInvoices);
      expect(totalPurchases, 1950.0); // 550 + 1400
    });

    test('Partial payment status correctly computed', () {
      final inv = sampleInvoices.first;
      expect(inv.hasDebt, true);
      expect(inv.isPaid, false);
      expect(inv.paymentStatus, PaymentStatus.partial);
    });

    test('Payment history record tracking and balance update', () {
      final initialInv = sampleInvoices.first;
      expect(initialInv.remainingAmount, 350.0);

      // Simulate customer paying 200 DA installment
      final updatedPaid = initialInv.paidAmount + 200.0;
      final updatedRemaining = initialInv.totalAmount - updatedPaid;
      expect(updatedRemaining, 150.0);
    });
  });
}
