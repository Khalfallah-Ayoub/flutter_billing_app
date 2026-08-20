/// Central app constants for currency, branding, etc.
class AppConstants {
  static const String currencySymbol = 'د.ج';
  static const String currencyCode = 'DZD';

  /// Format a price with the Algerian Dinar symbol.
  /// Example: 350.00 → '350.00 د.ج'
  static String formatPrice(double price) =>
      '${price.toStringAsFixed(2)} $currencySymbol';
}
