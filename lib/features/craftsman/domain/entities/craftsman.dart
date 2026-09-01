import 'package:equatable/equatable.dart';

/// حرفي — Trade professional who brings clients to the shop.
/// Clients (customers) link to a craftsman via [craftsmanId].
class Craftsman extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? specialty; // e.g. كهربائي, سبّاك, بنّاء
  final String? notes;
  final DateTime createdAt;

  const Craftsman({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.specialty,
    this.notes,
    required this.createdAt,
  });

  Craftsman copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? specialty,
    String? notes,
    DateTime? createdAt,
  }) {
    return Craftsman(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      specialty: specialty ?? this.specialty,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, address, specialty, notes, createdAt];
}
