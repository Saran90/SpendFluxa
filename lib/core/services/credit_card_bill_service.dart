import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/credit_card_bill.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import 'account_service.dart';
import 'transaction_service.dart';

class CreditCardBillService extends ChangeNotifier {
  final AccountService accountService;
  final TransactionService transactionService;
  final List<CreditCardBill> _bills = [];

  List<CreditCardBill> get all => List.unmodifiable(_bills);

  CreditCardBillService({
    required this.accountService,
    required this.transactionService,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _ensureTableExists();
    await _load();
  }

  /// Ensure the credit_card_bills table exists
  Future<void> _ensureTableExists() async {
    try {
      final db = await AppDatabase.instance.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='credit_card_bills'",
      );

      if (tables.isEmpty) {
        debugPrint('[CreditCardBillService] Creating credit_card_bills table');
        await db.execute('''
          CREATE TABLE credit_card_bills (
            id                    TEXT PRIMARY KEY,
            account_id            TEXT NOT NULL,
            bill_date             TEXT NOT NULL,
            bill_amount           REAL NOT NULL,
            status                TEXT NOT NULL CHECK(status IN ('unpaid','paid')),
            paid_date             TEXT,
            paid_from_account_id  TEXT,
            FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
            FOREIGN KEY (paid_from_account_id) REFERENCES accounts(id) ON DELETE SET NULL
          )
        ''');
      }
    } catch (e) {
      debugPrint('[CreditCardBillService] Error ensuring table exists: $e');
    }
  }

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'credit_card_bills',
        orderBy: 'bill_date DESC',
      );
      _bills.clear();
      for (final row in rows) {
        try {
          _bills.add(CreditCardBill.fromMap(row));
        } catch (e) {
          debugPrint('[CreditCardBillService] Error parsing bill: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CreditCardBillService] load error: $e');
    }
  }

  Future<void> reload() async {
    await _ensureTableExists();
    await _load();
  }

  /// Get unpaid bill for current month
  CreditCardBill? getUnpaidBillForCurrentMonth(String accountId) {
    final now = DateTime.now();
    try {
      return _bills.firstWhere(
        (b) =>
            b.accountId == accountId &&
            b.billDate.year == now.year &&
            b.billDate.month == now.month &&
            b.isUnpaid,
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if there's an unpaid bill for current month
  bool hasUnpaidBillForCurrentMonth(String accountId) {
    return getUnpaidBillForCurrentMonth(accountId) != null;
  }

  /// Generate a new bill
  Future<CreditCardBill> generateBill(
    Account account,
    double billAmount,
  ) async {
    final now = DateTime.now();
    final billDay = account.billDate ?? now.day;
    final billDate = DateTime(now.year, now.month, billDay);

    final bill = CreditCardBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: account.id,
      billDate: billDate,
      billAmount: billAmount,
      status: 'unpaid',
    );

    await AppDatabase.instance.insert('credit_card_bills', bill.toMap());

    await _load();
    return bill;
  }

  /// Pay a bill
  Future<void> payBill(CreditCardBill bill, String? fromAccountId) async {
    final paidBill = bill.copyWith(
      status: 'paid',
      paidDate: DateTime.now(),
      paidFromAccountId: fromAccountId,
    );

    await AppDatabase.instance.update(
      'credit_card_bills',
      paidBill.toMap(),
      where: 'id = ?',
      whereArgs: [bill.id],
    );

    // Reduce credit card outstanding
    await accountService.adjustBalance(bill.accountId, -bill.billAmount);

    // Reduce bank account balance if selected
    if (fromAccountId != null) {
      await accountService.adjustBalance(fromAccountId, -bill.billAmount);
    }

    // Create payment transaction
    final paymentTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Credit Card Bill Payment',
      amount: bill.billAmount,
      type: TransactionType.expense,
      category: TransactionCategory.bills,
      date: DateTime.now(),
      accountId: fromAccountId,
      note: 'Payment for ${bill.billDate.month}/${bill.billDate.year} bill',
      excludeFromExpense: true,
      isMonthly: false,
    );

    await transactionService.addTransaction(paymentTx);
    await _load();
  }
}
