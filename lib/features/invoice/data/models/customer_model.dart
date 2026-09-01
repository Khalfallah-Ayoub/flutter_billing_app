import 'package:hive/hive.dart';
import '../../domain/entities/customer.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 3)
class CustomerModel extends Customer {
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
  final String? notes;

  @HiveField(5)
  @override
  final DateTime createdAt;

  @HiveField(6)
  @override
  final String? craftsmanId;

  @HiveField(7)
  @override
  final String? craftsmanName;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    this.craftsmanId,
    this.craftsmanName,
  }) : super(
          id: id,
          name: name,
          phone: phone,
          address: address,
          notes: notes,
          createdAt: createdAt,
          craftsmanId: craftsmanId,
          craftsmanName: craftsmanName,
        );

  factory CustomerModel.fromEntity(Customer entity) {
    return CustomerModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      address: entity.address,
      notes: entity.notes,
      createdAt: entity.createdAt,
      craftsmanId: entity.craftsmanId,
      craftsmanName: entity.craftsmanName,
    );
  }

  Customer toEntity() {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      notes: notes,
      createdAt: createdAt,
      craftsmanId: craftsmanId,
      craftsmanName: craftsmanName,
    );
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      craftsmanId: map['craftsmanId'] as String?,
      craftsmanName: map['craftsmanName'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'craftsmanId': craftsmanId,
      'craftsmanName': craftsmanName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
