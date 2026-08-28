import 'dart:math';

/// Provides fuzzy matching for product search.
/// Allows typo tolerance and approximate matching.
class FuzzySearch {
  /// Search products by matching query against name, brand, category, barcode.
  /// Returns a sorted list of (product index, score) pairs.
  /// Score: 0.0 = no match, 1.0 = perfect match.
  static List<MapEntry<int, double>> search<T>({
    required String query,
    required List<T> items,
    required List<String> Function(T item) getSearchableFields,
    double threshold = 0.25,
    int maxResults = 10,
  }) {
    if (query.trim().isEmpty) return [];

    final queryLower = query.toLowerCase().trim();
    final queryWords = queryLower.split(RegExp(r'\s+'));
    final results = <MapEntry<int, double>>[];

    for (int i = 0; i < items.length; i++) {
      final fields = getSearchableFields(items[i]);
      final combined = fields.join(' ').toLowerCase();

      double totalScore = 0.0;

      for (final word in queryWords) {
        double bestWordScore = 0.0;

        // 1. Exact containment (highest weight)
        if (combined.contains(word)) {
          bestWordScore = 1.0;
        } else {
          // 2. Fuzzy match against individual field words
          final fieldWords = combined.split(RegExp(r'[\s,.\-/()[\]]+'));
          for (final fw in fieldWords) {
            if (fw.isEmpty) continue;
            final sim = _similarity(word, fw);
            if (sim > bestWordScore) bestWordScore = sim;
          }
        }

        totalScore += bestWordScore;
      }

      final avgScore = totalScore / queryWords.length;

      if (avgScore >= threshold) {
        results.add(MapEntry(i, avgScore));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.value.compareTo(a.value));

    return results.take(maxResults).toList();
  }

  /// Calculates similarity between two strings using a combination of:
  /// 1. Levenshtein distance (edit distance)
  /// 2. Common prefix bonus
  /// Returns 0.0 to 1.0
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Starts-with bonus
    if (b.startsWith(a) || a.startsWith(b)) {
      return 0.9;
    }

    // Contains bonus
    if (b.contains(a) || a.contains(b)) {
      return 0.85;
    }

    // Levenshtein distance
    final distance = _levenshtein(a, b);
    final maxLen = max(a.length, b.length);
    final normalized = 1.0 - (distance / maxLen);

    // Common prefix bonus
    int prefixLen = 0;
    final minLen = min(a.length, b.length);
    for (int i = 0; i < minLen; i++) {
      if (a[i] == b[i]) {
        prefixLen++;
      } else {
        break;
      }
    }
    final prefixBonus = prefixLen / maxLen * 0.15;

    return (normalized + prefixBonus).clamp(0.0, 1.0);
  }

  /// Standard Levenshtein distance algorithm.
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Optimization: use single-row DP
    var previousRow = List<int>.generate(b.length + 1, (i) => i);

    for (int i = 0; i < a.length; i++) {
      final currentRow = List<int>.filled(b.length + 1, 0);
      currentRow[0] = i + 1;

      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        currentRow[j + 1] = [
          currentRow[j] + 1,      // insertion
          previousRow[j + 1] + 1, // deletion
          previousRow[j] + cost,  // substitution
        ].reduce(min);
      }

      previousRow = currentRow;
    }

    return previousRow[b.length];
  }
}
