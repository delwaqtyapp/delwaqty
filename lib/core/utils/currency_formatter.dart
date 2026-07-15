import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static String format(double amount, {String currencyCode = 'USD'}) {
    final formatter = NumberFormat.currency(
      locale: 'en',
      symbol: _symbolFor(currencyCode),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currencyCode = 'USD'}) {
    final symbol = _symbolFor(currencyCode);
    if (amount.abs() >= 1000000000) {
      return '$symbol${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static String formatWithPrefix(double amount, {String currencyCode = 'USD'}) {
    final prefix = amount >= 0 ? '+' : '-';
    return '$prefix${format(amount.abs(), currencyCode: currencyCode)}';
  }

  static String _symbolFor(String code) {
    return switch (code) {
      'SAR' => 'ر.س ',
      'USD' => r'$',
      'EUR' => '€',
      'AED' => 'د.إ ',
      _ => '$code ',
    };
  }
}
