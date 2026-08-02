import '../models/tool_call.dart';
import '../preprocessing/amount_parser.dart';

/// Generates accurate natural-language summaries from tool results
/// without relying on the LLM, so numbers are always exact.
class ToolResultFormatter {
  const ToolResultFormatter._();

  /// Returns a human-readable summary string for the given [tool] result,
  /// or `null` if no deterministic summary is available (falls back to LLM).
  static String? format(String tool, ToolResult result) {
    if (!result.ok || result.result == null) return null;
    final r = result.result!;

    switch (tool) {
      case 'createTransaction':
        return r['message'] as String?;

      case 'updateTransaction':
        return 'Done — transaction updated.';

      case 'deleteTransaction':
        return 'Done — transaction deleted.';

      case 'createRecurringTransaction':
        return r['message'] as String?;

      case 'cancelRecurringTransaction':
        return r['message'] as String?;

      case 'getSpendingSummary':
        return _spendingSummary(r);

      case 'comparePeriods':
        return _comparePeriods(r);

      case 'getBudgetStatus':
        return _budgetStatus(r);

      case 'getForecast':
        return _forecast(r);

      case 'getBalanceForecast':
        return _balanceForecast(r);

      case 'getSavingsRate':
        return _savingsRate(r);

      case 'getFinancialSummary':
        return _financialSummary(r);

      case 'searchTransactions':
        return _searchTransactions(r);

      case 'getRecurringTransactions':
        return _recurringTransactions(r);

      case 'getAnomalies':
        return _anomalies(r);

      case 'getFinancialPlans':
        return _financialPlans(r);

      case 'createFinancialPlan':
        final plan = r['plan'] as Map?;
        final name = plan?['name'] ?? 'plan';
        final target = plan?['targetAmount'];
        final formatted = target != null
            ? AmountParser.formatInr((target as num).toDouble())
            : '';
        return 'Financial plan "$name" created'
            '${formatted.isNotEmpty ? ' with a target of $formatted' : ''}.';

      case 'updateFinancialPlan':
        return 'Plan updated successfully.';

      case 'deleteFinancialPlan':
        return 'Plan deleted.';

      default:
        return null;
    }
  }

  // ── Individual formatters ─────────────────────────────────────────────────

  static String _spendingSummary(Map<String, dynamic> r) {
    final period = _humanPeriod(r['period'] as String? ?? '');
    final expenses = _fmt(r['totalExpenses']);
    final income = _fmt(r['totalIncome']);
    final net = (r['netBalance'] as num?)?.toDouble() ?? 0;
    final netFmt = AmountParser.formatInr(net.abs());
    final netLabel = net >= 0 ? 'surplus' : 'deficit';

    final breakdown = r['categoryBreakdown'] as List?;
    String topCategory = '';
    if (breakdown != null && breakdown.isNotEmpty) {
      final sorted = List<Map>.from(breakdown)
        ..sort(
          (a, b) => ((b['expense'] as num?) ?? 0).compareTo(
            (a['expense'] as num?) ?? 0,
          ),
        );
      final top = sorted.first;
      if ((top['expense'] as num? ?? 0) > 0) {
        topCategory =
            ' Highest spend: ${top['category']} (${_fmt(top['expense'])}).';
      }
    }

    return '$period — Expenses: $expenses, Income: $income, '
        'Net: $netFmt $netLabel.$topCategory';
  }

  static String _comparePeriods(Map<String, dynamic> r) {
    final cur = r['current'] as Map?;
    final prev = r['previous'] as Map?;
    if (cur == null || prev == null) return 'Comparison data unavailable.';

    final curExp = _fmt(cur['totalExpenses']);
    final prevExp = _fmt(prev['totalExpenses']);
    final direction = r['direction'] as String? ?? 'different';
    final pct = r['expenseDeltaPercent'] as num?;
    final pctStr = pct != null ? ' (${pct.abs().toStringAsFixed(1)}%)' : '';
    final curPeriod = _humanPeriod(cur['period'] as String? ?? 'current');
    final prevPeriod = _humanPeriod(prev['period'] as String? ?? 'previous');

    return 'Spending $direction in $curPeriod ($curExp) vs $prevPeriod '
        '($prevExp)$pctStr.';
  }

  static String _budgetStatus(Map<String, dynamic> r) {
    final period = _humanPeriod(r['period'] as String? ?? '');
    final spent = _fmt(r['totalSpent']);
    final limit = r['overallLimit'];

    if (limit == null) {
      return '$period — Total spent: $spent. No overall budget set.';
    }

    final limitFmt = _fmt(limit);
    final warnings = r['warnings'] as List? ?? [];
    if (warnings.isEmpty) {
      return '$period — Spent $spent of $limitFmt budget. '
          "You're within budget.";
    }

    final overallWarning =
        warnings.where((w) => (w as Map)['type'] == 'overall').firstOrNull
            as Map?;
    if (overallWarning != null) {
      final overBy = _fmt(overallWarning['overBy']);
      return '$period — Spent $spent of $limitFmt budget. '
          'Over budget by $overBy!';
    }

    final catWarnings = warnings
        .where((w) => (w as Map)['type'] == 'category')
        .cast<Map>()
        .toList();
    if (catWarnings.isNotEmpty) {
      final names = catWarnings.map((w) => w['category']).join(', ');
      return '$period — Spent $spent of $limitFmt budget. '
          'Category limits exceeded: $names.';
    }

    return '$period — Spent $spent of $limitFmt budget.';
  }

  static String _forecast(Map<String, dynamic> r) {
    final days = r['days'] as num? ?? 30;
    final forecast = _fmt(r['forecastForDays']);
    final projected = _fmt(r['projectedMonthEnd']);
    final daily = _fmt(r['dailyAverage']);
    return 'Daily average: $daily. Projected spend for next $days days: '
        '$forecast. End-of-month projection: $projected.';
  }

  static String _balanceForecast(Map<String, dynamic> r) {
    final start = _fmt(r['startBalance']);
    final lowest = _fmt(r['lowestBalance']);
    final negative = r['daysWithNegativeBalance'] as num? ?? 0;
    final confidence = r['confidencePercent'] as num? ?? 0;

    if (negative > 0) {
      return 'Current balance: $start. Balance may go negative on $negative '
          'day(s). Lowest projected: $lowest. Confidence: $confidence%.';
    }
    return 'Current balance: $start. Lowest projected in period: $lowest. '
        'Confidence: $confidence%.';
  }

  static String _savingsRate(Map<String, dynamic> r) {
    final period = _humanPeriod(r['period'] as String? ?? '');
    final rate = r['formattedRate'] as String? ?? '0%';
    final num rateVal = (r['savingsRate'] as num?) ?? 0;
    String advice;
    if (rateVal >= 20) {
      advice = "Great savings rate!";
    } else if (rateVal >= 10) {
      advice = 'Decent — aim for 20%+ for financial security.';
    } else {
      advice = 'Consider reducing expenses to improve your savings rate.';
    }
    return '$period savings rate: $rate. $advice';
  }

  static String _financialSummary(Map<String, dynamic> r) {
    final period = _humanPeriod(r['period'] as String? ?? '');
    final income = _fmt(r['totalIncome']);
    final expenses = _fmt(r['totalExpenses']);
    final rate = (r['overallSavingsRate'] as num?)?.toStringAsFixed(1) ?? '0';
    return '$period — Income: $income, Expenses: $expenses, '
        'Savings rate: $rate%.';
  }

  static String _searchTransactions(Map<String, dynamic> r) {
    final count = r['count'] as num? ?? 0;
    if (count == 0) return 'No transactions found matching your search.';
    final txs = r['transactions'] as List? ?? [];
    if (txs.isEmpty) return 'No transactions found.';

    final lines = txs
        .take(5)
        .map((t) {
          final m = t as Map;
          return '• ${m['title']} — ${m['formattedAmount']} '
              '(${m['category']}, ${m['date']})';
        })
        .join('\n');

    final more = count > 5 ? '\n…and ${count - 5} more.' : '';
    return 'Found $count transaction(s):\n$lines$more';
  }

  static String _recurringTransactions(Map<String, dynamic> r) {
    final count = r['count'] as num? ?? 0;
    if (count == 0) return 'No recurring transactions set up.';
    final list = r['recurring'] as List? ?? [];
    final lines = list
        .take(5)
        .map((t) {
          final m = t as Map;
          return '• ${m['title']} — ${m['formattedAmount']} (${m['frequency']})';
        })
        .join('\n');
    return '$count recurring transaction(s):\n$lines';
  }

  static String _anomalies(Map<String, dynamic> r) {
    final count = r['count'] as num? ?? 0;
    if (count == 0) {
      return 'No unusual spending patterns detected this month.';
    }
    final list = r['anomalies'] as List? ?? [];
    final lines = list
        .take(3)
        .map((a) {
          final m = a as Map;
          final mult = (m['multiplier'] as num?)?.toStringAsFixed(1);
          return '• ${m['category']}: ${_fmt(m['currentMonth'])}'
              '${mult != null ? ' (${mult}× usual)' : ''}';
        })
        .join('\n');
    return '$count unusual spending pattern(s) detected:\n$lines';
  }

  static String _financialPlans(Map<String, dynamic> r) {
    final count = r['count'] as num? ?? 0;
    if (count == 0) return 'No financial plans found.';
    final plans = r['plans'] as List? ?? [];
    final lines = plans
        .take(5)
        .map((p) {
          final m = p as Map;
          final remaining = _fmt(m['remainingAmount']);
          final date = m['targetDate'] as String? ?? '';
          return '• ${m['name']}: $remaining remaining by $date';
        })
        .join('\n');
    return '$count plan(s):\n$lines';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _fmt(dynamic value) {
    if (value == null) return '₹0';
    return AmountParser.formatInr((value as num).toDouble());
  }

  static String _humanPeriod(String period) {
    switch (period) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'this_week':
        return 'This week';
      case 'last_week':
        return 'Last week';
      case 'this_month':
        return 'This month';
      case 'last_month':
        return 'Last month';
      case 'this_year':
        return 'This year';
      case 'last_year':
        return 'Last year';
      default:
        return period;
    }
  }
}
