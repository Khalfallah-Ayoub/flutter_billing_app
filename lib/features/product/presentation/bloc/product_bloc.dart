import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/product_usecases.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/data/hive_database.dart';
import '../../../smart_recognition/data/services/embedding_service.dart';
import '../../data/models/product_model.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final GetProductsUseCase getProductsUseCase;
  final AddProductUseCase addProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final EmbeddingService? embeddingService;

  ProductBloc({
    required this.getProductsUseCase,
    required this.addProductUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
    this.embeddingService,
  }) : super(const ProductState()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }

  Future<void> _onLoadProducts(
      LoadProducts event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await getProductsUseCase(NoParams());
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (products) => emit(
          state.copyWith(status: ProductStatus.loaded, products: products)),
    );
  }

  Future<void> _onAddProduct(
      AddProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await addProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product added successfully'));
        add(LoadProducts());
        // Auto-generate embedding in background
        _autoGenerateEmbedding(event.product);
      },
    );
  }

  Future<void> _onUpdateProduct(
      UpdateProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await updateProductUseCase(event.product);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product updated successfully'));
        add(LoadProducts());
        // Auto-generate embedding in background
        _autoGenerateEmbedding(event.product);
      },
    );
  }

  Future<void> _onDeleteProduct(
      DeleteProduct event, Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ProductStatus.loading));
    final result = await deleteProductUseCase(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
          status: ProductStatus.error, message: failure.message)),
      (_) {
        emit(state.copyWith(
            status: ProductStatus.success,
            message: 'Product deleted successfully'));
        add(LoadProducts());
      },
    );
  }

  /// Background auto-embedding: if a product has images but no embedding,
  /// generate one silently. This improves future smart recognition accuracy.
  Future<void> _autoGenerateEmbedding(Product product) async {
    if (kIsWeb) return; // Not supported on web
    if (embeddingService == null) return;
    if (product.imagePaths.isEmpty) return;
    if (product.embedding != null && product.embedding!.isNotEmpty) return;

    try {
      final imagePath = product.imagePaths.first;
      final embedding =
          await embeddingService!.generateEmbedding(imagePath);
      if (embedding != null && embedding.isNotEmpty) {
        final existingModel = HiveDatabase.productBox.get(product.id);
        if (existingModel != null) {
          // Use fromEntity to preserve ALL fields, then set embedding
          final updatedModel = ProductModel.fromEntity(
            existingModel.toEntity().copyWith(embedding: embedding),
          );
          await HiveDatabase.productBox.put(existingModel.id, updatedModel);
          debugPrint(
              'Auto-embedding generated for product: ${product.name}');
        }
      }
    } catch (e) {
      debugPrint('Auto-embedding failed for ${product.name}: $e');
    }
  }
}
