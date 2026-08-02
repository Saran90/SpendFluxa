import 'package:uuid/uuid.dart';

import '../../../core/models/account.dart';
import '../../../core/models/transaction.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/transaction_service.dart';
import '../constants/tool_schemas.dart';
import '../engine/financial_analysis_engine.dart';
import '../engine/plan_manager.dart';
import '../engine/tag_fuzzy_matcher.dart';
import '../models/financial_plan.dart';
import '../models/tool_call.dart';
import '../preprocessing/amount_parser.dart';

// ── Period resolver ───────────────────────────────────────────────────────────

/// Resolves period strings (e.g. `this_month`) to concrete date ranges.
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
        final s = now.subtract(Duration(days: now.weekday - 1));
        return (
          start: s,
          end: s.add(const Duration(days: 7)),
          year: now.year,
          month: now.month,
        );
      case 'last_week':
        final ts = now.subtract(Duration(days: now.weekday - 1));
        final s = ts.subtract(const Duration(days: 7));
        return (start: s, end: ts, year: s.year, month: s.month);
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
      default: // this_month
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
          year: now.year,
          month: now.month,
        );
    }
  }
}

// ── Tool Dispatcher ───────────────────────────────────────────────────────────

/// Executes all 19 whitelisted tool calls against local services.
///
/// Every method returns a [ToolResult]. Callers should check [ToolResult.ok]
/// before using [ToolResult.result].
class ToolDispatcher {
  ToolDispatcher({
    required this.transactionService,
    required this.accountService,
    required this.budgetService,
    required this.categoryService,
    required this.planManager,
    required this.analysisEngine,
    required this.tagFuzzyMatcher,
    PeriodResolver? periodResolver,
  }) : _periodResolver = periodResolver ?? PeriodResolver();

  final TransactionService transactionService;
  final AccountService accountService;
  final BudgetService budgetService;
  final CategoryService categoryService;
  final PlanManager planManager;
  final FinancialAnalysisEngine analysisEngine;
  final TagFuzzyMatcher tagFuzzyMatcher;
  final PeriodResolver _periodResolver;
  final _uuid = const Uuid();

  // ── Dispatch ───────────────────────────────────────────────────────────────

  Future<ToolResult> dispatch(ToolCall call) async {
    try {
      switch (call.tool) {
        case FluxAiTools.createTransaction:
          return await _createTransaction(call.arguments);
        case FluxAiTools.updateTransaction:
          return await _updateTransaction(call.arguments);
        case FluxAiTools.deleteTransaction:
          return await _deleteTransaction(call.arguments);
        case FluxAiTools.searchTransactions:
          return await _searchTransactions(call.arguments);
        case FluxAiTools.createRecurringTransaction:
          return await _createRecurringTransaction(call.arguments);
        case FluxAiTools.cancelRecurringTransaction:
          return await _cancelRecurringTransaction(call.arguments);
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
        case FluxAiTools.getBalanceForecast:
          return _getBalanceForecast(call.arguments);
        case FluxAiTools.getAnomalies:
          return _getAnomalies();
        case FluxAiTools.getSavingsRate:
          return _getSavingsRate(call.arguments);
        case FluxAiTools.getFinancialSummary:
          return _getFinancialSummary(call.arguments);
        case FluxAiTools.getFinancialPlans:
          return await _getFinancialPlans(call.arguments);
        case FluxAiTools.createFinancialPlan:
          return await _createFinancialPlan(call.arguments);
        case FluxAiTools.updateFinancialPlan:
          return await _updateFinancialPlan(call.arguments);
        case FluxAiTools.deleteFinancialPlan:
          return await _deleteFinancialPlan(call.arguments);
        default:
          return ToolResult.failure('Unknown tool: ${call.tool}');
      }
    } catch (e) {
      return ToolResult.failure('Tool execution error: $e');
    }
  }

  // ── Transaction tools ──────────────────────────────────────────────────────

  Future<ToolResult> _createTransaction(Map<String, dynamic> args) async {
    final amount = (args['amount'] as num).toDouble();
    final typeStr = args['type'] as String;
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );
    final category = _resolveCategory(type, args['category'] as String?);
    final date = args['dateIso'] != null
        ? DateTime.parse(args['dateIso'] as String)
        : DateTime.now();
    final accountId = _resolveAccountId(args['account'] as String?);
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

    return ToolResult.success({
      'transactionId': id,
      'message':
          '${_capitalize(typeStr)} of ${AmountParser.formatInr(amount)} added to ${category.label}.',
    });
  }

  Future<ToolResult> _updateTransaction(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final existing = transactionService.allTransactions
        .where((t) => t.id == id)
        .firstOrNull;
    if (existing == null)
      return ToolResult.failure('Transaction not found: $id');

    final updated = existing.copyWith(
      amount: args['amount'] != null
          ? (args['amount'] as num).toDouble()
          : null,
      type: args['type'] != null
          ? TransactionType.values.firstWhere(
              (t) => t.name == args['type'],
              orElse: () => existing.type,
            )
          : null,
      category: args['category'] != null
          ? _resolveCategory(existing.type, args['category'] as String)
          : null,
      date: args['dateIso'] != null
          ? DateTime.parse(args['dateIso'] as String)
          : null,
      note: args['note'] as String?,
    );
    await transactionService.updateTransaction(updated);
    return ToolResult.success({
      'transactionId': id,
      'message': 'Transaction updated.',
    });
  }

  Future<ToolResult> _deleteTransaction(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final existing = transactionService.allTransactions
        .where((t) => t.id == id)
        .firstOrNull;
    if (existing == null)
      return ToolResult.failure('Transaction not found: $id');
    await transactionService.removeTransaction(id);
    return ToolResult.success({
      'transactionId': id,
      'message': 'Transaction deleted.',
    });
  }

  Future<ToolResult> _searchTransactions(Map<String, dynamic> args) async {
    var txs = transactionService.allTransactions;

    // Date range
    if (args['dateFrom'] != null) {
      final from = DateTime.parse(args['dateFrom'] as String);
      txs = txs.where((t) => !t.date.isBefore(from)).toList();
    }
    if (args['dateTo'] != null) {
      final to = DateTime.parse(args['dateTo'] as String);
      txs = txs.where((t) => t.date.isBefore(to)).toList();
    }

    // Amount range
    if (args['amountMin'] != null) {
      final min = (args['amountMin'] as num).toDouble();
      txs = txs.where((t) => t.amount >= min).toList();
    }
    if (args['amountMax'] != null) {
      final max = (args['amountMax'] as num).toDouble();
      txs = txs.where((t) => t.amount <= max).toList();
    }

    // Category
    if (args['category'] != null) {
      final cat = args['category'] as String;
      txs = txs
          .where((t) => t.category.label.toLowerCase() == cat.toLowerCase())
          .toList();
    }

    // Account
    if (args['accountId'] != null) {
      final accId = args['accountId'] as String;
      txs = txs.where((t) => t.accountId == accId).toList();
    }

    // Keyword
    if (args['keyword'] != null) {
      final kw = (args['keyword'] as String).toLowerCase();
      txs = txs
          .where(
            (t) =>
                t.title.toLowerCase().contains(kw) ||
                (t.note?.toLowerCase().contains(kw) ?? false),
          )
          .toList();
    }

    // Tag — fuzzy match
    if (args['tagName'] != null) {
      final tagName = args['tagName'] as String;
      final matchResult = tagFuzzyMatcher.resolve(tagName);

      if (matchResult.hasExactMatch) {
        final tagId = matchResult.exactMatch!.id;
        txs = txs.where((t) => t.tagIds.contains(tagId)).toList();
      } else if (matchResult.hasSuggestions) {
        return ToolResult.success({
          'requiresTagSelection': true,
          'suggestions': matchResult.suggestions.map((t) => t.name).toList(),
          'message':
              'No tag named "$tagName" found. Did you mean one of these?',
        });
      } else {
        return ToolResult.success({
          'transactions': [],
          'count': 0,
          'note': 'No matching tags found for "$tagName".',
        });
      }
    }

    final limit = args['limit'] != null ? (args['limit'] as num).toInt() : 20;
    final result = txs.take(limit).toList();

    return ToolResult.success({
      'transactions': result
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'amount': t.amount,
              'formattedAmount': AmountParser.formatInr(t.amount),
              'type': t.type.name,
              'category': t.category.label,
              'date': t.date.toIso8601String().substring(0, 10),
              'note': t.note,
            },
          )
          .toList(),
      'count': result.length,
    });
  }

  Future<ToolResult> _createRecurringTransaction(
    Map<String, dynamic> args,
  ) async {
    final amount = (args['amount'] as num).toDouble();
    final typeStr = args['type'] as String;
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );
    final category = _resolveCategory(type, args['category'] as String?);
    final frequency = args['frequency'] as String;
    final startDate = DateTime.parse(args['startDateIso'] as String);
    final endDate = args['endDateIso'] != null
        ? DateTime.parse(args['endDateIso'] as String)
        : null;
    final title = args['title'] as String;
    final note = args['note'] as String?;
    final accountId = _resolveAccountId(args['account'] as String?);

    final id = _uuid.v4();
    final tx = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: startDate,
      note: note,
      accountId: accountId,
      isRecurring: true,
      recurringFrequency: frequency,
      recurringEndDate: endDate,
    );
    await transactionService.addTransaction(tx);
    return ToolResult.success({
      'transactionId': id,
      'message':
          'Recurring $typeStr of ${AmountParser.formatInr(amount)} created ($frequency).',
    });
  }

  Future<ToolResult> _cancelRecurringTransaction(
    Map<String, dynamic> args,
  ) async {
    final id = args['id'] as String;
    final existing = transactionService.allTransactions
        .where((t) => t.id == id)
        .firstOrNull;
    if (existing == null)
      return ToolResult.failure('Recurring transaction not found: $id');
    await transactionService.removeTransaction(id);
    return ToolResult.success({
      'transactionId': id,
      'message': 'Recurring transaction "${existing.title}" cancelled.',
    });
  }

  // ── Analysis tools ─────────────────────────────────────────────────────────

  ToolResult _getSpendingSummary(Map<String, dynamic> args) {
    final period = args['period'] as String;
    final category = args['category'] as String?;
    final result = analysisEngine.getSpendingSummary(
      period: period,
      category: category,
    );
    return ToolResult.success(result.toJson());
  }

  ToolResult _comparePeriods(Map<String, dynamic> args) {
    final current = args['current'] as String;
    final previous = args['previous'] as String;
    final category = args['category'] as String?;
    final result = analysisEngine.comparePeriods(
      current: current,
      previous: previous,
      category: category,
    );
    return ToolResult.success(result.toJson());
  }

  ToolResult _getRecurringTransactions() {
    final templates = transactionService.getRecurringTemplates();
    return ToolResult.success({
      'count': templates.length,
      'recurring': templates
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'amount': t.amount,
              'formattedAmount': AmountParser.formatInr(t.amount),
              'category': t.category.label,
              'frequency': t.recurringFrequency ?? 'monthly',
              'type': t.type.name,
            },
          )
          .toList(),
    });
  }

  ToolResult _getBudgetStatus(Map<String, dynamic> args) {
    final period = (args['period'] as String?) ?? 'this_month';
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
    });
  }

  ToolResult _getForecast(Map<String, dynamic> args) {
    final days = (args['days'] as num).toInt();
    final now = DateTime.now();
    final range = _periodResolver.resolve('this_month');
    final spentSoFar = transactionService.expensesForMonth(
      range.year,
      range.month,
    );
    final dailyAvg = now.day > 0 ? spentSoFar / now.day : 0.0;
    final projected = dailyAvg * DateTime(now.year, now.month + 1, 0).day;
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

  ToolResult _getBalanceForecast(Map<String, dynamic> args) {
    final accountId = args['accountId'] as String?;
    final days = args['days'] != null ? (args['days'] as num).toInt() : 30;
    final result = analysisEngine.getBalanceForecast(
      accountId: accountId,
      days: days,
    );
    return ToolResult.success(result.toJson());
  }

  ToolResult _getAnomalies() {
    final anomalies = analysisEngine.getAnomalies();
    return ToolResult.success({
      'count': anomalies.length,
      'anomalies': anomalies.map((a) => a.toJson()).toList(),
    });
  }

  ToolResult _getSavingsRate(Map<String, dynamic> args) {
    final period = args['period'] as String;
    final rate = analysisEngine.getSavingsRate(period: period);
    return ToolResult.success({
      'period': period,
      'savingsRate': rate,
      'formattedRate': '${rate.toStringAsFixed(1)}%',
    });
  }

  ToolResult _getFinancialSummary(Map<String, dynamic> args) {
    final period = args['period'] as String;
    final result = analysisEngine.getFinancialSummary(period: period);
    return ToolResult.success(result.toJson());
  }

  // ── Plan tools ─────────────────────────────────────────────────────────────

  Future<ToolResult> _getFinancialPlans(Map<String, dynamic> args) async {
    PlanType? type;
    if (args['type'] != null) {
      type = PlanType.values.firstWhere(
        (t) => t.name == args['type'],
        orElse: () => PlanType.goal,
      );
    }
    final plans = await planManager.getPlans(type: type);
    return ToolResult.success({
      'count': plans.length,
      'plans': plans.map(_planToJson).toList(),
    });
  }

  Future<ToolResult> _createFinancialPlan(Map<String, dynamic> args) async {
    try {
      final plan = FinancialPlan(
        id: _uuid.v4(),
        name: args['name'] as String,
        type: PlanType.values.firstWhere(
          (t) => t.name == args['type'],
          orElse: () => PlanType.goal,
        ),
        targetAmount: (args['targetAmount'] as num).toDouble(),
        targetDate: DateTime.parse(args['targetDate'] as String),
        contributionFrequency: ContributionFrequency.values.firstWhere(
          (f) => f.name == args['contributionFrequency'],
          orElse: () => ContributionFrequency.monthly,
        ),
        priority: args['priority'] != null
            ? PlanPriority.values.firstWhere(
                (p) => p.name == args['priority'],
                orElse: () => PlanPriority.medium,
              )
            : null,
        currentSavings: args['currentSavings'] != null
            ? (args['currentSavings'] as num).toDouble()
            : 0,
        preferredAccountId: args['preferredAccountId'] as String?,
        createdAt: DateTime.now(),
      );
      final created = await planManager.createPlan(plan);
      return ToolResult.success({
        'planId': created.id,
        'plan': _planToJson(created),
      });
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  }

  Future<ToolResult> _updateFinancialPlan(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    final existing = await planManager.getById(id);
    if (existing == null) return ToolResult.failure('Plan not found: $id');
    try {
      final updated = existing.copyWith(
        name: args['name'] as String?,
        targetAmount: args['targetAmount'] != null
            ? (args['targetAmount'] as num).toDouble()
            : null,
        targetDate: args['targetDate'] != null
            ? DateTime.parse(args['targetDate'] as String)
            : null,
        currentSavings: args['currentSavings'] != null
            ? (args['currentSavings'] as num).toDouble()
            : null,
        preferredAccountId: args['preferredAccountId'] as String?,
        priority: args['priority'] != null
            ? PlanPriority.values.firstWhere(
                (p) => p.name == args['priority'],
                orElse: () => PlanPriority.medium,
              )
            : null,
        contributionFrequency: args['contributionFrequency'] != null
            ? ContributionFrequency.values.firstWhere(
                (f) => f.name == args['contributionFrequency'],
                orElse: () => existing.contributionFrequency,
              )
            : null,
      );
      final result = await planManager.updatePlan(updated);
      return ToolResult.success({'planId': id, 'plan': _planToJson(result)});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  }

  Future<ToolResult> _deleteFinancialPlan(Map<String, dynamic> args) async {
    final id = args['id'] as String;
    await planManager.deletePlan(id);
    return ToolResult.success({'planId': id, 'message': 'Plan deleted.'});
  }

  /// Tries to resolve an account ID purely from free text (e.g. a user message).
  /// Returns the account ID string (name) if found, null otherwise.
  /// This is used by [ConversationManager] to enrich tool calls before dispatch.
  String? tryResolveAccountFromText(String text) {
    final q = text.trim().toLowerCase();
    final accounts = accountService.all;
    if (accounts.isEmpty) return null;

    // Substring match on account name
    for (final a in accounts) {
      if (q.contains(a.name.toLowerCase())) return a.id;
    }

    // Word-level match
    final queryWords = q.split(RegExp(r'\W+')).where((w) => w.length > 2);
    for (final a in accounts) {
      final nameWords = a.name.toLowerCase().split(RegExp(r'\W+'));
      for (final qw in queryWords) {
        for (final nw in nameWords) {
          if (nw.contains(qw) || qw.contains(nw)) return a.id;
        }
      }
    }

    // Type keyword
    final creditCardKeywords = ['credit', 'card', 'cc'];
    final walletKeywords = ['wallet', 'paytm', 'phonepe', 'gpay', 'upi'];
    final cashKeywords = ['cash'];
    final savingsKeywords = ['savings', 'fd'];

    bool matchesAny(Iterable<String> keywords) =>
        keywords.any((k) => q.contains(k));

    if (matchesAny(creditCardKeywords)) {
      return accounts
          .where((a) => a.type == AccountType.creditCard)
          .firstOrNull
          ?.id;
    }
    if (matchesAny(walletKeywords)) {
      return accounts
          .where((a) => a.type == AccountType.wallet)
          .firstOrNull
          ?.id;
    }
    if (matchesAny(cashKeywords)) {
      return accounts.where((a) => a.type == AccountType.cash).firstOrNull?.id;
    }
    if (matchesAny(savingsKeywords)) {
      return accounts
          .where((a) => a.type == AccountType.savings)
          .firstOrNull
          ?.id;
    }

    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Resolves a category label from the LLM using fuzzy matching.
  ///
  /// Matching order:
  /// 1. Exact enum name match (e.g. "grocery" → TransactionCategory.grocery)
  /// 2. Exact label match (case-insensitive)
  /// 3. Synonym / keyword map
  /// 4. Substring match against label
  /// 5. Any label that contains the input word
  /// 6. Default (salary for income, other for expense/transfer)
  TransactionCategory _resolveCategory(TransactionType type, String? input) {
    if (input == null || input.trim().isEmpty) {
      return type == TransactionType.income
          ? TransactionCategory.salary
          : TransactionCategory.other;
    }

    final q = input.trim().toLowerCase();

    // 1. Exact enum name
    for (final cat in TransactionCategory.values) {
      if (cat.name.toLowerCase() == q) return cat;
    }

    // 2. Exact label
    for (final cat in TransactionCategory.values) {
      if (cat.label.toLowerCase() == q) return cat;
    }

    // 3. Synonym map — covers common LLM outputs
    const synonyms = <String, TransactionCategory>{
      'groceries': TransactionCategory.grocery,
      'supermarket': TransactionCategory.grocery,
      'vegetables': TransactionCategory.vegetables,
      'veggies': TransactionCategory.vegetables,
      'food': TransactionCategory.food,
      'restaurant': TransactionCategory.food,
      'dining': TransactionCategory.food,
      'eating': TransactionCategory.food,
      'cafe': TransactionCategory.food,
      'coffee': TransactionCategory.drinksAndSnacks,
      'drinks': TransactionCategory.drinksAndSnacks,
      'snacks': TransactionCategory.drinksAndSnacks,
      'beverage': TransactionCategory.drinksAndSnacks,
      'bakery': TransactionCategory.bakery,
      'bread': TransactionCategory.bakery,
      'sweets': TransactionCategory.bakery,
      'transport': TransactionCategory.transport,
      'cab': TransactionCategory.transport,
      'taxi': TransactionCategory.transport,
      'auto': TransactionCategory.transport,
      'bus': TransactionCategory.transport,
      'metro': TransactionCategory.transport,
      'train': TransactionCategory.transport,
      'uber': TransactionCategory.transport,
      'ola': TransactionCategory.transport,
      'fuel': TransactionCategory.fuel,
      'petrol': TransactionCategory.fuel,
      'diesel': TransactionCategory.fuel,
      'gas': TransactionCategory.fuel,
      'shopping': TransactionCategory.shopping,
      'clothes': TransactionCategory.shopping,
      'apparel': TransactionCategory.shopping,
      'fashion': TransactionCategory.shopping,
      'entertainment': TransactionCategory.entertainment,
      'movie': TransactionCategory.entertainment,
      'netflix': TransactionCategory.entertainment,
      'subscription': TransactionCategory.entertainment,
      'health': TransactionCategory.health,
      'medical': TransactionCategory.health,
      'doctor': TransactionCategory.health,
      'pharmacy': TransactionCategory.health,
      'medicine': TransactionCategory.health,
      'hospital': TransactionCategory.health,
      'utilities': TransactionCategory.utilities,
      'electricity': TransactionCategory.utilities,
      'water': TransactionCategory.utilities,
      'internet': TransactionCategory.utilities,
      'wifi': TransactionCategory.utilities,
      'rent': TransactionCategory.rent,
      'house': TransactionCategory.rent,
      'home': TransactionCategory.rent,
      'education': TransactionCategory.education,
      'school': TransactionCategory.education,
      'college': TransactionCategory.education,
      'tuition': TransactionCategory.education,
      'books': TransactionCategory.education,
      'bills': TransactionCategory.bills,
      'insurance': TransactionCategory.insurance,
      'salary': TransactionCategory.salary,
      'income': TransactionCategory.salary,
      'freelance': TransactionCategory.freelance,
      'investment': TransactionCategory.investment,
      'gift': TransactionCategory.gift,
      'cashback': TransactionCategory.cashback,
      'savings': TransactionCategory.savings,
      'vacation': TransactionCategory.vacation,
      'travel': TransactionCategory.vacation,
      'trip': TransactionCategory.vacation,
    };
    if (synonyms.containsKey(q)) return synonyms[q]!;

    // 4. Partial word match: any category label that contains the query word
    for (final cat in TransactionCategory.values) {
      if (cat.label.toLowerCase().contains(q)) return cat;
    }

    // 5. Query contains a category label word
    for (final cat in TransactionCategory.values) {
      final labelWords = cat.label.toLowerCase().split(RegExp(r'\W+'));
      for (final word in labelWords) {
        if (word.isNotEmpty && q.contains(word)) return cat;
      }
    }

    return type == TransactionType.income
        ? TransactionCategory.salary
        : TransactionCategory.other;
  }

  /// Resolves an account ID from the LLM-provided account name using fuzzy
  /// matching against the user's actual accounts.
  ///
  /// Matching order:
  /// 1. Exact name match
  /// 2. Name contains the query (or query contains the name)
  /// 3. Any word in the query matches a word in the account name
  /// 4. Account type keyword (e.g. "credit card", "wallet", "cash")
  /// 5. Default account
  String? _resolveAccountId(String? accountName) {
    final accounts = accountService.all;
    if (accounts.isEmpty) return null;

    if (accountName == null || accountName.trim().isEmpty) {
      return accountService.defaultAccount?.id;
    }

    final q = accountName.trim().toLowerCase();

    // 1. Exact name
    for (final a in accounts) {
      if (a.name.toLowerCase() == q) return a.id;
    }

    // 2. Substring both ways
    for (final a in accounts) {
      final name = a.name.toLowerCase();
      if (name.contains(q) || q.contains(name)) return a.id;
    }

    // 3. Word-level match — any word in the query matches any word in name
    final queryWords = q.split(RegExp(r'\W+')).where((w) => w.length > 2);
    for (final a in accounts) {
      final nameWords = a.name.toLowerCase().split(RegExp(r'\W+'));
      for (final qw in queryWords) {
        for (final nw in nameWords) {
          if (nw.contains(qw) || qw.contains(nw)) return a.id;
        }
      }
    }

    // 4. Account type keyword fallback
    final creditCardKeywords = ['credit', 'card', 'cc'];
    final walletKeywords = ['wallet', 'paytm', 'phonepe', 'gpay'];
    final cashKeywords = ['cash'];
    final savingsKeywords = ['savings', 'fd', 'deposit'];

    bool matchesAny(Iterable<String> keywords) =>
        keywords.any((k) => q.contains(k));

    if (matchesAny(creditCardKeywords)) {
      final cc = accounts
          .where((a) => a.type == AccountType.creditCard)
          .firstOrNull;
      if (cc != null) return cc.id;
    }
    if (matchesAny(walletKeywords)) {
      final w = accounts.where((a) => a.type == AccountType.wallet).firstOrNull;
      if (w != null) return w.id;
    }
    if (matchesAny(cashKeywords)) {
      final c = accounts.where((a) => a.type == AccountType.cash).firstOrNull;
      if (c != null) return c.id;
    }
    if (matchesAny(savingsKeywords)) {
      final s = accounts
          .where((a) => a.type == AccountType.savings)
          .firstOrNull;
      if (s != null) return s.id;
    }

    return accountService.defaultAccount?.id;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Map<String, dynamic> _planToJson(FinancialPlan p) => {
    'id': p.id,
    'name': p.name,
    'type': p.type.name,
    'targetAmount': p.targetAmount,
    'targetDate': p.targetDate.toIso8601String().substring(0, 10),
    'currentSavings': p.currentSavings,
    'remainingAmount': p.remainingAmount,
    'contributionFrequency': p.contributionFrequency.name,
    if (p.priority != null) 'priority': p.priority!.name,
    if (p.requiredContribution != null)
      'requiredContribution': p.requiredContribution,
    if (p.achievable != null) 'achievable': p.achievable,
    if (p.estimatedCompletionDate != null)
      'estimatedCompletionDate': p.estimatedCompletionDate!
          .toIso8601String()
          .substring(0, 10),
    'atRisk': p.atRisk,
    'suggestions': p.suggestions,
  };
}
