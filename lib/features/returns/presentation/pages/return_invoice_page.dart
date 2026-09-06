import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../invoice/domain/entities/invoice.dart';
import '../../../invoice/domain/entities/invoice_item.dart';
import '../../domain/entities/return_invoice.dart';
import '../../../invoice/presentation/bloc/invoice_bloc.dart';
import '../bloc/return_bloc.dart';
import '../../../invoice/data/services/invoice_pdf_service.dart';

class ReturnInvoicePage extends StatefulWidget {
  final Invoice invoice;

  const ReturnInvoicePage({super.key, required this.invoice});

  @override
  State<ReturnInvoicePage> createState() => _ReturnInvoicePageState();
}

class _ReturnInvoicePageState extends State<ReturnInvoicePage> {
  /// qty[i] = how many units of item[i] the customer is returning
  late List<double> _returnQty;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _returnQty = List.filled(widget.invoice.items.length, 0);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalReturnAmount {
    double total = 0;
    for (int i = 0; i < widget.invoice.items.length; i++) {
      total += _returnQty[i] * widget.invoice.items[i].unitPrice;
    }
    return total;
  }

  bool get _hasAnyReturn => _returnQty.any((q) => q > 0);

  void _submit() {
    if (_isSubmitting) return; // Prevent double-tap
    if (!_hasAnyReturn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد كمية مرجعة لمنتج واحد على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate returned qty vs item.quantity (which already reflects prior returns)
    for (int i = 0; i < widget.invoice.items.length; i++) {
      if (_returnQty[i] > widget.invoice.items[i].quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الكمية المرجعة لـ "${widget.invoice.items[i].productName}" (${_returnQty[i]}) تتجاوز الكمية المتوفرة (${widget.invoice.items[i].quantity})',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final items = <ReturnItem>[];
    for (int i = 0; i < widget.invoice.items.length; i++) {
      if (_returnQty[i] > 0) {
        final inv = widget.invoice.items[i];
        items.add(ReturnItem(
          productId: inv.productId,
          productName: inv.productName,
          quantity: _returnQty[i],
          unitPrice: inv.unitPrice,
          subtotal: _returnQty[i] * inv.unitPrice,
          unit: inv.unit.isEmpty ? 'قطعة' : inv.unit,
        ));
      }
    }

    context.read<ReturnBloc>().add(AddReturnInvoiceEvent(
      originalInvoiceId: widget.invoice.id,
      originalInvoiceNumber: widget.invoice.invoiceNumber,
      customerId: widget.invoice.customerId ?? '',
      customerName: widget.invoice.customerName,
      craftsmanId: widget.invoice.craftsmanId,
      craftsmanName: widget.invoice.craftsmanName,
      items: items,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));

    _showSuccessDialog(items);
  }

  void _showSuccessDialog(List<ReturnItem> items) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocListener<ReturnBloc, ReturnBlocState>(
        listenWhen: (prev, curr) =>
            (curr.lastAdded != null && prev.lastAdded != curr.lastAdded) ||
            (curr.error != null && prev.error != curr.error),
        listener: (_, state) {
          if (state.error != null) {
            // Error: close loading dialog, show error, reset submit flag
            Navigator.pop(ctx);
            if (mounted) setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state.lastAdded != null) {
            // Success: reload invoices then close
            context.read<InvoiceBloc>().add(LoadInvoicesEvent());
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('تم تسجيل الإرجاع'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الزبون: ${widget.invoice.customerName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('${items.length} منتج مرجع'),
              const SizedBox(height: 4),
              Text('إجمالي الإرجاع: ${AppConstants.formatPrice(_totalReturnAmount)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'تم خصم مبلغ الإرجاع من الدين المتبقي تلقائياً',
                  style: TextStyle(color: Colors.blue[700], fontSize: 12),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              children: [
                BlocBuilder<ReturnBloc, ReturnBlocState>(
                  builder: (_, state) {
                    if (state.lastAdded == null) {
                      return const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.pop(true);
                              InvoicePdfService.printReturnInvoice(state.lastAdded!);
                            },
                            icon: const Icon(Icons.print, color: Colors.white),
                            label: const Text('طباعة وصل الإرجاع',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.pop(true);
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('إغلاق'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inv = widget.invoice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل إرجاع بضاعة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Invoice summary header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                  AppTheme.primaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الفاتورة: ${inv.invoiceNumber}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('الزبون: ${inv.customerName}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                      if (inv.craftsmanName != null)
                        Text('الحرفي: ${inv.craftsmanName}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الدين المتبقي',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
                    Text(AppConstants.formatPrice(inv.remainingAmount),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'حدد الكميات المرجعة لكل منتج',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Items list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: inv.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _ReturnItemTile(
                item: inv.items[i],
                returnQty: _returnQty[i],
                onChanged: (qty) => setState(() => _returnQty[i] = qty),
              ),
            ),
          ),

          // Notes field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: 'ملاحظة على الإرجاع (اختياري)...',
                prefixIcon: const Icon(Icons.notes, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي الإرجاع:',
                        style: TextStyle(color: Colors.grey[600])),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        AppConstants.formatPrice(_totalReturnAmount),
                        key: ValueKey(_totalReturnAmount),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _hasAnyReturn ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _hasAnyReturn ? _submit : null,
                    icon: const Icon(Icons.assignment_return, color: Colors.white),
                    label: const Text('تأكيد الإرجاع وحفظه',
                        style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasAnyReturn ? Colors.green : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Return Item Tile ─────────────────────────────────────────────
class _ReturnItemTile extends StatefulWidget {
  final InvoiceItem item;
  final double returnQty;
  final ValueChanged<double> onChanged;

  const _ReturnItemTile({
    required this.item,
    required this.returnQty,
    required this.onChanged,
  });

  @override
  State<_ReturnItemTile> createState() => _ReturnItemTileState();
}

class _ReturnItemTileState extends State<_ReturnItemTile> {
  late TextEditingController _meterCtrl;

  @override
  void initState() {
    super.initState();
    _meterCtrl = TextEditingController(
      text: widget.returnQty > 0 ? widget.returnQty.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ReturnItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller when parent changes qty (e.g. via slider)
    if (oldWidget.returnQty != widget.returnQty) {
      final cursorPos = _meterCtrl.selection;
      _meterCtrl.text = widget.returnQty > 0 ? widget.returnQty.toString() : '';
      // Try to restore cursor, but don't crash if out of range
      if (_meterCtrl.text.isNotEmpty && cursorPos.isValid) {
        try {
          _meterCtrl.selection = cursorPos;
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _meterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.returnQty > 0;
    final maxQty = widget.item.quantity;
    final isPipe = widget.item.isPipe;
    final unit = widget.item.unit.isEmpty ? 'قطعة' : widget.item.unit;
    // For pipes: step by 0.5m. For products: step by 1
    final step = isPipe ? 0.5 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.green.withValues(alpha: 0.05)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? Colors.green.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isPipe ? Colors.blue : AppTheme.primaryColor)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPipe ? Icons.architecture : Icons.shopping_bag,
                  color: isPipe ? Colors.blue : AppTheme.primaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      isPipe
                          ? 'تم شراؤه: ${widget.item.quantity} متر × ${AppConstants.formatPrice(widget.item.unitPrice)}/متر'
                          : 'تم شراؤه: ${widget.item.quantity.toInt()} $unit × ${AppConstants.formatPrice(widget.item.unitPrice)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppConstants.formatPrice(widget.returnQty * widget.item.unitPrice),
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (isPipe) ...[
            // ─── Pipe: precise meter input with +/- 0.5m buttons ───
            Row(
              children: [
                // Decrease by 0.5m
                _QtyBtn(
                  icon: Icons.remove,
                  color: Colors.red,
                  label: '-${step}م',
                  onTap: widget.returnQty > 0
                      ? () {
                          final newQty = (widget.returnQty - step).clamp(0.0, maxQty);
                          widget.onChanged(double.parse(newQty.toStringAsFixed(2)));
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                // Direct meter input
                Expanded(
                  child: TextField(
                    controller: _meterCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.green : Colors.grey[600],
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'متر',
                      suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isSelected ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.green, width: 2),
                      ),
                      isDense: true,
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text) ?? 0.0;
                      final clamped = val.clamp(0.0, maxQty);
                      widget.onChanged(double.parse(clamped.toStringAsFixed(2)));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Increase by 0.5m
                _QtyBtn(
                  icon: Icons.add,
                  color: Colors.green,
                  label: '+${step}م',
                  onTap: widget.returnQty < maxQty
                      ? () {
                          final newQty = (widget.returnQty + step).clamp(0.0, maxQty);
                          widget.onChanged(double.parse(newQty.toStringAsFixed(2)));
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                // Max button
                GestureDetector(
                  onTap: () => widget.onChanged(maxQty),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'الكل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar showing returned vs total
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxQty > 0 ? (widget.returnQty / maxQty) : 0,
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSelected ? Colors.green : Colors.grey,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.returnQty}/${maxQty} متر',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ] else ...[
            // ─── Regular product: integer slider ───
            Row(
              children: [
                _QtyBtn(
                  icon: Icons.remove,
                  color: Colors.red,
                  onTap: widget.returnQty > 0
                      ? () => widget.onChanged((widget.returnQty - 1).clamp(0, maxQty))
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: widget.returnQty,
                    min: 0,
                    max: maxQty,
                    divisions: maxQty > 0 ? maxQty.round() : 1,
                    activeColor: Colors.green,
                    inactiveColor: Colors.grey.withValues(alpha: 0.2),
                    label: '${widget.returnQty.toInt()} $unit',
                    onChanged: (val) => widget.onChanged(val.roundToDouble()),
                  ),
                ),
                _QtyBtn(
                  icon: Icons.add,
                  color: Colors.green,
                  onTap: widget.returnQty < maxQty
                      ? () => widget.onChanged((widget.returnQty + 1).clamp(0, maxQty))
                      : null,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${widget.returnQty.toInt()}/${maxQty.toInt()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? label;

  const _QtyBtn({required this.icon, required this.color, this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : null,
        width: label != null ? null : 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: label != null ? BorderRadius.circular(8) : null,
          shape: label != null ? BoxShape.rectangle : BoxShape.circle,
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14,
                      color: onTap != null ? color : Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(width: 2),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: onTap != null ? color : Colors.grey.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              )
            : Icon(icon, size: 16,
                color: onTap != null ? color : Colors.grey.withValues(alpha: 0.4)),
      ),
    );
  }
}

