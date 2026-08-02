/// A record of a Proactive_Alert that was emitted by the Alert_Engine.
///
/// Persisted in the `alert_records` SQLite table for 24-hour deduplication.
/// Rows older than 7 days are purged at the start of each [AlertEngine.evaluateAll] run.
class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.alertType,
    required this.subject,
    required this.emittedAt,
  });

  final String id;

  /// Identifies the kind of alert (e.g. `budget_category_80`, `salary_overdue`).
  final String alertType;

  /// Narrows the alert to a specific entity (e.g. a category name, account id).
  /// Empty string when the alert is not entity-specific.
  final String subject;

  final DateTime emittedAt;

  // ── Alert type constants ───────────────────────────────────────────────────

  static const budgetOverall80 = 'budget_overall_80';
  static const budgetCategory80 = 'budget_category_80';
  static const spendSpikeCategory = 'spend_spike_category';
  static const recurringBalanceRisk = 'recurring_balance_risk';
  static const creditCardDue = 'credit_card_due';
  static const salaryOverdue = 'salary_overdue';
  static const balanceForecastZero = 'balance_forecast_zero';
  static const debtIncomeRatio = 'debt_income_ratio';

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'alert_type': alertType,
    'subject': subject,
    'emitted_at': emittedAt.toIso8601String(),
  };

  factory AlertRecord.fromMap(Map<String, dynamic> map) => AlertRecord(
    id: map['id'] as String,
    alertType: map['alert_type'] as String,
    subject: (map['subject'] as String?) ?? '',
    emittedAt: DateTime.parse(map['emitted_at'] as String),
  );
}
