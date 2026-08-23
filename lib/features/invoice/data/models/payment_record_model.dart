import 'package:hive/hive.dart';
import '../../domain/entities/payment_record.dart';

part 'payment_record_model.g.dart';

@HiveType(typeId: 6)
class PaymentRecordModel extends PaymentRecord {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final double amount;

  @HiveField(2)
  @override
  final DateTime date;

  @HiveField(3)
  @override
  final String? note;

  const PaymentRecordModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  }) : super(
          id: id,
          amount: amount,
          date: date,
          note: note,
        );

  factory PaymentRecordModel.fromEntity(PaymentRecord entity) {
    return PaymentRecordModel(
      id: entity.id,
      amount: entity.amount,
      date: entity.date,
      note: entity.note,
    );
  }

  PaymentRecord toEntity() {
    return PaymentRecord(
      id: id,
      amount: amount,
      date: date,
      note: note,
    );
  }
}
