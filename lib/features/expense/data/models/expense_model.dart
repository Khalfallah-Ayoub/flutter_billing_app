import 'package:hive/hive.dart';
import '../../domain/entities/expense.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 7)
class ExpenseModel extends Expense {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String title;

  @HiveField(2)
  @override
  final double amount;

  @HiveField(3)
  @override
  final String category;

  @HiveField(4)
  @override
  final DateTime date;

  @HiveField(5)
  @override
  final String? note;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  }) : super(
          id: id,
          title: title,
          amount: amount,
          category: category,
          date: date,
          note: note,
        );

  factory ExpenseModel.fromEntity(Expense entity) {
    return ExpenseModel(
      id: entity.id,
      title: entity.title,
      amount: entity.amount,
      category: entity.category,
      date: entity.date,
      note: entity.note,
    );
  }

  Expense toEntity() {
    return Expense(
      id: id,
      title: title,
      amount: amount,
      category: category,
      date: date,
      note: note,
    );
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'أخرى',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}
