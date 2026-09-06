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
import '../../../craftsman/presentation/bloc/craftsman_bloc.dart';
import '../../../craftsman/domain/entities/craftsman.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _uuid = const Uuid();
  bool _isProcessing = false;

  Customer? _selectedCustomer;
  Craftsman? _selectedCraftsman; // حرفي مرتبط بالعميل
  final TextEditingController _customerNameCtrl = TextEditingController(text: 'زبون عادي');
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _paidAmountCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');

  String _paymentOption = 'cash'; // 'cash', 'debt', 'partial'

  @override
  void initState() {
    super.initState();
    final billingState = context.read<BillingBloc>().state;
    if (billingState.editingInvoice != null) {
      final inv = billingState.editingInvoice!;
      _customerNameCtrl.text = inv.customerName;
      _customerPhoneCtrl.text = inv.customerPhone ?? '';
      _discountCtrl.text = inv.discount.toStringAsFixed(0);
      _paidAmountCtrl.text = inv.paidAmount.toStringAsFixed(0);
      _paymentOption = inv.paymentMethod == 'debt'
          ? 'debt'
          : (inv.remainingAmount > 0 ? 'partial' : 'cash');

      if (inv.craftsmanId != null) {
        final craftsmen = context.read<CraftsmanBloc>().state.craftsmen;
        try {
          _selectedCraftsman = craftsmen.firstWhere((c) => c.id == inv.craftsmanId);
        } catch (_) {}
      }

      if (inv.customerId != null) {
        final customers = context.read<CustomerBloc>().state.customers;
        try {
          _selectedCustomer = customers.firstWhere((c) => c.id == inv.customerId);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _paidAmountCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  void _processInvoiceCheckout(BillingState billingState, ShopState shopState) {
    if (_isProcessing) return;
    if (billingState.cartItems.isEmpty) return;

    // Set flag immediately — only reset when user closes the result dialog
    if (mounted) setState(() => _isProcessing = true);

    final editingInvoice = billingState.editingInvoice;
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

    final invoiceNumber = editingInvoice?.invoiceNumber ?? InvoiceService.generateNextInvoiceNumber();

    // Map cart items to InvoiceItems
    final invoiceItems = billingState.cartItems.map((cartItem) {
      final p = cartItem.product;
      final unitCost = (p.isPipe && p.fullLength != null && p.fullLength! > 0)
          ? (p.costPrice > 0 ? p.costPrice / p.fullLength! : 0.0)
          : p.costPrice;
      return InvoiceItem(
        productId: p.id,
        productName: p.name,
        barcode: p.barcode,
        unitPrice: p.price,
        costPrice: unitCost,
        quantity: cartItem.quantity.toDouble(),
        unit: p.isPipe ? 'متر' : 'قطعة',
        subtotal: cartItem.total,
        isPipe: p.isPipe,
      );
    }).toList();

    final List<PaymentRecord> initialPaymentHistory = editingInvoice != null
        ? List.from(editingInvoice.paymentHistory)
        : [];
    if (paid > 0 && editingInvoice == null) {
      initialPaymentHistory.add(PaymentRecord(
        id: _uuid.v4(),
        amount: paid,
        date: DateTime.now(),
        note: _paymentOption == 'cash' ? 'دفع كاش بالكامل' : 'دفعة أولية عند الشراء',
      ));
    }

    // Auto-create customer if it's a new name (not selected from dropdown)
    String? customerId = _selectedCustomer?.id ?? editingInvoice?.customerId;
    if (_selectedCustomer == null && editingInvoice == null) {
      final customerName = _customerNameCtrl.text.trim();
      final customerPhone = _customerPhoneCtrl.text.trim();
      if (customerName.isNotEmpty && customerName != 'زبون عادي') {
        final newCustomer = Customer(
          id: _uuid.v4(),
          name: customerName,
          phone: customerPhone,
          createdAt: DateTime.now(),
          craftsmanId: _selectedCraftsman?.id,
          craftsmanName: _selectedCraftsman?.name,
        );
        context.read<CustomerBloc>().add(AddCustomerEvent(newCustomer));
        customerId = newCustomer.id;
      }
    }

    final invoice = Invoice(
      id: editingInvoice?.id ?? _uuid.v4(),
      invoiceNumber: invoiceNumber,
      customerId: customerId,
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
      createdAt: editingInvoice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      craftsmanId: _selectedCraftsman?.id ?? editingInvoice?.craftsmanId,
      craftsmanName: _selectedCraftsman?.name ?? editingInvoice?.craftsmanName,
      returnIds: editingInvoice?.returnIds ?? const [],
    );

    if (editingInvoice != null) {
      context.read<InvoiceBloc>().add(UpdateInvoiceEvent(invoice));
    } else {
      context.read<InvoiceBloc>().add(AddInvoiceEvent(invoice));
    }

    // Show post-save options dialog — _isProcessing stays true until user closes it
    _showInvoiceCreatedOptionsDialog(invoice, isEdit: editingInvoice != null);
  }

  void _showInvoiceCreatedOptionsDialog(Invoice invoice, {bool isEdit = false}) {
    void resetProcessing() {
      if (mounted) setState(() => _isProcessing = false);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 10),
              Flexible(child: Text(isEdit ? 'تم تعديل الفاتورة بنجاح!' : 'تم حفظ الفاتورة وإكمال العملية!')),
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
                      resetProcessing();
                      Navigator.pop(dialogCtx);
                      context.read<BillingBloc>().add(ClearCartEvent());
                      InvoicePdfService.printInvoice(invoice);
                      context.go('/');
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
                      resetProcessing();
                      Navigator.pop(dialogCtx);
                      context.read<BillingBloc>().add(ClearCartEvent());
                      InvoicePdfService.shareInvoicePdf(invoice);
                      context.go('/');
                    },
                    icon: const Icon(Icons.share, color: Colors.green),
                    label: const Text('مشاركة الفاتورة عبر واتساب', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      resetProcessing();
                      Navigator.pop(dialogCtx);
                      context.read<BillingBloc>().add(ClearCartEvent());
                      context.go('/');
                    },
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('بيع جديد / إنهاء', style: TextStyle(fontWeight: FontWeight.bold)),
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
        // Don't clear cart on back — preserve edit session so user can go back and modify
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
                                                  // Auto-load linked craftsman if customer has one
                                                  if (c.craftsmanId != null && c.craftsmanId!.isNotEmpty) {
                                                    final craftsmen = context.read<CraftsmanBloc>().state.craftsmen;
                                                    try {
                                                      _selectedCraftsman = craftsmen.firstWhere((cr) => cr.id == c.craftsmanId);
                                                    } catch (_) {
                                                      // Craftsman not found, keep current selection
                                                    }
                                                  }
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
                                    const SizedBox(height: 10),
                                    // Craftsman picker
                                    BlocBuilder<CraftsmanBloc, CraftsmanState>(
                                      builder: (context, craftsmanState) {
                                        if (craftsmanState.craftsmen.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('الحرفي المسؤول (اختياري)',
                                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            const SizedBox(height: 6),
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: _selectedCraftsman != null
                                                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                                      : Colors.grey.withValues(alpha: 0.3),
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<Craftsman?>(
                                                  value: _selectedCraftsman,
                                                  isExpanded: true,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  hint: const Row(children: [
                                                    Icon(Icons.engineering, size: 18, color: Colors.grey),
                                                    SizedBox(width: 8),
                                                    Text('لا يوجد حرفي',
                                                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                                                  ]),
                                                  items: [
                                                    const DropdownMenuItem<Craftsman?>(
                                                      value: null,
                                                      child: Text('لا يوجد حرفي',
                                                          style: TextStyle(color: Colors.grey)),
                                                    ),
                                                    ...craftsmanState.craftsmen.map((c) =>
                                                        DropdownMenuItem<Craftsman?>(
                                                          value: c,
                                                          child: Row(children: [
                                                            Icon(Icons.engineering, size: 16,
                                                                color: AppTheme.primaryColor),
                                                            const SizedBox(width: 8),
                                                            Text('${c.name} (${c.specialty ?? ''})'),
                                                          ]),
                                                        )),
                                                  ],
                                                  onChanged: (c) =>
                                                      setState(() => _selectedCraftsman = c),
                                                ),
                                              ),
                                            ),
                                            if (_selectedCraftsman != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.check_circle, size: 14,
                                                        color: Colors.green[600]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'سيتم ربط هذه الفاتورة بالحرفي ${_selectedCraftsman!.name}',
                                                      style: TextStyle(
                                                          fontSize: 11, color: Colors.green[700]),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        );
                                      },
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
                            onPressed: _isProcessing ? null : () => _processInvoiceCheckout(billingState, shopState),
                            label: _isProcessing ? 'جاري الحفظ...' : 'إكمال الدفع وحفظ الفاتورة',
                            icon: Icons.check_circle,
                            isLoading: _isProcessing,
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
