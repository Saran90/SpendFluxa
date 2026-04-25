import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/account.dart';

class AccountService extends ChangeNotifier {
  final List<Account> _accounts = [];

  List<Account> get all => List.unmodifiable(_accounts);

  List<Account> get banks =>
      _accounts.where((a) => a.type == AccountType.bank).toList();

  List<Account> get creditCards =>
      _accounts.where((a) => a.type == AccountType.creditCard).toList();

  List<Account> get wallets =>
      _accounts.where((a) => a.type == AccountType.wallet).toList();

  List<Account> get cash =>
      _accounts.where((a) => a.type == AccountType.cash).toList();

  List<Account> get savings =>
      _accounts.where((a) => a.type == AccountType.savings).toList();

  double get totalBalance => _accounts.fold(0.0, (sum, a) => sum + a.balance);

  Account? get defaultAccount =>
      _accounts.where((a) => a.isDefault).firstOrNull ?? _accounts.firstOrNull;

  AccountService() {
    _load();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'accounts',
        orderBy: 'is_default DESC, name ASC',
      );
      _accounts
        ..clear()
        ..addAll(rows.map(_fromRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[AccountService] load error: $e');
    }
  }

  /// Reloads all accounts from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() => _load();

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> add(Account account) async {
    if (account.isDefault) await _clearDefaultInDb();
    await AppDatabase.instance.insert('accounts', _toRow(account));
    await _load();
  }

  Future<void> update(Account updated) async {
    if (updated.isDefault) await _clearDefaultInDb();
    await AppDatabase.instance.update(
      'accounts',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
  }

  Future<void> remove(String id) async {
    await AppDatabase.instance.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
    // If no default left, mark first as default
    if (_accounts.isNotEmpty && !_accounts.any((a) => a.isDefault)) {
      await setDefault(_accounts.first.id);
    }
  }

  Future<void> setDefault(String id) async {
    await _clearDefaultInDb();
    await AppDatabase.instance.update(
      'accounts',
      {'is_default': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
  }

  /// Adjusts the balance/outstanding of an account by [delta].
  ///
  /// Credit cards:
  ///   +delta → outstanding increases (expense charged to card)
  ///   -delta → outstanding decreases (payment / credit received)
  ///
  /// Other account types:
  ///   +delta → balance increases (income received)
  ///   -delta → balance decreases (expense paid out)
  ///
  /// The result is clamped to zero from below for credit cards.
  Future<void> adjustBalance(String accountId, double delta) async {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final account = _accounts[idx];

    double newBalance = account.balance + delta;
    if (account.type == AccountType.creditCard) {
      newBalance = newBalance.clamp(0.0, double.infinity);
    }

    await AppDatabase.instance.update(
      'accounts',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    await _load();
  }

  /// Legacy full-recalculation kept for data-integrity repairs.
  /// Prefer [adjustBalance] for normal transaction flows.
  Future<void> recalculateCreditCardOutstanding(
    String accountId,
    List<dynamic> transactions,
  ) async {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final account = _accounts[idx];
    if (account.type != AccountType.creditCard) return;

    double outstanding = 0.0;
    for (final tx in transactions) {
      if (tx.accountId != accountId) continue;
      if (tx.type.name == 'expense') {
        outstanding += (tx.amount as num).toDouble();
      } else if (tx.type.name == 'income') {
        outstanding -= (tx.amount as num).toDouble();
      }
    }
    outstanding = outstanding.clamp(0.0, double.infinity);

    await AppDatabase.instance.update(
      'accounts',
      {'balance': outstanding},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    await _load();
  }

  Future<void> _clearDefaultInDb() async {
    await AppDatabase.instance.update(
      'accounts',
      {'is_default': 0},
      where: 'is_default = ?',
      whereArgs: [1],
    );
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(Account a) => {
    'id': a.id,
    'name': a.name,
    'type': a.type.name,
    'balance': a.balance,
    'credit_limit': a.creditLimit,
    'bill_date': a.billDate,
    'last_four_digits': a.lastFourDigits,
    'color': a.color.toARGB32(),
    'is_default': a.isDefault ? 1 : 0,
  };

  Account _fromRow(Map<String, dynamic> row) => Account(
    id: row['id'] as String,
    name: row['name'] as String,
    type: AccountType.values.firstWhere(
      (t) => t.name == row['type'],
      orElse: () => AccountType.bank,
    ),
    balance: (row['balance'] as num).toDouble(),
    color: Color(row['color'] as int),
    creditLimit: row['credit_limit'] != null
        ? (row['credit_limit'] as num).toDouble()
        : null,
    billDate: row['bill_date'] as int?,
    lastFourDigits: row['last_four_digits'] as String?,
    isDefault: (row['is_default'] as int) == 1,
  );
}
