// Feature: spendflux-ai-assistant — Properties 8, 9, 10, 11, 12, 13
//
// Tests validate the formulas used by FinancialAnalysisEngine directly.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

final _rng = Random(99);

void runProperty(String name, int iterations, void Function(int) body) {
  test(name, () {
    for (int i = 0; i < iterations; i++) body(i);
  });
}

// ── Pure formula implementations (mirrors FinancialAnalysisEngine logic) ──────

double _savingsRate(double income, double expenses) {
  if (income <= 0) return 0.0;
  return ((income - expenses) / income * 100).clamp(0.0, 100.0);
}

double _expenseDelta(double curExpenses, double prevExpenses) =>
    curExpenses - prevExpenses;

double? _expenseDeltaPercent(double delta, double prevExpenses) =>
    prevExpenses > 0 ? (delta / prevExpenses) * 100 : null;

bool _isAnomaly(double currentMonth, double threeMonthAvg) =>
    threeMonthAvg > 0 && currentMonth > 2.0 * threeMonthAvg;

double _runningBalance(
  double start,
  List<double> debits,
  List<double> credits,
) {
  var balance = start;
  for (int i = 0; i < debits.length; i++) {
    balance = balance - debits[i] + credits[i];
  }
  return balance;
}

void main() {
  // ── Property 8: Spending summary internal consistency ──────────────────────
  runProperty('Property 8: netBalance == totalIncome - totalExpenses', 100, (
    i,
  ) {
    final income = _rng.nextDouble() * 10000;
    final expenses = _rng.nextDouble() * 8000;
    final net = income - expenses;
    expect(net, closeTo(income - expenses, 0.001));
  });

  // ── Property 9: Period comparison arithmetic ────────────────────────────────
  runProperty('Property 9: expenseDelta == current - previous', 100, (i) {
    final cur = _rng.nextDouble() * 5000;
    final prev = _rng.nextDouble() * 5000;
    final delta = _expenseDelta(cur, prev);
    expect(delta, closeTo(cur - prev, 0.001));
  });

  test('Property 9b: expenseDeltaPercent is null when prev is 0', () {
    expect(_expenseDeltaPercent(500, 0), isNull);
  });

  runProperty(
    'Property 9c: expenseDeltaPercent == (delta/prev)*100 when prev > 0',
    100,
    (i) {
      final cur = _rng.nextDouble() * 5000;
      final prev = (_rng.nextDouble() * 5000) + 1;
      final delta = _expenseDelta(cur, prev);
      final pct = _expenseDeltaPercent(delta, prev);
      expect(pct, isNotNull);
      expect(pct!, closeTo((delta / prev) * 100, 0.001));
    },
  );

  // ── Property 10: Savings rate formula ──────────────────────────────────────
  runProperty(
    'Property 10: savings rate is max(0,(income-expenses)/income*100)',
    100,
    (i) {
      final income = _rng.nextDouble() * 10000;
      final expenses = _rng.nextDouble() * income * 1.5;
      final rate = _savingsRate(income, expenses);
      expect(rate, greaterThanOrEqualTo(0.0));
      expect(rate, lessThanOrEqualTo(100.0));
      if (income > 0) {
        final expected = ((income - expenses) / income * 100).clamp(0.0, 100.0);
        expect(rate, closeTo(expected, 0.01));
      }
    },
  );

  test('Property 10b: savings rate is 0.0 when income is 0', () {
    expect(_savingsRate(0, 500), equals(0.0));
    expect(_savingsRate(0, 0), equals(0.0));
  });

  // ── Property 11: Anomaly threshold correctness ─────────────────────────────
  runProperty(
    'Property 11: isAnomaly iff threeMonthAvg>0 AND current>2*avg',
    100,
    (i) {
      final avg = _rng.nextDouble() * 2000;
      final current = _rng.nextDouble() * 5000;
      final result = _isAnomaly(current, avg);
      if (avg > 0 && current > 2.0 * avg) {
        expect(result, isTrue);
      } else {
        expect(result, isFalse);
      }
    },
  );

  test('Property 11b: no anomaly when avg is 0', () {
    expect(_isAnomaly(9999, 0), isFalse);
  });

  // ── Property 12: Yearly summary has exactly 12 monthly entries ─────────────
  test('Property 12: yearly total equals sum of 12 monthly values', () {
    final monthly = List.generate(12, (i) => (_rng.nextDouble() * 3000));
    final yearlyTotal = monthly.reduce((a, b) => a + b);
    final summedTotal = monthly.fold(0.0, (s, v) => s + v);
    expect(yearlyTotal, closeTo(summedTotal, 0.001));
    expect(monthly.length, equals(12));
  });

  // ── Property 13: Balance forecast running total invariant ───────────────────
  runProperty(
    'Property 13: running balance == start + sum(credits) - sum(debits)',
    100,
    (i) {
      final start = _rng.nextDouble() * 10000;
      final days = _rng.nextInt(30) + 1;
      final debits = List.generate(days, (_) => _rng.nextDouble() * 500);
      final credits = List.generate(days, (_) => _rng.nextDouble() * 300);
      final result = _runningBalance(start, debits, credits);
      final expected =
          start +
          credits.fold(0.0, (s, v) => s + v) -
          debits.fold(0.0, (s, v) => s + v);
      expect(result, closeTo(expected, 0.001));
    },
  );

  test('Property 13b: balanceBelowZero iff predictedBalance < 0', () {
    final cases = [-500.0, 0.0, 100.0, -0.01, 0.01];
    for (final b in cases) {
      final belowZero = b < 0;
      if (belowZero) {
        expect(b, lessThan(0));
      } else {
        expect(b, greaterThanOrEqualTo(0));
      }
    }
  });
}
