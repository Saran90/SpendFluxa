import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'account_service.dart';

/// Manages transactions, persisted via SQLite.
class TransactionService extends ChangeNotifier {
  final List<Transaction> _transactions = [];
  final AccountService accountService;

  TransactionService({required this.accountService}) {
    _load();
  }
  // ── Accessors ──────────────────────────────────────────────────────────────

  List<Transaction> get allTransactions {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.where(_isVisible).toList();
  }

  /// Transactions for the given month/year, newest first.
  List<Transaction> transactionsForMonth(int year, int month) {
    return _transactions.where((t) {
      if (t.date.year != year || t.date.month != month) return false;
      return _isVisible(t);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Total income for the given month/year — only monthly transactions.
  double incomeForMonth(int year, int month) =>
      transactionsForMonth(year, month)
          .where((t) => t.isIncome && t.isMonthly)
          .fold(0.0, (sum, t) => sum + t.amount);

  /// Total expenses for the given month/year — only monthly transactions.
  double expensesForMonth(int year, int month) =>
      transactionsForMonth(year, month)
          .where((t) => t.isExpense && !t.excludeFromExpense && t.isMonthly)
          .fold(0.0, (sum, t) => sum + t.amount);

  /// Net balance (income - expenses) for the given month/year.
  double balanceForMonth(int year, int month) =>
      incomeForMonth(year, month) - expensesForMonth(year, month);

  /// Most recent [limit] transactions across all time.
  List<Transaction> recentTransactions({int limit = 6}) {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.where(_isVisible).take(limit).toList();
  }

  /// Transactions with a specific tag.
  List<Transaction> transactionsWithTag(String tagId) {
    return _transactions.where((t) {
      if (!t.tagIds.contains(tagId)) return false;
      return _isVisible(t);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  double totalForTag(String tagId) =>
      transactionsWithTag(tagId).fold(0.0, (sum, t) => sum + t.amount);

  double incomeForTag(String tagId) => transactionsWithTag(
    tagId,
  ).where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);

  double expensesForTag(String tagId) => transactionsWithTag(tagId)
      .where((t) => t.isExpense && !t.excludeFromExpense)
      .fold(0.0, (sum, t) => sum + t.amount);

  /// All recurring transaction templates (parent transactions).
  List<Transaction> getRecurringTemplates() {
    return _transactions
        .where((t) => t.isRecurring && t.recurringParentId == null)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  /// All visible transactions linked to a specific account, newest first.
  List<Transaction> transactionsForAccount(String accountId) {
    return _transactions
        .where(
          (t) =>
              (t.accountId == accountId || t.toAccountId == accountId) &&
              _isVisible(t),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> addTransaction(Transaction transaction) async {
    await AppDatabase.instance.insert('transactions', _toRow(transaction));
    await _load();
    await _applyTransactionDelta(transaction, reverse: false);
  }

  Future<void> updateTransaction(Transaction updated) async {
    final old = _transactions.firstWhere(
      (t) => t.id == updated.id,
      orElse: () => updated,
    );
    await AppDatabase.instance.update(
      'transactions',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
    // Undo the old transaction's effect, then apply the new one
    await _applyTransactionDelta(old, reverse: true);
    await _applyTransactionDelta(updated, reverse: false);
  }

  /// Updates a recurring template row only — no balance changes.
  /// Already-recorded child instances are left untouched.
  Future<void> updateRecurringTemplate(Transaction updated) async {
    await AppDatabase.instance.update(
      'transactions',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
  }

  Future<void> removeTransaction(String id) async {
    final tx = _transactions.firstWhere(
      (t) => t.id == id,
      orElse: () => Transaction(
        id: id,
        title: '',
        amount: 0,
        type: TransactionType.expense,
        category: TransactionCategory.other,
        date: DateTime.now(),
      ),
    );
    await AppDatabase.instance.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
    await _applyTransactionDelta(tx, reverse: true);
  }

  /// Applies (or reverses) the balance effect of [tx] on its linked account.
  Future<void> _applyTransactionDelta(
    Transaction tx, {
    required bool reverse,
  }) async {
    if (tx.accountId == null) return;
    // Recurring templates are never real transactions — skip balance changes
    if (tx.isRecurring && tx.recurringParentId == null) return;

    final account = accountService.all.firstWhere(
      (a) => a.id == tx.accountId,
      orElse: () => Account(
        id: '',
        name: '',
        type: AccountType.bank,
        balance: 0,
        color: const Color(0xFF000000),
      ),
    );

    if (account.id.isEmpty) return;

    double delta;

    if (account.type == AccountType.creditCard) {
      // Credit card: expense increases outstanding, income/payment decreases it
      if (tx.type == TransactionType.expense) {
        delta = tx.amount;
      } else if (tx.type == TransactionType.income) {
        delta = -tx.amount;
      } else {
        return; // transfers handled separately via toAccountId
      }
    } else {
      // Bank / wallet / cash / savings:
      // income credits the account (+), expense debits it (-)
      if (tx.type == TransactionType.income) {
        delta = tx.amount;
      } else if (tx.type == TransactionType.expense) {
        delta = -tx.amount;
      } else {
        return; // transfers handled separately via toAccountId
      }
    }

    if (reverse) delta = -delta;

    await accountService.adjustBalance(tx.accountId!, delta);
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'transactions',
        orderBy: 'date DESC',
      );
      debugPrint(
        '[TransactionService] _load() read ${rows.length} rows from DB',
      );
      _transactions
        ..clear()
        ..addAll(rows.map(_fromRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[TransactionService] load error: $e');
    }
  }

  /// Reloads all transactions from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() => _load();

  // ── Visibility filter ──────────────────────────────────────────────────────

  bool _isVisible(Transaction t) {
    // Hide recurring template/parent transactions
    if (t.isRecurring && t.recurringParentId == null) return false;
    // Hide future recurring instances
    if (t.recurringParentId != null) {
      return t.date.isBefore(DateTime.now().add(const Duration(days: 1)));
    }
    return true;
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(Transaction t) => {
    'id': t.id,
    'title': t.title,
    'amount': t.amount,
    'type': t.type.name,
    'category': t.category.name,
    'date': t.date.toIso8601String(),
    'note': t.note,
    'account_id': t.accountId,
    'to_account_id': t.toAccountId,
    'tag_ids': jsonEncode(t.tagIds),
    'is_emi': t.isEmi ? 1 : 0,
    'emi_interest_rate': t.emiInterestRate,
    'emi_duration_months': t.emiDurationMonths,
    'emi_monthly_amount': t.emiMonthlyAmount,
    'parent_transaction_id': t.parentTransactionId,
    'exclude_from_expense': t.excludeFromExpense ? 1 : 0,
    'is_monthly': t.isMonthly ? 1 : 0,
    'is_recurring': t.isRecurring ? 1 : 0,
    'recurring_frequency': t.recurringFrequency,
    'recurring_end_date': t.recurringEndDate?.toIso8601String(),
    'recurring_parent_id': t.recurringParentId,
    'custom_category_id': t.customCategoryId,
  };

  Transaction _fromRow(Map<String, dynamic> row) => Transaction(
    id: row['id'] as String,
    title: row['title'] as String,
    amount: (row['amount'] as num).toDouble(),
    type: TransactionType.values.firstWhere(
      (t) => t.name == row['type'],
      orElse: () => TransactionType.expense,
    ),
    category: TransactionCategory.values.firstWhere(
      (c) => c.name == row['category'],
      orElse: () => TransactionCategory.other,
    ),
    date: DateTime.parse(row['date'] as String),
    note: row['note'] as String?,
    accountId: row['account_id'] as String?,
    toAccountId: row['to_account_id'] as String?,
    tagIds: row['tag_ids'] != null
        ? List<String>.from(jsonDecode(row['tag_ids'] as String) as List)
        : const [],
    isEmi: (row['is_emi'] as int) == 1,
    emiInterestRate: row['emi_interest_rate'] != null
        ? (row['emi_interest_rate'] as num).toDouble()
        : null,
    emiDurationMonths: row['emi_duration_months'] as int?,
    emiMonthlyAmount: row['emi_monthly_amount'] != null
        ? (row['emi_monthly_amount'] as num).toDouble()
        : null,
    parentTransactionId: row['parent_transaction_id'] as String?,
    excludeFromExpense: (row['exclude_from_expense'] as int) == 1,
    isMonthly: (row['is_monthly'] as int? ?? 1) == 1,
    isRecurring: (row['is_recurring'] as int) == 1,
    recurringFrequency: row['recurring_frequency'] as String?,
    recurringEndDate: row['recurring_end_date'] != null
        ? DateTime.parse(row['recurring_end_date'] as String)
        : null,
    recurringParentId: row['recurring_parent_id'] as String?,
    customCategoryId: row['custom_category_id'] as String?,
  );
}
