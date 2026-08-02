import 'dart:math' as math;

import '../../../core/models/account.dart';
import '../../../core/models/transaction.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/credit_card_bill_service.dart';
import '../../../core/services/transaction_service.dart';
import '../data/tool_dispatcher.dart'; // re-uses PeriodResolver

// ── Result types ──────────────────────────────────────────────────────────────

/// Per-category breakdown entry inside [SpendingSummaryResult].
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryLabel,
    required this.totalExpense,
    required this.totalIncome,
    required this.transactionCount,
  });
  final String categoryLabel;
  final double totalExpense;
  final double totalIncome;
  final int transactionCount;
}

/// Result of [FinancialAnalysisEngine.getSpendingSummary].
class SpendingSummaryResult {
  const SpendingSummaryResult({
    required this.period,
    required this.totalExpenses,
    required this.totalIncome,
    required this.netBalance,
    required this.categoryBreakdown,
    this.categoryFilter,
  });
  final String period;
  final double totalExpenses;
  final double totalIncome;
  final double netBalance;
  final List<CategoryBreakdown> categoryBreakdown;
  final String? categoryFilter;

  Map<String, dynamic> toJson() => {
    'period': period,
    'totalExpenses': totalExpenses,
    'totalIncome': totalIncome,
    'netBalance': netBalance,
    'transactionCount': categoryBreakdown.fold(
      0,
      (s, c) => s + c.transactionCount,
    ),
    'categoryBreakdown': categoryBreakdown
        .map(
          (c) => {
            'category': c.categoryLabel,
            'expense': c.totalExpense,
            'income': c.totalIncome,
            'count': c.transactionCount,
          },
        )
        .toList(),
    if (categoryFilter != null) 'categoryFilter': categoryFilter,
  };
}

/// Result of [FinancialAnalysisEngine.comparePeriods].
class PeriodComparisonResult {
  const PeriodComparisonResult({
    required this.current,
    required this.previous,
    required this.expenseDelta,
    required this.expenseDeltaPercent,
    required this.incomeDelta,
    required this.incomeDeltaPercent,
  });
  final SpendingSummaryResult current;
  final SpendingSummaryResult previous;
  final double expenseDelta;

  /// null when previous expenses are 0 (avoid division by zero).
  final double? expenseDeltaPercent;
  final double incomeDelta;
  final double? incomeDeltaPercent;

  String get direction => expenseDelta >= 0 ? 'higher' : 'lower';

  Map<String, dynamic> toJson() => {
    'current': current.toJson(),
    'previous': previous.toJson(),
    'expenseDelta': expenseDelta,
    if (expenseDeltaPercent != null) 'expenseDeltaPercent': expenseDeltaPercent,
    'direction': direction,
    'incomeDelta': incomeDelta,
    if (incomeDeltaPercent != null) 'incomeDeltaPercent': incomeDeltaPercent,
  };
}

/// A detected spending anomaly.
class AnomalyResult {
  const AnomalyResult({
    required this.categoryLabel,
    required this.currentMonthTotal,
    required this.threeMonthAverage,
    this.multiplier,
    this.note,
  });
  final String categoryLabel;
  final double currentMonthTotal;
  final double threeMonthAverage;

  /// currentMonthTotal / threeMonthAverage. Null when no prior history.
  final double? multiplier;
  final String? note;

  Map<String, dynamic> toJson() => {
    'category': categoryLabel,
    'currentMonth': currentMonthTotal,
    'threeMonthAverage': threeMonthAverage,
    if (multiplier != null) 'multiplier': multiplier,
    if (note != null) 'note': note,
  };
}

/// Monthly entry inside [FinancialSummaryResult].
class MonthlySummaryEntry {
  const MonthlySummaryEntry({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.savingsRate,
    required this.categoryBreakdown,
  });
  final int year;
  final int month;
  final double income;
  final double expenses;
  final double savingsRate;
  final List<CategoryBreakdown> categoryBreakdown;
}

/// Result of [FinancialAnalysisEngine.getFinancialSummary].
class FinancialSummaryResult {
  const FinancialSummaryResult({
    required this.period,
    required this.totalIncome,
    required this.totalExpenses,
    required this.overallSavingsRate,
    required this.monthlyBreakdown,
  });
  final String period;
  final double totalIncome;
  final double totalExpenses;
  final double overallSavingsRate;
  final List<MonthlySummaryEntry> monthlyBreakdown;

  Map<String, dynamic> toJson() => {
    'period': period,
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
    'overallSavingsRate': overallSavingsRate,
    'monthlyBreakdown': monthlyBreakdown
        .map(
          (m) => {
            'year': m.year,
            'month': m.month,
            'income': m.income,
            'expenses': m.expenses,
            'savingsRate': m.savingsRate,
          },
        )
        .toList(),
  };
}

/// A single day in a [BalanceForecast].
class DayForecast {
  const DayForecast({
    required this.date,
    required this.predictedBalance,
    required this.scheduledDebits,
    required this.scheduledCredits,
    this.balanceBelowZero = false,
  });
  final DateTime date;
  final double predictedBalance;
  final double scheduledDebits;
  final double scheduledCredits;
  final bool balanceBelowZero;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'predictedBalance': predictedBalance,
    'scheduledDebits': scheduledDebits,
    'scheduledCredits': scheduledCredits,
    'balanceBelowZero': balanceBelowZero,
  };
}

/// Result of [FinancialAnalysisEngine.getBalanceForecast].
class BalanceForecast {
  const BalanceForecast({
    required this.startBalance,
    required this.days,
    required this.confidencePercent,
  });
  final double startBalance;
  final List<DayForecast> days;
  final int confidencePercent;

  Map<String, dynamic> toJson() => {
    'startBalance': startBalance,
    'confidencePercent': confidencePercent,
    'days': days.map((d) => d.toJson()).toList(),
    'lowestBalance': days.isEmpty
        ? startBalance
        : days.map((d) => d.predictedBalance).reduce(math.min),
    'daysWithNegativeBalance': days.where((d) => d.balanceBelowZero).length,
  };
}

/// A detected recurring-subscription candidate.
class SubscriptionCandidate {
  const SubscriptionCandidate({
    required this.title,
    required this.categoryLabel,
    required this.approximateAmount,
    required this.consecutiveMonths,
    required this.source,
  });

  /// `recurring` = detected via isRecurring flag; `pattern` = inferred from history.
  final String source;
  final String title;
  final String categoryLabel;
  final double approximateAmount;
  final int consecutiveMonths;

  Map<String, dynamic> toJson() => {
    'title': title,
    'category': categoryLabel,
    'approximateAmount': approximateAmount,
    'consecutiveMonths': consecutiveMonths,
    'source': source,
  };
}

// ── Engine ────────────────────────────────────────────────────────────────────

/// Deterministic financial analysis engine.
///
/// All methods read data from existing services — no LLM calls here.
/// Called exclusively by [ToolDispatcher] and [AlertEngine].
class FinancialAnalysisEngine {
  FinancialAnalysisEngine({
    required this.transactionService,
    required this.accountService,
    required this.budgetService,
    required this.creditCardBillService,
    PeriodResolver? periodResolver,
  }) : _periodResolver = periodResolver ?? PeriodResolver();

  final TransactionService transactionService;
  final AccountService accountService;
  final BudgetService budgetService;
  final CreditCardBillService creditCardBillService;
  final PeriodResolver _periodResolver;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Category-wise spending and income totals for [period].
  SpendingSummaryResult getSpendingSummary({
    required String period,
    String? category,
  }) {
    final range = _periodResolver.resolve(period);
    var txs = _txsForRange(range.start, range.end);

    if (category != null) {
      txs = txs
          .where(
            (t) => t.category.label.toLowerCase() == category.toLowerCase(),
          )
          .toList();
    }

    final expenses = txs
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = txs
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);

    final breakdownMap = <String, CategoryBreakdown>{};
    for (final t in txs) {
      final label = t.category.label;
      final existing = breakdownMap[label];
      breakdownMap[label] = CategoryBreakdown(
        categoryLabel: label,
        totalExpense:
            (existing?.totalExpense ?? 0) + (t.isExpense ? t.amount : 0),
        totalIncome: (existing?.totalIncome ?? 0) + (t.isIncome ? t.amount : 0),
        transactionCount: (existing?.transactionCount ?? 0) + 1,
      );
    }

    return SpendingSummaryResult(
      period: period,
      totalExpenses: expenses,
      totalIncome: income,
      netBalance: income - expenses,
      categoryBreakdown: breakdownMap.values.toList(),
      categoryFilter: category,
    );
  }

  /// Absolute and percentage difference in spending/income between two periods.
  PeriodComparisonResult comparePeriods({
    required String current,
    required String previous,
    String? category,
  }) {
    final cur = getSpendingSummary(period: current, category: category);
    final prev = getSpendingSummary(period: previous, category: category);

    final expDelta = cur.totalExpenses - prev.totalExpenses;
    final expPct = prev.totalExpenses > 0
        ? (expDelta / prev.totalExpenses) * 100
        : null;

    final incDelta = cur.totalIncome - prev.totalIncome;
    final incPct = prev.totalIncome > 0
        ? (incDelta / prev.totalIncome) * 100
        : null;

    return PeriodComparisonResult(
      current: cur,
      previous: prev,
      expenseDelta: expDelta,
      expenseDeltaPercent: expPct,
      incomeDelta: incDelta,
      incomeDeltaPercent: incPct,
    );
  }

  /// Savings rate for [period] as a percentage (0–100). Returns 0 when income is 0.
  double getSavingsRate({required String period}) {
    final summary = getSpendingSummary(period: period);
    if (summary.totalIncome <= 0) return 0.0;
    return math.max(
      0.0,
      ((summary.totalIncome - summary.totalExpenses) / summary.totalIncome) *
          100,
    );
  }

  /// Categories where current-month spending exceeds 2× their 3-month average.
  List<AnomalyResult> getAnomalies() {
    final now = DateTime.now();
    final results = <AnomalyResult>[];

    for (final cat in TransactionCategory.values) {
      final thisMonth = _categoryExpense(cat, now.year, now.month);

      // 3-month rolling average
      double total = 0;
      int monthsWithData = 0;
      for (int i = 1; i <= 3; i++) {
        final d = DateTime(now.year, now.month - i, 1);
        final amt = _categoryExpense(cat, d.year, d.month);
        if (amt > 0) {
          total += amt;
          monthsWithData++;
        }
      }
      final avg = monthsWithData > 0 ? total / 3 : 0.0;

      if (avg > 0 && thisMonth > 2.0 * avg) {
        results.add(
          AnomalyResult(
            categoryLabel: cat.label,
            currentMonthTotal: thisMonth,
            threeMonthAverage: avg,
            multiplier: thisMonth / avg,
          ),
        );
      } else if (avg == 0 && thisMonth > 0) {
        results.add(
          AnomalyResult(
            categoryLabel: cat.label,
            currentMonthTotal: thisMonth,
            threeMonthAverage: 0,
            note: 'No prior history in this category.',
          ),
        );
      }
    }

    results.sort((a, b) => (b.multiplier ?? 0).compareTo(a.multiplier ?? 0));
    return results;
  }

  /// Yearly (or partial-year) income/expense summary broken down by month.
  FinancialSummaryResult getFinancialSummary({required String period}) {
    final now = DateTime.now();
    final year = period == 'last_year' ? now.year - 1 : now.year;
    final months = <MonthlySummaryEntry>[];

    double totalIncome = 0;
    double totalExpenses = 0;

    for (int m = 1; m <= 12; m++) {
      final txs = transactionService.transactionsForMonth(year, m);
      final inc = txs
          .where((t) => t.isIncome && t.isMonthly)
          .fold(0.0, (s, t) => s + t.amount);
      final exp = txs
          .where((t) => t.isExpense && t.isMonthly)
          .fold(0.0, (s, t) => s + t.amount);
      final rate = inc > 0 ? math.max(0.0, ((inc - exp) / inc) * 100) : 0.0;

      final breakdownMap = <String, CategoryBreakdown>{};
      for (final t in txs) {
        if (!t.isExpense && !t.isIncome) continue;
        final label = t.category.label;
        final existing = breakdownMap[label];
        breakdownMap[label] = CategoryBreakdown(
          categoryLabel: label,
          totalExpense:
              (existing?.totalExpense ?? 0) + (t.isExpense ? t.amount : 0),
          totalIncome:
              (existing?.totalIncome ?? 0) + (t.isIncome ? t.amount : 0),
          transactionCount: (existing?.transactionCount ?? 0) + 1,
        );
      }

      months.add(
        MonthlySummaryEntry(
          year: year,
          month: m,
          income: inc,
          expenses: exp,
          savingsRate: rate,
          categoryBreakdown: breakdownMap.values.toList(),
        ),
      );

      totalIncome += inc;
      totalExpenses += exp;
    }

    final overallRate = totalIncome > 0
        ? math.max(0.0, ((totalIncome - totalExpenses) / totalIncome) * 100)
        : 0.0;

    return FinancialSummaryResult(
      period: period,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      overallSavingsRate: overallRate,
      monthlyBreakdown: months,
    );
  }

  /// Predicted day-by-day account balance for the next [days] days.
  BalanceForecast getBalanceForecast({String? accountId, int days = 30}) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // 1. Starting balance
    final accounts = accountId != null
        ? accountService.all.where((a) => a.id == accountId).toList()
        : accountService.all
              .where((a) => a.type != AccountType.creditCard)
              .toList();
    final startBalance = accounts.fold(0.0, (s, a) => s + a.balance);

    // 2. Initialise daily debit/credit maps
    final debits = <int, double>{};
    final credits = <int, double>{};

    void addDebit(DateTime date, double amount) {
      final idx = date.difference(today).inDays;
      if (idx >= 0 && idx < days) debits[idx] = (debits[idx] ?? 0) + amount;
    }

    void addCredit(DateTime date, double amount) {
      final idx = date.difference(today).inDays;
      if (idx >= 0 && idx < days) credits[idx] = (credits[idx] ?? 0) + amount;
    }

    // 3. Recurring transactions
    for (final t in transactionService.getRecurringTemplates()) {
      final freq = t.recurringFrequency ?? 'monthly';
      final stepDays = _freqToDays(freq);
      if (stepDays <= 0) continue;

      // Find next occurrence on or after today
      DateTime next = t.date;
      while (next.isBefore(today)) {
        next = next.add(Duration(days: stepDays));
      }
      while (next.isBefore(today.add(Duration(days: days)))) {
        if (t.isExpense) addDebit(next, t.amount);
        if (t.isIncome) addCredit(next, t.amount);
        next = next.add(Duration(days: stepDays));
      }
    }

    // 4. Unpaid credit card bills
    for (final bill in creditCardBillService.all) {
      if (bill.isUnpaid && !bill.billDate.isBefore(today)) {
        addDebit(bill.billDate, bill.billAmount);
      }
    }

    // 5. Active EMI amounts
    for (final t in transactionService.allTransactions) {
      if (!t.isEmi || t.emiMonthlyAmount == null) continue;
      // Schedule one EMI payment per month within the window
      var next = DateTime(today.year, today.month, t.date.day);
      if (next.isBefore(today))
        next = DateTime(today.year, today.month + 1, t.date.day);
      if (!next.isBefore(today.add(Duration(days: days))))
        addDebit(next, t.emiMonthlyAmount!);
    }

    // 6. Build running balance
    final forecastDays = <DayForecast>[];
    double running = startBalance;

    for (int i = 0; i < days; i++) {
      final d = debits[i] ?? 0.0;
      final c = credits[i] ?? 0.0;
      running = running - d + c;
      forecastDays.add(
        DayForecast(
          date: today.add(Duration(days: i)),
          predictedBalance: running,
          scheduledDebits: d,
          scheduledCredits: c,
          balanceBelowZero: running < 0,
        ),
      );
    }

    // 7. Confidence level
    final historyMonths = _countMonthsWithTransactions();
    final confidence = historyMonths >= 3
        ? 85
        : historyMonths >= 1
        ? 65
        : 40;

    return BalanceForecast(
      startBalance: startBalance,
      days: forecastDays,
      confidencePercent: confidence,
    );
  }

  /// Average monthly surplus (income − expenses) over the past [monthsBack] months.
  double estimateMonthlySurplus({int monthsBack = 3}) {
    final now = DateTime.now();
    double total = 0;
    int counted = 0;
    for (int i = 1; i <= monthsBack; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final inc = transactionService.incomeForMonth(d.year, d.month);
      final exp = transactionService.expensesForMonth(d.year, d.month);
      if (inc > 0 || exp > 0) {
        total += inc - exp;
        counted++;
      }
    }
    return counted > 0 ? total / counted : 0.0;
  }

  /// Detect recurring subscription candidates.
  List<SubscriptionCandidate> detectSubscriptions() {
    final subscriptionCategories = {
      TransactionCategory.entertainment,
      TransactionCategory.utilities,
      TransactionCategory.bills,
    };

    final seen = <String>{};
    final results = <SubscriptionCandidate>[];

    // From explicit recurring templates
    for (final t in transactionService.getRecurringTemplates()) {
      if (!subscriptionCategories.contains(t.category)) continue;
      final key = '${t.title}_${t.category.name}';
      if (seen.add(key)) {
        results.add(
          SubscriptionCandidate(
            source: 'recurring',
            title: t.title,
            categoryLabel: t.category.label,
            approximateAmount: t.amount,
            consecutiveMonths: 3, // template implies ongoing
          ),
        );
      }
    }

    // Pattern-based detection
    final txs = transactionService.allTransactions
        .where((t) => t.isExpense)
        .toList();
    final groups = <String, List<Transaction>>{};
    for (final t in txs) {
      final key = '${t.title.toLowerCase().trim()}_${t.category.name}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    for (final entry in groups.entries) {
      final list = entry.value;
      if (list.length < 3) continue;

      final monthSet = <String>{};
      for (final t in list) {
        monthSet.add('${t.date.year}-${t.date.month}');
      }
      if (monthSet.length < 3) continue;

      final consecutive = _longestConsecutiveMonthRun(list);
      if (consecutive < 3) continue;

      final amounts = list.map((t) => t.amount).toList();
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance =
          amounts.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) /
          amounts.length;
      final stddev = math.sqrt(variance);
      if (mean > 0 && stddev / mean > 0.05) continue;

      final key = '${list.first.title}_${list.first.category.name}';
      if (seen.add(key)) {
        results.add(
          SubscriptionCandidate(
            source: 'pattern',
            title: list.first.title,
            categoryLabel: list.first.category.label,
            approximateAmount: mean,
            consecutiveMonths: consecutive,
          ),
        );
      }
    }

    return results;
  }

  /// Average monthly salary income over the past [monthsBack] months.
  double inferAverageMonthlySalary({int monthsBack = 3}) {
    final now = DateTime.now();
    double total = 0;
    int counted = 0;
    for (int i = 1; i <= monthsBack; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final salary = transactionService
          .transactionsForMonth(d.year, d.month)
          .where((t) => t.isIncome && t.category == TransactionCategory.salary)
          .fold(0.0, (s, t) => s + t.amount);
      if (salary > 0) {
        total += salary;
        counted++;
      }
    }
    return counted > 0 ? total / counted : 0.0;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  List<Transaction> _txsForRange(DateTime start, DateTime end) {
    return transactionService.allTransactions.where((t) {
      return !t.date.isBefore(start) && t.date.isBefore(end);
    }).toList();
  }

  double _categoryExpense(TransactionCategory cat, int year, int month) {
    return transactionService
        .transactionsForMonth(year, month)
        .where((t) => t.isExpense && t.category == cat)
        .fold(0.0, (s, t) => s + t.amount);
  }

  int _countMonthsWithTransactions() {
    final months = <String>{};
    for (final t in transactionService.allTransactions) {
      months.add('${t.date.year}-${t.date.month}');
    }
    return months.length;
  }

  int _freqToDays(String frequency) {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'monthly':
        return 30;
      case 'yearly':
        return 365;
      default:
        return 30;
    }
  }

  int _longestConsecutiveMonthRun(List<Transaction> txs) {
    if (txs.isEmpty) return 0;
    final months =
        txs.map((t) => t.date.year * 12 + t.date.month).toSet().toList()
          ..sort();
    int max = 1, current = 1;
    for (int i = 1; i < months.length; i++) {
      if (months[i] == months[i - 1] + 1) {
        current++;
        if (current > max) max = current;
      } else {
        current = 1;
      }
    }
    return max;
  }
}
