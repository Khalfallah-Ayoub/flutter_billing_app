import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final String? craftsmanId;   // ID of the craftsman this client belongs to
  final String? craftsmanName; // Denormalized for display performance
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    this.craftsmanId,
    this.craftsmanName,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    String? craftsmanId,
    String? craftsmanName,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      craftsmanId: craftsmanId ?? this.craftsmanId,
      craftsmanName: craftsmanName ?? this.craftsmanName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, address, notes, craftsmanId, craftsmanName, createdAt];
}
