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

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.sku,
    this.category,
    this.brand,
    this.size,
    this.imagePaths = const [],
    this.embedding,
    this.ocrText,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          sku: sku,
          category: category,
          brand: brand,
          size: size,
          imagePaths: imagePaths,
          embedding: embedding,
          ocrText: ocrText,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      sku: product.sku,
      category: product.category,
      brand: product.brand,
      size: product.size,
      imagePaths: product.imagePaths,
      embedding: product.embedding,
      ocrText: product.ocrText,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      sku: sku,
      category: category,
      brand: brand,
      size: size,
      imagePaths: imagePaths,
      embedding: embedding,
      ocrText: ocrText,
    );
  }
}
