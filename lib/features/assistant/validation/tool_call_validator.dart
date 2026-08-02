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

    // Try progressively repaired versions of the JSON:
    // 1. As-is (complete JSON)
    // 2. With one closing brace appended (missing inner `}`)
    // 3. With two closing braces appended (missing `}}`)
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
        return ToolCall.fromJson(map);
      } catch (_) {
        continue;
      }
    }
    return null;
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
