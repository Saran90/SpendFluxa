import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/credit_card_bill.dart';

class CreditCardBillService extends ChangeNotifier {
  final List<CreditCardBill> _bills = [];

  List<CreditCardBill> get all => List.unmodifiable(_bills);

  CreditCardBillService() {
    _load();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final rows = await AppDatabase.instance.query(
        'credit_card_bills',
        orderBy: 'bill_date DESC',
      );
      _bills
        ..clear()
        ..addAll(rows.map(_fromRow));
      notifyListeners();
    } catch (e) {
      debugPrint('[CreditCardBillService] load error: $e');
    }
  }

  /// Reloads all bills from the database.
  /// Call this after a backup restore to refresh in-memory state.
  Future<void> reload() => _load();

  // ── Queries ────────────────────────────────────────────────────────────────

  /// Get all bills for a specific credit card account
  List<CreditCardBill> billsForAccount(String accountId) =>
      _bills.where((b) => b.creditCardAccountId == accountId).toList();

  /// Get the most recent bill for a credit card account
  CreditCardBill? getLatestBillForAccount(String accountId) {
    final bills = billsForAccount(accountId);
    if (bills.isEmpty) return null;
    return bills.first; // Already sorted by bill_date DESC
  }

  /// Get outstanding balance for a credit card account
  /// (sum of all unpaid bills)
  double getOutstandingBalance(String accountId) {
    final bills = billsForAccount(accountId);
    return bills.fold(0.0, (sum, bill) => sum + bill.outstandingBalance);
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> add(CreditCardBill bill) async {
    await AppDatabase.instance.insert('credit_card_bills', _toRow(bill));
    await _load();
  }

  Future<void> update(CreditCardBill updated) async {
    await AppDatabase.instance.update(
      'credit_card_bills',
      _toRow(updated),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    await _load();
  }

  Future<void> remove(String id) async {
    await AppDatabase.instance.delete(
      'credit_card_bills',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
  }

  /// Record a payment toward a bill
  /// Updates the bill's payments list and status
  Future<void> recordPayment(
    String billId,
    double amount,
    DateTime paymentDate,
    String? note,
  ) async {
    final billIdx = _bills.indexWhere((b) => b.id == billId);
    if (billIdx == -1) {
      throw Exception('Bill not found: $billId');
    }

    final bill = _bills[billIdx];
    final payment = BillPayment(
      id: _generateId(),
      billId: billId,
      amount: amount,
      paymentDate: paymentDate,
      note: note,
      createdAt: DateTime.now(),
    );

    // Add payment to bill
    final updatedPayments = [...bill.payments, payment];
    final newStatus = _calculateBillStatus(bill.actualAmount, updatedPayments);

    final updatedBill = bill.copyWith(
      payments: updatedPayments,
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    await update(updatedBill);
  }

  /// Calculate bill status based on payments
  BillStatus _calculateBillStatus(
    double actualAmount,
    List<BillPayment> payments,
  ) {
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    if (totalPaid >= actualAmount) {
      return BillStatus.paid;
    } else if (totalPaid > 0) {
      return BillStatus.partial;
    }
    return BillStatus.pending;
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(CreditCardBill bill) => {
    'id': bill.id,
    'credit_card_account_id': bill.creditCardAccountId,
    'bill_date': bill.billDate.toIso8601String(),
    'due_date': bill.dueDate.toIso8601String(),
    'tracked_amount': bill.trackedAmount,
    'actual_amount': bill.actualAmount,
    'difference': bill.difference,
    'difference_note': bill.differenceNote,
    'status': bill.status.name,
    'created_at': bill.createdAt.toIso8601String(),
    'updated_at': bill.updatedAt.toIso8601String(),
  };

  CreditCardBill _fromRow(Map<String, dynamic> row) {
    // Load payments for this bill
    final payments = _loadPaymentsForBill(row['id'] as String);
    // Load transaction IDs for this bill
    final transactionIds = _loadTransactionIdsForBill(row['id'] as String);

    return CreditCardBill(
      id: row['id'] as String,
      creditCardAccountId: row['credit_card_account_id'] as String,
      billDate: DateTime.parse(row['bill_date'] as String),
      dueDate: DateTime.parse(row['due_date'] as String),
      trackedAmount: (row['tracked_amount'] as num).toDouble(),
      actualAmount: (row['actual_amount'] as num).toDouble(),
      difference: row['difference'] != null
          ? (row['difference'] as num).toDouble()
          : null,
      differenceNote: row['difference_note'] as String?,
      transactionIds: transactionIds,
      status: BillStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => BillStatus.pending,
      ),
      payments: payments,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Load payments for a specific bill (synchronously for now)
  /// In a real app, this should be async
  List<BillPayment> _loadPaymentsForBill(String billId) {
    // This is a placeholder - in production, you'd query the database
    // For now, we'll return empty and load on demand
    return [];
  }

  /// Load transaction IDs for a specific bill (synchronously for now)
  List<String> _loadTransactionIdsForBill(String billId) {
    // This is a placeholder - in production, you'd query the database
    return [];
  }

  /// Generate a unique ID
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}
