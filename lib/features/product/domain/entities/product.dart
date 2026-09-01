import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price; // Selling Price (سعر البيع)
  final double costPrice; // Cost Price / Purchase Price (سعر الشراء / التكلفة)
  final int stock; // Optional implementation detail

  // Smart Recognition fields (all nullable for backward compatibility)
  final String? sku;
  final String? category;
  final String? brand;
  final String? size;
  final List<String> imagePaths;
  final List<double>? embedding;
  final String? ocrText;
  final int? pHash; // 64-bit perceptual hash for fast visual comparison

  // Pipe Management fields
  final bool isPipe;
  final String? pipeType; // 'pvc', 'copper', 'other'
  final double? fullLength; // in meters (e.g. 6.0 for PVC, 5.0 for copper, 4.0 for other)
  final double? fullPrice; // price of 1 full pipe
  final String? diameter; // e.g. '110', '50', 'Ø16'
  final String? origin; // e.g. 'الجزائر', 'فرنسا'
  final String? color; // e.g. 'أبيض', 'أسود', 'رمادي'

  // Description and Usage Instructions for AI assistant or catalog details
  final String? description;
  final String? usageInstructions;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.costPrice = 0.0,
    this.stock = 0,
    this.sku,
    this.category,
    this.brand,
    this.size,
    this.imagePaths = const [],
    this.embedding,
    this.ocrText,
    this.pHash,
    this.isPipe = false,
    this.pipeType,
    this.fullLength,
    this.fullPrice,
    this.diameter,
    this.origin,
    this.color,
    this.description,
    this.usageInstructions,
  });

  /// Calculates rate per meter for pipes
  double get calculatedPricePerMeter {
    if (isPipe && fullPrice != null && fullLength != null && fullLength! > 0) {
      return fullPrice! / fullLength!;
    }
    return price;
  }

  /// Calculates profit per unit/meter
  double get profitPerUnit => price - costPrice;

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? costPrice,
    int? stock,
    String? sku,
    String? category,
    String? brand,
    String? size,
    List<String>? imagePaths,
    List<double>? embedding,
    String? ocrText,
    int? pHash,
    bool? isPipe,
    String? pipeType,
    double? fullLength,
    double? fullPrice,
    String? diameter,
    String? origin,
    String? color,
    String? description,
    String? usageInstructions,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      imagePaths: imagePaths ?? this.imagePaths,
      embedding: embedding ?? this.embedding,
      ocrText: ocrText ?? this.ocrText,
      pHash: pHash ?? this.pHash,
      isPipe: isPipe ?? this.isPipe,
      pipeType: pipeType ?? this.pipeType,
      fullLength: fullLength ?? this.fullLength,
      fullPrice: fullPrice ?? this.fullPrice,
      diameter: diameter ?? this.diameter,
      origin: origin ?? this.origin,
      color: color ?? this.color,
      description: description ?? this.description,
      usageInstructions: usageInstructions ?? this.usageInstructions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        costPrice,
        stock,
        sku,
        category,
        brand,
        size,
        imagePaths,
        embedding,
        ocrText,
        pHash,
        isPipe,
        pipeType,
        fullLength,
        fullPrice,
        diameter,
        origin,
        color,
        description,
        usageInstructions,
      ];
}
