import 'package:flutter/material.dart';
import 'custom_category.dart';
import 'credit_card_bill.dart';

enum TransactionType { income, expense, transfer }

enum TransactionCategory {
  // Expense categories
  food,
  transport,
  shopping,
  entertainment,
  health,
  utilities,
  rent,
  education,
  fuel,
  bills,
  bakery,
  grocery,
  vegetables,
  drinksAndSnacks,
  insurance,
  expenseInvestment,
  other,
  // Income categories
  salary,
  freelance,
  investment,
  gift,
  cashback,
}

extension TransactionCategoryExtension on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.food:
        return 'Food & Dining';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.health:
        return 'Health';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.rent:
        return 'Rent';
      case TransactionCategory.education:
        return 'Education';
      case TransactionCategory.fuel:
        return 'Fuel';
      case TransactionCategory.bills:
        return 'Bills';
      case TransactionCategory.bakery:
        return 'Bakery';
      case TransactionCategory.grocery:
        return 'Grocery';
      case TransactionCategory.vegetables:
        return 'Vegetables';
      case TransactionCategory.drinksAndSnacks:
        return 'Drinks & Snacks';
      case TransactionCategory.insurance:
        return 'Insurance';
      case TransactionCategory.expenseInvestment:
        return 'Investment';
      case TransactionCategory.other:
        return 'Other';
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.investment:
        return 'Investment';
      case TransactionCategory.gift:
        return 'Gift';
      case TransactionCategory.cashback:
        return 'Cashback';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionCategory.food:
        return Icons.restaurant_rounded;
      case TransactionCategory.transport:
        return Icons.directions_car_rounded;
      case TransactionCategory.shopping:
        return Icons.shopping_bag_rounded;
      case TransactionCategory.entertainment:
        return Icons.movie_rounded;
      case TransactionCategory.health:
        return Icons.favorite_rounded;
      case TransactionCategory.utilities:
        return Icons.bolt_rounded;
      case TransactionCategory.rent:
        return Icons.home_rounded;
      case TransactionCategory.education:
        return Icons.school_rounded;
      case TransactionCategory.fuel:
        return Icons.local_gas_station_rounded;
      case TransactionCategory.bills:
        return Icons.receipt_rounded;
      case TransactionCategory.bakery:
        return Icons.bakery_dining_rounded;
      case TransactionCategory.grocery:
        return Icons.shopping_cart_rounded;
      case TransactionCategory.vegetables:
        return Icons.eco_rounded;
      case TransactionCategory.drinksAndSnacks:
        return Icons.local_cafe_rounded;
      case TransactionCategory.insurance:
        return Icons.shield_rounded;
      case TransactionCategory.expenseInvestment:
        return Icons.account_balance_rounded;
      case TransactionCategory.other:
        return Icons.category_rounded;
      case TransactionCategory.salary:
        return Icons.work_rounded;
      case TransactionCategory.freelance:
        return Icons.laptop_rounded;
      case TransactionCategory.investment:
        return Icons.trending_up_rounded;
      case TransactionCategory.gift:
        return Icons.card_giftcard_rounded;
      case TransactionCategory.cashback:
        return Icons.currency_exchange_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.food:
        return const Color(0xFFFF6B6B);
      case TransactionCategory.transport:
        return const Color(0xFF4ECDC4);
      case TransactionCategory.shopping:
        return const Color(0xFFFFBE0B);
      case TransactionCategory.entertainment:
        return const Color(0xFF9B59B6);
      case TransactionCategory.health:
        return const Color(0xFFE74C3C);
      case TransactionCategory.utilities:
        return const Color(0xFF3498DB);
      case TransactionCategory.rent:
        return const Color(0xFF2ECC71);
      case TransactionCategory.education:
        return const Color(0xFF1ABC9C);
      case TransactionCategory.fuel:
        return const Color(0xFFFF9800);
      case TransactionCategory.bills:
        return const Color(0xFF607D8B);
      case TransactionCategory.bakery:
        return const Color(0xFFD4A574);
      case TransactionCategory.grocery:
        return const Color(0xFF8BC34A);
      case TransactionCategory.vegetables:
        return const Color(0xFF4CAF50);
      case TransactionCategory.drinksAndSnacks:
        return const Color(0xFFFF7043);
      case TransactionCategory.insurance:
        return const Color(0xFF5C6BC0);
      case TransactionCategory.expenseInvestment:
        return const Color(0xFF00897B);
      case TransactionCategory.other:
        return const Color(0xFF95A5A6);
      case TransactionCategory.salary:
        return const Color(0xFF2D9E6B);
      case TransactionCategory.freelance:
        return const Color(0xFF27AE60);
      case TransactionCategory.investment:
        return const Color(0xFF16A085);
      case TransactionCategory.gift:
        return const Color(0xFFE91E63);
      case TransactionCategory.cashback:
        return const Color(0xFF00BCD4);
    }
  }
}

/// Resolved display properties for a transaction category.
/// Use [Transaction.resolveCategory] to obtain this.
class ResolvedCategory {
  final String label;
  final IconData icon;
  final Color color;

  const ResolvedCategory({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class Transaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String? note;
  final String? accountId;
  final String? toAccountId; // transfers only
  final List<String> tagIds; // IDs of tags applied to this transaction

  // EMI fields (for credit card transactions)
  final bool isEmi;
  final double? emiInterestRate; // Annual interest rate percentage
  final int? emiDurationMonths; // Duration in months (3, 6, 9, 12, etc.)
  final double? emiMonthlyAmount; // Calculated EMI amount per month
  final String?
  parentTransactionId; // For EMI installments, links to original transaction

  // Expense calculation control
  final bool excludeFromExpense; // If true, not included in expense totals

  /// When true (default), this transaction counts toward the monthly
  /// income/expense totals shown on the home screen.
  /// When false, it is a "general" transaction — still recorded and visible
  /// in all lists, but excluded from the monthly summary figures.
  final bool isMonthly;

  // Recurring transaction fields
  final bool isRecurring; // If true, this is a recurring transaction
  final String?
  recurringFrequency; // 'daily', 'weekly', 'monthly', 'quarterly', 'yearly'
  final DateTime?
  recurringEndDate; // When to stop creating recurring transactions
  final String?
  recurringParentId; // For instances, links to the recurring template

  // Custom category (user-defined, overrides the built-in category enum)
  final String? customCategoryId;

  // SMS import fields
  final String? source; // 'manual', 'sms', 'bank_api'
  final String? smsMessageId; // Original SMS message ID for deduplication
  final String? bankName; // Bank that sent the SMS

  // Credit card tracking fields
  final String?
  creditCardAccountId; // Links to CC account if this is a CC transaction
  final TransactionState state; // pending, billed, paid
  final String? creditCardBillId; // Links to bill (if billed)
  final DateTime? stateChangedAt; // Audit trail for state changes

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.accountId,
    this.toAccountId,
    this.tagIds = const [],
    this.isEmi = false,
    this.emiInterestRate,
    this.emiDurationMonths,
    this.emiMonthlyAmount,
    this.parentTransactionId,
    this.excludeFromExpense = false,
    this.isMonthly = true,
    this.isRecurring = false,
    this.recurringFrequency,
    this.recurringEndDate,
    this.recurringParentId,
    this.customCategoryId,
    this.source,
    this.smsMessageId,
    this.bankName,
    this.creditCardAccountId,
    this.state = TransactionState.pending,
    this.creditCardBillId,
    this.stateChangedAt,
  });

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
  bool get isTransfer => type == TransactionType.transfer;

  // Credit card transaction getters
  bool get isCreditCardTransaction => creditCardAccountId != null;
  bool get isPending => state == TransactionState.pending;
  bool get isBilled => state == TransactionState.billed;
  bool get isPaid => state == TransactionState.paid;

  /// Returns the effective icon/color/label for display.
  /// If [customCategoryId] is set and [lookupCustom] finds it, those values
  /// are used; otherwise falls back to the built-in [category].
  ResolvedCategory resolveCategory(
    CustomCategory? Function(String) lookupCustom,
  ) {
    if (customCategoryId != null) {
      final custom = lookupCustom(customCategoryId!);
      if (custom != null) {
        return ResolvedCategory(
          label: custom.label,
          icon: custom.icon,
          color: custom.color,
        );
      }
    }
    return ResolvedCategory(
      label: category.label,
      icon: category.icon,
      color: category.color,
    );
  }

  Transaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? note,
    String? accountId,
    String? toAccountId,
    List<String>? tagIds,
    bool? isEmi,
    double? emiInterestRate,
    int? emiDurationMonths,
    double? emiMonthlyAmount,
    String? parentTransactionId,
    bool? excludeFromExpense,
    bool? isMonthly,
    bool? isRecurring,
    String? recurringFrequency,
    DateTime? recurringEndDate,
    String? recurringParentId,
    String? customCategoryId,
    String? source,
    String? smsMessageId,
    String? bankName,
    String? creditCardAccountId,
    TransactionState? state,
    String? creditCardBillId,
    DateTime? stateChangedAt,
  }) {
    return Transaction(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      tagIds: tagIds ?? this.tagIds,
      isEmi: isEmi ?? this.isEmi,
      emiInterestRate: emiInterestRate ?? this.emiInterestRate,
      emiDurationMonths: emiDurationMonths ?? this.emiDurationMonths,
      emiMonthlyAmount: emiMonthlyAmount ?? this.emiMonthlyAmount,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      excludeFromExpense: excludeFromExpense ?? this.excludeFromExpense,
      isMonthly: isMonthly ?? this.isMonthly,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      customCategoryId: customCategoryId ?? this.customCategoryId,
      source: source ?? this.source,
      smsMessageId: smsMessageId ?? this.smsMessageId,
      bankName: bankName ?? this.bankName,
      creditCardAccountId: creditCardAccountId ?? this.creditCardAccountId,
      state: state ?? this.state,
      creditCardBillId: creditCardBillId ?? this.creditCardBillId,
      stateChangedAt: stateChangedAt ?? this.stateChangedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'category': category.name,
    'date': date.toIso8601String(),
    'note': note,
    'accountId': accountId,
    'toAccountId': toAccountId,
    'tagIds': tagIds,
    'isEmi': isEmi,
    'emiInterestRate': emiInterestRate,
    'emiDurationMonths': emiDurationMonths,
    'emiMonthlyAmount': emiMonthlyAmount,
    'parentTransactionId': parentTransactionId,
    'excludeFromExpense': excludeFromExpense,
    'isRecurring': isRecurring,
    'recurringFrequency': recurringFrequency,
    'recurringEndDate': recurringEndDate?.toIso8601String(),
    'recurringParentId': recurringParentId,
    'customCategoryId': customCategoryId,
    'source': source,
    'smsMessageId': smsMessageId,
    'bankName': bankName,
    'creditCardAccountId': creditCardAccountId,
    'state': state.name,
    'creditCardBillId': creditCardBillId,
    'stateChangedAt': stateChangedAt?.toIso8601String(),
  };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String,
    title: map['title'] as String,
    amount: (map['amount'] as num).toDouble(),
    type: TransactionType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => TransactionType.expense,
    ),
    category: TransactionCategory.values.firstWhere(
      (c) => c.name == map['category'],
      orElse: () => TransactionCategory.other,
    ),
    date: DateTime.parse(map['date'] as String),
    note: map['note'] as String?,
    accountId: map['accountId'] as String?,
    toAccountId: map['toAccountId'] as String?,
    tagIds: map['tagIds'] != null
        ? List<String>.from(map['tagIds'] as List)
        : const [],
    isEmi: map['isEmi'] as bool? ?? false,
    emiInterestRate: map['emiInterestRate'] != null
        ? (map['emiInterestRate'] as num).toDouble()
        : null,
    emiDurationMonths: map['emiDurationMonths'] as int?,
    emiMonthlyAmount: map['emiMonthlyAmount'] != null
        ? (map['emiMonthlyAmount'] as num).toDouble()
        : null,
    parentTransactionId: map['parentTransactionId'] as String?,
    excludeFromExpense: map['excludeFromExpense'] as bool? ?? false,
    isRecurring: map['isRecurring'] as bool? ?? false,
    recurringFrequency: map['recurringFrequency'] as String?,
    recurringEndDate: map['recurringEndDate'] != null
        ? DateTime.parse(map['recurringEndDate'] as String)
        : null,
    recurringParentId: map['recurringParentId'] as String?,
    customCategoryId: map['customCategoryId'] as String?,
    source: map['source'] as String?,
    smsMessageId: map['smsMessageId'] as String?,
    bankName: map['bankName'] as String?,
    creditCardAccountId: map['creditCardAccountId'] as String?,
    state: TransactionState.values.firstWhere(
      (s) => s.name == map['state'],
      orElse: () => TransactionState.pending,
    ),
    creditCardBillId: map['creditCardBillId'] as String?,
    stateChangedAt: map['stateChangedAt'] != null
        ? DateTime.parse(map['stateChangedAt'] as String)
        : null,
  );
}
