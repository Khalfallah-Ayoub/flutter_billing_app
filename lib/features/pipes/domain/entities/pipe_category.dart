import 'dart:convert';
import 'package:equatable/equatable.dart';

class PipeCategory extends Equatable {
  final String id;
  final String name;
  final double defaultLength; // in meters (e.g. 6.0 for PVC, 5.0 for copper)
  final String? description;
  final bool isSystem;

  const PipeCategory({
    required this.id,
    required this.name,
    required this.defaultLength,
    this.description,
    this.isSystem = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'defaultLength': defaultLength,
      'description': description,
      'isSystem': isSystem,
    };
  }

  factory PipeCategory.fromMap(Map<String, dynamic> map) {
    return PipeCategory(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      defaultLength: (map['defaultLength'] as num?)?.toDouble() ?? 6.0,
      description: map['description'] as String?,
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PipeCategory.fromJson(String source) =>
      PipeCategory.fromMap(jsonDecode(source) as Map<String, dynamic>);

  PipeCategory copyWith({
    String? id,
    String? name,
    double? defaultLength,
    String? description,
    bool? isSystem,
  }) {
    return PipeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultLength: defaultLength ?? this.defaultLength,
      description: description ?? this.description,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  List<Object?> get props => [id, name, defaultLength, description, isSystem];
}
