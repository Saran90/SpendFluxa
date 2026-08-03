import 'dart:convert';

import '../constants/tool_schemas.dart';
import '../models/tool_call.dart';

class ToolCallValidationResult {
  const ToolCallValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;
}

/// Parses and validates whitelisted tool calls against JSON schema rules.
class ToolCallValidator {
  /// Attempts to extract a tool call JSON object from [text].
  ///
  /// Handles:
  /// - Raw JSON
  /// - Markdown code-fenced JSON (` ```json ... ``` `)
  /// - Truncated JSON missing closing braces (model cut off mid-output)
  ///
  /// Returns `null` if no valid `{"tool": ..., "arguments": ...}` object
  /// is found. Never throws.
  ToolCall? tryParse(String text) {
    // Strip markdown code fences the model sometimes wraps around JSON.
    final stripped = text
        .replaceAll(RegExp(r'```(?:json)?\s*', caseSensitive: false), '')
        .trim();

    if (!stripped.contains('{')) return null;

    final start = stripped.indexOf('{');
    if (start < 0) return null;

    final base = stripped.substring(start);
    for (final candidate in [base, '$base}', '$base}}']) {
      final end = candidate.lastIndexOf('}');
      if (end <= 0) continue;
      final jsonStr = candidate.substring(0, end + 1);
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        if (!map.containsKey('tool')) continue;

        final argsMap = map['arguments'] as Map<String, dynamic>?;
        if (argsMap != null) {
          _recoverFirstValues(jsonStr, argsMap);
        }

        // Correct misspelled/wrong tool names before constructing the call
        map['tool'] = _correctToolName(map['tool'] as String);

        final call = ToolCall.fromJson(map);
        return _sanitize(call);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Maps common model mistakes to the correct tool name.
  static String _correctToolName(String raw) {
    // Exact match — no correction needed
    if (FluxAiTools.all.contains(raw)) return raw;

    // Known aliases and typos
    const aliases = <String, String>{
      // createTransaction aliases
      'addTransaction': 'createTransaction',
      'add_transaction': 'createTransaction',
      'logTransaction': 'createTransaction',
      'recordTransaction': 'createTransaction',
      'newTransaction': 'createTransaction',
      'addExpense': 'createTransaction',
      'addIncome': 'createTransaction',

      // getSpendingSummary aliases
      'getSpending': 'getSpendingSummary',
      'spendingSummary': 'getSpendingSummary',
      'getExpenses': 'getSpendingSummary',
      'getExpenseSummary': 'getSpendingSummary',

      // getFinancialSummary aliases
      'financialSummary': 'getFinancialSummary',
      'getSummary': 'getFinancialSummary',

      // getBudgetStatus aliases
      'getBudget': 'getBudgetStatus',
      'budgetStatus': 'getBudgetStatus',
      'checkBudget': 'getBudgetStatus',

      // getBalanceForecast aliases
      'getBalance': 'getBalanceForecast',
      'balance': 'getBalanceForecast',
      'checkBalance': 'getBalanceForecast',

      // getForecast aliases
      'forecast': 'getForecast',
      'getSpendingForecast': 'getForecast',

      // getSavingsRate aliases
      'savingsRate': 'getSavingsRate',
      'getSavings': 'getSavingsRate',

      // searchTransactions aliases
      'search': 'searchTransactions',
      'findTransactions': 'searchTransactions',
      'getTransactions': 'searchTransactions',
      'listTransactions': 'searchTransactions',

      // getFinancialPlans aliases — common model mistake (singular)
      'getFinancialPlan': 'getFinancialPlans',
      'getPlans': 'getFinancialPlans',
      'financialPlans': 'getFinancialPlans',
    };

    if (aliases.containsKey(raw)) return aliases[raw]!;

    // Fuzzy: find the known tool with the most character overlap
    String? best;
    int bestScore = 0;
    final rawLower = raw.toLowerCase();
    for (final tool in FluxAiTools.all) {
      final toolLower = tool.toLowerCase();
      int score = 0;
      // Count shared characters
      for (int i = 0; i < rawLower.length && i < toolLower.length; i++) {
        if (rawLower[i] == toolLower[i]) score++;
      }
      // Bonus for shared prefix length
      int prefix = 0;
      while (prefix < rawLower.length &&
          prefix < toolLower.length &&
          rawLower[prefix] == toolLower[prefix]) {
        prefix++;
      }
      score += prefix;
      if (score > bestScore) {
        bestScore = score;
        best = tool;
      }
    }

    // Only substitute if reasonably confident (score >= 6)
    return (best != null && bestScore >= 6) ? best : raw;
  }

  /// Scans [jsonStr] for the arguments object and fills in any keys whose
  /// first occurrence differs from the value that [jsonDecode] kept (last wins).
  /// This lets us recover category info from duplicated `type` keys.
  static void _recoverFirstValues(
    String jsonStr,
    Map<String, dynamic> argsMap,
  ) {
    // Find all "key":"value" string pairs in the arguments block.
    final stringPairs = RegExp(r'"(\w+)"\s*:\s*"([^"]*)"');
    final firstSeen = <String, String>{};
    for (final m in stringPairs.allMatches(jsonStr)) {
      final key = m.group(1)!;
      final val = m.group(2)!;
      if (!firstSeen.containsKey(key)) firstSeen[key] = val;
    }

    const validTypes = {'expense', 'income', 'transfer'};

    // If "type" had a first value that was not a valid type but the decoded
    // value also isn't valid — use whichever looks more like a category.
    final decodedType = argsMap['type'] as String?;
    final firstType = firstSeen['type'];
    if (firstType != null &&
        firstType != decodedType &&
        !validTypes.contains(decodedType?.toLowerCase())) {
      // Both values are non-standard — the first is likely the category.
      if (argsMap['category'] == null) {
        argsMap['category'] = firstType;
      }
    } else if (firstType != null &&
        firstType != decodedType &&
        !validTypes.contains(firstType.toLowerCase()) &&
        validTypes.contains(decodedType?.toLowerCase())) {
      // First value is category-like, decoded value is the correct type.
      if (argsMap['category'] == null) {
        argsMap['category'] = firstType;
      }
    }
  }

  static const _validTypes = {'expense', 'income', 'transfer'};

  /// Fixes common model errors in tool call arguments:
  /// - Remaps account-related key aliases (card, payment, via…) to `account`
  /// - If `type` is not a valid transaction type, moves it to `category`
  /// - Ensures `amount` is a number
  ToolCall _sanitize(ToolCall call) {
    if (call.tool != 'createTransaction' &&
        call.tool != 'updateTransaction' &&
        call.tool != 'createRecurringTransaction') {
      return call;
    }

    final args = Map<String, dynamic>.from(call.arguments);
    bool changed = false;

    // ── Remap account key aliases ──────────────────────────────────────────
    // The model sometimes uses 'card', 'payment', 'via', 'payment_mode' etc.
    // instead of the correct 'account' key.
    const accountAliases = [
      'card',
      'credit_card',
      'debit_card',
      'payment',
      'payment_mode',
      'payment_method',
      'via',
      'using',
      'bank',
      'wallet',
      'paid_via',
      'paid_with',
      'payment_account',
    ];
    if (!args.containsKey('account') || args['account'] == null) {
      for (final alias in accountAliases) {
        if (args.containsKey(alias) && args[alias] != null) {
          args['account'] = args[alias];
          args.remove(alias);
          changed = true;
          break;
        }
      }
    } else {
      // Remove any stray alias keys so they don't confuse downstream
      for (final alias in accountAliases) {
        if (args.containsKey(alias)) {
          args.remove(alias);
          changed = true;
        }
      }
    }

    // ── Fix invalid type values ───────────────────────────────────────────
    final type = args['type'] as String?;
    if (type != null && !_validTypes.contains(type.toLowerCase())) {
      if (args['category'] == null) {
        args['category'] = type;
      }
      args['type'] = 'expense';
      changed = true;
    }

    // Normalise type to lowercase
    if (args['type'] is String) {
      final t = (args['type'] as String).toLowerCase();
      if (_validTypes.contains(t) && args['type'] != t) {
        args['type'] = t;
        changed = true;
      }
    }

    // ── Fix amount if wrapped in quotes ──────────────────────────────────
    final rawAmount = args['amount'];
    if (rawAmount is String) {
      final cleaned = rawAmount.replaceAll(RegExp(r'[₹,\s]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) {
        args['amount'] = parsed;
        changed = true;
      }
    }

    return changed ? ToolCall(tool: call.tool, arguments: args) : call;
  }

  /// Validates a parsed [ToolCall] against whitelist and schema rules.
  ToolCallValidationResult validate(ToolCall call) {
    final errors = <String>[];

    if (!FluxAiTools.all.contains(call.tool)) {
      errors.add('Unknown tool: ${call.tool}');
      return ToolCallValidationResult(isValid: false, errors: errors);
    }

    switch (call.tool) {
      // ── Transaction mutations ──────────────────────────────────────────────
      case FluxAiTools.createTransaction:
        _validateCreateTransaction(call.arguments, errors);
      case FluxAiTools.updateTransaction:
        _requireField(call.arguments, 'id', errors);
      case FluxAiTools.deleteTransaction:
        _requireField(call.arguments, 'id', errors);
      case FluxAiTools.createRecurringTransaction:
        _validateCreateRecurring(call.arguments, errors);
      case FluxAiTools.cancelRecurringTransaction:
        _requireField(call.arguments, 'id', errors);

      // ── Query tools ────────────────────────────────────────────────────────
      case FluxAiTools.getSpendingSummary:
        _validatePeriod(call.arguments, 'period', errors);
      case FluxAiTools.comparePeriods:
        _validatePeriod(call.arguments, 'current', errors);
        _validatePeriod(call.arguments, 'previous', errors);
      case FluxAiTools.getBudgetStatus:
        _validatePeriod(call.arguments, 'period', errors);
      case FluxAiTools.getForecast:
        _validatePositiveInt(call.arguments, 'days', errors);
      case FluxAiTools.getBalanceForecast:
        // all args optional (accountId, days)
        if (call.arguments.containsKey('days')) {
          _validatePositiveInt(call.arguments, 'days', errors);
        }
      case FluxAiTools.getSavingsRate:
        _validatePeriod(call.arguments, 'period', errors);
      case FluxAiTools.getFinancialSummary:
        _validatePeriod(call.arguments, 'period', errors);
      case FluxAiTools.getAnomalies:
      case FluxAiTools.getRecurringTransactions:
      case FluxAiTools.searchTransactions:
        // all args optional
        break;

      // ── Plan tools ─────────────────────────────────────────────────────────
      case FluxAiTools.getFinancialPlans:
        // type is optional
        if (call.arguments.containsKey('type')) {
          final type = call.arguments['type'];
          if (type is! String ||
              !FluxAiToolSchemas.validPlanTypes.contains(type)) {
            errors.add(
              "type must be one of: ${FluxAiToolSchemas.validPlanTypes.join(', ')}",
            );
          }
        }
      case FluxAiTools.createFinancialPlan:
        _validateCreatePlan(call.arguments, errors);
      case FluxAiTools.updateFinancialPlan:
        _requireField(call.arguments, 'id', errors);
      case FluxAiTools.deleteFinancialPlan:
        _requireField(call.arguments, 'id', errors);
    }

    return ToolCallValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  // ── Private validators ─────────────────────────────────────────────────────

  void _validateCreateTransaction(
    Map<String, dynamic> args,
    List<String> errors,
  ) {
    for (final key in FluxAiToolSchemas.createTransactionRequired) {
      if (!args.containsKey(key) || args[key] == null) {
        errors.add('$key is required');
      }
    }
    final type = args['type'];
    if (type is String &&
        !FluxAiToolSchemas.createTransactionTypes.contains(type)) {
      errors.add('type must be expense, income, or transfer');
    }
    final amount = args['amount'];
    if (amount != null && amount is! num) {
      errors.add('amount must be a number');
    } else if (amount is num && amount <= 0) {
      errors.add('amount must be positive');
    }
  }

  void _validateCreateRecurring(
    Map<String, dynamic> args,
    List<String> errors,
  ) {
    for (final key in FluxAiToolSchemas.createRecurringTransactionRequired) {
      if (!args.containsKey(key) || args[key] == null) {
        errors.add('$key is required');
      }
    }
    final freq = args['frequency'];
    if (freq is String && !FluxAiToolSchemas.validFrequencies.contains(freq)) {
      errors.add(
        'frequency must be one of: ${FluxAiToolSchemas.validFrequencies.join(', ')}',
      );
    }
    final type = args['type'];
    if (type is String &&
        !FluxAiToolSchemas.createTransactionTypes.contains(type)) {
      errors.add('type must be expense, income, or transfer');
    }
  }

  void _validateCreatePlan(Map<String, dynamic> args, List<String> errors) {
    for (final key in FluxAiToolSchemas.createFinancialPlanRequired) {
      if (!args.containsKey(key) || args[key] == null) {
        errors.add('$key is required');
      }
    }
    final type = args['type'];
    if (type is String && !FluxAiToolSchemas.validPlanTypes.contains(type)) {
      errors.add('type must be goal or event');
    }
    final freq = args['contributionFrequency'];
    if (freq is String &&
        !FluxAiToolSchemas.validContributionFrequencies.contains(freq)) {
      errors.add('contributionFrequency must be weekly or monthly');
    }
    final priority = args['priority'];
    if (priority != null &&
        priority is String &&
        !FluxAiToolSchemas.validPlanPriorities.contains(priority)) {
      errors.add('priority must be low, medium, or high');
    }
    final amount = args['targetAmount'];
    if (amount != null && amount is num && amount <= 0) {
      errors.add('targetAmount must be positive');
    }
  }

  void _requireField(
    Map<String, dynamic> args,
    String key,
    List<String> errors,
  ) {
    if (!args.containsKey(key) || args[key] == null) {
      errors.add('$key is required');
    }
  }

  void _validatePeriod(
    Map<String, dynamic> args,
    String key,
    List<String> errors,
  ) {
    final period = args[key];
    if (period == null) {
      errors.add('$key is required');
      return;
    }
    if (period is! String) {
      errors.add('$key must be a string');
      return;
    }
    if (!FluxAiToolSchemas.validPeriods.contains(period)) {
      errors.add(
        'Invalid period "$period". Valid: ${FluxAiToolSchemas.validPeriods.join(', ')}',
      );
    }
  }

  void _validatePositiveInt(
    Map<String, dynamic> args,
    String key,
    List<String> errors,
  ) {
    final val = args[key];
    if (val == null) {
      errors.add('$key is required');
    } else if (val is! num || val.toInt() <= 0) {
      errors.add('$key must be a positive integer');
    }
  }
}
