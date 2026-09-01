// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      barcode: fields[2] as String,
      price: fields[3] as double,
      stock: fields[4] as int,
      sku: fields[5] as String?,
      category: fields[6] as String?,
      brand: fields[7] as String?,
      size: fields[8] as String?,
      imagePaths: (fields[9] as List).cast<String>(),
      embedding: (fields[10] as List?)?.cast<double>(),
      ocrText: fields[11] as String?,
      isPipe: fields[12] as bool? ?? false,
      pipeType: fields[13] as String?,
      fullLength: (fields[14] as num?)?.toDouble(),
      fullPrice: (fields[15] as num?)?.toDouble(),
      diameter: fields[16] as String?,
      origin: fields[17] as String?,
      color: fields[18] as String?,
      description: fields[19] as String?,
      usageInstructions: fields[20] as String?,
      costPrice: (fields[21] as num?)?.toDouble() ?? 0.0,
      pHash: fields[22] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.stock)
      ..writeByte(5)
      ..write(obj.sku)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.brand)
      ..writeByte(8)
      ..write(obj.size)
      ..writeByte(9)
      ..write(obj.imagePaths)
      ..writeByte(10)
      ..write(obj.embedding)
      ..writeByte(11)
      ..write(obj.ocrText)
      ..writeByte(12)
      ..write(obj.isPipe)
      ..writeByte(13)
      ..write(obj.pipeType)
      ..writeByte(14)
      ..write(obj.fullLength)
      ..writeByte(15)
      ..write(obj.fullPrice)
      ..writeByte(16)
      ..write(obj.diameter)
      ..writeByte(17)
      ..write(obj.origin)
      ..writeByte(18)
      ..write(obj.color)
      ..writeByte(19)
      ..write(obj.description)
      ..writeByte(20)
      ..write(obj.usageInstructions)
      ..writeByte(21)
      ..write(obj.costPrice)
      ..writeByte(22)
      ..write(obj.pHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
