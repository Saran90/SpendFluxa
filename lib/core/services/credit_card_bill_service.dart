import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  /// Ensure the credit_card_bills table exists and has correct schema
  Future<void> _ensureTableExists() async {
    try {
      final db = await AppDatabase.instance.database;

      // Check if table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='credit_card_bills'",
      );

      if (tables.isNotEmpty) {
        // Table exists, verify it has correct schema
        final columns = await db.rawQuery(
          "PRAGMA table_info(credit_card_bills)",
        );
        final columnNames = columns.map((c) => c['name'] as String).toList();

        // If account_id column doesn't exist, drop and recreate with correct schema
        if (!columnNames.contains('account_id')) {
          debugPrint(
            '[CreditCardBillService] Wrong schema detected, recreating table...',
          );
          await db.execute('DROP TABLE IF EXISTS credit_card_bills');
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
          debugPrint(
            '[CreditCardBillService] Table recreated with correct schema',
          );
          return;
        }
        // Schema is correct, no action needed
        return;
      }

      // Table doesn't exist, create it
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
    final creditCardAccount = accountService.all.firstWhere(
      (a) => a.id == bill.accountId,
    );
    final currentOutstanding = creditCardAccount.balance;

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

    // Case 1: Bill amount is LESS than or EQUAL to outstanding
    // We pay the bill amount, leaving the remaining as outstanding
    if (bill.billAmount <= currentOutstanding) {
      // The individual CC expense transactions were already recorded in the
      // month they were spent, so the bill payment itself must NOT count again
      // as an expense — it is purely a cash-flow settlement.
      final billPaymentTxn = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Bill Payment - ${creditCardAccount.name}',
        amount: bill.billAmount,
        type: TransactionType.expense,
        category: TransactionCategory.bills,
        date: DateTime.now(),
        accountId: fromAccountId, // Cash leaves the bank account
        note:
            'Credit card bill payment for ${DateFormat('MMMM yyyy').format(bill.billDate)}',
        // Exclude from expense totals: the spending was already counted in the
        // month the credit card transactions were made.
        excludeFromExpense: true,
        isMonthly: false,
      );
      await transactionService.addTransaction(billPaymentTxn);

      // Reduce credit card outstanding by bill amount
      await accountService.adjustBalance(bill.accountId, -bill.billAmount);
    } else {
      // Case 2: Bill amount is MORE than outstanding (e.g. advance payment or
      // the bill includes charges not yet individually recorded).
      // Only the portion that exceeds already-recorded expenses is a new expense.
      // For simplicity we still exclude the full payment from expense totals —
      // the user should have recorded any missing CC transactions separately.
      final billPaymentTxn = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Bill Payment - ${creditCardAccount.name}',
        amount: bill.billAmount,
        type: TransactionType.expense,
        category: TransactionCategory.bills,
        date: DateTime.now(),
        accountId: fromAccountId, // Cash leaves the bank account
        note:
            'Credit card bill payment for ${DateFormat('MMMM yyyy').format(bill.billDate)}',
        excludeFromExpense: true,
        isMonthly: false,
      );
      await transactionService.addTransaction(billPaymentTxn);

      // Reduce outstanding to zero (bill covers all outstanding)
      if (currentOutstanding > 0) {
        await accountService.adjustBalance(bill.accountId, -currentOutstanding);
      }
    }

    await _load();
  }
}
