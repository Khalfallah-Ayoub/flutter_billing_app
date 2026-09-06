import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/return_invoice.dart';
import '../../data/models/return_invoice_model.dart';
import '../../../../core/data/hive_database.dart';
import '../../../invoice/data/models/invoice_model.dart';
import '../../../invoice/data/models/invoice_item_model.dart';

part 'return_bloc_event.dart';
part 'return_bloc_state.dart';

class ReturnBloc extends Bloc<ReturnBlocEvent, ReturnBlocState> {
  final _uuid = const Uuid();
  static int _returnCounter = 0;

  ReturnBloc() : super(const ReturnBlocState()) {
    on<LoadReturnsEvent>(_onLoad);
    on<LoadReturnsForInvoiceEvent>(_onLoadForInvoice);
    on<LoadReturnsForCustomerEvent>(_onLoadForCustomer);
    on<AddReturnInvoiceEvent>(_onAdd);
    on<DeleteReturnInvoiceEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadReturnsEvent event, Emitter<ReturnBlocState> emit) async {
    final returns = HiveDatabase.returnInvoiceBox.values
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Derive max counter from existing return numbers (RET-XXXX)
    int maxNum = 0;
    for (final r in returns) {
      final num = r.returnNumber;
      if (num.startsWith('RET-')) {
        final parsed = int.tryParse(num.substring(4));
        if (parsed != null && parsed > maxNum) maxNum = parsed;
      }
    }
    _returnCounter = maxNum;

    emit(state.copyWith(returns: returns));
  }

  Future<void> _onLoadForInvoice(LoadReturnsForInvoiceEvent event, Emitter<ReturnBlocState> emit) async {
    final returns = HiveDatabase.returnInvoiceBox.values
        .where((m) => m.originalInvoiceId == event.invoiceId)
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(returns: returns));
  }

  Future<void> _onLoadForCustomer(LoadReturnsForCustomerEvent event, Emitter<ReturnBlocState> emit) async {
    final returns = HiveDatabase.returnInvoiceBox.values
        .where((m) => m.customerId == event.customerId)
        .map((m) => m.toEntity())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(returns: returns));
  }

  // Lock to prevent concurrent/double submissions
  bool _isProcessingReturn = false;

  Future<void> _onAdd(AddReturnInvoiceEvent event, Emitter<ReturnBlocState> emit) async {
    if (_isProcessingReturn) return; // Prevent double-tap
    _isProcessingReturn = true;

    try {
      // ── 1. Validate against current invoice data from Hive ──────────────
      final invoiceBox = HiveDatabase.invoiceBox;
      final origModel = invoiceBox.get(event.originalInvoiceId);
      if (origModel == null) {
        emit(state.copyWith(error: 'الفاتورة الأصلية غير موجودة'));
        return;
      }

      // Validate each returned qty does NOT exceed what is still on the invoice
      for (final returnItem in event.items) {
        final origItem = origModel.items.cast<InvoiceItemModel?>().firstWhere(
          (i) => i != null &&
              ((returnItem.productId.isNotEmpty && i.productId == returnItem.productId) ||
                  i.productName == returnItem.productName),
          orElse: () => null,
        );
        if (origItem == null) continue;
        if (returnItem.quantity > origItem.quantity) {
          emit(state.copyWith(
            error: 'الكمية المرجعة لـ "${returnItem.productName}" تتجاوز الكمية المتوفرة في الفاتورة',
          ));
          return;
        }
      }

      // ── 2. Check total return amount is > 0 ──────────────────────────────
      final totalAmount = event.items.fold<double>(0, (s, i) => s + i.subtotal);
      if (totalAmount <= 0) {
        emit(state.copyWith(error: 'مبلغ الإرجاع يجب أن يكون أكبر من صفر'));
        return;
      }

      // ── 3. Build return record ────────────────────────────────────────────
      _returnCounter++;
      final returnNum = 'RET-${_returnCounter.toString().padLeft(4, '0')}';

      final returnInvoice = ReturnInvoice(
        id: _uuid.v4(),
        returnNumber: returnNum,
        originalInvoiceId: event.originalInvoiceId,
        originalInvoiceNumber: event.originalInvoiceNumber,
        customerId: event.customerId,
        customerName: event.customerName,
        craftsmanId: event.craftsmanId,
        craftsmanName: event.craftsmanName,
        items: event.items,
        totalReturnAmount: totalAmount,
        notes: event.notes,
        createdAt: DateTime.now(),
      );

      final model = ReturnInvoiceModel.fromEntity(returnInvoice);
      await HiveDatabase.returnInvoiceBox.put(returnInvoice.id, model);

      // ── 4. Update original invoice atomically ─────────────────────────────
      final updatedReturnIds = [...origModel.returnIds, returnInvoice.id];

      // Reduce item quantities
      final updatedItems = origModel.items.map((item) {
        final match = event.items.cast<ReturnItem?>().firstWhere(
          (ri) => ri != null &&
              ((ri.productId.isNotEmpty && ri.productId == item.productId) ||
                  ri.productName == item.productName),
          orElse: () => null,
        );
        if (match == null) return item;
        final newQty = (item.quantity - match.quantity).clamp(0.0, double.infinity);
        final newSub = newQty * item.unitPrice;
        return InvoiceItemModel(
          productId: item.productId,
          productName: item.productName,
          barcode: item.barcode,
          unitPrice: item.unitPrice,
          costPrice: item.costPrice,
          quantity: newQty,
          unit: item.unit,
          subtotal: newSub,
          isPipe: item.isPipe,
          lengthCut: item.lengthCut,
        );
      }).toList();

      final newSubtotal = updatedItems.fold<double>(0, (s, i) => s + i.subtotal);
      final newTotalAmount = (newSubtotal - origModel.discount).clamp(0.0, double.infinity);

      // Debt-first reduction: return amount clears debt before refunding cash
      final debtReduction = totalAmount.clamp(0.0, origModel.remainingAmount);
      final cashRefund = (totalAmount - debtReduction).clamp(0.0, origModel.paidAmount);

      final newRemainingAmount = (origModel.remainingAmount - debtReduction).clamp(0.0, double.infinity);
      final newPaidAmount = (origModel.paidAmount - cashRefund).clamp(0.0, double.infinity);

      String newStatusString;
      if (newRemainingAmount <= 0.001) {
        newStatusString = 'paid';
      } else if (newPaidAmount > 0.001) {
        newStatusString = 'partial';
      } else {
        newStatusString = 'unpaid';
      }

      final updatedInvoice = InvoiceModel(
        id: origModel.id,
        invoiceNumber: origModel.invoiceNumber,
        customerId: origModel.customerId,
        customerName: origModel.customerName,
        customerPhone: origModel.customerPhone,
        items: updatedItems,
        subtotal: newSubtotal,
        discount: origModel.discount,
        totalAmount: newTotalAmount,
        paidAmount: newPaidAmount,
        remainingAmount: newRemainingAmount,
        statusString: newStatusString,
        paymentMethod: origModel.paymentMethod,
        paymentHistory: origModel.paymentHistory,
        createdAt: origModel.createdAt,
        updatedAt: DateTime.now(),
        notes: origModel.notes,
        craftsmanId: origModel.craftsmanId,
        craftsmanName: origModel.craftsmanName,
        returnIds: updatedReturnIds,
      );
      await invoiceBox.put(origModel.id, updatedInvoice);

      emit(state.copyWith(lastAdded: returnInvoice, clearError: true));
      add(LoadReturnsEvent());
    } finally {
      _isProcessingReturn = false;
    }
  }

  Future<void> _onDelete(DeleteReturnInvoiceEvent event, Emitter<ReturnBlocState> emit) async {
    await HiveDatabase.returnInvoiceBox.delete(event.id);
    add(LoadReturnsEvent());
  }
}
