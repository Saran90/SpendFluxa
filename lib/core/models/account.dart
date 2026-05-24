import 'package:flutter/material.dart';
import 'credit_card_config.dart';

enum AccountType { bank, creditCard, wallet, cash, savings }

extension AccountTypeExtension on AccountType {
  String get label {
    switch (this) {
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.cash:
        return 'Cash';
      case AccountType.savings:
        return 'Savings';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.bank:
        return Icons.account_balance_rounded;
      case AccountType.creditCard:
        return Icons.credit_card_rounded;
      case AccountType.wallet:
        return Icons.account_balance_wallet_rounded;
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.savings:
        return Icons.savings_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AccountType.bank:
        return const Color(0xFF3498DB);
      case AccountType.creditCard:
        return const Color(0xFFE74C3C);
      case AccountType.wallet:
        return const Color(0xFF9B59B6);
      case AccountType.cash:
        return const Color(0xFF2D9E6B);
      case AccountType.savings:
        return const Color(0xFFFF9800);
    }
  }

  // Gradient used on the card face
  List<Color> get gradientColors {
    switch (this) {
      case AccountType.bank:
        return [const Color(0xFF2980B9), const Color(0xFF1A5276)];
      case AccountType.creditCard:
        return [const Color(0xFFC0392B), const Color(0xFF7B241C)];
      case AccountType.wallet:
        return [const Color(0xFF8E44AD), const Color(0xFF5B2C6F)];
      case AccountType.cash:
        return [const Color(0xFF27AE60), const Color(0xFF1A6B3C)];
      case AccountType.savings:
        return [const Color(0xFFE67E22), const Color(0xFF935116)];
    }
  }
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance; // outstanding for credit cards
  final double? creditLimit; // credit cards only
  final int? billDate; // day of month (1–31), credit cards only
  final String? lastFourDigits;
  final Color color;
  final bool isDefault;
  final CreditCardConfig? creditCardConfig; // CC-specific configuration

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.creditLimit,
    this.billDate,
    this.lastFourDigits,
    this.isDefault = false,
    this.creditCardConfig,
  });

  /// Available credit = limit - outstanding (credit cards only)
  /// If balance is negative (credit), available credit is limit + credit
  double? get availableCredit => creditLimit != null
      ? (creditLimit! - balance).clamp(0.0, creditLimit!)
      : null;

  /// Utilization ratio 0.0–1.0 (credit cards only)
  double? get utilizationRatio => (creditLimit != null && creditLimit! > 0)
      ? (balance / creditLimit!).clamp(0.0, 1.0)
      : null;

  Account copyWith({
    String? name,
    AccountType? type,
    double? balance,
    double? creditLimit,
    int? billDate,
    String? lastFourDigits,
    Color? color,
    bool? isDefault,
    CreditCardConfig? creditCardConfig,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      color: color ?? this.color,
      creditLimit: creditLimit ?? this.creditLimit,
      billDate: billDate ?? this.billDate,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      isDefault: isDefault ?? this.isDefault,
      creditCardConfig: creditCardConfig ?? this.creditCardConfig,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'balance': balance,
    'color': color.toARGB32(),
    'creditLimit': creditLimit,
    'billDate': billDate,
    'lastFourDigits': lastFourDigits,
    'isDefault': isDefault,
    'creditCardConfig': creditCardConfig?.toMap(),
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'] as String,
    name: map['name'] as String,
    type: AccountType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => AccountType.bank,
    ),
    balance: (map['balance'] as num).toDouble(),
    color: Color(map['color'] as int),
    creditLimit: map['creditLimit'] != null
        ? (map['creditLimit'] as num).toDouble()
        : null,
    billDate: map['billDate'] as int?,
    lastFourDigits: map['lastFourDigits'] as String?,
    isDefault: map['isDefault'] as bool? ?? false,
    creditCardConfig: map['creditCardConfig'] != null
        ? CreditCardConfig.fromMap(
            map['creditCardConfig'] as Map<String, dynamic>,
          )
        : null,
  );
}
