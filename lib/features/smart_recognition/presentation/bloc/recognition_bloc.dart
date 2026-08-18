import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/ocr_service.dart';
import '../../data/services/embedding_service.dart';
import '../../data/services/ranking_service.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/entities/ranked_product.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/data/models/product_model.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/image_storage_service.dart';

part 'recognition_event.dart';
part 'recognition_state.dart';

class RecognitionBloc extends Bloc<RecognitionEvent, RecognitionState> {
  final OcrService ocrService;
  final EmbeddingService embeddingService;
  final RankingService rankingService;
  final ImageStorageService imageStorageService;

  RecognitionBloc({
    required this.ocrService,
    required this.embeddingService,
    required this.rankingService,
    required this.imageStorageService,
  }) : super(const RecognitionState()) {
    on<RecognizeFromImage>(_onRecognize);
    on<ConfirmRecognition>(_onConfirm);
    on<RejectRecognition>(_onReject);
    on<ResetRecognition>(_onReset);
  }

  Future<void> _onRecognize(
    RecognizeFromImage event,
    Emitter<RecognitionState> emit,
  ) async {
    emit(state.copyWith(
      status: RecognitionStatus.processing,
      processedImagePath: event.imagePath,
    ));

    try {
      // 1. Get all products from DB
      final allProducts = HiveDatabase.productBox.values
          .map((m) => m.toEntity())
          .toList();

      if (allProducts.isEmpty) {
        emit(state.copyWith(
          status: RecognitionStatus.error,
          errorMessage: 'No products in database. Add products first.',
        ));
        return;
      }

      // 2. Run OCR on the image
      final ocrResult = await ocrService.extractText(event.imagePath);

      // 3. Detect brand from known products
      final ocrWithBrand =
          ocrService.detectBrandFromProducts(ocrResult, allProducts);

      // 4. Generate embedding (may be null on web or failure)
      final embedding =
          await embeddingService.generateEmbedding(event.imagePath);

      // 5. Rank all products using multi-signal engine
      final rankedResults = rankingService.rankCandidates(
        ocrResult: ocrWithBrand,
        queryEmbedding: embedding,
        allProducts: allProducts,
        topK: 5,
      );

      if (rankedResults.isEmpty) {
        emit(state.copyWith(
          status: RecognitionStatus.success,
          results: [],
          ocrResult: ocrWithBrand,
          errorMessage: 'No matching products found.',
        ));
      } else {
        emit(state.copyWith(
          status: RecognitionStatus.success,
          results: rankedResults,
          ocrResult: ocrWithBrand,
          errorMessage: null,
        ));
      }
    } catch (e) {
      debugPrint('RecognitionBloc: error: $e');
      emit(state.copyWith(
        status: RecognitionStatus.error,
        errorMessage: 'Recognition failed: $e',
      ));
    }
  }

  Future<void> _onConfirm(
    ConfirmRecognition event,
    Emitter<RecognitionState> emit,
  ) async {
    try {
      // Save the image for this product
      String? savedPath;
      if (!kIsWeb) {
        savedPath = await imageStorageService.saveProductImage(
          event.confirmedProduct.id,
          File(event.imagePath),
        );
      }

      // Update product with new image and OCR text
      final existingModel =
          HiveDatabase.productBox.get(event.confirmedProduct.id);
      if (existingModel != null) {
        final updatedPaths = List<String>.from(existingModel.imagePaths);
        if (savedPath != null && updatedPaths.length < 3) {
          updatedPaths.add(savedPath);
        }

        final ocrText = state.ocrResult?.fullText;
        final updatedModel = ProductModel(
          id: existingModel.id,
          name: existingModel.name,
          barcode: existingModel.barcode,
          price: existingModel.price,
          stock: existingModel.stock,
          sku: existingModel.sku,
          category: existingModel.category,
          brand: existingModel.brand,
          size: existingModel.size,
          imagePaths: updatedPaths,
          embedding: existingModel.embedding,
          ocrText: ocrText ?? existingModel.ocrText,
        );

        await HiveDatabase.productBox.put(existingModel.id, updatedModel);
      }

      // Save feedback record
      await HiveDatabase.feedbackBox.add({
        'productId': event.confirmedProduct.id,
        'imagePath': savedPath ?? event.imagePath,
        'action': 'confirmed',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('RecognitionBloc: confirm feedback error: $e');
    }

    emit(const RecognitionState()); // Reset
  }

  Future<void> _onReject(
    RejectRecognition event,
    Emitter<RecognitionState> emit,
  ) async {
    try {
      await HiveDatabase.feedbackBox.add({
        'productId': event.manualProduct.id,
        'imagePath': event.imagePath,
        'action': 'corrected',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('RecognitionBloc: reject feedback error: $e');
    }

    emit(const RecognitionState()); // Reset
  }

  void _onReset(
    ResetRecognition event,
    Emitter<RecognitionState> emit,
  ) {
    emit(const RecognitionState());
  }
}
