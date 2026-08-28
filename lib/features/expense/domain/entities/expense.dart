import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String category; // 'وجبات وعمال', 'نقل وشحن', 'صيانة وإصلاح', 'فواتير ومصاريف', 'أخرى'
  final DateTime date;
  final String? note;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    this.category = 'أخرى',
    required this.date,
    this.note,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [id, title, amount, category, date, note];
}
