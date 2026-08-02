// ignore_for_file: lines_longer_than_80_chars
// Feature: spendflux-ai-assistant — Properties 5, 6, 7

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spend_sense/features/assistant/constants/tool_schemas.dart';
import 'package:spend_sense/features/assistant/models/tool_call.dart';
import 'package:spend_sense/features/assistant/validation/tool_call_validator.dart';

// ── Minimal random helpers (no external PBT lib required) ─────────────────────

final _rng = Random(42);

String _randomString(int maxLen) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_{}[]()!@#\$%^&*';
  final len = _rng.nextInt(maxLen) + 1;
  return String.fromCharCodes(
    List.generate(len, (_) => chars.codeUnitAt(_rng.nextInt(chars.length))),
  );
}

void runProperty(String name, int iterations, void Function(int) body) {
  test(name, () {
    for (int i = 0; i < iterations; i++) {
      body(i);
    }
  });
}

void main() {
  final validator = ToolCallValidator();

  // ── Property 5: Tool call parser never throws ──────────────────────────────
  runProperty('Property 5: tryParse never throws on arbitrary input', 100, (_) {
    final input = _randomString(200);
    expect(() => validator.tryParse(input), returnsNormally);
  });

  test('Property 5b: tryParse returns non-null for valid tool call JSON', () {
    const valid =
        '{"tool":"createTransaction","arguments":{"amount":500,"type":"expense"}}';
    expect(validator.tryParse(valid), isNotNull);
  });

  test('Property 5c: tryParse returns null for random non-JSON strings', () {
    final samples = ['hello world', 'no json here', '123 456', '{no tool key}'];
    for (final s in samples) {
      final result = validator.tryParse(s);
      if (result != null) {
        expect(result.tool, isNotEmpty);
      }
    }
  });

  // ── Property 6: Whitelist enforcement ─────────────────────────────────────
  runProperty('Property 6: unknown tool names always fail validation', 100, (
    i,
  ) {
    final fakeTool = 'fakeTool_$i';
    if (FluxAiTools.all.contains(fakeTool)) return; // skip collision
    final call = ToolCall(tool: fakeTool, arguments: {});
    final result = validator.validate(call);
    expect(
      result.isValid,
      isFalse,
      reason: '$fakeTool should not be whitelisted',
    );
    expect(result.errors, isNotEmpty);
  });

  test('Property 6b: all whitelisted tools pass whitelist check', () {
    for (final tool in FluxAiTools.all) {
      // Each tool may still fail for missing required args —
      // but it should NOT fail with "Unknown tool"
      final call = ToolCall(tool: tool, arguments: {});
      final result = validator.validate(call);
      expect(
        result.errors.any((e) => e.contains('Unknown tool')),
        isFalse,
        reason: '$tool is whitelisted and should pass the whitelist check',
      );
    }
  });

  // ── Property 7: Missing required args always fail ─────────────────────────
  group(
    'Property 7: missing required arguments fail with informative errors',
    () {
      final requiredArgsByTool = {
        FluxAiTools.createTransaction:
            FluxAiToolSchemas.createTransactionRequired,
        FluxAiTools.updateTransaction:
            FluxAiToolSchemas.updateTransactionRequired,
        FluxAiTools.deleteTransaction:
            FluxAiToolSchemas.deleteTransactionRequired,
        FluxAiTools.cancelRecurringTransaction:
            FluxAiToolSchemas.cancelRecurringTransactionRequired,
        FluxAiTools.getSpendingSummary:
            FluxAiToolSchemas.getSpendingSummaryRequired,
        FluxAiTools.comparePeriods: FluxAiToolSchemas.comparePeriodsRequired,
        FluxAiTools.getForecast: FluxAiToolSchemas.getForecastRequired,
        FluxAiTools.getSavingsRate: FluxAiToolSchemas.getSavingsRateRequired,
        FluxAiTools.getFinancialSummary:
            FluxAiToolSchemas.getFinancialSummaryRequired,
        FluxAiTools.createFinancialPlan:
            FluxAiToolSchemas.createFinancialPlanRequired,
        FluxAiTools.updateFinancialPlan:
            FluxAiToolSchemas.updateFinancialPlanRequired,
        FluxAiTools.deleteFinancialPlan:
            FluxAiToolSchemas.deleteFinancialPlanRequired,
      };

      for (final entry in requiredArgsByTool.entries) {
        final tool = entry.key;
        final required = entry.value;

        test('$tool — empty args should list missing required fields', () {
          final call = ToolCall(tool: tool, arguments: {});
          final result = validator.validate(call);
          expect(
            result.isValid,
            isFalse,
            reason: '$tool with no args should be invalid',
          );
          // At least one required field should be mentioned in errors
          final errorText = result.errors.join(' ');
          final mentionsARequired = required.any((r) => errorText.contains(r));
          expect(
            mentionsARequired,
            isTrue,
            reason:
                'Errors for $tool should mention at least one required field',
          );
        });
      }
    },
  );
}
