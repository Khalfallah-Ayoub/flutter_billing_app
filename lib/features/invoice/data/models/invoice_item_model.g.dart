// GENERATED CODE - HANDWRITTEN HIVE ADAPTER

part of 'invoice_item_model.dart';

class InvoiceItemModelAdapter extends TypeAdapter<InvoiceItemModel> {
  @override
  final int typeId = 4;

  @override
  InvoiceItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceItemModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      barcode: fields[2] as String,
      unitPrice: fields[3] as double,
      quantity: fields[4] as double,
      unit: fields[5] as String,
      subtotal: fields[6] as double,
      isPipe: fields[7] as bool,
      lengthCut: fields[8] as double?,
      costPrice: (fields[9] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceItemModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.subtotal)
      ..writeByte(7)
      ..write(obj.isPipe)
      ..writeByte(8)
      ..write(obj.lengthCut)
      ..writeByte(9)
      ..write(obj.costPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
