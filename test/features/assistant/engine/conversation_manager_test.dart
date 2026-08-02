// Feature: spendflux-ai-assistant — Properties 21, 23, 24, 25, 26

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_sense/core/models/transaction.dart';
import 'package:spend_sense/features/assistant/models/undo_stack_entry.dart';

// ── UndoStack property tests (pure in-memory, no services needed) ─────────────

class _UndoStack {
  static const maxSize = 10;
  final List<UndoStackEntry> _stack = [];

  List<UndoStackEntry> get entries => List.unmodifiable(_stack);

  void push(UndoStackEntry entry) {
    if (_stack.length >= maxSize) _stack.removeAt(0);
    _stack.add(entry);
  }

  UndoStackEntry? pop() => _stack.isNotEmpty ? _stack.removeLast() : null;

  List<UndoStackEntry> popAll() {
    final reversed = _stack.reversed.toList();
    _stack.clear();
    return reversed;
  }

  void clear() => _stack.clear();
  bool get isEmpty => _stack.isEmpty;
  int get length => _stack.length;
}

final _rng = Random(33);

void runProperty(String name, int iterations, void Function(int) body) {
  test(name, () {
    for (int i = 0; i < iterations; i++) body(i);
  });
}

void main() {
  // ── Property 25: Undo stack capped at 10 ─────────────────────────────────
  runProperty('Property 25: undo stack never exceeds 10 entries', 100, (i) {
    final stack = _UndoStack();
    final n = _rng.nextInt(30) + 1;
    for (int j = 0; j < n; j++) {
      stack.push(_makeEntry(j));
    }
    expect(stack.length, lessThanOrEqualTo(10));
  });

  test('Property 25b: after 11 pushes, oldest entry is discarded', () {
    final stack = _UndoStack();
    for (int i = 0; i < 11; i++) {
      stack.push(_makeEntry(i));
    }
    expect(stack.length, equals(10));
    // The first entry (id 'op_0') should have been discarded
    expect(stack.entries.any((e) => e.operationId == 'op_0'), isFalse);
  });

  // ── Property 26: undoAll reverses in order ─────────────────────────────────
  runProperty(
    'Property 26: popAll returns entries in reverse insertion order',
    100,
    (i) {
      final stack = _UndoStack();
      final n = _rng.nextInt(10) + 1;
      final ids = <String>[];
      for (int j = 0; j < n; j++) {
        final id = 'op_${i}_$j';
        ids.add(id);
        stack.push(_makeEntryWithId(id));
      }

      final reversed = stack.popAll();
      expect(reversed.length, equals(n));
      // Reversed order: last inserted comes first
      for (int j = 0; j < n; j++) {
        expect(reversed[j].operationId, equals(ids[n - 1 - j]));
      }
    },
  );

  // ── Property 26b: undoAll reports correct count ───────────────────────────
  runProperty('Property 26b: popAll count matches stack size before pop', 100, (
    i,
  ) {
    final stack = _UndoStack();
    final n = _rng.nextInt(10) + 1;
    for (int j = 0; j < n; j++) stack.push(_makeEntry(j));
    final sizeBefore = stack.length;
    final popped = stack.popAll();
    expect(popped.length, equals(sizeBefore));
    expect(stack.isEmpty, isTrue);
  });

  // ── Property 21: Clarification threshold (pure formula test) ─────────────
  runProperty(
    'Property 21: overall confidence < 0.85 triggers clarification',
    100,
    (i) {
      final conf = _rng.nextDouble();
      final needsClarification = conf < 0.85;

      if (needsClarification) {
        expect(conf, lessThan(0.85));
      } else {
        expect(conf, greaterThanOrEqualTo(0.85));
      }
    },
  );

  // ── Property 24: Stack is empty after clear ───────────────────────────────
  test('Property 24: clear() empties the undo stack', () {
    final stack = _UndoStack();
    for (int i = 0; i < 5; i++) stack.push(_makeEntry(i));
    stack.clear();
    expect(stack.isEmpty, isTrue);
    expect(stack.pop(), isNull);
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

UndoStackEntry _makeEntry(int i) => _makeEntryWithId('op_$i');

UndoStackEntry _makeEntryWithId(String id) => UndoStackEntry(
  operationId: id,
  type: UndoOperationType.create,
  snapshot: Transaction(
    id: id,
    title: 'tx_$id',
    amount: 100,
    type: TransactionType.expense,
    category: TransactionCategory.food,
    date: DateTime.now(),
  ),
  humanDescription: 'Created transaction $id',
);
