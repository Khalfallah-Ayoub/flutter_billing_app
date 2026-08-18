part of 'recognition_bloc.dart';

enum RecognitionStatus { idle, processing, success, error }

class RecognitionState extends Equatable {
  final RecognitionStatus status;
  final List<RankedProduct> results;
  final OcrResult? ocrResult;
  final String? errorMessage;
  final String? processedImagePath;

  const RecognitionState({
    this.status = RecognitionStatus.idle,
    this.results = const [],
    this.ocrResult,
    this.errorMessage,
    this.processedImagePath,
  });

  RecognitionState copyWith({
    RecognitionStatus? status,
    List<RankedProduct>? results,
    OcrResult? ocrResult,
    String? errorMessage,
    String? processedImagePath,
  }) {
    return RecognitionState(
      status: status ?? this.status,
      results: results ?? this.results,
      ocrResult: ocrResult ?? this.ocrResult,
      errorMessage: errorMessage ?? this.errorMessage,
      processedImagePath: processedImagePath ?? this.processedImagePath,
    );
  }

  @override
  List<Object?> get props =>
      [status, results, ocrResult, errorMessage, processedImagePath];
}
