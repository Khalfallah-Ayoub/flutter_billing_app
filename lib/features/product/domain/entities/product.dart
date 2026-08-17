import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock; // Optional implementation detail

  // Smart Recognition fields (all nullable for backward compatibility)
  final String? sku;
  final String? category;
  final String? brand;
  final String? size;
  final List<String> imagePaths;
  final List<double>? embedding;
  final String? ocrText;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.sku,
    this.category,
    this.brand,
    this.size,
    this.imagePaths = const [],
    this.embedding,
    this.ocrText,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    String? sku,
    String? category,
    String? brand,
    String? size,
    List<String>? imagePaths,
    List<double>? embedding,
    String? ocrText,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      imagePaths: imagePaths ?? this.imagePaths,
      embedding: embedding ?? this.embedding,
      ocrText: ocrText ?? this.ocrText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        stock,
        sku,
        category,
        brand,
        size,
        imagePaths,
        embedding,
        ocrText,
      ];
}
