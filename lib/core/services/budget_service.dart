import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class BudgetService extends ChangeNotifier {
  /// Keyed by "year-month"
  final Map<String, MonthlyBudget> _budgets = {};

  BudgetService() {
    _load();
  }

  // ── Accessors ──────────────────────────────────────────────────────────────

  MonthlyBudget budgetFor(int year, int month) {
    return _budgets['$year-$month'] ?? MonthlyBudget(year: year, month: month);
  }

  double? overallLimitFor(int year, int month) =>
      budgetFor(year, month).overallLimit;

  double? categoryLimitFor(int year, int month, TransactionCategory category) =>
      budgetFor(year, month).categoryLimits[category];

  double? customCategoryLimitFor(
    int year,
    int month,
    String customCategoryId,
  ) => budgetFor(year, month).customCategoryLimits[customCategoryId];

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> setOverallLimit(int year, int month, double? limit) async {
    final existing = budgetFor(year, month);
    final updated = existing.copyWith(
      overallLimit: limit,
      clearOverall: limit == null,
    );
    _budgets['$year-$month'] = updated;
    notifyListeners();
    await _upsert(updated);
  }

  Future<void> setCategoryLimit(
    int year,
    int month,
    TransactionCategory category,
    double? limit,
  ) async {
    final existing = budgetFor(year, month);
    final limits = Map<TransactionCategory, double>.from(
      existing.categoryLimits,
    );
    if (limit == null || limit <= 0) {
      limits.remove(category);
    } else {
      limits[category] = limit;
    }
    final updated = existing.copyWith(categoryLimits: limits);
    _budgets['$year-$month'] = updated;
    notifyListeners();
    await _upsert(updated);
  }

  Future<void> setCustomCategoryLimit(
    int year,
    int month,
    String customCategoryId,
    double? limit,
  ) async {
    final existing = budgetFor(year, month);
    final limits = Map<String, double>.from(existing.customCategoryLimits);
    if (limit == null || limit <= 0) {
      limits.remove(customCategoryId);
    } else {
      limits[customCategoryId] = limit;
    }
    final updated = existing.copyWith(customCategoryLimits: limits);
    _budgets['$year-$month'] = updated;
    notifyListeners();
    await _upsert(updated);
  }

  Future<void> clearMonth(int year, int month) async {
    _budgets.remove('$year-$month');
    notifyListeners();
    await AppDatabase.instance.delete(
      'budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query('budgets');
      for (final row in rows) {
        final budget = _fromRow(row);
        _budgets[budget.key] = budget;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[BudgetService] load error: $e');
    }
  }

  /// Reloads all budgets from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() async {
    _budgets.clear();
    await _load();
  }

  Future<void> _upsert(MonthlyBudget budget) async {
    await AppDatabase.instance.insert('budgets', _toRow(budget));
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(MonthlyBudget b) => {
    'id': b.key,
    'year': b.year,
    'month': b.month,
    'overall_limit': b.overallLimit,
    'category_limits': jsonEncode(
      b.categoryLimits.map((k, v) => MapEntry(k.name, v)),
    ),
    'custom_category_limits': jsonEncode(b.customCategoryLimits),
  };

  MonthlyBudget _fromRow(Map<String, dynamic> row) {
    final rawLimits =
        jsonDecode(row['category_limits'] as String) as Map<String, dynamic>;
    final limits = <TransactionCategory, double>{};
    for (final entry in rawLimits.entries) {
      final cat = TransactionCategory.values.firstWhere(
        (c) => c.name == entry.key,
        orElse: () => TransactionCategory.other,
      );
      limits[cat] = (entry.value as num).toDouble();
    }

    // Load custom category limits (column may not exist in older DB rows)
    final rawCustom = row['custom_category_limits'] != null
        ? jsonDecode(row['custom_category_limits'] as String)
              as Map<String, dynamic>
        : <String, dynamic>{};
    final customLimits = rawCustom.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return MonthlyBudget(
      year: row['year'] as int,
      month: row['month'] as int,
      overallLimit: row['overall_limit'] != null
          ? (row['overall_limit'] as num).toDouble()
          : null,
      categoryLimits: limits,
      customCategoryLimits: customLimits,
    );
  }
}
