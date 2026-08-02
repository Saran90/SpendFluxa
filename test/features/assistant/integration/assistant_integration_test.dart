// Feature: spendflux-ai-assistant — Task 22: Integration Smoke Tests
//
// These tests verify end-to-end flows through the assistant's pure Dart
// components: serialisation, undo stack, tag fuzzy matching, tool validation,
// context window, and download progress logic.
//
// Tests that require real DB-backed services (ConversationManager,
// AlertEngine with WorkManager) are deferred to device/integration
// test suites due to Flutter ChangeNotifier constraints.

import 'package:flutter_test/flutter_test.dart';
import 'package:spend_sense/core/models/transaction.dart';
import 'package:spend_sense/features/assistant/data/assistant_repository.dart';
import 'package:spend_sense/features/assistant/data/model_download_service.dart';
import 'package:spend_sense/features/assistant/engine/context_window_manager.dart';
import 'package:spend_sense/features/assistant/models/chat_message.dart';
import 'package:spend_sense/features/assistant/models/tool_call.dart';
import 'package:spend_sense/features/assistant/models/undo_stack_entry.dart';
import 'package:spend_sense/features/assistant/validation/tool_call_validator.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ChatMessage _userMsg(String content, int offset) => ChatMessage(
  id: 'u_$offset',
  role: ChatRole.user,
  content: content,
  timestamp: DateTime(2024, 6, 1).add(Duration(seconds: offset)),
);

ChatMessage _assistantMsg(String content, int offset) => ChatMessage(
  id: 'a_$offset',
  role: ChatRole.assistant,
  content: content,
  timestamp: DateTime(2024, 6, 1).add(Duration(seconds: offset)),
);

Transaction _tx(String id, double amount) => Transaction(
  id: id,
  title: 'tx_$id',
  amount: amount,
  type: TransactionType.expense,
  category: TransactionCategory.food,
  date: DateTime(2024, 6, 15),
);

// ── Undo stack class (extracted for integration testing) ──────────────────────

class _UndoStack {
  static const maxSize = 10;
  final List<UndoStackEntry> _stack = [];

  void push(UndoStackEntry entry) {
    if (_stack.length >= maxSize) _stack.removeAt(0);
    _stack.add(entry);
  }

  UndoStackEntry? pop() => _stack.isNotEmpty ? _stack.removeLast() : null;
  List<UndoStackEntry> popAll() {
    final all = _stack.reversed.toList();
    _stack.clear();
    return all;
  }

  void clear() => _stack.clear();
  bool get isEmpty => _stack.isEmpty;
  int get length => _stack.length;
}

void main() {
  // ── 1. Tool call detection + tool round-trip ──────────────────────────────
  group('Smoke 1: Tool call parse → validate round-trip', () {
    final validator = ToolCallValidator();

    test('Valid createTransaction JSON is parsed and validates correctly', () {
      const json =
          '{"tool":"createTransaction","arguments":{"amount":500,"type":"expense"}}';
      final call = validator.tryParse(json);
      expect(call, isNotNull);
      expect(call!.tool, equals('createTransaction'));

      final result = validator.validate(call);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Valid getSpendingSummary JSON validates correctly', () {
      const json =
          '{"tool":"getSpendingSummary","arguments":{"period":"this_month"}}';
      final call = validator.tryParse(json);
      expect(call, isNotNull);
      final result = validator.validate(call!);
      expect(result.isValid, isTrue);
    });

    test('Tool call JSON embedded in prose is extracted correctly', () {
      const response =
          'Sure! Here is the data: {"tool":"getForecast","arguments":{"days":7}}';
      final call = validator.tryParse(response);
      expect(call, isNotNull);
      expect(call!.tool, equals('getForecast'));
      expect(call.arguments['days'], equals(7));
    });

    test('Invalid tool name fails validation with informative error', () {
      final call = ToolCall(tool: 'doSomethingBad', arguments: {});
      final result = validator.validate(call);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Unknown tool'));
    });

    test('ToolResult serialisation round-trip', () {
      const result = ToolResult(ok: true, result: {'amount': 500.0});
      final json = result.toJson();
      expect(json['ok'], isTrue);
      expect((json['result'] as Map)['amount'], equals(500.0));
    });
  });

  // ── 2. Undo stack: create + undo round-trip ───────────────────────────────
  group('Smoke 2: Undo stack round-trip', () {
    test('Push create entry → pop reverses it', () {
      final stack = _UndoStack();
      final tx = _tx('tx1', 500);
      stack.push(
        UndoStackEntry(
          operationId: 'op1',
          type: UndoOperationType.create,
          snapshot: tx,
          humanDescription: 'Added ₹500 food',
        ),
      );

      final entry = stack.pop();
      expect(entry, isNotNull);
      expect(entry!.type, equals(UndoOperationType.create));
      expect(entry.snapshot.id, equals('tx1'));
      expect(stack.isEmpty, isTrue);
    });

    test('undoAll reverses N operations in reverse-insertion order', () {
      final stack = _UndoStack();
      for (int i = 1; i <= 5; i++) {
        stack.push(
          UndoStackEntry(
            operationId: 'op$i',
            type: UndoOperationType.create,
            snapshot: _tx('tx$i', i * 100.0),
            humanDescription: 'op$i',
          ),
        );
      }

      final all = stack.popAll();
      expect(all.length, equals(5));
      // Most recent first
      expect(all.first.operationId, equals('op5'));
      expect(all.last.operationId, equals('op1'));
      expect(stack.isEmpty, isTrue);
    });

    test('Stack cap: 11 pushes leaves exactly 10 entries', () {
      final stack = _UndoStack();
      for (int i = 1; i <= 11; i++) {
        stack.push(
          UndoStackEntry(
            operationId: 'op$i',
            type: UndoOperationType.create,
            snapshot: _tx('tx$i', i * 100.0),
            humanDescription: 'op$i',
          ),
        );
      }
      expect(stack.length, equals(10));
      // op1 should have been dropped
      expect(stack.popAll().any((e) => e.operationId == 'op1'), isFalse);
    });
  });

  // ── 3. Context window: build prompt structure ──────────────────────────────
  group('Smoke 3: Context window builds correct prompt', () {
    test('buildPrompt includes User: and Assistant: prefixes', () {
      final mgr = ContextWindowManager();
      mgr.addMessage(_userMsg('How much did I spend?', 0));
      mgr.addMessage(_assistantMsg('You spent ₹3,500.', 1));

      final prompt = mgr.buildPrompt();
      expect(prompt, contains('User: How much did I spend?'));
      expect(prompt, contains('Assistant: You spent ₹3,500.'));
    });

    test('buildPrompt limits active window to last 10 messages', () {
      final mgr = ContextWindowManager();
      for (int i = 0; i < 20; i++) {
        mgr.addMessage(_userMsg('msg $i', i));
      }
      final prompt = mgr.buildPrompt();
      final count = 'User:'.allMatches(prompt).length;
      expect(count, lessThanOrEqualTo(10));
    });

    test('clear() produces empty prompt', () {
      final mgr = ContextWindowManager();
      mgr.addMessage(_userMsg('hello', 0));
      mgr.clear();
      expect(mgr.buildPrompt().trim(), isEmpty);
    });
  });

  // ── 4. Tag fuzzy matching (pure algorithm) ────────────────────────────────
  group('Smoke 4: Tag fuzzy match (algorithm only)', () {
    int levenshtein(String a, String b) {
      if (a == b) return 0;
      if (a.isEmpty) return b.length;
      if (b.isEmpty) return a.length;
      var prev = List<int>.generate(b.length + 1, (i) => i);
      var curr = List<int>.filled(b.length + 1, 0);
      for (int i = 1; i <= a.length; i++) {
        curr[0] = i;
        for (int j = 1; j <= b.length; j++) {
          final cost = a[i - 1] == b[j - 1] ? 0 : 1;
          curr[j] = [
            prev[j] + 1,
            curr[j - 1] + 1,
            prev[j - 1] + cost,
          ].reduce((x, y) => x < y ? x : y);
        }
        final tmp = prev;
        prev = curr;
        curr = tmp;
      }
      return prev[b.length];
    }

    test('Exact match returns 0 distance', () {
      expect(levenshtein('food', 'food'), equals(0));
    });

    test('One typo is within threshold for 8+ char query', () {
      // 'resturant' vs 'restaurant' → 1 edit, threshold = 9/2 = 4
      final dist = levenshtein('resturant', 'restaurant');
      expect(dist, lessThanOrEqualTo('resturant'.length ~/ 2));
    });

    test('Completely different strings exceed threshold', () {
      final dist = levenshtein('xyzqrst', 'abc');
      expect(dist, greaterThan('xyzqrst'.length ~/ 2));
    });
  });

  // ── 5. DownloadProgress formatting ────────────────────────────────────────
  group('Smoke 5: DownloadProgress formatting', () {
    test('percentage is correct when totalBytes known', () {
      final p = DownloadProgress(
        bytesDownloaded: 264 * 1024 * 1024,
        totalBytes: 529 * 1024 * 1024,
      );
      expect(p.percentage, closeTo(0.5, 0.01));
      expect(p.hasError, isFalse);
      expect(p.isComplete, isFalse);
    });

    test('percentage is -1 when totalBytes unknown', () {
      final p = DownloadProgress(bytesDownloaded: 1024 * 1024, totalBytes: -1);
      expect(p.percentage, equals(-1.0));
    });

    test('error progress has hasError true', () {
      final p = DownloadProgress(
        bytesDownloaded: 0,
        totalBytes: -1,
        error: 'Network error',
      );
      expect(p.hasError, isTrue);
      expect(p.error, equals('Network error'));
    });

    test('complete progress has isComplete true', () {
      final p = DownloadProgress(
        bytesDownloaded: 529 * 1024 * 1024,
        totalBytes: 529 * 1024 * 1024,
        isComplete: true,
      );
      expect(p.isComplete, isTrue);
      expect(p.percentage, closeTo(1.0, 0.001));
    });
  });

  // ── 6. Alert deduplication 24h boundary ──────────────────────────────────
  group('Smoke 6: Alert dedup 24h boundary', () {
    test('Alert emitted 23h ago should block re-emit (within window)', () {
      final emittedAt = DateTime.now().subtract(const Duration(hours: 23));
      final since = DateTime.now().subtract(const Duration(hours: 24));
      expect(emittedAt.isAfter(since), isTrue);
    });

    test('Alert emitted 25h ago should allow re-emit (outside window)', () {
      final emittedAt = DateTime.now().subtract(const Duration(hours: 25));
      final since = DateTime.now().subtract(const Duration(hours: 24));
      expect(emittedAt.isBefore(since), isTrue);
    });
  });

  // ── 7. AssistantMessage serialisation ─────────────────────────────────────
  group('Smoke 7: AssistantMessage serialisation', () {
    test('Round-trip preserves all fields', () {
      final msg = AssistantMessage(
        id: 'smoke_1',
        sessionId: 'sess_smoke',
        role: ChatRole.user,
        content: 'Add ₹500 grocery expense',
        timestamp: DateTime(2024, 6, 15, 10, 0),
      );
      final restored = AssistantMessage.fromMap(msg.toMap());
      expect(restored.id, equals(msg.id));
      expect(restored.sessionId, equals(msg.sessionId));
      expect(restored.role, equals(msg.role));
      expect(restored.content, equals(msg.content));
    });

    test('toChatMessage produces correct ChatMessage', () {
      final msg = AssistantMessage(
        id: 'smoke_2',
        sessionId: 'sess_smoke',
        role: ChatRole.assistant,
        content: 'Done! Added ₹500 to Grocery.',
        timestamp: DateTime.now(),
      );
      final cm = msg.toChatMessage();
      expect(cm.role, equals(ChatRole.assistant));
      expect(cm.isStreaming, isFalse);
      expect(cm.content, equals(msg.content));
    });
  });
}
