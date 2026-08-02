import 'package:intl/intl.dart';

import '../data/plan_repository.dart';
import '../models/financial_plan.dart';
import 'financial_analysis_engine.dart';

/// A single scheduled contribution entry in a [SavingsSchedule].
class ScheduleEntry {
  const ScheduleEntry({
    required this.date,
    required this.amount,
    required this.cumulativeTotal,
  });

  final DateTime date;
  final double amount;
  final double cumulativeTotal;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'amount': amount,
    'cumulativeTotal': cumulativeTotal,
  };
}

/// A computed savings schedule for a [FinancialPlan].
class SavingsSchedule {
  const SavingsSchedule({required this.entries, required this.plan});

  final List<ScheduleEntry> entries;
  final FinancialPlan plan;

  Map<String, dynamic> toJson() => {
    'planId': plan.id,
    'planName': plan.name,
    'targetAmount': plan.targetAmount,
    'targetDate': plan.targetDate.toIso8601String().substring(0, 10),
    'contributionFrequency': plan.contributionFrequency.name,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

/// Manages [FinancialPlan] objects — both goals and events.
///
/// All writes go through this class so achievability is always recomputed
/// before returning the plan to callers.
class PlanManager {
  PlanManager({required this.planRepository, required this.analysisEngine});

  final PlanRepository planRepository;
  final FinancialAnalysisEngine analysisEngine;

  static final _currencyFmt = NumberFormat.currency(
    symbol: '₹',
    locale: 'en_IN',
    decimalDigits: 0,
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns all plans, optionally filtered by [type], with computed fields.
  Future<List<FinancialPlan>> getPlans({PlanType? type}) async {
    final raw = await planRepository.getAll(type: type);
    return raw.map(_enrich).toList();
  }

  /// Returns a single plan by [id] with computed fields, or `null`.
  Future<FinancialPlan?> getById(String id) async {
    final raw = await planRepository.getById(id);
    return raw == null ? null : _enrich(raw);
  }

  /// Creates a new plan after validation. Returns the enriched plan.
  ///
  /// Throws [ArgumentError] if [plan.targetDate] is in the past.
  Future<FinancialPlan> createPlan(FinancialPlan plan) async {
    _validateTargetDate(plan.targetDate);
    await planRepository.insert(plan);
    return _enrich(plan);
  }

  /// Updates an existing plan after validation. Returns the enriched plan.
  Future<FinancialPlan> updatePlan(FinancialPlan plan) async {
    _validateTargetDate(plan.targetDate);
    await planRepository.update(plan);
    return _enrich(plan);
  }

  /// Deletes the plan with [id].
  Future<void> deletePlan(String id) async {
    await planRepository.delete(id);
  }

  /// Returns all event-type plans that are at risk (< 30 days away, underfunded).
  Future<List<FinancialPlan>> getAtRiskPlans() async {
    final all = await getPlans(type: PlanType.event);
    return all.where((p) => p.atRisk).toList();
  }

  /// Computes a week-by-week or month-by-month savings schedule for [plan].
  SavingsSchedule computeSavingsSchedule(FinancialPlan plan) {
    final entries = <ScheduleEntry>[];
    var remaining = plan.remainingAmount;
    if (remaining <= 0) return SavingsSchedule(entries: entries, plan: plan);

    final contribution = plan.requiredContribution ?? 0;
    if (contribution <= 0) return SavingsSchedule(entries: entries, plan: plan);

    final isWeekly = plan.contributionFrequency == ContributionFrequency.weekly;
    final stepDays = isWeekly ? 7 : 30;

    var date = DateTime.now().add(Duration(days: isWeekly ? 7 : 30));
    double cumulative = 0;

    while (remaining > 0 && !date.isAfter(plan.targetDate)) {
      final amount = remaining < contribution ? remaining : contribution;
      cumulative += amount;
      remaining -= amount;
      entries.add(
        ScheduleEntry(date: date, amount: amount, cumulativeTotal: cumulative),
      );
      date = date.add(Duration(days: stepDays));
    }

    return SavingsSchedule(entries: entries, plan: plan);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Enriches a raw plan with all computed fields.
  FinancialPlan _enrich(FinancialPlan plan) {
    return _assessAchievability(plan);
  }

  /// Computes [requiredContribution], [achievable], [estimatedCompletionDate],
  /// and [suggestions] for [plan].
  FinancialPlan _assessAchievability(FinancialPlan plan) {
    final now = DateTime.now();
    final remaining = plan.remainingAmount;

    // Already fully funded
    if (remaining <= 0) {
      return plan.copyWith(
        requiredContribution: 0,
        achievable: true,
        estimatedCompletionDate: now,
        suggestions: [],
      );
    }

    final isWeekly = plan.contributionFrequency == ContributionFrequency.weekly;
    final remainingPeriods = isWeekly
        ? plan.targetDate.difference(now).inDays / 7
        : _monthsBetween(now, plan.targetDate).toDouble();

    // Target date already passed or today
    if (remainingPeriods <= 0) {
      return plan.copyWith(
        requiredContribution: remaining,
        achievable: false,
        suggestions: [
          'The target date has passed. Please choose a future date.',
        ],
      );
    }

    final requiredContribution = remaining / remainingPeriods;

    // Monthly surplus → effective per-period surplus
    final monthlySurplus = analysisEngine.estimateMonthlySurplus();
    final effectiveSurplus = isWeekly ? monthlySurplus / 4.33 : monthlySurplus;

    final achievable = requiredContribution <= effectiveSurplus;

    // Estimated completion date at current surplus rate
    final DateTime? completionDate;
    if (effectiveSurplus > 0) {
      final periodsNeeded = remaining / effectiveSurplus;
      completionDate = isWeekly
          ? now.add(Duration(days: (periodsNeeded * 7).round()))
          : DateTime(now.year, now.month + periodsNeeded.ceil(), now.day);
    } else {
      completionDate = null;
    }

    final suggestions = <String>[];
    if (!achievable) {
      // Suggestion 1: extended date at current surplus
      if (completionDate != null) {
        final fmt = DateFormat('d MMM yyyy').format(completionDate);
        final amt = _currencyFmt.format(plan.targetAmount);
        suggestions.add(
          'You could reach $amt by $fmt at your current savings rate.',
        );
      }

      // Suggestion 2: reduced target achievable by target date
      if (effectiveSurplus > 0) {
        final reducedTarget =
            plan.currentSavings + (effectiveSurplus * remainingPeriods);
        final reduced = _currencyFmt.format(
          reducedTarget.clamp(0, double.infinity),
        );
        final targetFmt = DateFormat('d MMM yyyy').format(plan.targetDate);
        suggestions.add(
          'Or reduce your target to $reduced to meet the $targetFmt deadline.',
        );
      }
    }

    return plan.copyWith(
      requiredContribution: requiredContribution,
      achievable: achievable,
      estimatedCompletionDate: completionDate,
      suggestions: suggestions,
    );
  }

  void _validateTargetDate(DateTime targetDate) {
    if (!targetDate.isAfter(DateTime.now())) {
      throw ArgumentError('Target date must be in the future.');
    }
  }

  /// Number of whole months between [from] and [to].
  int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }
}
