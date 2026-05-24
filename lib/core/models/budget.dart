import 'transaction.dart';

/// Holds the budget configuration for a single month (year + month).
class MonthlyBudget {
  final int year;
  final int month;

  /// Overall spending cap for the month. Null = not set.
  final double? overallLimit;

  /// Per built-in-category limits.
  final Map<TransactionCategory, double> categoryLimits;

  /// Per custom-category limits, keyed by CustomCategory.id.
  final Map<String, double> customCategoryLimits;

  const MonthlyBudget({
    required this.year,
    required this.month,
    this.overallLimit,
    this.categoryLimits = const {},
    this.customCategoryLimits = const {},
  });

  MonthlyBudget copyWith({
    double? overallLimit,
    bool clearOverall = false,
    Map<TransactionCategory, double>? categoryLimits,
    Map<String, double>? customCategoryLimits,
  }) {
    return MonthlyBudget(
      year: year,
      month: month,
      overallLimit: clearOverall ? null : (overallLimit ?? this.overallLimit),
      categoryLimits: categoryLimits ?? this.categoryLimits,
      customCategoryLimits: customCategoryLimits ?? this.customCategoryLimits,
    );
  }

  Map<String, dynamic> toMap() => {
    'year': year,
    'month': month,
    'overallLimit': overallLimit,
    'categoryLimits': categoryLimits.map((k, v) => MapEntry(k.name, v)),
    'customCategoryLimits': customCategoryLimits,
  };

  factory MonthlyBudget.fromMap(Map<String, dynamic> map) {
    final rawLimits = (map['categoryLimits'] as Map<String, dynamic>?) ?? {};
    final limits = <TransactionCategory, double>{};
    for (final entry in rawLimits.entries) {
      final cat = TransactionCategory.values.firstWhere(
        (c) => c.name == entry.key,
        orElse: () => TransactionCategory.other,
      );
      limits[cat] = (entry.value as num).toDouble();
    }
    final rawCustom =
        (map['customCategoryLimits'] as Map<String, dynamic>?) ?? {};
    final customLimits = rawCustom.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    return MonthlyBudget(
      year: map['year'] as int,
      month: map['month'] as int,
      overallLimit: map['overallLimit'] != null
          ? (map['overallLimit'] as num).toDouble()
          : null,
      categoryLimits: limits,
      customCategoryLimits: customLimits,
    );
  }

  /// Unique storage key for this month.
  String get key => '$year-$month';
}
