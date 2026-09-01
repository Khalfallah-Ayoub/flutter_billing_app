// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'craftsman_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CraftsmanModelAdapter extends TypeAdapter<CraftsmanModel> {
  @override
  final int typeId = 8;

  @override
  CraftsmanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CraftsmanModel(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      address: fields[3] as String?,
      specialty: fields[4] as String?,
      notes: fields[5] as String?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CraftsmanModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.specialty)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CraftsmanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
