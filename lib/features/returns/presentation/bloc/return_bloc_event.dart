part of 'return_bloc.dart';

abstract class ReturnBlocEvent extends Equatable {
  const ReturnBlocEvent();
  @override List<Object?> get props => [];
}

class LoadReturnsEvent extends ReturnBlocEvent {}

class LoadReturnsForInvoiceEvent extends ReturnBlocEvent {
  final String invoiceId;
  const LoadReturnsForInvoiceEvent(this.invoiceId);
  @override List<Object?> get props => [invoiceId];
}

class LoadReturnsForCustomerEvent extends ReturnBlocEvent {
  final String customerId;
  const LoadReturnsForCustomerEvent(this.customerId);
  @override List<Object?> get props => [customerId];
}

class AddReturnInvoiceEvent extends ReturnBlocEvent {
  final String originalInvoiceId;
  final String originalInvoiceNumber;
  final String customerId;
  final String customerName;
  final String? craftsmanId;
  final String? craftsmanName;
  final List<ReturnItem> items;
  final String? notes;

  const AddReturnInvoiceEvent({
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    required this.customerId,
    required this.customerName,
    this.craftsmanId,
    this.craftsmanName,
    required this.items,
    this.notes,
  });

  @override List<Object?> get props => [originalInvoiceId, items];
}

class DeleteReturnInvoiceEvent extends ReturnBlocEvent {
  final String id;
  const DeleteReturnInvoiceEvent(this.id);
  @override List<Object?> get props => [id];
}
