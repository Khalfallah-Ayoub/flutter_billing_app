import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
import '../bloc/customer_bloc.dart';
import '../bloc/invoice_bloc.dart';
import '../../data/services/invoice_service.dart';

class CreateEditInvoicePage extends StatefulWidget {
  final Invoice? invoice;

  const CreateEditInvoicePage({super.key, this.invoice});

  @override
  State<CreateEditInvoicePage> createState() => _CreateEditInvoicePageState();
}

class _CreateEditInvoicePageState extends State<CreateEditInvoicePage> {
  final _uuid = const Uuid();

  late String _invoiceNumber;
  Customer? _selectedCustomer;
  final TextEditingController _customerNameCtrl = TextEditingController(text: 'زبون عادي');
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  final TextEditingController _paidAmountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash', 'debt'
  final List<InvoiceItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _invoiceNumber = inv.invoiceNumber;
      _customerNameCtrl.text = inv.customerName;
      _customerPhoneCtrl.text = inv.customerPhone ?? '';
      _discountCtrl.text = inv.discount.toStringAsFixed(0);
      _paidAmountCtrl.text = inv.paidAmount.toStringAsFixed(0);
      _notesCtrl.text = inv.notes ?? '';
      _paymentMethod = inv.paymentMethod;
      _selectedItems.addAll(inv.items);
    } else {
      _invoiceNumber = InvoiceService.generateNextInvoiceNumber();
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _discountCtrl.dispose();
    _paidAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get subtotal => _selectedItems.fold(0.0, (sum, i) => sum + i.subtotal);
  double get discount => double.tryParse(_discountCtrl.text) ?? 0.0;
  double get totalAmount => (subtotal - discount).clamp(0.0, double.infinity);
  double get paidAmount {
    if (_paymentMethod == 'cash' && _paidAmountCtrl.text.isEmpty) {
      return totalAmount;
    }
    return double.tryParse(_paidAmountCtrl.text) ?? 0.0;
  }

  double get remainingDebt => (totalAmount - paidAmount).clamp(0.0, double.infinity);

  void _showAddProductModal() {
    final products = context.read<ProductBloc>().state.products;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('اختر منتجاً أو أنبوباً لإضافته للفاتورة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات مسجلة.'))
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, idx) {
                          final p = products[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.isPipe
                                  ? Colors.blue.withValues(alpha: 0.15)
                                  : AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Icon(
                                p.isPipe ? Icons.architecture : Icons.shopping_bag,
                                color: p.isPipe ? Colors.blue : AppTheme.primaryColor,
                              ),
                            ),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              p.isPipe
                                  ? 'سعر المتر: ${p.calculatedPricePerMeter.toStringAsFixed(2)} دج'
                                  : 'السعر: ${p.price} دج',
                            ),
                            trailing: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                            onTap: () {
                              Navigator.pop(ctx);
                              _addItemToInvoice(p);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addItemToInvoice(Product product) {
    if (product.isPipe) {
      _showPipeLengthDialog(product);
    } else {
      setState(() {
        final existingIdx = _selectedItems.indexWhere((item) => item.productId == product.id);
        if (existingIdx >= 0) {
          final item = _selectedItems[existingIdx];
          final newQty = item.quantity + 1;
          _selectedItems[existingIdx] = item.copyWith(
            quantity: newQty,
            subtotal: newQty * item.unitPrice,
          );
        } else {
          _selectedItems.add(InvoiceItem(
            productId: product.id,
            productName: product.name,
            barcode: product.barcode,
            unitPrice: product.price,
            quantity: 1,
            unit: 'قطعة',
            subtotal: product.price,
            isPipe: false,
          ));
        }
      });
    }
  }

  void _showPipeLengthDialog(Product pipe) {
    final meterCtrl = TextEditingController(text: '1.0');
    final pricePerMeter = pipe.calculatedPricePerMeter;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('تحديد طول أنبوب ${pipe.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('سعر المتر التلقائي: ${pricePerMeter.toStringAsFixed(2)} دج / متر'),
              const SizedBox(height: 12),
              TextFormField(
                controller: meterCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الطول المطلوب بالمتر (مثلاً 2.5)',
                  prefixIcon: Icon(Icons.straighten),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final meters = double.tryParse(meterCtrl.text) ?? 1.0;
                if (meters <= 0) return;

                final sub = meters * pricePerMeter;
                setState(() {
                  _selectedItems.add(InvoiceItem(
                    productId: pipe.id,
                    productName: '${pipe.name} ($metersمتر)',
                    barcode: pipe.barcode,
                    unitPrice: pricePerMeter,
                    quantity: meters,
                    unit: 'متر',
                    subtotal: sub,
                    isPipe: true,
                    lengthCut: meters,
                  ));
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('إضافة للفاتورة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _saveInvoice() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى إضافة منتج واحد على الأقل للفاتورة')),
      );
      return;
    }

    final cName = _customerNameCtrl.text.trim();
    if (cName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى إدخال اسم الزبون')),
      );
      return;
    }

    PaymentStatus status = PaymentStatus.paid;
    if (remainingDebt > 0 && paidAmount > 0) {
      status = PaymentStatus.partial;
    } else if (remainingDebt > 0 && paidAmount == 0) {
      status = PaymentStatus.unpaid;
    }

    final invoice = Invoice(
      id: widget.invoice?.id ?? _uuid.v4(),
      invoiceNumber: _invoiceNumber,
      customerId: _selectedCustomer?.id,
      customerName: cName,
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty ? null : _customerPhoneCtrl.text.trim(),
      items: _selectedItems,
      subtotal: subtotal,
      discount: discount,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingDebt,
      paymentStatus: status,
      paymentMethod: _paymentMethod,
      createdAt: widget.invoice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (widget.invoice == null) {
      context.read<InvoiceBloc>().add(AddInvoiceEvent(invoice));
    } else {
      context.read<InvoiceBloc>().add(UpdateInvoiceEvent(invoice));
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = context.watch<CustomerBloc>().state.customers;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoice == null ? 'إنشاء فاتورة جديدة' : 'تعديل الفاتورة'),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Invoice Number Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رقم الفاتورة التلقائي:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _invoiceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Customer Selector / Inputs
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
                        const Text('بيانات الزبون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        labelText: 'اسم الزبون *',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف (اختياري)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Selected Items Header & Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المنتجات والفواتير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                OutlinedButton.icon(
                  onPressed: _showAddProductModal,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة منتج/أنبوب'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4. Items List Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _selectedItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('لم يتم إضافة أي منتج بعد. انقر على "إضافة منتج" أعلاه.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : Column(
                        children: _selectedItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return ListTile(
                            leading: Icon(
                              item.isPipe ? Icons.architecture : Icons.shopping_bag,
                              color: item.isPipe ? Colors.blue : AppTheme.primaryColor,
                            ),
                            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${item.quantity} ${item.unit} × ${item.unitPrice} دج',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.subtotal.toStringAsFixed(2)} دج',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedItems.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Payment & Discount Summary
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'الخصم (دج)',
                              prefixIcon: Icon(Icons.discount),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'طريقة الدفع',
                              prefixIcon: Icon(Icons.payment),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('نقداً (كاش)')),
                              DropdownMenuItem(value: 'debt', child: Text('دين معلق')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _paymentMethod = val;
                                  if (val == 'debt' && _paidAmountCtrl.text.isEmpty) {
                                    _paidAmountCtrl.text = '0';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidAmountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع (دج)',
                        hintText: 'اتركه فارغاً إذا تم دفع كامل المبلغ',
                        prefixIcon: const Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),

                    // Financial Summary Rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموع الصافي:', style: TextStyle(fontSize: 14)),
                        Text('${subtotal.toStringAsFixed(2)} دج', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ الإجمالي المطلـوب:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${totalAmount.toStringAsFixed(2)} دج',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الدين المتبقي:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          '${remainingDebt.toStringAsFixed(2)} دج',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: remainingDebt > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveInvoice,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  'حفظ الفاتورة والعملية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
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
}
