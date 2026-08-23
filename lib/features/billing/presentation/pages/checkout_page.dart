import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../invoice/domain/entities/customer.dart';
import '../../../invoice/domain/entities/invoice.dart';
import '../../../invoice/domain/entities/invoice_item.dart';
import '../../../invoice/domain/entities/payment_record.dart';
import '../../../invoice/presentation/bloc/customer_bloc.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../../../invoice/data/services/invoice_pdf_service.dart';
import '../../../invoice/data/services/invoice_service.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _uuid = const Uuid();

  Customer? _selectedCustomer;
  final TextEditingController _customerNameCtrl = TextEditingController(text: 'زبون عادي');
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _paidAmountCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');

  String _paymentOption = 'cash'; // 'cash', 'debt', 'partial'

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _paidAmountCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  void _processInvoiceCheckout(BillingState billingState, ShopState shopState) {
    if (billingState.cartItems.isEmpty) return;

    final subtotal = billingState.totalAmount;
    final discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    final totalAmount = (subtotal - discount).clamp(0.0, double.infinity);

    double paid = totalAmount;
    if (_paymentOption == 'debt') {
      paid = 0.0;
    } else if (_paymentOption == 'partial') {
      paid = double.tryParse(_paidAmountCtrl.text) ?? 0.0;
    }
    paid = paid.clamp(0.0, totalAmount);
    final remainingDebt = (totalAmount - paid).clamp(0.0, double.infinity);

    PaymentStatus status = PaymentStatus.paid;
    if (remainingDebt > 0 && paid > 0) {
      status = PaymentStatus.partial;
    } else if (remainingDebt > 0 && paid == 0) {
      status = PaymentStatus.unpaid;
    }

    final invoiceNumber = InvoiceService.generateNextInvoiceNumber();

    // Map cart items to InvoiceItems
    final invoiceItems = billingState.cartItems.map((cartItem) {
      final p = cartItem.product;
      return InvoiceItem(
        productId: p.id,
        productName: p.name,
        barcode: p.barcode,
        unitPrice: p.price,
        quantity: cartItem.quantity.toDouble(),
        unit: p.isPipe ? 'متر' : 'قطعة',
        subtotal: cartItem.total,
        isPipe: p.isPipe,
      );
    }).toList();

    final List<PaymentRecord> initialPaymentHistory = [];
    if (paid > 0) {
      initialPaymentHistory.add(PaymentRecord(
        id: _uuid.v4(),
        amount: paid,
        date: DateTime.now(),
        note: _paymentOption == 'cash' ? 'دفع كاش بالكامل' : 'دفعة أولية عند الشراء',
      ));
    }

    final invoice = Invoice(
      id: _uuid.v4(),
      invoiceNumber: invoiceNumber,
      customerId: _selectedCustomer?.id,
      customerName: _customerNameCtrl.text.trim().isEmpty ? 'زبون عادي' : _customerNameCtrl.text.trim(),
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
      items: invoiceItems,
      subtotal: subtotal,
      discount: discount,
      totalAmount: totalAmount,
      paidAmount: paid,
      remainingAmount: remainingDebt,
      paymentStatus: status,
      paymentMethod: _paymentOption == 'cash' ? 'cash' : 'debt',
      paymentHistory: initialPaymentHistory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save in InvoiceBloc & Hive
    context.read<InvoiceBloc>().add(AddInvoiceEvent(invoice));

    // Also trigger printer if shop loaded
    if (shopState is ShopLoaded) {
      context.read<BillingBloc>().add(PrintReceiptEvent(
            shopName: shopState.shop.name,
            address1: shopState.shop.addressLine1,
            address2: shopState.shop.addressLine2,
            phone: shopState.shop.phoneNumber,
            footer: shopState.shop.footerText,
          ));
    }

    // Show Options Dialog
    _showInvoiceCreatedOptionsDialog(invoice);
  }

  void _showInvoiceCreatedOptionsDialog(Invoice invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('تم حفظ الفاتورة وإكمال العملية!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الفاتورة: ${invoice.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('الزبون: ${invoice.customerName}'),
              Text('الإجمالي: ${invoice.totalAmount.toStringAsFixed(2)} دج'),
              Text('المدفوع: ${invoice.paidAmount.toStringAsFixed(2)} دج'),
              Text(
                'المتبقي (الدين): ${invoice.remainingAmount.toStringAsFixed(2)} دج',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: invoice.remainingAmount > 0 ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text('اختر الإجراء المطلوب:'),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      InvoicePdfService.printInvoice(invoice);
                    },
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('طباعة الفاتورة PDF', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      InvoicePdfService.shareInvoicePdf(invoice);
                    },
                    icon: const Icon(Icons.share, color: Colors.green),
                    label: const Text('مشاركة الفاتورة عبر واتساب', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      context.read<BillingBloc>().add(ClearCartEvent());
                      context.go('/');
                    },
                    child: const Text('بدء بيع جديد 🛒', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);
    final customers = context.watch<CustomerBloc>().state.customers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.read<BillingBloc>().add(ClearCartEvent());
        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دفع وإعادة مراجعة الفاتورة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
            onPressed: () {
              context.read<BillingBloc>().add(ClearCartEvent());
              context.go('/');
            },
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {},
          builder: (context, billingState) {
            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                final subtotal = billingState.totalAmount;
                final discount = double.tryParse(_discountCtrl.text) ?? 0.0;
                final totalAmount = (subtotal - discount).clamp(0.0, double.infinity);

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 1. Items Table
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Table(
                                  border: const TableBorder(
                                    horizontalInside: BorderSide(color: borderColor),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                      children: [
                                        _buildHeaderCell('اسم المنتج / الأنابيب', TextAlign.left),
                                        _buildHeaderCell('السعر', TextAlign.right),
                                        _buildHeaderCell('الإجمالي', TextAlign.right),
                                      ],
                                    ),
                                    ...billingState.cartItems.map((item) {
                                      final isPipe = item.product.isPipe;
                                      final qtyStr = isPipe
                                          ? '${item.quantity} متر'
                                          : '${item.quantity} قطعة';
                                      return TableRow(
                                        children: [
                                          _buildDataCell('$qtyStr × ${item.product.name}', TextAlign.left),
                                          _buildDataCell(
                                              AppConstants.formatPrice(item.product.price), TextAlign.right,
                                              isSubtitle: true),
                                          _buildDataCell(
                                              AppConstants.formatPrice(item.total), TextAlign.right,
                                              isBold: true),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Customer Selection & Payment Options Card
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('بيانات الزبون وطريقة الدفع',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        if (customers.isNotEmpty)
                                          DropdownButton<Customer>(
                                            hint: const Text('اختر عميل مسجل'),
                                            value: _selectedCustomer,
                                            items: customers.map((c) {
                                              return DropdownMenuItem(
                                                value: c,
                                                child: Text('${c.name} (${c.phone})'),
                                              );
                                            }).toList(),
                                            onChanged: (c) {
                                              if (c != null) {
                                                setState(() {
                                                  _selectedCustomer = c;
                                                  _customerNameCtrl.text = c.name;
                                                  _customerPhoneCtrl.text = c.phone;
                                                });
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _customerNameCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم الزبون',
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _customerPhoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'رقم الهاتف (اختياري للواتساب)',
                                        prefixIcon: Icon(Icons.phone),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('اختر خيار الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),

                                    // Payment Choice Options
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ChoiceChip(
                                            label: const Text('دفع كاش ✅'),
                                            selected: _paymentOption == 'cash',
                                            onSelected: (val) {
                                              if (val) setState(() => _paymentOption = 'cash');
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ChoiceChip(
                                            label: const Text('دفع مؤجل (دين) ⏳'),
                                            selected: _paymentOption == 'debt',
                                            selectedColor: Colors.orange,
                                            onSelected: (val) {
                                              if (val) setState(() => _paymentOption = 'debt');
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ChoiceChip(
                                            label: const Text('دفع جزئي ⚡'),
                                            selected: _paymentOption == 'partial',
                                            selectedColor: Colors.blue,
                                            onSelected: (val) {
                                              if (val) setState(() => _paymentOption = 'partial');
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (_paymentOption == 'partial') ...[
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _paidAmountCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'المبلغ المدفوع كدفعة أُولى (دج) *',
                                          prefixIcon: Icon(Icons.payments),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Total & Checkout Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المبلغ الإجمالي:',
                                  style: TextStyle(fontSize: 14, color: Colors.grey)),
                              Text(
                                '${totalAmount.toStringAsFixed(2)} دج',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            onPressed: () => _processInvoiceCheckout(billingState, shopState),
                            label: 'إكمال الدفع وحفظ الفاتورة',
                            icon: Icons.check_circle,
                            isLoading: billingState.isPrinting,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[600] : null,
        ),
      ),
    );
  }
}
