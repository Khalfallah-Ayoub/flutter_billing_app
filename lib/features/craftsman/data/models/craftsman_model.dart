import 'package:hive/hive.dart';
import '../../domain/entities/craftsman.dart';

part 'craftsman_model.g.dart';

@HiveType(typeId: 8)
class CraftsmanModel extends Craftsman {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String name;

  @HiveField(2)
  @override
  final String phone;

  @HiveField(3)
  @override
  final String? address;

  @HiveField(4)
  @override
  final String? specialty;

  @HiveField(5)
  @override
  final String? notes;

  @HiveField(6)
  @override
  final DateTime createdAt;

  const CraftsmanModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.specialty,
    this.notes,
    required this.createdAt,
  }) : super(
          id: id,
          name: name,
          phone: phone,
          address: address,
          specialty: specialty,
          notes: notes,
          createdAt: createdAt,
        );

  factory CraftsmanModel.fromEntity(Craftsman e) => CraftsmanModel(
        id: e.id,
        name: e.name,
        phone: e.phone,
        address: e.address,
        specialty: e.specialty,
        notes: e.notes,
        createdAt: e.createdAt,
      );

  Craftsman toEntity() => Craftsman(
        id: id,
        name: name,
        phone: phone,
        address: address,
        specialty: specialty,
        notes: notes,
        createdAt: createdAt,
      );
}
