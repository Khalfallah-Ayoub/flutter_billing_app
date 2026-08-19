import 'package:equatable/equatable.dart';

/// A record of a smart recognition event for learning/improvement.
class FeedbackRecord extends Equatable {
  /// Path to the query image
  final String queryImagePath;

  /// Product ID suggested by the AI (top match)
  final String? suggestedProductId;

  /// Product ID actually selected by the user
  final String selectedProductId;

  /// Confidence score of the AI suggestion (0.0-1.0)
  final double confidence;

  /// Whether the user confirmed the top suggestion or corrected it
  final bool wasCorrect;

  /// Timestamp of the event
  final DateTime timestamp;

  const FeedbackRecord({
    required this.queryImagePath,
    this.suggestedProductId,
    required this.selectedProductId,
    required this.confidence,
    required this.wasCorrect,
    required this.timestamp,
  });

  /// Convert to a Map for Hive storage
  Map<String, dynamic> toMap() => {
        'queryImagePath': queryImagePath,
        'suggestedProductId': suggestedProductId,
        'selectedProductId': selectedProductId,
        'confidence': confidence,
        'wasCorrect': wasCorrect,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Create from a Hive Map
  factory FeedbackRecord.fromMap(Map<dynamic, dynamic> map) => FeedbackRecord(
        queryImagePath: map['queryImagePath'] as String? ?? '',
        suggestedProductId: map['suggestedProductId'] as String?,
        selectedProductId: map['selectedProductId'] as String? ?? '',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
        wasCorrect: map['wasCorrect'] as bool? ?? false,
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [
        queryImagePath,
        suggestedProductId,
        selectedProductId,
        confidence,
        wasCorrect,
        timestamp,
      ];
}
