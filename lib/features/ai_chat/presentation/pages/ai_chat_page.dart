import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/services/local_ai_chat_service.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _addInitialGreeting();
  }

  void _addInitialGreeting() {
    _messages.add(
      ChatMessage(
        id: _uuid.v4(),
        text: '''👋 **أهلاً بك يا بطل! أنا مساعد المحل الذكي (أوفلاين 100%):**

كيف يمكنني مساعدتك اليوم؟
• **الأسعار والمخزون:** *"كم سعر أنبوب PVC 110؟"*
• **حساب أطوال بالتقطيع:** *"احسب 2.5 متر أنبوب نحاس"*
• **استشارات فنية:** *"ماذا نستخدم للمياه الساخنة والتدفئة؟"*
• **متابعة المخزن:** *"ما هي المنتجات قريبة النفاد؟"*''',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _handleSendMessage([String? predefinedText]) {
    final text = predefinedText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (predefinedText == null) {
      _inputController.clear();
    }

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
    });

    _scrollToBottom();

    // Process locally with ProductBloc products state
    final products = context.read<ProductBloc>().state.products;

    Future.delayed(const Duration(milliseconds: 250), () {
      final aiResponse = LocalAIChatService.processQuery(text, products);
      if (mounted) {
        setState(() {
          _messages.add(aiResponse);
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المساعد الذكي (AI Chat)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'يعمل محلياً (Offline 100%)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, size: 28, color: theme.primaryColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Quick Suggestion Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSuggestionChip('🔍 PVC 110'),
                  const SizedBox(width: 6),
                  _buildSuggestionChip('📏 احسب 2.5 متر نحاس 16'),
                  const SizedBox(width: 6),
                  _buildSuggestionChip('💡 ماذا نستخدم للمياه الساخنة؟'),
                  const SizedBox(width: 6),
                  _buildSuggestionChip('⚠️ المنتجات قريبة النفاد'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg, isDark);
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText: 'اسأل عن سعر، مقياس، نصيحة تركيب...',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _handleSendMessage(),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () => _handleSendMessage(text),
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isDark) {
    final theme = Theme.of(context);

    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    // AI Response Bubble
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: const Icon(Icons.smart_toy, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (msg.quickActions != null && msg.quickActions!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: msg.quickActions!.map((act) {
                              return ElevatedButton.icon(
                                onPressed: () {
                                  if (act.actionType == 'pipe_sale' && act.product != null) {
                                    context.push('/pipe-sales', extra: act.product);
                                  }
                                },
                                icon: const Icon(Icons.content_cut, size: 16),
                                label: Text(act.label),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
