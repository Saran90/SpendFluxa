import 'package:flutter/foundation.dart';
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

  /// Resolves an account from free text using a type-first approach:
  ///
  /// 1. Detect account type from keywords in [text]
  ///    (credit card, wallet, cash, bank, savings)
  /// 2. Filter accounts to only that type
  /// 3. Word-match within that filtered list
  /// 4. If confident match found → return it
  /// 5. If ambiguous (multiple accounts, low score) → return null
  ///    so the caller shows the picker
  ///
  /// Returns the account ID on confident match, null if ambiguous/unknown.
  String? tryResolveAccountFromText(String text) {
    final q = text.trim().toLowerCase();
    final accounts = accountService.all;
    if (accounts.isEmpty) return null;

    // ── Step 1: detect account type from keywords ─────────────────────────
    AccountType? detectedType;

    // Credit card check — must come before bank since "credit card" contains
    // no "bank" but "bank credit card" contains "bank".
    // Prioritise explicit "credit card" / "credit" / "cc" phrase.
    final isCreditCard =
        q.contains('credit card') ||
        q.contains('credit card') ||
        RegExp(r'\bcredit\b').hasMatch(q) ||
        RegExp(r'\bcc\b').hasMatch(q);

    final isWallet =
        q.contains('wallet') ||
        RegExp(
          r'\b(paytm|phonepe|gpay|google pay|amazon pay|freecharge|mobikwik|upi)\b',
        ).hasMatch(q);

    final isCash = RegExp(r'\bcash\b').hasMatch(q);

    final isSavings =
        q.contains('savings account') ||
        RegExp(r'\b(fd|fixed deposit|recurring deposit|rd)\b').hasMatch(q);

    // Bank: has "bank" but NOT "credit" (otherwise it's a bank credit card)
    final isBank = RegExp(r'\bbank\b').hasMatch(q) && !isCreditCard;

    if (isCreditCard) {
      detectedType = AccountType.creditCard;
    } else if (isWallet) {
      detectedType = AccountType.wallet;
    } else if (isCash) {
      detectedType = AccountType.cash;
    } else if (isSavings) {
      detectedType = AccountType.savings;
    } else if (isBank) {
      detectedType = AccountType.bank;
    }

    // ── Step 2: filter to detected type (or all if unknown) ───────────────
    final pool = detectedType != null
        ? accounts.where((a) => a.type == detectedType).toList()
        : accounts;

    if (pool.isEmpty) return null;

    // If only one account of that type, return it directly
    if (pool.length == 1) return pool.first.id;

    // ── Step 3: word-match within the pool ────────────────────────────────
    // Strip the type keyword from the query so we match on the bank/card name
    // e.g. "federal bank super credit card" → strip "credit card" → "federal bank super"
    var nameQuery = q
        .replaceAll('credit card', '')
        .replaceAll('debit card', '')
        .replaceAll('credit', '')
        .replaceAll('wallet', '')
        .replaceAll('bank account', '')
        .replaceAll('savings account', '')
        .replaceAll('cash', '')
        .replaceAll(RegExp(r'\b(using|via|with|from|through|on|by)\b'), '')
        .trim();

    // If nothing meaningful left, fall back to full query
    if (nameQuery.length < 3) nameQuery = q;

    final queryWords = nameQuery
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toList();

    if (queryWords.isEmpty) {
      // No name words — if single type match return first, else null (show picker)
      return detectedType != null ? pool.first.id : null;
    }

    final scores = <String, int>{};
    for (final a in pool) {
      final name = a.name.toLowerCase();
      int score = 0;

      // Full cleaned query contained in name
      if (name.contains(nameQuery)) score += 50;
      // Full name contained in query
      if (nameQuery.contains(name)) score += 40;

      // Word-level matching
      final nameWords = name.split(RegExp(r'\W+'));
      for (final qw in queryWords) {
        for (final nw in nameWords) {
          if (nw == qw) {
            score += 20; // exact word
          } else if (nw.contains(qw) || qw.contains(nw)) {
            score += 8; // partial
          }
        }
      }
      scores[a.id] = score;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Step 4: confident if top score is clearly ahead ───────────────────
    if (sorted.isNotEmpty && sorted.first.value > 0) {
      // Confident if top score ≥ 20 AND at least 2× the second score
      final topScore = sorted.first.value;
      final secondScore = sorted.length > 1 ? sorted[1].value : 0;
      if (topScore >= 20 && topScore >= secondScore * 2) {
        return sorted.first.key;
      }
      // Only one account matched at all
      final nonZero = sorted.where((e) => e.value > 0).toList();
      if (nonZero.length == 1) return nonZero.first.key;
    }

    // ── Step 5: ambiguous — return null so picker is shown ────────────────
    return null;
  }

  /// Returns accounts filtered to the type detected in [text].
  /// Used by the account picker to pre-filter the list when the type is clear.
  AccountType? detectAccountTypeFromText(String text) {
    final q = text.trim().toLowerCase();
    if (q.contains('credit card') ||
        RegExp(r'\bcredit\b').hasMatch(q) ||
        RegExp(r'\bcc\b').hasMatch(q)) {
      return AccountType.creditCard;
    }
    if (q.contains('wallet') ||
        RegExp(r'\b(paytm|phonepe|gpay|google pay|upi)\b').hasMatch(q)) {
      return AccountType.wallet;
    }
    if (RegExp(r'\bcash\b').hasMatch(q)) return AccountType.cash;
    if (q.contains('savings account') ||
        RegExp(r'\b(fd|fixed deposit)\b').hasMatch(q)) {
      return AccountType.savings;
    }
    if (RegExp(r'\bbank\b').hasMatch(q)) return AccountType.bank;
    return null;
  }

  /// Returns the best-matching category plus up to [maxCandidates] alternatives,
  /// ordered by relevance. The first element is always the best match.
  /// [input] can be a rich query (LLM category arg + full user message).
  List<TransactionCategory> resolveCategoryWithCandidates(
    TransactionType type,
    String? input, {
    int maxCandidates = 4,
  }) {
    // Filter categories valid for this transaction type
    final validCats = TransactionCategory.values.where((cat) {
      if (type == TransactionType.income) {
        return const {
          TransactionCategory.salary,
          TransactionCategory.freelance,
          TransactionCategory.investment,
          TransactionCategory.gift,
          TransactionCategory.cashback,
        }.contains(cat);
      }
      if (type == TransactionType.transfer) {
        return const {
          TransactionCategory.savings,
          TransactionCategory.childEducation,
          TransactionCategory.vacation,
          TransactionCategory.emergencyFund,
          TransactionCategory.transferInvestment,
          TransactionCategory.houseDownPayment,
          TransactionCategory.retirement,
          TransactionCategory.transferOther,
        }.contains(cat);
      }
      // expense — exclude income/transfer categories
      return !const {
        TransactionCategory.salary,
        TransactionCategory.freelance,
        TransactionCategory.investment,
        TransactionCategory.gift,
        TransactionCategory.cashback,
        TransactionCategory.savings,
        TransactionCategory.childEducation,
        TransactionCategory.vacation,
        TransactionCategory.emergencyFund,
        TransactionCategory.transferInvestment,
        TransactionCategory.houseDownPayment,
        TransactionCategory.retirement,
        TransactionCategory.transferOther,
      }.contains(cat);
    }).toList();

    // Get the best match via the synonym-aware resolver
    final best = _resolveCategory(type, input);

    if (input == null || input.trim().isEmpty) {
      // No input — return best + first N-1 valid categories
      final result = <TransactionCategory>[best];
      for (final cat in validCats) {
        if (result.length >= maxCandidates) break;
        if (!result.contains(cat)) result.add(cat);
      }
      return result;
    }

    // Extract meaningful query words from the rich input.
    // Strip numbers, payment phrases, stop words — keep item/action words.
    // Also normalize underscores/hyphens to spaces.
    final stripped = input
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .replaceAll(RegExp(r'[\d,₹]+'), '') // remove numbers/amounts
        .replaceAll(
          RegExp(
            r'\b(using|with|via|through|on|by|from|for|the|a|an|my|some|bought|paid|spent|got|add|added|expense|income)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final qWords = stripped
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toSet()
        .toList();

    debugPrint('[CategoryScore] input="$input" qWords=$qWords');

    // Score each valid category
    final scored = <TransactionCategory, int>{};
    for (final cat in validCats) {
      int score = 0;

      // Always boost the best match so it stays first
      if (cat == best) score += 100;

      final label = cat.label.toLowerCase();
      final name = cat.name.toLowerCase();

      // Exact full label/name match with any query word
      for (final qw in qWords) {
        if (label == qw || name == qw) score += 50;
        if (label.contains(qw)) score += 25;
        if (qw.contains(label)) score += 20;
        if (name.contains(qw)) score += 15;
        if (qw.contains(name)) score += 12;
        // Word-level overlap within multi-word labels
        for (final lw in label.split(RegExp(r'\W+'))) {
          if (lw.length > 2) {
            if (lw == qw)
              score += 20;
            else if (lw.contains(qw) || qw.contains(lw))
              score += 8;
          }
        }
      }

      scored[cat] = score;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint(
      '[CategoryScore] top5: ${sorted.take(5).map((e) => "${e.key.label}=${e.value}").join(", ")}',
    );

    // Build result: best first, then up to maxCandidates-1 alternatives
    final result = <TransactionCategory>[best];
    final remaining = sorted.where((e) => e.key != best).toList();

    // First: categories with meaningful score
    for (final entry in remaining) {
      if (result.length >= maxCandidates) break;
      if (entry.value > 0) result.add(entry.key);
    }

    // Pad if needed
    for (final entry in remaining) {
      if (result.length >= maxCandidates) break;
      if (!result.contains(entry.key)) result.add(entry.key);
    }

    return result;
  }

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

    // Normalize: lowercase, replace underscores/hyphens with spaces, collapse whitespace
    final q = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 1. Exact enum name (after normalization)
    for (final cat in TransactionCategory.values) {
      if (cat.name.toLowerCase() == q) return cat;
    }

    // 2. Exact label
    for (final cat in TransactionCategory.values) {
      if (cat.label.toLowerCase() == q) return cat;
    }

    // 3. Comprehensive item-to-category map.
    // Covers single words AND multi-word phrases (checked longest first).
    // Indian household items, services, and common LLM outputs are included.
    const synonyms = <String, TransactionCategory>{
      // ── Grocery ──────────────────────────────────────────────────────────
      'groceries': TransactionCategory.grocery,
      'grocery': TransactionCategory.grocery,
      'supermarket': TransactionCategory.grocery,
      'kirana': TransactionCategory.grocery,
      'provision': TransactionCategory.grocery,
      'provisions': TransactionCategory.grocery,
      'rice': TransactionCategory.grocery,
      'wheat': TransactionCategory.grocery,
      'flour': TransactionCategory.grocery,
      'maida': TransactionCategory.grocery,
      'atta': TransactionCategory.grocery,
      'dal': TransactionCategory.grocery,
      'lentils': TransactionCategory.grocery,
      'pulses': TransactionCategory.grocery,
      'oil': TransactionCategory.grocery,
      'ghee': TransactionCategory.grocery,
      'butter': TransactionCategory.grocery,
      'milk': TransactionCategory.grocery,
      'curd': TransactionCategory.grocery,
      'yogurt': TransactionCategory.grocery,
      'cheese': TransactionCategory.grocery,
      'eggs': TransactionCategory.grocery,
      'sugar': TransactionCategory.grocery,
      'salt': TransactionCategory.grocery,
      'spices': TransactionCategory.grocery,
      'masala': TransactionCategory.grocery,
      'turmeric': TransactionCategory.grocery,
      'chilli': TransactionCategory.grocery,
      'pepper': TransactionCategory.grocery,
      'tea': TransactionCategory.grocery,
      'coffee powder': TransactionCategory.grocery,
      'tea powder': TransactionCategory.grocery,
      'biscuits': TransactionCategory.grocery,
      'oats': TransactionCategory.grocery,
      'cereals': TransactionCategory.grocery,
      'bread': TransactionCategory.grocery,
      'noodles': TransactionCategory.grocery,
      'pasta': TransactionCategory.grocery,
      'soap': TransactionCategory.grocery,
      'shampoo': TransactionCategory.grocery,
      'detergent': TransactionCategory.grocery,
      'toothpaste': TransactionCategory.grocery,
      'toothbrush': TransactionCategory.grocery,
      'tissue': TransactionCategory.grocery,
      'sanitary': TransactionCategory.grocery,
      'household': TransactionCategory.grocery,

      // ── Vegetables ───────────────────────────────────────────────────────
      'vegetables': TransactionCategory.vegetables,
      'veggies': TransactionCategory.vegetables,
      'vegetable': TransactionCategory.vegetables,
      'sabzi': TransactionCategory.vegetables,
      'tomato': TransactionCategory.vegetables,
      'onion': TransactionCategory.vegetables,
      'potato': TransactionCategory.vegetables,
      'carrot': TransactionCategory.vegetables,
      'cabbage': TransactionCategory.vegetables,
      'spinach': TransactionCategory.vegetables,
      'cauliflower': TransactionCategory.vegetables,
      'brinjal': TransactionCategory.vegetables,
      'bitter gourd': TransactionCategory.vegetables,
      'lady finger': TransactionCategory.vegetables,
      'okra': TransactionCategory.vegetables,
      'beans': TransactionCategory.vegetables,
      'peas': TransactionCategory.vegetables,
      'corn': TransactionCategory.vegetables,
      'garlic': TransactionCategory.vegetables,
      'ginger': TransactionCategory.vegetables,
      'coriander': TransactionCategory.vegetables,
      'mint': TransactionCategory.vegetables,
      'fruits': TransactionCategory.vegetables,
      'mango': TransactionCategory.vegetables,
      'banana': TransactionCategory.vegetables,
      'apple': TransactionCategory.vegetables,
      'orange': TransactionCategory.vegetables,

      // ── Food & Dining ─────────────────────────────────────────────────────
      'food': TransactionCategory.food,
      'restaurant': TransactionCategory.food,
      'dining': TransactionCategory.food,
      'eating out': TransactionCategory.food,
      'lunch': TransactionCategory.food,
      'dinner': TransactionCategory.food,
      'breakfast': TransactionCategory.food,
      'hotel': TransactionCategory.food,
      'dhaba': TransactionCategory.food,
      'biryani': TransactionCategory.food,
      'pizza': TransactionCategory.food,
      'burger': TransactionCategory.food,
      'swiggy': TransactionCategory.food,
      'zomato': TransactionCategory.food,
      'food delivery': TransactionCategory.food,
      'cafe': TransactionCategory.food,
      'canteen': TransactionCategory.food,
      'mess': TransactionCategory.food,

      // ── Drinks & Snacks ───────────────────────────────────────────────────
      'coffee': TransactionCategory.drinksAndSnacks,
      'drinks': TransactionCategory.drinksAndSnacks,
      'snacks': TransactionCategory.drinksAndSnacks,
      'snack': TransactionCategory.drinksAndSnacks,
      'juice': TransactionCategory.drinksAndSnacks,
      'cold drink': TransactionCategory.drinksAndSnacks,
      'cold drinks': TransactionCategory.drinksAndSnacks,
      'beverage': TransactionCategory.drinksAndSnacks,
      'beverages': TransactionCategory.drinksAndSnacks,
      'chips': TransactionCategory.drinksAndSnacks,
      'chocolate': TransactionCategory.drinksAndSnacks,
      'candy': TransactionCategory.drinksAndSnacks,
      'ice cream': TransactionCategory.drinksAndSnacks,
      'tea stall': TransactionCategory.drinksAndSnacks,
      'chai': TransactionCategory.drinksAndSnacks,

      // ── Bakery ────────────────────────────────────────────────────────────
      'bakery': TransactionCategory.bakery,
      'cake': TransactionCategory.bakery,
      'sweets': TransactionCategory.bakery,
      'mithai': TransactionCategory.bakery,
      'ladoo': TransactionCategory.bakery,
      'halwa': TransactionCategory.bakery,
      'puff': TransactionCategory.bakery,
      'croissant': TransactionCategory.bakery,
      'pastry': TransactionCategory.bakery,

      // ── Bills ─────────────────────────────────────────────────────────────
      'bill': TransactionCategory.bills,
      'bills': TransactionCategory.bills,
      'electricity bill': TransactionCategory.bills,
      'water bill': TransactionCategory.bills,
      'gas bill': TransactionCategory.bills,
      'phone bill': TransactionCategory.bills,
      'mobile bill': TransactionCategory.bills,
      'landline bill': TransactionCategory.bills,
      'broadband bill': TransactionCategory.bills,
      'cable bill': TransactionCategory.bills,
      'maintenance': TransactionCategory.bills,
      'society maintenance': TransactionCategory.bills,
      'property tax': TransactionCategory.bills,
      'credit card bill': TransactionCategory.bills,
      'emi': TransactionCategory.bills,

      // ── Utilities ─────────────────────────────────────────────────────────
      'utilities': TransactionCategory.utilities,
      'utility': TransactionCategory.utilities,
      'electricity': TransactionCategory.utilities,
      'power': TransactionCategory.utilities,
      'water': TransactionCategory.utilities,
      'internet': TransactionCategory.utilities,
      'wifi': TransactionCategory.utilities,
      'broadband': TransactionCategory.utilities,
      'recharge': TransactionCategory.utilities,
      'mobile recharge': TransactionCategory.utilities,
      'phone recharge': TransactionCategory.utilities,
      'prepaid recharge': TransactionCategory.utilities,
      'dth recharge': TransactionCategory.utilities,
      'dth': TransactionCategory.utilities,
      'tata sky': TransactionCategory.utilities,
      'airtel dth': TransactionCategory.utilities,
      'gas cylinder': TransactionCategory.utilities,
      'lpg cylinder': TransactionCategory.utilities,
      'lpg': TransactionCategory.utilities,
      'cylinder': TransactionCategory.utilities,
      'cooking gas': TransactionCategory.utilities,
      'piped gas': TransactionCategory.utilities,
      'postpaid': TransactionCategory.utilities,
      'jio': TransactionCategory.utilities,
      'airtel': TransactionCategory.utilities,
      'bsnl': TransactionCategory.utilities,
      'vi': TransactionCategory.utilities,

      // ── Transport ─────────────────────────────────────────────────────────
      'transport': TransactionCategory.transport,
      'cab': TransactionCategory.transport,
      'taxi': TransactionCategory.transport,
      'auto': TransactionCategory.transport,
      'bus': TransactionCategory.transport,
      'metro': TransactionCategory.transport,
      'train': TransactionCategory.transport,
      'uber': TransactionCategory.transport,
      'ola': TransactionCategory.transport,
      'rapido': TransactionCategory.transport,
      'local train': TransactionCategory.transport,
      'rickshaw': TransactionCategory.transport,
      'bike taxi': TransactionCategory.transport,
      'commute': TransactionCategory.transport,
      'ticket': TransactionCategory.transport,
      'travel ticket': TransactionCategory.transport,

      // ── Fuel ─────────────────────────────────────────────────────────────
      'fuel': TransactionCategory.fuel,
      'petrol': TransactionCategory.fuel,
      'diesel': TransactionCategory.fuel,
      'gas station': TransactionCategory.fuel,
      'filling': TransactionCategory.fuel,
      'fuel filling': TransactionCategory.fuel,
      'cng': TransactionCategory.fuel,
      'ev charging': TransactionCategory.fuel,

      // ── Health ────────────────────────────────────────────────────────────
      'health': TransactionCategory.health,
      'medical': TransactionCategory.health,
      'doctor': TransactionCategory.health,
      'hospital': TransactionCategory.health,
      'clinic': TransactionCategory.health,
      'pharmacy': TransactionCategory.health,
      'medicine': TransactionCategory.health,
      'medicines': TransactionCategory.health,
      'tablets': TransactionCategory.health,
      'tablet': TransactionCategory.health,
      'injection': TransactionCategory.health,
      'test': TransactionCategory.health,
      'lab test': TransactionCategory.health,
      'blood test': TransactionCategory.health,
      'scan': TransactionCategory.health,
      'xray': TransactionCategory.health,
      'consultation': TransactionCategory.health,
      'dentist': TransactionCategory.health,
      'eye': TransactionCategory.health,
      'glasses': TransactionCategory.health,
      'gym': TransactionCategory.health,
      'fitness': TransactionCategory.health,
      'yoga': TransactionCategory.health,

      // ── Shopping ──────────────────────────────────────────────────────────
      'shopping': TransactionCategory.shopping,
      'clothes': TransactionCategory.shopping,
      'clothing': TransactionCategory.shopping,
      'shirt': TransactionCategory.shopping,
      'pants': TransactionCategory.shopping,
      'dress': TransactionCategory.shopping,
      'saree': TransactionCategory.shopping,
      'shoes': TransactionCategory.shopping,
      'footwear': TransactionCategory.shopping,
      'bag': TransactionCategory.shopping,
      'accessories': TransactionCategory.shopping,
      'watch': TransactionCategory.shopping,
      'jewellery': TransactionCategory.shopping,
      'jewelry': TransactionCategory.shopping,
      'toys': TransactionCategory.shopping,
      'toy': TransactionCategory.shopping,
      'electronics': TransactionCategory.shopping,
      'gadget': TransactionCategory.shopping,
      'gadgets': TransactionCategory.shopping,
      'phone': TransactionCategory.shopping,
      'mobile': TransactionCategory.shopping,
      'laptop': TransactionCategory.shopping,
      'appliance': TransactionCategory.shopping,
      'appliances': TransactionCategory.shopping,
      'amazon': TransactionCategory.shopping,
      'flipkart': TransactionCategory.shopping,
      'meesho': TransactionCategory.shopping,
      'myntra': TransactionCategory.shopping,
      'online shopping': TransactionCategory.shopping,

      // ── Entertainment ─────────────────────────────────────────────────────
      'entertainment': TransactionCategory.entertainment,
      'movie': TransactionCategory.entertainment,
      'movies': TransactionCategory.entertainment,
      'cinema': TransactionCategory.entertainment,
      'theatre': TransactionCategory.entertainment,
      'netflix': TransactionCategory.entertainment,
      'hotstar': TransactionCategory.entertainment,
      'prime video': TransactionCategory.entertainment,
      'spotify': TransactionCategory.entertainment,
      'youtube premium': TransactionCategory.entertainment,
      'ott': TransactionCategory.entertainment,
      'game': TransactionCategory.entertainment,
      'gaming': TransactionCategory.entertainment,
      'concert': TransactionCategory.entertainment,
      'show': TransactionCategory.entertainment,
      'event': TransactionCategory.entertainment,
      'amusement': TransactionCategory.entertainment,
      'park': TransactionCategory.entertainment,
      'subscription': TransactionCategory.entertainment,

      // ── Education ─────────────────────────────────────────────────────────
      'education': TransactionCategory.education,
      'school': TransactionCategory.education,
      'college': TransactionCategory.education,
      'university': TransactionCategory.education,
      'tuition': TransactionCategory.education,
      'coaching': TransactionCategory.education,
      'course': TransactionCategory.education,
      'udemy': TransactionCategory.education,
      'coursera': TransactionCategory.education,
      'fees': TransactionCategory.education,
      'admission': TransactionCategory.education,
      'exam': TransactionCategory.education,
      'books': TransactionCategory.education,
      'stationery': TransactionCategory.education,
      'notebook': TransactionCategory.education,
      'pencil': TransactionCategory.education,

      // ── Insurance ─────────────────────────────────────────────────────────
      'insurance': TransactionCategory.insurance,
      'premium': TransactionCategory.insurance,
      'life insurance': TransactionCategory.insurance,
      'health insurance': TransactionCategory.insurance,
      'car insurance': TransactionCategory.insurance,
      'vehicle insurance': TransactionCategory.insurance,
      'term plan': TransactionCategory.insurance,
      'policy': TransactionCategory.insurance,
      'lic': TransactionCategory.insurance,

      // ── Rent ─────────────────────────────────────────────────────────────
      'rent': TransactionCategory.rent,
      'house rent': TransactionCategory.rent,
      'room rent': TransactionCategory.rent,
      'pg': TransactionCategory.rent,
      'hostel': TransactionCategory.rent,
      'accommodation': TransactionCategory.rent,
      'lease': TransactionCategory.rent,

      // ── Income ────────────────────────────────────────────────────────────
      'salary': TransactionCategory.salary,
      'income': TransactionCategory.salary,
      'wage': TransactionCategory.salary,
      'stipend': TransactionCategory.salary,
      'freelance': TransactionCategory.freelance,
      'freelancing': TransactionCategory.freelance,
      'project payment': TransactionCategory.freelance,
      'side income': TransactionCategory.freelance,
      'investment': TransactionCategory.investment,
      'dividend': TransactionCategory.investment,
      'interest': TransactionCategory.investment,
      'returns': TransactionCategory.investment,
      'gift': TransactionCategory.gift,
      'cashback': TransactionCategory.cashback,
      'refund': TransactionCategory.cashback,
      'reward': TransactionCategory.cashback,
    };

    // Check full query first
    if (synonyms.containsKey(q)) return synonyms[q]!;

    // Check multi-word phrases by looking for any synonym key contained in q
    // Sort by length descending to prefer longer (more specific) matches
    final sortedKeys = synonyms.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      if (key.contains(' ') && q.contains(key)) return synonyms[key]!;
    }

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
  /// Resolves an account ID from a name/phrase or a direct ID.
  /// If [accountName] is already a valid account ID in the DB, returns it directly.
  /// Otherwise delegates to [tryResolveAccountFromText] for fuzzy matching.
  String? _resolveAccountId(String? accountName) {
    if (accountName == null || accountName.trim().isEmpty) {
      return accountService.defaultAccount?.id;
    }

    // Check if the value is already a direct account ID (UUID injected by enrichment)
    final directMatch = accountService.all
        .where((a) => a.id == accountName)
        .firstOrNull;
    if (directMatch != null) return directMatch.id;

    // Fuzzy name/phrase matching
    final resolved = tryResolveAccountFromText(accountName);
    return resolved ?? accountService.defaultAccount?.id;
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
