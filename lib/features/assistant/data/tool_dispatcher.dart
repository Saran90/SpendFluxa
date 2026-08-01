import 'package:uuid/uuid.dart';

import '../../../core/models/transaction.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/transaction_service.dart';
import '../constants/tool_schemas.dart';
import '../models/tool_call.dart';
import '../preprocessing/amount_parser.dart';

/// Resolves period strings to date ranges.
class PeriodResolver {
  PeriodResolver({DateTime? reference}) : _ref = reference ?? DateTime.now();

  final DateTime _ref;

  ({DateTime start, DateTime end, int year, int month}) resolve(String period) {
    final now = DateTime(_ref.year, _ref.month, _ref.day);
    switch (period) {
      case 'today':
        return (
          start: now,
          end: now.add(const Duration(days: 1)),
          year: now.year,
          month: now.month,
        );
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        return (start: y, end: now, year: y.year, month: y.month);
      case 'this_week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (
          start: start,
          end: start.add(const Duration(days: 7)),
          year: now.year,
          month: now.month,
        );
      case 'last_week':
        final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = thisWeekStart.subtract(const Duration(days: 7));
        return (
          start: start,
          end: thisWeekStart,
          year: start.year,
          month: start.month,
        );
      case 'last_month':
        final m = DateTime(now.year, now.month - 1, 1);
        return (
          start: m,
          end: DateTime(now.year, now.month, 1),
          year: m.year,
          month: m.month,
        );
      case 'this_year':
        return (
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
          year: now.year,
          month: now.month,
        );
      case 'last_year':
        return (
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year, 1, 1),
          year: now.year - 1,
          month: 1,
        );
      case 'this_month':
      default:
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
          year: now.year,
          month: now.month,
        );
    }
  }
}

/// Executes whitelisted tool functions against local repositories.
class ToolDispatcher {
  ToolDispatcher({
    required this.transactionService,
    required this.accountService,
    required this.budgetService,
    required this.categoryService,
    PeriodResolver? periodResolver,
  }) : _periodResolver = periodResolver ?? PeriodResolver();

  final TransactionService transactionService;
  final AccountService accountService;
  final BudgetService budgetService;
  final CategoryService categoryService;
  final PeriodResolver _periodResolver;
  final _uuid = const Uuid();

  Future<ToolResult> dispatch(ToolCall call) async {
    switch (call.tool) {
      case FluxAiTools.createTransaction:
        return _createTransaction(call.arguments);
      case FluxAiTools.getSpendingSummary:
        return _getSpendingSummary(call.arguments);
      case FluxAiTools.comparePeriods:
        return _comparePeriods(call.arguments);
      case FluxAiTools.getRecurringTransactions:
        return _getRecurringTransactions();
      case FluxAiTools.getBudgetStatus:
        return _getBudgetStatus(call.arguments);
      case FluxAiTools.getForecast:
        return _getForecast(call.arguments);
      default:
        return ToolResult.failure('Unknown tool: ${call.tool}');
    }
  }

  Future<ToolResult> _createTransaction(Map<String, dynamic> args) async {
    final amount = (args['amount'] as num).toDouble();
    final typeStr = args['type'] as String;
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );

    final categoryLabel = args['category'] as String?;
    final category = _resolveCategory(type, categoryLabel);

    final dateIso = args['dateIso'] as String?;
    final date = dateIso != null ? DateTime.parse(dateIso) : DateTime.now();

    final accountName = args['account'] as String?;
    final accountId = _resolveAccountId(accountName);

    final payee = args['payee'] as String?;
    final note = args['note'] as String?;
    final title = payee ?? note ?? category.label;

    final id = _uuid.v4();
    final tx = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note,
      accountId: accountId,
    );

    await transactionService.addTransaction(tx);

    final formatted = AmountParser.formatInr(amount);
    final typeLabel = typeStr;
    return ToolResult.success({
      'transactionId': id,
      'message':
          '${typeLabel[0].toUpperCase()}${typeLabel.substring(1)} of $formatted added to ${category.label}.',
    });
  }

  Future<ToolResult> _getSpendingSummary(Map<String, dynamic> args) async {
    final period = args['period'] as String;
    final categoryFilter = args['category'] as String?;
    final range = _periodResolver.resolve(period);

    var txs = transactionService.transactionsForMonth(range.year, range.month);
    if (period == 'today' || period == 'yesterday') {
      txs = txs.where((t) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        return !d.isBefore(range.start) && d.isBefore(range.end);
      }).toList();
    }

    if (categoryFilter != null) {
      txs = txs.where((t) => t.category.label == categoryFilter).toList();
    }

    final expenses = txs
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);
    final income = txs
        .where((t) => t.isIncome)
        .fold(0.0, (s, t) => s + t.amount);

    return ToolResult.success({
      'period': period,
      'category': categoryFilter,
      'totalExpenses': expenses,
      'totalIncome': income,
      'transactionCount': txs.length,
      'formattedExpenses': AmountParser.formatInr(expenses),
      'formattedIncome': AmountParser.formatInr(income),
    });
  }

  Future<ToolResult> _comparePeriods(Map<String, dynamic> args) async {
    final current = args['current'] as String;
    final previous = args['previous'] as String;

    final currentResult = await _getSpendingSummary({'period': current});
    final previousResult = await _getSpendingSummary({'period': previous});

    if (!currentResult.ok || !previousResult.ok) {
      return ToolResult.failure('Failed to compare periods');
    }

    final curExp = currentResult.result!['totalExpenses'] as double;
    final prevExp = previousResult.result!['totalExpenses'] as double;
    final delta = curExp - prevExp;
    final pct = prevExp > 0 ? (delta / prevExp) * 100 : 0.0;

    return ToolResult.success({
      'current': currentResult.result,
      'previous': previousResult.result,
      'expenseDelta': delta,
      'expenseDeltaPercent': pct,
      'formattedDelta': AmountParser.formatInr(delta.abs()),
      'direction': delta >= 0 ? 'higher' : 'lower',
    });
  }

  Future<ToolResult> _getRecurringTransactions() async {
    final templates = transactionService.getRecurringTemplates();
    final items = templates
        .map(
          (t) => {
            'title': t.title,
            'amount': t.amount,
            'category': t.category.label,
            'frequency': t.recurringFrequency ?? 'monthly',
            'formattedAmount': AmountParser.formatInr(t.amount),
          },
        )
        .toList();

    return ToolResult.success({'count': items.length, 'recurring': items});
  }

  Future<ToolResult> _getBudgetStatus(Map<String, dynamic> args) async {
    final period = args['period'] as String? ?? 'this_month';
    final range = _periodResolver.resolve(period);
    final budget = budgetService.budgetFor(range.year, range.month);

    final spent = transactionService.expensesForMonth(range.year, range.month);
    final overallLimit = budget.overallLimit;
    final warnings = <Map<String, dynamic>>[];

    if (overallLimit != null && spent > overallLimit) {
      warnings.add({
        'type': 'overall',
        'limit': overallLimit,
        'spent': spent,
        'overBy': spent - overallLimit,
      });
    }

    for (final entry in budget.categoryLimits.entries) {
      final catSpent = transactionService
          .transactionsForMonth(range.year, range.month)
          .where((t) => t.category == entry.key && t.isExpense)
          .fold(0.0, (s, t) => s + t.amount);
      if (catSpent > entry.value) {
        warnings.add({
          'type': 'category',
          'category': entry.key.label,
          'limit': entry.value,
          'spent': catSpent,
          'overBy': catSpent - entry.value,
        });
      }
    }

    return ToolResult.success({
      'period': period,
      'overallLimit': overallLimit,
      'totalSpent': spent,
      'formattedSpent': AmountParser.formatInr(spent),
      'warnings': warnings,
      'categoryLimits': budget.categoryLimits.map(
        (k, v) => MapEntry(k.label, v),
      ),
    });
  }

  Future<ToolResult> _getForecast(Map<String, dynamic> args) async {
    final days = (args['days'] as num).toInt();
    final now = DateTime.now();
    final range = _periodResolver.resolve('this_month');
    final spentSoFar = transactionService.expensesForMonth(
      range.year,
      range.month,
    );
    final dayOfMonth = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAvg = dayOfMonth > 0 ? spentSoFar / dayOfMonth : 0.0;
    final projected = dailyAvg * daysInMonth;
    final forecastPeriod = dailyAvg * days;

    return ToolResult.success({
      'days': days,
      'dailyAverage': dailyAvg,
      'projectedMonthEnd': projected,
      'forecastForDays': forecastPeriod,
      'formattedForecast': AmountParser.formatInr(forecastPeriod),
      'formattedProjected': AmountParser.formatInr(projected),
    });
  }

  TransactionCategory _resolveCategory(TransactionType type, String? label) {
    if (label == null) {
      return type == TransactionType.income
          ? TransactionCategory.salary
          : TransactionCategory.other;
    }

    for (final cat in TransactionCategory.values) {
      if (cat.label.toLowerCase() == label.toLowerCase()) {
        return cat;
      }
    }
    return TransactionCategory.other;
  }

  String? _resolveAccountId(String? accountName) {
    if (accountName == null || accountName.isEmpty) {
      return accountService.defaultAccount?.id;
    }
    final match = accountService.all.where(
      (a) => a.name.toLowerCase().contains(accountName.toLowerCase()),
    );
    return match.isNotEmpty
        ? match.first.id
        : accountService.defaultAccount?.id;
  }
}
