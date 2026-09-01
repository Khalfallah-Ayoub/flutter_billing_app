// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'return_invoice_model.dart';

class ReturnItemModelAdapter extends TypeAdapter<ReturnItemModel> {
  @override
  final int typeId = 9;

  @override
  ReturnItemModel read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ReturnItemModel(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: (fields[2] as num).toDouble(),
      unitPrice: (fields[3] as num).toDouble(),
      subtotal: (fields[4] as num).toDouble(),
      unit: fields[5] as String? ?? 'قطعة',
    );
  }

  @override
  void write(BinaryWriter writer, ReturnItemModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.productId)
      ..writeByte(1)..write(obj.productName)
      ..writeByte(2)..write(obj.quantity)
      ..writeByte(3)..write(obj.unitPrice)
      ..writeByte(4)..write(obj.subtotal)
      ..writeByte(5)..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReturnItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReturnInvoiceModelAdapter extends TypeAdapter<ReturnInvoiceModel> {
  @override
  final int typeId = 10;

  @override
  ReturnInvoiceModel read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ReturnInvoiceModel(
      id: fields[0] as String,
      returnNumber: fields[1] as String,
      originalInvoiceId: fields[2] as String,
      originalInvoiceNumber: fields[3] as String,
      customerId: fields[4] as String,
      customerName: fields[5] as String,
      craftsmanId: fields[6] as String?,
      craftsmanName: fields[7] as String?,
      items: (fields[8] as List).cast<ReturnItemModel>(),
      totalReturnAmount: (fields[9] as num).toDouble(),
      notes: fields[10] as String?,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ReturnInvoiceModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.returnNumber)
      ..writeByte(2)..write(obj.originalInvoiceId)
      ..writeByte(3)..write(obj.originalInvoiceNumber)
      ..writeByte(4)..write(obj.customerId)
      ..writeByte(5)..write(obj.customerName)
      ..writeByte(6)..write(obj.craftsmanId)
      ..writeByte(7)..write(obj.craftsmanName)
      ..writeByte(8)..write(obj.items)
      ..writeByte(9)..write(obj.totalReturnAmount)
      ..writeByte(10)..write(obj.notes)
      ..writeByte(11)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReturnInvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
