import 'package:equatable/equatable.dart';

class PaymentRecord extends Equatable {
  final String id;
  final double amount;
  final DateTime date;
  final String? note;

  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  PaymentRecord copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [id, amount, date, note];
}
