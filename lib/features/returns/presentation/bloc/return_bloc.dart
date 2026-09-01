import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/return_invoice.dart';
import '../../data/models/return_invoice_model.dart';
import '../../../../core/data/hive_database.dart';
import '../../../invoice/data/models/invoice_model.dart';

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
    _returnCounter = returns.length;
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

  Future<void> _onAdd(AddReturnInvoiceEvent event, Emitter<ReturnBlocState> emit) async {
    _returnCounter++;
    final returnNum = 'RET-${_returnCounter.toString().padLeft(4, '0')}';

    final totalAmount = event.items.fold<double>(0, (s, i) => s + i.subtotal);

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

    // Update original invoice's returnIds + reduce remainingAmount
    final invoiceBox = HiveDatabase.invoiceBox;
    final origModel = invoiceBox.get(event.originalInvoiceId);
    if (origModel != null) {
      final updatedReturnIds = [...origModel.returnIds, returnInvoice.id];
      // Reduce remaining debt by the returned amount
      final newRemaining = (origModel.remainingAmount - totalAmount).clamp(0.0, double.infinity);
      final newPaid = origModel.paidAmount + totalAmount;
      final newStatusString = newRemaining == 0 ? 'paid' : origModel.statusString;

      final updatedInvoice = InvoiceModel(
        id: origModel.id,
        invoiceNumber: origModel.invoiceNumber,
        customerId: origModel.customerId,
        customerName: origModel.customerName,
        customerPhone: origModel.customerPhone,
        items: origModel.items,
        subtotal: origModel.subtotal,
        discount: origModel.discount,
        totalAmount: origModel.totalAmount - totalAmount, // reduce total
        paidAmount: newPaid,
        remainingAmount: newRemaining,
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
    }

    emit(state.copyWith(lastAdded: returnInvoice));
    add(LoadReturnsEvent());
  }

  Future<void> _onDelete(DeleteReturnInvoiceEvent event, Emitter<ReturnBlocState> emit) async {
    await HiveDatabase.returnInvoiceBox.delete(event.id);
    add(LoadReturnsEvent());
  }
}
