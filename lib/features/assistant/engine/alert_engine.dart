import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/transaction.dart'; // provides TransactionCategoryExtension.label
import '../../../core/services/account_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/credit_card_bill_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/transaction_service.dart';
import '../data/alert_repository.dart';
import '../engine/financial_analysis_engine.dart';
import '../engine/plan_manager.dart';
import '../models/alert_record.dart';
import '../preprocessing/amount_parser.dart';

/// Evaluates all proactive alert conditions and dispatches local notifications.
///
/// Called once per day from the WorkManager background task.
/// All expensive computation is synchronous over in-memory service state.
class AlertEngine {
  AlertEngine({
    required this.transactionService,
    required this.budgetService,
    required this.accountService,
    required this.creditCardBillService,
    required this.planManager,
    required this.analysisEngine,
    required this.alertRepository,
    required this.notificationService,
    this.salaryDayOverride,
  });

  final TransactionService transactionService;
  final BudgetService budgetService;
  final AccountService accountService;
  final CreditCardBillService creditCardBillService;
  final PlanManager planManager;
  final FinancialAnalysisEngine analysisEngine;
  final AlertRepository alertRepository;
  final NotificationService notificationService;

  /// User-configured salary credit day (1–31). Overrides auto-inference when set.
  final int? salaryDayOverride;

  static const _uuid = Uuid();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Evaluates all alert conditions. Call this once per day.
  ///
  /// Purges stale alert records at the start to prevent unbounded growth,
  /// then runs each evaluator. Failures in individual evaluators are caught
  /// so a single bad check does not abort the rest.
  Future<void> evaluateAll() async {
    // 1. Purge records older than 7 days
    await alertRepository.deleteOlderThan(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    // 2. Run all evaluators
    final evaluators = [
      _checkCategoryBudget80,
      _checkOverallBudget80,
      _checkSpendingSpike,
      _checkRecurringBalance,
      _checkCreditCardDue,
      _checkSalaryOverdue,
      _checkForecastNegative,
      _checkDebtIncomeRatio,
    ];

    for (final evaluator in evaluators) {
      try {
        await evaluator();
      } catch (e) {
        debugPrint('[AlertEngine] Evaluator error: $e');
      }
    }
  }

  // ── Evaluators ─────────────────────────────────────────────────────────────

  /// Alert when any category spending exceeds 80% of its budget limit.
  Future<void> _checkCategoryBudget80() async {
    final now = DateTime.now();
    final budget = budgetService.budgetFor(now.year, now.month);

    for (final entry in budget.categoryLimits.entries) {
      if (entry.value <= 0) continue;
      final spent = transactionService
          .transactionsForMonth(now.year, now.month)
          .where((t) => t.category == entry.key && t.isExpense)
          .fold(0.0, (s, t) => s + t.amount);

      if (spent / entry.value >= 0.8) {
        final subject = entry.key.name;
        if (await _shouldEmit(AlertRecord.budgetCategory80, subject)) {
          final pct = ((spent / entry.value) * 100).toStringAsFixed(0);
          await _emit(
            alertType: AlertRecord.budgetCategory80,
            subject: subject,
            title: 'Budget Alert — ${entry.key.label}',
            body:
                'You have used $pct% of your ${entry.key.label} budget this month.',
          );
        }
      }
    }
  }

  /// Alert when total monthly spending exceeds 80% of the overall budget.
  Future<void> _checkOverallBudget80() async {
    final now = DateTime.now();
    final budget = budgetService.budgetFor(now.year, now.month);
    final overallLimit = budget.overallLimit;
    if (overallLimit == null || overallLimit <= 0) return;

    final spent = transactionService.expensesForMonth(now.year, now.month);
    if (spent / overallLimit >= 0.8) {
      if (await _shouldEmit(AlertRecord.budgetOverall80, '')) {
        final pct = ((spent / overallLimit) * 100).toStringAsFixed(0);
        await _emit(
          alertType: AlertRecord.budgetOverall80,
          subject: '',
          title: 'Monthly Budget Alert',
          body:
              'You have used $pct% of your monthly budget. '
              '${AmountParser.formatInr(overallLimit - spent)} remaining.',
        );
      }
    }
  }

  /// Alert when a category spends more than 130% of what it did last month.
  Future<void> _checkSpendingSpike() async {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);

    for (final cat
        in transactionService
            .transactionsForMonth(now.year, now.month)
            .map((t) => t.category)
            .toSet()) {
      final thisMonth = transactionService
          .transactionsForMonth(now.year, now.month)
          .where((t) => t.category == cat && t.isExpense)
          .fold(0.0, (s, t) => s + t.amount);

      final lastMonth = transactionService
          .transactionsForMonth(prev.year, prev.month)
          .where((t) => t.category == cat && t.isExpense)
          .fold(0.0, (s, t) => s + t.amount);

      if (lastMonth <= 0 || thisMonth / lastMonth <= 1.30) continue;

      final subject = cat.name;
      if (await _shouldEmit(AlertRecord.spendSpikeCategory, subject)) {
        final pct = ((thisMonth / lastMonth - 1) * 100).toStringAsFixed(0);
        await _emit(
          alertType: AlertRecord.spendSpikeCategory,
          subject: subject,
          title: 'Spending Spike — ${cat.label}',
          body:
              'You spent $pct% more on ${cat.label} this month compared to last month.',
        );
      }
    }
  }

  /// Alert when a recurring expense is due within 5 days and balance is < 2× the amount.
  Future<void> _checkRecurringBalance() async {
    final now = DateTime.now();
    final in5Days = now.add(const Duration(days: 5));
    final totalBalance = accountService.all
        .where((a) => a.type.name != 'creditCard')
        .fold(0.0, (s, a) => s + a.balance);

    for (final t in transactionService.getRecurringTemplates()) {
      if (!t.isExpense) continue;
      final freq = t.recurringFrequency ?? 'monthly';
      final stepDays = _freqToDays(freq);
      var next = t.date;
      while (next.isBefore(now)) {
        next = next.add(Duration(days: stepDays));
      }
      if (!next.isBefore(in5Days)) continue;
      if (totalBalance >= 2 * t.amount) continue;

      final subject = t.id;
      if (await _shouldEmit(AlertRecord.recurringBalanceRisk, subject)) {
        await _emit(
          alertType: AlertRecord.recurringBalanceRisk,
          subject: subject,
          title: 'Low Balance Warning',
          body:
              '"${t.title}" of ${AmountParser.formatInr(t.amount)} is due in '
              '${next.difference(now).inDays} day(s). Current balance: '
              '${AmountParser.formatInr(totalBalance)}.',
        );
      }
    }
  }

  /// Alert when a credit card bill is due within 7 days.
  Future<void> _checkCreditCardDue() async {
    final now = DateTime.now();
    final in7Days = now.add(const Duration(days: 7));

    for (final bill in creditCardBillService.all) {
      if (bill.isPaid) continue;
      if (bill.billDate.isBefore(now) || !bill.billDate.isBefore(in7Days))
        continue;

      final subject = bill.id;
      if (await _shouldEmit(AlertRecord.creditCardDue, subject)) {
        final daysLeft = bill.billDate.difference(now).inDays;
        await _emit(
          alertType: AlertRecord.creditCardDue,
          subject: subject,
          title: 'Credit Card Bill Due',
          body:
              '${AmountParser.formatInr(bill.billAmount)} due in $daysLeft day(s).',
        );
      }
    }
  }

  /// Alert when salary hasn't been credited and we're 5+ days past the expected date.
  Future<void> _checkSalaryOverdue() async {
    final now = DateTime.now();
    final salaryDay = salaryDayOverride ?? _inferSalaryDay();
    if (salaryDay == null) return;

    // Check if today is 5+ days past the expected salary day
    if (now.day < salaryDay + 5) return;

    // Check if any salary income exists this month
    final hasIncome = transactionService
        .transactionsForMonth(now.year, now.month)
        .any(
          (t) =>
              t.isIncome &&
              (t.category.name == 'salary' || t.category.name == 'freelance'),
        );

    if (hasIncome) return;

    if (await _shouldEmit(AlertRecord.salaryOverdue, '')) {
      await _emit(
        alertType: AlertRecord.salaryOverdue,
        subject: '',
        title: 'Salary Not Credited',
        body:
            'Your salary is usually credited around the ${salaryDay}th. '
            'No income has been recorded this month yet.',
      );
    }
  }

  /// Alert when the balance forecast predicts a negative balance within 30 days.
  Future<void> _checkForecastNegative() async {
    final forecast = analysisEngine.getBalanceForecast(days: 30);
    final negativeDays = forecast.days
        .where((d) => d.balanceBelowZero)
        .toList();
    if (negativeDays.isEmpty) return;

    if (await _shouldEmit(AlertRecord.balanceForecastZero, '')) {
      final firstNeg = negativeDays.first;
      final daysUntil = firstNeg.date.difference(DateTime.now()).inDays;
      await _emit(
        alertType: AlertRecord.balanceForecastZero,
        subject: '',
        title: 'Balance May Go Negative',
        body:
            'Your account balance is projected to go below zero in '
            '$daysUntil day(s) (${AmountParser.formatInr(firstNeg.predictedBalance)}).',
      );
    }
  }

  /// Alert when rent + EMI exceeds 50% of average monthly income.
  Future<void> _checkDebtIncomeRatio() async {
    final avgIncome = analysisEngine.inferAverageMonthlySalary(monthsBack: 3);
    if (avgIncome <= 0) return;

    // Sum next month's rent and EMI obligations
    double obligations = 0;
    for (final t in transactionService.getRecurringTemplates()) {
      if (!t.isExpense) continue;
      if (t.category.name == 'rent' || t.isEmi) {
        obligations += t.emiMonthlyAmount ?? t.amount;
      }
    }

    if (obligations / avgIncome <= 0.5) return;

    if (await _shouldEmit(AlertRecord.debtIncomeRatio, '')) {
      final pct = ((obligations / avgIncome) * 100).toStringAsFixed(0);
      await _emit(
        alertType: AlertRecord.debtIncomeRatio,
        subject: '',
        title: 'High Debt-to-Income Ratio',
        body:
            'Your rent and EMI obligations consume $pct% of your average monthly income.',
      );
    }
  }

  // ── Salary inference ───────────────────────────────────────────────────────

  /// Infers the expected salary credit day from the past 3 months.
  ///
  /// Returns the median day-of-month across salary-category income transactions.
  int? _inferSalaryDay() {
    final now = DateTime.now();
    final days = <int>[];

    for (int i = 1; i <= 3; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final salaryTxs = transactionService
          .transactionsForMonth(d.year, d.month)
          .where((t) => t.isIncome && t.category.name == 'salary')
          .toList();
      for (final t in salaryTxs) {
        days.add(t.date.day);
      }
    }

    if (days.isEmpty) return null;
    days.sort();
    return days[days.length ~/ 2];
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<bool> _shouldEmit(String alertType, String subject) async {
    return !(await alertRepository.wasRecentlyEmitted(
      alertType: alertType,
      subject: subject,
    ));
  }

  Future<void> _emit({
    required String alertType,
    required String subject,
    required String title,
    required String body,
  }) async {
    // Fire notification
    try {
      await notificationService.showImmediateNotification(
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('[AlertEngine] Notification send failed: $e');
    }

    // Persist deduplication record
    await alertRepository.insert(
      AlertRecord(
        id: _uuid.v4(),
        alertType: alertType,
        subject: subject,
        emittedAt: DateTime.now(),
      ),
    );
  }

  int _freqToDays(String frequency) {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'yearly':
        return 365;
      default:
        return 30; // monthly
    }
  }
}
