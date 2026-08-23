import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/invoice.dart';
import '../../data/services/invoice_service.dart';

// --- Events ---
abstract class InvoiceEvent extends Equatable {
  const InvoiceEvent();
  @override
  List<Object?> get props => [];
}

class LoadInvoicesEvent extends InvoiceEvent {}

class AddInvoiceEvent extends InvoiceEvent {
  final Invoice invoice;
  const AddInvoiceEvent(this.invoice);
  @override
  List<Object?> get props => [invoice];
}

class UpdateInvoiceEvent extends InvoiceEvent {
  final Invoice invoice;
  const UpdateInvoiceEvent(this.invoice);
  @override
  List<Object?> get props => [invoice];
}

class DeleteInvoiceEvent extends InvoiceEvent {
  final String id;
  const DeleteInvoiceEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class PayInvoiceDebtEvent extends InvoiceEvent {
  final String invoiceId;
  final double paymentAmount;
  final String? note;
  const PayInvoiceDebtEvent({
    required this.invoiceId,
    required this.paymentAmount,
    this.note,
  });
  @override
  List<Object?> get props => [invoiceId, paymentAmount, note];
}

class FilterInvoicesEvent extends InvoiceEvent {
  final String? searchQuery;
  final String? statusFilter; // 'all', 'paid', 'partial', 'unpaid'
  final DateTimeRange? dateRange;

  const FilterInvoicesEvent({this.searchQuery, this.statusFilter, this.dateRange});
  @override
  List<Object?> get props => [searchQuery, statusFilter, dateRange];
}

class DateTimeRange extends Equatable {
  final DateTime start;
  final DateTime end;
  const DateTimeRange({required this.start, required this.end});
  @override
  List<Object?> get props => [start, end];
}

// --- States ---
enum InvoiceStatus { initial, loading, success, error }

class InvoiceState extends Equatable {
  final InvoiceStatus status;
  final List<Invoice> allInvoices;
  final List<Invoice> filteredInvoices;
  final String? searchQuery;
  final String statusFilter; // 'all', 'paid', 'partial', 'unpaid'
  final DateTimeRange? dateRange;
  final String? message;

  const InvoiceState({
    this.status = InvoiceStatus.initial,
    this.allInvoices = const [],
    this.filteredInvoices = const [],
    this.searchQuery,
    this.statusFilter = 'all',
    this.dateRange,
    this.message,
  });

  double get totalRevenue =>
      allInvoices.fold(0.0, (sum, inv) => sum + inv.paidAmount);

  double get totalRemainingDebt =>
      allInvoices.fold(0.0, (sum, inv) => sum + inv.remainingAmount);

  InvoiceState copyWith({
    InvoiceStatus? status,
    List<Invoice>? allInvoices,
    List<Invoice>? filteredInvoices,
    String? searchQuery,
    String? statusFilter,
    DateTimeRange? dateRange,
    String? message,
  }) {
    return InvoiceState(
      status: status ?? this.status,
      allInvoices: allInvoices ?? this.allInvoices,
      filteredInvoices: filteredInvoices ?? this.filteredInvoices,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      dateRange: dateRange ?? this.dateRange,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allInvoices,
        filteredInvoices,
        searchQuery,
        statusFilter,
        dateRange,
        message,
      ];
}

// --- BLoC ---
class InvoiceBloc extends Bloc<InvoiceEvent, InvoiceState> {
  InvoiceBloc() : super(const InvoiceState()) {
    on<LoadInvoicesEvent>(_onLoadInvoices);
    on<AddInvoiceEvent>(_onAddInvoice);
    on<UpdateInvoiceEvent>(_onUpdateInvoice);
    on<DeleteInvoiceEvent>(_onDeleteInvoice);
    on<PayInvoiceDebtEvent>(_onPayInvoiceDebt);
    on<FilterInvoicesEvent>(_onFilterInvoices);
  }

  void _onLoadInvoices(LoadInvoicesEvent event, Emitter<InvoiceState> emit) {
    emit(state.copyWith(status: InvoiceStatus.loading));
    try {
      final invoices = InvoiceService.getInvoices();
      final filtered = _applyFilters(invoices, state.searchQuery, state.statusFilter, state.dateRange);
      emit(state.copyWith(
        status: InvoiceStatus.success,
        allInvoices: invoices,
        filteredInvoices: filtered,
      ));
    } catch (e) {
      emit(state.copyWith(status: InvoiceStatus.error, message: 'فشل تحميل الفواتير: $e'));
    }
  }

  Future<void> _onAddInvoice(AddInvoiceEvent event, Emitter<InvoiceState> emit) async {
    try {
      await InvoiceService.saveInvoice(event.invoice);
      final invoices = InvoiceService.getInvoices();
      final filtered = _applyFilters(invoices, state.searchQuery, state.statusFilter, state.dateRange);
      emit(state.copyWith(
        status: InvoiceStatus.success,
        allInvoices: invoices,
        filteredInvoices: filtered,
        message: 'تم حفظ الفاتورة بنجاح!',
      ));
    } catch (e) {
      emit(state.copyWith(status: InvoiceStatus.error, message: 'فشل حفظ الفاتورة: $e'));
    }
  }

  Future<void> _onUpdateInvoice(UpdateInvoiceEvent event, Emitter<InvoiceState> emit) async {
    try {
      await InvoiceService.saveInvoice(event.invoice);
      final invoices = InvoiceService.getInvoices();
      final filtered = _applyFilters(invoices, state.searchQuery, state.statusFilter, state.dateRange);
      emit(state.copyWith(
        status: InvoiceStatus.success,
        allInvoices: invoices,
        filteredInvoices: filtered,
        message: 'تم تحديث الفاتورة بنجاح!',
      ));
    } catch (e) {
      emit(state.copyWith(status: InvoiceStatus.error, message: 'فشل تحديث الفاتورة: $e'));
    }
  }

  Future<void> _onDeleteInvoice(DeleteInvoiceEvent event, Emitter<InvoiceState> emit) async {
    try {
      await InvoiceService.deleteInvoice(event.id);
      final invoices = InvoiceService.getInvoices();
      final filtered = _applyFilters(invoices, state.searchQuery, state.statusFilter, state.dateRange);
      emit(state.copyWith(
        status: InvoiceStatus.success,
        allInvoices: invoices,
        filteredInvoices: filtered,
        message: 'تم حذف الفاتورة.',
      ));
    } catch (e) {
      emit(state.copyWith(status: InvoiceStatus.error, message: 'فشل حذف الفاتورة: $e'));
    }
  }

  Future<void> _onPayInvoiceDebt(PayInvoiceDebtEvent event, Emitter<InvoiceState> emit) async {
    try {
      await InvoiceService.payInvoiceDebt(
        event.invoiceId,
        event.paymentAmount,
        note: event.note,
      );
      final invoices = InvoiceService.getInvoices();
      final filtered = _applyFilters(invoices, state.searchQuery, state.statusFilter, state.dateRange);
      emit(state.copyWith(
        status: InvoiceStatus.success,
        allInvoices: invoices,
        filteredInvoices: filtered,
        message: 'تم تسجيل الدفعة بنجاح!',
      ));
    } catch (e) {
      emit(state.copyWith(status: InvoiceStatus.error, message: 'فشل تسديد الدفعة: $e'));
    }
  }

  void _onFilterInvoices(FilterInvoicesEvent event, Emitter<InvoiceState> emit) {
    final query = event.searchQuery ?? state.searchQuery;
    final status = event.statusFilter ?? state.statusFilter;
    final date = event.dateRange ?? state.dateRange;

    final filtered = _applyFilters(state.allInvoices, query, status, date);
    emit(state.copyWith(
      searchQuery: query,
      statusFilter: status,
      dateRange: date,
      filteredInvoices: filtered,
    ));
  }

  List<Invoice> _applyFilters(
    List<Invoice> invoices,
    String? query,
    String status,
    DateTimeRange? dateRange,
  ) {
    return invoices.where((inv) {
      // 1. Status Filter
      if (status == 'paid' && inv.paymentStatus != PaymentStatus.paid) return false;
      if (status == 'partial' && inv.paymentStatus != PaymentStatus.partial) return false;
      if (status == 'unpaid' && inv.paymentStatus != PaymentStatus.unpaid) return false;
      if (status == 'debt' && inv.remainingAmount <= 0) return false;

      // 2. Date Range Filter
      if (dateRange != null) {
        if (inv.createdAt.isBefore(dateRange.start) || inv.createdAt.isAfter(dateRange.end)) {
          return false;
        }
      }

      // 3. Search Query Filter
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final nameMatch = inv.customerName.toLowerCase().contains(q);
        final phoneMatch = (inv.customerPhone ?? '').toLowerCase().contains(q);
        final numMatch = inv.invoiceNumber.toLowerCase().contains(q);
        return nameMatch || phoneMatch || numMatch;
      }

      return true;
    }).toList();
  }
}
