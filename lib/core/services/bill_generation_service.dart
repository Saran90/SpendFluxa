import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/credit_card_bill.dart';
import '../models/transaction.dart';
import 'account_service.dart';
import 'credit_card_bill_service.dart';
import 'transaction_service.dart';

/// Service to automatically generate credit card bills on their due dates
class BillGenerationService extends ChangeNotifier {
  final AccountService accountService;
  final TransactionService transactionService;
  final CreditCardBillService billService;

  BillGenerationService({
    required this.accountService,
    required this.transactionService,
    required this.billService,
  });

  /// Check and generate bills for all credit card accounts
  /// Call this periodically (e.g., on app launch, daily check)
  Future<void> checkAndGenerateBills() async {
    try {
      debugPrint('[BillGenerationService] Checking for bills to generate...');

      final creditCards = accountService.creditCards;

      for (final account in creditCards) {
        await _generateBillIfDue(account);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[BillGenerationService] Error checking bills: $e');
    }
  }

  /// Generate a bill for a specific credit card account with a custom amount
  Future<void> generateBillWithAmount(
    Account creditCardAccount,
    double customAmount,
  ) async {
    try {
      debugPrint(
        '[BillGenerationService] Generating bill for ${creditCardAccount.name} with amount: $customAmount',
      );

      // Check if a bill already exists for this month
      final existingBill = await _getBillForCurrentMonth(creditCardAccount.id);
      if (existingBill != null) {
        throw Exception('Bill already exists for this month');
      }

      await _createBillForAccountWithAmount(creditCardAccount, customAmount);
      notifyListeners();
    } catch (e) {
      debugPrint(
        '[BillGenerationService] Error generating bill with custom amount: $e',
      );
      rethrow;
    }
  }

  /// Generate a bill for a specific credit card account if the bill date has arrived
  Future<void> _generateBillIfDue(Account creditCardAccount) async {
    if (creditCardAccount.billDate == null) {
      debugPrint(
        '[BillGenerationService] Account ${creditCardAccount.id} has no bill date set',
      );
      return;
    }

    try {
      // Check if a bill already exists for this month
      final existingBill = await _getBillForCurrentMonth(creditCardAccount.id);
      if (existingBill != null) {
        debugPrint(
          '[BillGenerationService] Bill already exists for ${creditCardAccount.name} this month',
        );
        return;
      }

      // Check if today is the bill date or later
      final today = DateTime.now();
      final billDate = creditCardAccount.billDate!;

      // If today's day >= bill date, generate the bill
      if (today.day >= billDate) {
        await _createBillForAccount(creditCardAccount);
      }
    } catch (e) {
      debugPrint(
        '[BillGenerationService] Error generating bill for ${creditCardAccount.name}: $e',
      );
    }
  }

  /// Create a new bill for the credit card account with custom amount
  Future<void> _createBillForAccountWithAmount(
    Account creditCardAccount,
    double customAmount,
  ) async {
    try {
      final now = DateTime.now();
      final billDate = DateTime(
        now.year,
        now.month,
        creditCardAccount.billDate ?? now.day,
      );

      // Calculate due date (typically 20 days after bill date)
      final dueDate = billDate.add(const Duration(days: 20));

      // Get all pending transactions for this account
      final allTransactions = transactionService.allTransactions;
      final accountTransactions = allTransactions
          .where((tx) => tx.accountId == creditCardAccount.id)
          .toList();

      // Calculate tracked amount (sum of all expenses)
      double trackedAmount = 0;
      for (final tx in accountTransactions) {
        if (tx.type.name == 'expense') {
          trackedAmount += tx.amount;
        } else if (tx.type.name == 'income') {
          trackedAmount -= tx.amount;
        }
      }

      // Use custom amount as actual amount
      final actualAmount = customAmount;
      final difference = actualAmount - trackedAmount;

      // Create the bill
      final bill = CreditCardBill(
        id: _generateId(),
        creditCardAccountId: creditCardAccount.id,
        billDate: billDate,
        dueDate: dueDate,
        trackedAmount: trackedAmount,
        actualAmount: actualAmount,
        difference: difference != 0 ? difference : null,
        differenceNote: difference != 0
            ? 'Manual adjustment: ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(2)}'
            : null,
        transactionIds: accountTransactions.map((tx) => tx.id).toList(),
        status: BillStatus.pending,
        payments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database using bill service
      await billService.add(bill);

      // Create adjustment transaction ONLY when bill > outstanding
      // (i.e. the bank added fees, interest, or other charges).
      // When bill < outstanding, the difference is simply transactions recorded
      // after the billing cycle closed — they belong to the next cycle, so no
      // adjustment is needed.
      if (difference > 0) {
        await _createAdjustmentTransaction(
          creditCardAccount,
          difference,
          billDate,
        );
      }

      // NOTE: Outstanding balance is NOT changed here.
      // It will be recalculated when the user records a payment.

      debugPrint(
        '[BillGenerationService] Generated bill for ${creditCardAccount.name}: $actualAmount',
      );
      if (difference != 0) {
        debugPrint(
          '[BillGenerationService] Created adjustment transaction: ${difference > 0 ? '+' : ''}$difference',
        );
      }
    } catch (e) {
      debugPrint(
        '[BillGenerationService] Error creating bill with custom amount for ${creditCardAccount.name}: $e',
      );
      rethrow;
    }
  }

  /// Create a new bill for the credit card account
  Future<void> _createBillForAccount(Account creditCardAccount) async {
    try {
      final now = DateTime.now();
      final billDate = DateTime(
        now.year,
        now.month,
        creditCardAccount.billDate!,
      );

      // Calculate due date (typically 20 days after bill date)
      final dueDate = billDate.add(const Duration(days: 20));

      // Get all pending transactions for this account
      final allTransactions = transactionService.allTransactions;
      final accountTransactions = allTransactions
          .where((tx) => tx.accountId == creditCardAccount.id)
          .toList();

      // Calculate tracked amount (sum of all expenses)
      double trackedAmount = 0;
      for (final tx in accountTransactions) {
        if (tx.type.name == 'expense') {
          trackedAmount += tx.amount;
        } else if (tx.type.name == 'income') {
          trackedAmount -= tx.amount;
        }
      }

      // For now, actual amount = tracked amount
      // (User can adjust this later if there are fees/interest)
      final actualAmount = trackedAmount;

      // Create the bill
      final bill = CreditCardBill(
        id: _generateId(),
        creditCardAccountId: creditCardAccount.id,
        billDate: billDate,
        dueDate: dueDate,
        trackedAmount: trackedAmount,
        actualAmount: actualAmount,
        difference: null,
        differenceNote: null,
        transactionIds: accountTransactions.map((tx) => tx.id).toList(),
        status: BillStatus.pending,
        payments: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database using bill service
      await billService.add(bill);

      // NOTE: Outstanding balance is NOT changed here.
      // It will be recalculated when the user records a payment.

      debugPrint(
        '[BillGenerationService] Generated bill for ${creditCardAccount.name}: $actualAmount',
      );
    } catch (e) {
      debugPrint(
        '[BillGenerationService] Error creating bill for ${creditCardAccount.name}: $e',
      );
      rethrow;
    }
  }

  /// Get the bill for the current month (if it exists)
  Future<CreditCardBill?> _getBillForCurrentMonth(String accountId) async {
    try {
      final now = DateTime.now();
      final bills = billService.billsForAccount(accountId);

      // Find bill for current month
      for (final bill in bills) {
        if (bill.billDate.year == now.year &&
            bill.billDate.month == now.month) {
          return bill;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[BillGenerationService] Error getting bill for month: $e');
      return null;
    }
  }

  /// Create an adjustment transaction for bill differences
  Future<void> _createAdjustmentTransaction(
    Account creditCardAccount,
    double difference,
    DateTime billDate,
  ) async {
    try {
      // Determine transaction type and title based on difference
      final isPositive = difference > 0;
      final transactionType = isPositive
          ? TransactionType.expense
          : TransactionType.income;
      final title = isPositive
          ? 'Bill Adjustment (Fees)'
          : 'Bill Adjustment (Credit)';

      // Use the 'other' category for adjustments
      final adjustmentCategory = TransactionCategory.other;

      // Create the adjustment transaction
      final adjustmentTransaction = Transaction(
        id: _generateId(),
        title: title,
        amount: difference.abs(),
        date: billDate,
        type: transactionType,
        category: adjustmentCategory,
        accountId: creditCardAccount.id,
        note:
            'Automatic adjustment for bill generation - difference between tracked transactions and actual bill amount',
        tagIds: const [],
        isEmi: false,
        excludeFromExpense: false,
        isMonthly: true,
        isRecurring: false,
        state: TransactionState.billed, // Since this is part of bill generation
      );

      // Add the transaction using the transaction service
      await transactionService.addTransaction(adjustmentTransaction);

      debugPrint(
        '[BillGenerationService] Created adjustment transaction: ${adjustmentTransaction.title} - ${difference.abs()}',
      );
    } catch (e) {
      debugPrint(
        '[BillGenerationService] Error creating adjustment transaction: $e',
      );
      // Don't rethrow - adjustment transaction failure shouldn't stop bill generation
    }
  }

  /// Generate a unique ID
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}
