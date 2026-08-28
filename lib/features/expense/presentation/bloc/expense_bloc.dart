import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/data/hive_database.dart';
import '../../data/models/expense_model.dart';
import '../../domain/entities/expense.dart';

// Events
abstract class ExpenseEvent extends Equatable {
  const ExpenseEvent();
  @override
  List<Object?> get props => [];
}

class LoadExpensesEvent extends ExpenseEvent {}

class AddExpenseEvent extends ExpenseEvent {
  final Expense expense;
  const AddExpenseEvent(this.expense);
  @override
  List<Object?> get props => [expense];
}

class DeleteExpenseEvent extends ExpenseEvent {
  final String id;
  const DeleteExpenseEvent(this.id);
  @override
  List<Object?> get props => [id];
}

// State
class ExpenseState extends Equatable {
  final List<Expense> expenses;
  final bool isLoading;

  const ExpenseState({
    this.expenses = const [],
    this.isLoading = false,
  });

  ExpenseState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
  }) {
    return ExpenseState(
      expenses: expenses ?? this.expenses,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Calculates total expenses
  double get totalExpenseAmount =>
      expenses.fold(0.0, (sum, item) => sum + item.amount);

  /// Filters expenses for today
  double get todayExpenseAmount {
    final now = DateTime.now();
    return expenses.where((e) {
      return e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  @override
  List<Object?> get props => [expenses, isLoading];
}

// Bloc
class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  ExpenseBloc() : super(const ExpenseState()) {
    on<LoadExpensesEvent>(_onLoadExpenses);
    on<AddExpenseEvent>(_onAddExpense);
    on<DeleteExpenseEvent>(_onDeleteExpense);

    // Initial load
    add(LoadExpensesEvent());
  }

  void _onLoadExpenses(LoadExpensesEvent event, Emitter<ExpenseState> emit) {
    try {
      final box = HiveDatabase.expenseBox;
      final expenses = box.values.map((m) => m.toEntity()).toList();
      // Sort newest first
      expenses.sort((a, b) => b.date.compareTo(a.date));
      emit(state.copyWith(expenses: expenses, isLoading: false));
    } catch (_) {
      emit(state.copyWith(expenses: [], isLoading: false));
    }
  }

  Future<void> _onAddExpense(AddExpenseEvent event, Emitter<ExpenseState> emit) async {
    final box = HiveDatabase.expenseBox;
    final model = ExpenseModel.fromEntity(event.expense);
    await box.put(event.expense.id, model);

    add(LoadExpensesEvent());
  }

  Future<void> _onDeleteExpense(DeleteExpenseEvent event, Emitter<ExpenseState> emit) async {
    final box = HiveDatabase.expenseBox;
    await box.delete(event.id);

    add(LoadExpensesEvent());
  }
}
