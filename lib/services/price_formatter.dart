// lib/utils/price_formatter.dart
// Shared utility for consistent price formatting across the app

class PriceFormatter {
  static String format(double price) {
    if (price <= 0) {
      return '0';
    }

    double roundedPrice = double.parse(price.toStringAsFixed(2));

    if (roundedPrice == roundedPrice.toInt()) {
      return roundedPrice.toInt().toString();
    }

    String formatted = roundedPrice.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');

    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    return formatted;
  }

  static String formatCurrency(double price) {
    return '₹${format(price)}';
  }

  static double parseSafely(String? value, {double defaultValue = 0.0}) {
    if (value == null || value.isEmpty) return defaultValue;
    try {
      return double.parse(value);
    } catch (e) {
      return defaultValue;
    }
  }

  static bool isValidAmount(double amount) {
    return amount > 0 && amount.isFinite && !amount.isNaN;
  }
}