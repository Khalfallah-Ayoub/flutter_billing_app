import 'package:uuid/uuid.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/chat_message.dart';

class LocalAIChatService {
  static const _uuid = Uuid();

  /// Process worker query locally against product catalog
  static ChatMessage processQuery(String queryText, List<Product> products) {
    final cleanQuery = queryText.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return _buildGreetingResponse();
    }

    // 1. Check for Low Stock query
    if (_isLowStockQuery(cleanQuery)) {
      return _handleLowStockQuery(products);
    }

    // 2. Check for Custom Meter Calculation query
    final meterReq = _extractMeterCalculation(cleanQuery, products);
    if (meterReq != null) {
      return meterReq;
    }

    // 3. Check for Usage Instructions / Recommendation query
    if (_isUsageOrAdviceQuery(cleanQuery)) {
      return _handleUsageOrAdviceQuery(cleanQuery, products);
    }

    // 4. Default: Product Search & Pricing Lookup
    return _handleProductSearchQuery(cleanQuery, products);
  }

  static bool _isLowStockQuery(String q) {
    return q.contains('مخزون') ||
        q.contains('نفاد') ||
        q.contains('ينتهي') ||
        q.contains('قليل') ||
        q.contains('ناقص') ||
        q.contains('نفاذ') ||
        q.contains('stock') ||
        q.contains('low');
  }

  static ChatMessage _handleLowStockQuery(List<Product> products) {
    final lowStockItems = products.where((p) => p.stock <= 5).toList();
    lowStockItems.sort((a, b) => a.stock.compareTo(b.stock));

    if (lowStockItems.isEmpty) {
      return ChatMessage(
        id: _uuid.v4(),
        text: '✅ **المخزون بوضع ممتاز!**\nجميع المنتجات متوفرة بكميات كافية (أكثر من 5 قطع).',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('⚠️ **تنبيه المنتجات قريبة النفاد (${lowStockItems.length} منتج):**\n');
    for (final p in lowStockItems.take(5)) {
      final unit = p.isPipe ? 'أنبوب' : 'قطعة';
      sb.writeln('• **${p.name}**: متوفر فقط **${p.stock}** $unit (السعر: ${p.price} دج)');
    }

    if (lowStockItems.length > 5) {
      sb.writeln('\n...وهناك ${lowStockItems.length - 5} منتجات أخرى قريبة النفاد.');
    }

    return ChatMessage(
      id: _uuid.v4(),
      text: sb.toString().trim(),
      isUser: false,
      timestamp: DateTime.now(),
      relatedProducts: lowStockItems.take(5).toList(),
    );
  }

  static ChatMessage? _extractMeterCalculation(String q, List<Product> products) {
    final meterRegex = RegExp(r'(\d+(?:\.\d+)?)\*?\s*(?:متر|م|meters?|m)');
    final match = meterRegex.firstMatch(q);
    if (match == null) return null;

    final meters = double.tryParse(match.group(1) ?? '');
    if (meters == null || meters <= 0) return null;

    // Search for pipe product in query
    final pipeProducts = products.where((p) => p.isPipe).toList();
    final matchedPipe = _findBestMatchingProduct(q, pipeProducts.isNotEmpty ? pipeProducts : products);

    if (matchedPipe == null) {
      return ChatMessage(
        id: _uuid.v4(),
        text: '📏 لقد طلبت حساب **$meters متر**، لكن يرجى تحديد نوع الأنبوب أو مقياسه (مثلاً: احسب $meters متر PVC 110).',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final pricePerMeter = matchedPipe.calculatedPricePerMeter;
    final totalPrice = meters * pricePerMeter;

    final StringBuffer sb = StringBuffer();
    sb.writeln('📏 **حساب سعر القطع بالمتر:**');
    sb.writeln('• **المنتج:** ${matchedPipe.name}');
    sb.writeln('• **الطول المطلوب:** $meters متر');
    sb.writeln('• **سعر المتر التلقائي:** ${pricePerMeter.toStringAsFixed(2)} دج / متر');
    sb.writeln('-----------------------------------');
    sb.writeln('💰 **الإجمالي المطلوب:** **${totalPrice.toStringAsFixed(2)} دج**');

    return ChatMessage(
      id: _uuid.v4(),
      text: sb.toString(),
      isUser: false,
      timestamp: DateTime.now(),
      relatedProducts: [matchedPipe],
      quickActions: [
        ChatQuickAction(
          label: '✂️ قص وبيع ($metersم)',
          actionType: 'pipe_sale',
          product: matchedPipe,
        ),
      ],
    );
  }

  static bool _isUsageOrAdviceQuery(String q) {
    return q.contains('كيف') ||
        q.contains('طريقة') ||
        q.contains('استخدام') ||
        q.contains('استعمال') ||
        q.contains('تركيب') ||
        q.contains('تلحيم') ||
        q.contains('حرارة') ||
        q.contains('سخن') ||
        q.contains('ماء') ||
        q.contains('نصيحة') ||
        q.contains('أفضل') ||
        q.contains('افضل');
  }

  static ChatMessage _handleUsageOrAdviceQuery(String q, List<Product> products) {
    // Search for products that have descriptions or usage instructions or match topic
    final matchedProducts = products.where((p) {
      final name = p.name.toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      final usage = (p.usageInstructions ?? '').toLowerCase();
      final type = (p.pipeType ?? '').toLowerCase();
      final cat = (p.category ?? '').toLowerCase();

      final tokens = q.split(RegExp(r'\s+')).where((t) => t.length > 2);
      for (final t in tokens) {
        if (name.contains(t) || desc.contains(t) || usage.contains(t) || type.contains(t) || cat.contains(t)) {
          return true;
        }
      }
      return false;
    }).toList();

    if (matchedProducts.isEmpty) {
      // General advice fallback based on pipe types
      if (q.contains('سخن') || q.contains('حرارة') || q.contains('تدفئة')) {
        return ChatMessage(
          id: _uuid.v4(),
          text: '💡 **استشارة فنية (المياه الساخنة والتدفئة):**\n• يُنصح باستخدام **أنابيب النحاس (Copper)** أو **أنابيب PPR / PEX** المقاومة للحرارة والضغط العالي.\n• تجنّب استخدام PVC العادي للمياه الساخنة.',
          isUser: false,
          timestamp: DateTime.now(),
        );
      } else if (q.contains('صرف') || q.contains('بارد')) {
        return ChatMessage(
          id: _uuid.v4(),
          text: '💡 **استشارة فنية (المياه الباردة والصرف الصحي):**\n• أجهزة وأنابيب **PVC** بمقاييس (110 أو 75 أو 50) خيار مثالي للصرف والمياه الباردة.',
          isUser: false,
          timestamp: DateTime.now(),
        );
      }

      return ChatMessage(
        id: _uuid.v4(),
        text: '🔍 لم أجد تعليماً خافاً بهذا البحث في الكتالوج الحالي.\nيمكنك إضافة وصف أو تعليمات استخدام لأي منتج من صفحة التعديل ليتمكن المساعد من تذكرها.',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('💡 **نتائج الاستشارة وتوجيهات الاستعمال:**\n');

    for (final p in matchedProducts.take(3)) {
      sb.writeln('🔹 **${p.name}**:');
      if (p.description != null && p.description!.isNotEmpty) {
        sb.writeln('  • **الوصف:** ${p.description}');
      }
      if (p.usageInstructions != null && p.usageInstructions!.isNotEmpty) {
        sb.writeln('  • **طريقة الاستعمال:** ${p.usageInstructions}');
      } else {
        sb.writeln('  • **السعر:** ${p.price} دج (المخزون: ${p.stock})');
      }
      sb.writeln('');
    }

    return ChatMessage(
      id: _uuid.v4(),
      text: sb.toString().trim(),
      isUser: false,
      timestamp: DateTime.now(),
      relatedProducts: matchedProducts.take(3).toList(),
    );
  }

  static ChatMessage _handleProductSearchQuery(String q, List<Product> products) {
    if (products.isEmpty) {
      return ChatMessage(
        id: _uuid.v4(),
        text: '📦 **المخزن فارغ حالياً.**\nقم بإضافة منتجات أو أنابيب للبدء في الاستعلام عنها.',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final matches = _rankMatchingProducts(q, products);
    if (matches.isEmpty) {
      return ChatMessage(
        id: _uuid.v4(),
        text: '🔍 لم أجد أي منتج يطابق البحث "$q".\nتأكد من اسم المنتج، المقياس (مثلاً 110 أو 16)، أو خامة الأنبوب (PVC, نحاس).',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    final topProduct = matches.first;
    final StringBuffer sb = StringBuffer();

    if (topProduct.isPipe) {
      final pricePerMeter = topProduct.calculatedPricePerMeter;
      final fullLen = topProduct.fullLength ?? 6.0;
      final fullPrice = topProduct.fullPrice ?? topProduct.price;

      sb.writeln('🔍 **بيانات أنبوب ${topProduct.name}:**\n');
      sb.writeln('• **سعر الأنبوب الكامل (${fullLen}م):** ${fullPrice.toStringAsFixed(2)} دج');
      sb.writeln('• **سعر المتر التلقائي:** **${pricePerMeter.toStringAsFixed(2)} دج / متر**');
      sb.writeln('• **المخزون المتوفر:** ${topProduct.stock} أنبوب كامل');
      if (topProduct.diameter != null && topProduct.diameter!.isNotEmpty) {
        sb.writeln('• **المقياس:** Ø ${topProduct.diameter}');
      }
      if (topProduct.origin != null && topProduct.origin!.isNotEmpty) {
        sb.writeln('• **بلد الصنع:** ${topProduct.origin}');
      }
      if (topProduct.description != null && topProduct.description!.isNotEmpty) {
        sb.writeln('• **الوصف:** ${topProduct.description}');
      }
      if (topProduct.usageInstructions != null && topProduct.usageInstructions!.isNotEmpty) {
        sb.writeln('• **طريقة الاستعمال:** ${topProduct.usageInstructions}');
      }
    } else {
      sb.writeln('🔍 **تفاصيل المنتج ${topProduct.name}:**\n');
      sb.writeln('• **السعر:** **${topProduct.price.toStringAsFixed(2)} دج**');
      sb.writeln('• **المخزون:** ${topProduct.stock} قطعة');
      if (topProduct.barcode.isNotEmpty) {
        sb.writeln('• **الباركد:** `${topProduct.barcode}`');
      }
      if (topProduct.brand != null && topProduct.brand!.isNotEmpty) {
        sb.writeln('• **الماركة:** ${topProduct.brand}');
      }
      if (topProduct.description != null && topProduct.description!.isNotEmpty) {
        sb.writeln('• **الوصف:** ${topProduct.description}');
      }
      if (topProduct.usageInstructions != null && topProduct.usageInstructions!.isNotEmpty) {
        sb.writeln('• **طريقة الاستعمال:** ${topProduct.usageInstructions}');
      }
    }

    if (matches.length > 1) {
      sb.writeln('\n💡 *منتجات مشابهة أخرى:* ' +
          matches.skip(1).take(3).map((p) => p.name).join(' ، '));
    }

    return ChatMessage(
      id: _uuid.v4(),
      text: sb.toString().trim(),
      isUser: false,
      timestamp: DateTime.now(),
      relatedProducts: matches.take(3).toList(),
      quickActions: topProduct.isPipe
          ? [
              ChatQuickAction(
                label: '✂️ قص وبيع بالمتر',
                actionType: 'pipe_sale',
                product: topProduct,
              ),
            ]
          : null,
    );
  }

  static Product? _findBestMatchingProduct(String q, List<Product> products) {
    final matches = _rankMatchingProducts(q, products);
    return matches.isNotEmpty ? matches.first : null;
  }

  static List<Product> _rankMatchingProducts(String q, List<Product> products) {
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty) return [];

    final List<MapEntry<Product, double>> scored = [];

    for (final p in products) {
      final name = p.name.toLowerCase();
      final type = (p.pipeType ?? '').toLowerCase();
      final dia = (p.diameter ?? '').toLowerCase();
      final origin = (p.origin ?? '').toLowerCase();
      final color = (p.color ?? '').toLowerCase();
      final desc = (p.description ?? '').toLowerCase();
      final barcode = p.barcode.toLowerCase();

      double score = 0.0;
      for (final t in tokens) {
        if (name.contains(t)) score += 3.0;
        if (dia == t || dia.contains(t)) score += 2.5;
        if (type.contains(t)) score += 2.0;
        if (origin.contains(t)) score += 1.5;
        if (color.contains(t)) score += 1.0;
        if (barcode == t) score += 4.0;
        if (desc.contains(t)) score += 1.0;
      }

      if (score > 0) {
        scored.add(MapEntry(p, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  static ChatMessage _buildGreetingResponse() {
    return ChatMessage(
      id: _uuid.v4(),
      text: '''🤖 **مرحباً بك! أنا مساعد المحل الذكي (أوفلاين 100%):**

يمكنك سؤالي فوراً عن أي مما يلي:
• **الأسعار والمخزون:** *"كم سعر أنبوب PVC 110؟"* أو *"ما هو سعر المتر للنحاس؟"*
• **حساب الأطوال بالمتر:** *"احسب لي 2.5 متر أنبوب PVC 50"*
• **استشارات واستعمال المواد:** *"ماذا أستخدم للمياه الساخنة والتدفئة؟"*
• **تنبيهات المخزون:** *"أعطني المنتجات قريبة النفاد"*''',
      isUser: false,
      timestamp: DateTime.now(),
    );
  }
}
