// GENERATED CODE - HANDWRITTEN HIVE ADAPTER

part of 'invoice_model.dart';

class InvoiceModelAdapter extends TypeAdapter<InvoiceModel> {
  @override
  final int typeId = 5;

  @override
  InvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceModel(
      id: fields[0] as String,
      invoiceNumber: fields[1] as String,
      customerId: fields[2] as String?,
      customerName: fields[3] as String,
      customerPhone: fields[4] as String?,
      items: (fields[5] as List).cast<InvoiceItemModel>(),
      subtotal: fields[6] as double,
      discount: fields[7] as double,
      totalAmount: fields[8] as double,
      paidAmount: fields[9] as double,
      remainingAmount: fields[10] as double,
      statusString: fields[11] as String,
      paymentMethod: fields[12] as String,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      notes: fields[15] as String?,
      paymentHistory: fields[16] != null ? (fields[16] as List).cast<PaymentRecordModel>() : const [],
      craftsmanId: fields[17] as String?,
      craftsmanName: fields[18] as String?,
      returnIds: fields[19] != null ? (fields[19] as List).cast<String>() : const [],
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.invoiceNumber)
      ..writeByte(2)
      ..write(obj.customerId)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.customerPhone)
      ..writeByte(5)
      ..write(obj.items)
      ..writeByte(6)
      ..write(obj.subtotal)
      ..writeByte(7)
      ..write(obj.discount)
      ..writeByte(8)
      ..write(obj.totalAmount)
      ..writeByte(9)
      ..write(obj.paidAmount)
      ..writeByte(10)
      ..write(obj.remainingAmount)
      ..writeByte(11)
      ..write(obj.statusString)
      ..writeByte(12)
      ..write(obj.paymentMethod)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.paymentHistory)
      ..writeByte(17)
      ..write(obj.craftsmanId)
      ..writeByte(18)
      ..write(obj.craftsmanName)
      ..writeByte(19)
      ..write(obj.returnIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
