import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/customer.dart';
import '../../data/services/customer_service.dart';

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomersEvent extends CustomerEvent {}

class AddCustomerEvent extends CustomerEvent {
  final Customer customer;
  const AddCustomerEvent(this.customer);
  @override
  List<Object?> get props => [customer];
}

class UpdateCustomerEvent extends CustomerEvent {
  final Customer customer;
  const UpdateCustomerEvent(this.customer);
  @override
  List<Object?> get props => [customer];
}

class DeleteCustomerEvent extends CustomerEvent {
  final String id;
  const DeleteCustomerEvent(this.id);
  @override
  List<Object?> get props => [id];
}

enum CustomerStatus { initial, loading, success, error }

class CustomerState extends Equatable {
  final CustomerStatus status;
  final List<Customer> customers;
  final String? message;

  const CustomerState({
    this.status = CustomerStatus.initial,
    this.customers = const [],
    this.message,
  });

  CustomerState copyWith({
    CustomerStatus? status,
    List<Customer>? customers,
    String? message,
  }) {
    return CustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, customers, message];
}

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc() : super(const CustomerState()) {
    on<LoadCustomersEvent>(_onLoadCustomers);
    on<AddCustomerEvent>(_onAddCustomer);
    on<UpdateCustomerEvent>(_onUpdateCustomer);
    on<DeleteCustomerEvent>(_onDeleteCustomer);
  }

  void _onLoadCustomers(LoadCustomersEvent event, Emitter<CustomerState> emit) {
    emit(state.copyWith(status: CustomerStatus.loading));
    try {
      final customers = CustomerService.getCustomers();
      emit(state.copyWith(
        status: CustomerStatus.success,
        customers: customers,
      ));
    } catch (e) {
      emit(state.copyWith(status: CustomerStatus.error, message: 'فشل تحميل العملاء: $e'));
    }
  }

  Future<void> _onAddCustomer(AddCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await CustomerService.saveCustomer(event.customer);
      final customers = CustomerService.getCustomers();
      emit(state.copyWith(
        status: CustomerStatus.success,
        customers: customers,
        message: 'تمت إضافة الزبون بنجاح!',
      ));
    } catch (e) {
      emit(state.copyWith(status: CustomerStatus.error, message: 'فشل إضافة الزبون: $e'));
    }
  }

  Future<void> _onUpdateCustomer(UpdateCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await CustomerService.saveCustomer(event.customer);
      final customers = CustomerService.getCustomers();
      emit(state.copyWith(
        status: CustomerStatus.success,
        customers: customers,
        message: 'تم تحديث بيانات الزبون بنجاح!',
      ));
    } catch (e) {
      emit(state.copyWith(status: CustomerStatus.error, message: 'فشل تحديث الزبون: $e'));
    }
  }

  Future<void> _onDeleteCustomer(DeleteCustomerEvent event, Emitter<CustomerState> emit) async {
    try {
      await CustomerService.deleteCustomer(event.id);
      final customers = CustomerService.getCustomers();
      emit(state.copyWith(
        status: CustomerStatus.success,
        customers: customers,
        message: 'تم حذف الزبون.',
      ));
    } catch (e) {
      emit(state.copyWith(status: CustomerStatus.error, message: 'فشل حذف الزبون: $e'));
    }
  }
}
