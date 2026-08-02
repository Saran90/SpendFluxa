/// Parses currency amounts from natural language (INR).
class AmountParser {
  static final RegExp _currencyPattern = RegExp(
    r'(?:₹|INR|Rs\.?|rs\.?|rupees?)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _bareAmountPattern = RegExp(
    r'\b([\d,]+(?:\.\d{1,2})?)\s*(?:₹|INR|Rs\.?|rs\.?|rupees?)\b',
    caseSensitive: false,
  );

  static final RegExp _standalonePattern = RegExp(
    r'\b([\d,]+(?:\.\d{1,2})?)\b',
  );

  /// Returns parsed amount and confidence (0.0–1.0).
  static ({double? amount, double confidence}) parse(String text) {
    for (final pattern in [_currencyPattern, _bareAmountPattern]) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = _parseNumber(match.group(1)!);
        if (value != null && value > 0) {
          return (amount: value, confidence: 0.95);
        }
      }
    }

    // Fallback: largest number in text (lower confidence)
    final numbers = _standalonePattern
        .allMatches(text)
        .map((m) => _parseNumber(m.group(1)!))
        .whereType<double>()
        .where((n) => n >= 10)
        .toList();

    if (numbers.isEmpty) {
      return (amount: null, confidence: 0.0);
    }

    numbers.sort();
    return (amount: numbers.last, confidence: 0.75);
  }

  static double? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  /// Formats amount in Indian numbering system.
  static String formatInr(double amount) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final parts = abs.toStringAsFixed(abs == abs.roundToDouble() ? 0 : 2);
    final split = parts.split('.');
    final intPart = split[0];
    final decPart = split.length > 1 ? split[1] : null;

    final formatted = _formatIndian(intPart);
    final suffix = decPart != null && decPart != '00' ? '.$decPart' : '';
    return '${isNegative ? '-' : ''}₹$formatted$suffix';
  }

  static String _formatIndian(String digits) {
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$lastThree';
  }
}
