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

/// Validates whitelisted tool calls against JSON schema rules.
class ToolCallValidator {
  ToolCall? tryParse(String text) {
    final trimmed = text.trim();
    if (!trimmed.contains('{')) return null;

    try {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start < 0 || end <= start) return null;

      final jsonStr = trimmed.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;

      final map = Map<String, dynamic>.from(decoded);
      if (!map.containsKey('tool')) return null;
      return ToolCall.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  ToolCallValidationResult validate(ToolCall call) {
    final errors = <String>[];

    if (!FluxAiTools.all.contains(call.tool)) {
      errors.add('Unknown tool: ${call.tool}');
      return ToolCallValidationResult(isValid: false, errors: errors);
    }

    switch (call.tool) {
      case FluxAiTools.createTransaction:
        _validateCreateTransaction(call.arguments, errors);
      case FluxAiTools.getSpendingSummary:
        _validatePeriod(call.arguments, 'period', errors);
      case FluxAiTools.comparePeriods:
        _validatePeriod(call.arguments, 'current', errors);
        _validatePeriod(call.arguments, 'previous', errors);
      case FluxAiTools.getForecast:
        final days = call.arguments['days'];
        if (days == null) {
          errors.add('days is required');
        } else if (days is! num || days.toInt() <= 0) {
          errors.add('days must be a positive integer');
        }
      case FluxAiTools.getRecurringTransactions:
        break;
      case FluxAiTools.getBudgetStatus:
        _validatePeriod(call.arguments, 'period', errors);
    }

    return ToolCallValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

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
      errors.add('Invalid period: $period');
    }
  }
}
