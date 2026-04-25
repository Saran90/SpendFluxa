import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

enum AppCurrency { inr, usd, eur, gbp }

extension AppCurrencyExtension on AppCurrency {
  String get symbol {
    switch (this) {
      case AppCurrency.inr:
        return '₹';
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.gbp:
        return '£';
    }
  }

  String get code {
    switch (this) {
      case AppCurrency.inr:
        return 'INR';
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.gbp:
        return 'GBP';
    }
  }

  String get name {
    switch (this) {
      case AppCurrency.inr:
        return 'Indian Rupee';
      case AppCurrency.usd:
        return 'US Dollar';
      case AppCurrency.eur:
        return 'Euro';
      case AppCurrency.gbp:
        return 'British Pound';
    }
  }

  String get flag {
    switch (this) {
      case AppCurrency.inr:
        return '🇮🇳';
      case AppCurrency.usd:
        return '🇺🇸';
      case AppCurrency.eur:
        return '🇪🇺';
      case AppCurrency.gbp:
        return '🇬🇧';
    }
  }

  NumberFormat get formatter =>
      NumberFormat.currency(symbol: symbol, decimalDigits: 2);
}

/// Holds the full metadata for a currency row from the DB.
class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String flag;
  final bool isBuiltin;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
    required this.isBuiltin,
  });
}

class CurrencyService extends ChangeNotifier {
  static const _prefKey = 'selected_currency';

  AppCurrency _current = AppCurrency.inr;

  /// All currencies available in the DB (built-in + any future custom ones).
  List<CurrencyInfo> _allCurrencies = [];

  AppCurrency get current => _current;
  NumberFormat get formatter => _current.formatter;
  String get symbol => _current.symbol;
  String get code => _current.code;
  List<CurrencyInfo> get allCurrencies => List.unmodifiable(_allCurrencies);

  CurrencyService() {
    _load();
  }

  Future<void> _load() async {
    // Load selected currency from prefs (lightweight, no DB needed)
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _current = AppCurrency.values.firstWhere(
        (c) => c.name == saved,
        orElse: () => AppCurrency.inr,
      );
    }

    // Load full currency list from DB
    try {
      final rows = await AppDatabase.instance.query(
        'currencies',
        orderBy: 'name ASC',
      );
      _allCurrencies = rows
          .map(
            (r) => CurrencyInfo(
              code: r['code'] as String,
              name: r['name'] as String,
              symbol: r['symbol'] as String,
              flag: r['flag'] as String,
              isBuiltin: (r['is_builtin'] as int) == 1,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[CurrencyService] load error: $e');
    }

    notifyListeners();
  }

  Future<void> setCurrency(AppCurrency currency) async {
    if (_current == currency) return;
    _current = currency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency.name);
  }
}
