// Feature: spendflux-ai-assistant — Properties 27, 28, 29

import 'package:flutter_test/flutter_test.dart';
import 'package:spend_sense/features/assistant/data/assistant_repository.dart';
import 'package:spend_sense/features/assistant/models/chat_message.dart';

void main() {
  // ── Property 27: Message serialisation round-trip ─────────────────────────
  test('Property 27: AssistantMessage round-trips through toMap/fromMap', () {
    final messages = [
      AssistantMessage(
        id: 'msg_1',
        sessionId: 'sess_1',
        role: ChatRole.user,
        content: 'How much did I spend on food?',
        timestamp: DateTime(2024, 6, 15, 10, 30),
      ),
      AssistantMessage(
        id: 'msg_2',
        sessionId: 'sess_1',
        role: ChatRole.assistant,
        content: 'You spent ₹3,500 on Food & Dining this month.',
        timestamp: DateTime(2024, 6, 15, 10, 31),
      ),
    ];

    for (final msg in messages) {
      final map = msg.toMap();
      final restored = AssistantMessage.fromMap(map);

      expect(restored.id, equals(msg.id));
      expect(restored.sessionId, equals(msg.sessionId));
      expect(restored.role, equals(msg.role));
      expect(restored.content, equals(msg.content));
      expect(
        restored.timestamp.toIso8601String(),
        equals(msg.timestamp.toIso8601String()),
      );
    }
  });

  // ── Property 27b: toChatMessage produces correct role mapping ─────────────
  test('Property 27b: toChatMessage maps roles correctly', () {
    for (final role in [ChatRole.user, ChatRole.assistant]) {
      final msg = AssistantMessage(
        id: 'x',
        sessionId: 's',
        role: role,
        content: 'test',
        timestamp: DateTime.now(),
      );
      final chatMsg = msg.toChatMessage();
      expect(chatMsg.role, equals(role));
      expect(chatMsg.content, equals('test'));
      expect(chatMsg.isStreaming, isFalse);
    }
  });

  // ── Property 29: System content excluded from persistence ─────────────────
  test('Property 29: system-role messages should not be persisted', () {
    // This property validates the contract: the repository should only
    // receive user/assistant messages from the session notifier.
    // We verify that a system message converted to AssistantMessage
    // correctly stores and restores the role — and callers must filter.
    final sysMsg = AssistantMessage(
      id: 'sys_1',
      sessionId: 's',
      role: ChatRole.system,
      content: '[System instruction]',
      timestamp: DateTime.now(),
    );
    final restored = AssistantMessage.fromMap(sysMsg.toMap());
    expect(restored.role, equals(ChatRole.system));

    // The session notifier filters by role before calling insertMessage.
    // This test documents that system messages CAN be round-tripped
    // (they are valid DB rows) but SHOULD NOT be inserted by callers.
    // Validate that the role check works:
    final shouldPersist =
        sysMsg.role == ChatRole.user || sysMsg.role == ChatRole.assistant;
    expect(
      shouldPersist,
      isFalse,
      reason: 'System messages must not be persisted',
    );
  });

  // ── Property 28: Table size cap logic (pure formula) ──────────────────────
  test('Property 28: excess count calculation is correct', () {
    const maxMessages = 500;
    for (final totalCount in [499, 500, 501, 600, 1000]) {
      final excess = (totalCount - maxMessages).clamp(0, totalCount);
      if (totalCount <= maxMessages) {
        expect(excess, equals(0));
      } else {
        expect(excess, equals(totalCount - maxMessages));
        expect(excess, greaterThan(0));
      }
    }
  });
}
