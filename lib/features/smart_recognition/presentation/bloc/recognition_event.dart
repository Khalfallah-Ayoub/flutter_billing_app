part of 'recognition_bloc.dart';

abstract class RecognitionEvent extends Equatable {
  const RecognitionEvent();

  @override
  List<Object?> get props => [];
}

/// User triggered smart recognition from an image
class RecognizeFromImage extends RecognitionEvent {
  final String imagePath;
  const RecognizeFromImage(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

/// User selected a product from the recognition results
class ConfirmRecognition extends RecognitionEvent {
  final Product confirmedProduct;
  final String imagePath;
  const ConfirmRecognition(this.confirmedProduct, this.imagePath);

  @override
  List<Object?> get props => [confirmedProduct, imagePath];
}

/// User rejected all results and manually selected a product
class RejectRecognition extends RecognitionEvent {
  final Product manualProduct;
  final String imagePath;
  const RejectRecognition(this.manualProduct, this.imagePath);

  @override
  List<Object?> get props => [manualProduct, imagePath];
}

/// Reset recognition state
class ResetRecognition extends RecognitionEvent {
  const ResetRecognition();
}
