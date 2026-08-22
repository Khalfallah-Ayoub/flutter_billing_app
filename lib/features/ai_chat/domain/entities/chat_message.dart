import '../../../product/domain/entities/product.dart';

class ChatQuickAction {
  final String label;
  final String actionType; // 'pipe_sale', 'view_product', 'calculator'
  final Product? product;

  const ChatQuickAction({
    required this.label,
    required this.actionType,
    this.product,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Product>? relatedProducts;
  final List<ChatQuickAction>? quickActions;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.relatedProducts,
    this.quickActions,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<Product>? relatedProducts,
    List<ChatQuickAction>? quickActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      relatedProducts: relatedProducts ?? this.relatedProducts,
      quickActions: quickActions ?? this.quickActions,
    );
  }
}
