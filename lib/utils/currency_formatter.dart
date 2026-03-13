import 'package:intl/intl.dart';

/// Shared currency formatter for the PIMS DepED app.
/// Formats numbers with Philippine Peso symbol, comma digit grouping,
/// and 2 decimal places. Example: 1000000 → ₱1,000,000.00
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat('#,##0.00', 'en_US');

  /// Formats a double as ₱1,234,567.89
  static String format(double amount) {
    return '₱${_formatter.format(amount)}';
  }

  /// Formats without the peso sign — useful for input hints or plain numbers.
  static String formatPlain(double amount) {
    return _formatter.format(amount);
  }
}
