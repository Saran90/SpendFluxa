// Feature: spendflux-ai-assistant — Properties 18, 19, 20

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spend_sense/features/assistant/models/financial_plan.dart';

final _rng = Random(77);

void runProperty(String name, int iterations, void Function(int) body) {
  test(name, () {
    for (int i = 0; i < iterations; i++) body(i);
  });
}

FinancialPlan _plan({
  double targetAmount = 10000,
  double currentSavings = 0,
  DateTime? targetDate,
  PlanType type = PlanType.goal,
  ContributionFrequency freq = ContributionFrequency.monthly,
}) => FinancialPlan(
  id: 'test',
  name: 'Test Plan',
  type: type,
  targetAmount: targetAmount,
  targetDate: targetDate ?? DateTime.now().add(const Duration(days: 365)),
  contributionFrequency: freq,
  createdAt: DateTime.now(),
  currentSavings: currentSavings,
);

void main() {
  // ── Property 18: Plan contribution formula ────────────────────────────────
  runProperty(
    'Property 18: remainingAmount == targetAmount - currentSavings (clamped to 0)',
    100,
    (i) {
      final target = (_rng.nextDouble() * 100000).roundToDouble();
      final savings = (_rng.nextDouble() * target * 1.2).roundToDouble();
      final plan = _plan(targetAmount: target, currentSavings: savings);
      final expected = (target - savings).clamp(0.0, double.infinity);
      expect(plan.remainingAmount, closeTo(expected, 0.01));
    },
  );

  // ── Property 19: Achievability binary condition ───────────────────────────
  test('Property 19a: already-funded plan has zero remaining', () {
    final plan = _plan(targetAmount: 5000, currentSavings: 6000);
    expect(plan.remainingAmount, equals(0.0));
  });

  test('Property 19b: plan with future target date has positive remaining', () {
    final plan = _plan(targetAmount: 10000, currentSavings: 2000);
    expect(plan.remainingAmount, closeTo(8000, 0.01));
  });

  // ── Property 20: atRisk detection for events ─────────────────────────────
  test('Property 20a: event < 30 days away and underfunded is atRisk', () {
    final plan = _plan(
      type: PlanType.event,
      targetAmount: 5000,
      currentSavings: 1000,
      targetDate: DateTime.now().add(const Duration(days: 10)),
    );
    expect(plan.atRisk, isTrue);
  });

  test('Property 20b: event >= 30 days away is NOT atRisk', () {
    final plan = _plan(
      type: PlanType.event,
      targetAmount: 5000,
      currentSavings: 1000,
      targetDate: DateTime.now().add(const Duration(days: 60)),
    );
    expect(plan.atRisk, isFalse);
  });

  test('Property 20c: fully funded event is NOT atRisk', () {
    final plan = _plan(
      type: PlanType.event,
      targetAmount: 5000,
      currentSavings: 5000,
      targetDate: DateTime.now().add(const Duration(days: 5)),
    );
    expect(plan.atRisk, isFalse);
  });

  test('Property 20d: goal type never triggers atRisk', () {
    final plan = _plan(
      type: PlanType.goal,
      targetAmount: 5000,
      currentSavings: 0,
      targetDate: DateTime.now().add(const Duration(days: 5)),
    );
    expect(plan.atRisk, isFalse);
  });

  runProperty(
    'Property 20e: atRisk iff event AND days < 30 AND underfunded',
    100,
    (i) {
      final days = _rng.nextInt(60) + 1;
      final target = 5000.0;
      final savings = _rng.nextDouble() * 6000;
      final plan = _plan(
        type: PlanType.event,
        targetAmount: target,
        currentSavings: savings,
        targetDate: DateTime.now().add(Duration(days: days)),
      );
      final expectedAtRisk = days < 30 && savings < target;
      expect(plan.atRisk, equals(expectedAtRisk));
    },
  );
}
