import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final int stock;

  // Smart Recognition fields
  @override
  @HiveField(5)
  final String? sku;
  @override
  @HiveField(6)
  final String? category;
  @override
  @HiveField(7)
  final String? brand;
  @override
  @HiveField(8)
  final String? size;
  @override
  @HiveField(9)
  final List<String> imagePaths;
  @override
  @HiveField(10)
  final List<double>? embedding;
  @override
  @HiveField(11)
  final String? ocrText;

  // Pipe fields
  @override
  @HiveField(12)
  final bool isPipe;
  @override
  @HiveField(13)
  final String? pipeType;
  @override
  @HiveField(14)
  final double? fullLength;
  @override
  @HiveField(15)
  final double? fullPrice;
  @override
  @HiveField(16)
  final String? diameter;
  @override
  @HiveField(17)
  final String? origin;
  @override
  @HiveField(18)
  final String? color;

  @override
  @HiveField(19)
  final String? description;

  @override
  @HiveField(20)
  final String? usageInstructions;

  @override
  @HiveField(21)
  final double costPrice;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    required this.stock,
    this.sku,
    this.category,
    this.brand,
    this.size,
    this.imagePaths = const [],
    this.embedding,
    this.ocrText,
    this.isPipe = false,
    this.pipeType,
    this.fullLength,
    this.fullPrice,
    this.diameter,
    this.origin,
    this.color,
    this.description,
    this.usageInstructions,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          costPrice: costPrice,
          stock: stock,
          sku: sku,
          category: category,
          brand: brand,
          size: size,
          imagePaths: imagePaths,
          embedding: embedding,
          ocrText: ocrText,
          isPipe: isPipe,
          pipeType: pipeType,
          fullLength: fullLength,
          fullPrice: fullPrice,
          diameter: diameter,
          origin: origin,
          color: color,
          description: description,
          usageInstructions: usageInstructions,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      costPrice: product.costPrice,
      stock: product.stock,
      sku: product.sku,
      category: product.category,
      brand: product.brand,
      size: product.size,
      imagePaths: product.imagePaths,
      embedding: product.embedding,
      ocrText: product.ocrText,
      isPipe: product.isPipe,
      pipeType: product.pipeType,
      fullLength: product.fullLength,
      fullPrice: product.fullPrice,
      diameter: product.diameter,
      origin: product.origin,
      color: product.color,
      description: product.description,
      usageInstructions: product.usageInstructions,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      costPrice: costPrice,
      stock: stock,
      sku: sku,
      category: category,
      brand: brand,
      size: size,
      imagePaths: imagePaths,
      embedding: embedding,
      ocrText: ocrText,
      isPipe: isPipe,
      pipeType: pipeType,
      fullLength: fullLength,
      fullPrice: fullPrice,
      diameter: diameter,
      origin: origin,
      color: color,
      description: description,
      usageInstructions: usageInstructions,
    );
  }

  /// Serialize to JSON Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'costPrice': costPrice,
      'stock': stock,
      'sku': sku,
      'category': category,
      'brand': brand,
      'size': size,
      'imagePaths': imagePaths,
      'embedding': embedding,
      'ocrText': ocrText,
      'isPipe': isPipe,
      'pipeType': pipeType,
      'fullLength': fullLength,
      'fullPrice': fullPrice,
      'diameter': diameter,
      'origin': origin,
      'color': color,
      'description': description,
      'usageInstructions': usageInstructions,
    };
  }

  /// Deserialize from JSON Map
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      sku: map['sku'] as String?,
      category: map['category'] as String?,
      brand: map['brand'] as String?,
      size: map['size'] as String?,
      imagePaths: (map['imagePaths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      embedding: (map['embedding'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      ocrText: map['ocrText'] as String?,
      isPipe: map['isPipe'] as bool? ?? false,
      pipeType: map['pipeType'] as String?,
      fullLength: (map['fullLength'] as num?)?.toDouble(),
      fullPrice: (map['fullPrice'] as num?)?.toDouble(),
      diameter: map['diameter'] as String?,
      origin: map['origin'] as String?,
      color: map['color'] as String?,
      description: map['description'] as String?,
      usageInstructions: map['usageInstructions'] as String?,
    );
  }
}
