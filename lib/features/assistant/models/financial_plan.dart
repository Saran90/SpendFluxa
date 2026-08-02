/// Whether this plan is a long-term savings goal or a one-time future event.
enum PlanType { goal, event }

/// Urgency level for goal-type plans.
enum PlanPriority { low, medium, high }

/// How often the user intends to contribute toward the plan.
enum ContributionFrequency { weekly, monthly }

/// A unified model representing either a savings goal (e.g. emergency fund,
/// house down payment) or a future expense event (e.g. vacation, wedding).
///
/// Persisted in the `financial_plans` SQLite table.
/// Computed fields ([requiredContribution], [achievable], etc.) are NOT
/// persisted — they are set by [PlanManager] after loading from the DB.
class FinancialPlan {
  const FinancialPlan({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.targetDate,
    required this.contributionFrequency,
    required this.createdAt,
    this.priority,
    this.currentSavings = 0,
    this.preferredAccountId,
    // Computed — not persisted
    this.requiredContribution,
    this.achievable,
    this.estimatedCompletionDate,
    this.suggestions = const [],
  });

  // ── Persisted fields ───────────────────────────────────────────────────────

  final String id;
  final String name;
  final PlanType type;
  final double targetAmount;
  final DateTime targetDate;

  /// Urgency level — meaningful for [PlanType.goal] plans only.
  final PlanPriority? priority;

  final double currentSavings;
  final String? preferredAccountId;
  final ContributionFrequency contributionFrequency;
  final DateTime createdAt;

  // ── Computed fields (set by PlanManager, not persisted) ───────────────────

  final double? requiredContribution;
  final bool? achievable;
  final DateTime? estimatedCompletionDate;

  /// Suggested adjustments when [achievable] is false.
  final List<String> suggestions;

  // ── Derived helpers ────────────────────────────────────────────────────────

  double get remainingAmount =>
      (targetAmount - currentSavings).clamp(0, double.infinity);

  /// For [PlanType.event] plans: true if the event is less than 30 days away
  /// and the target amount has not been fully funded.
  bool get atRisk {
    if (type != PlanType.event) return false;
    final daysUntil = targetDate.difference(DateTime.now()).inDays;
    return daysUntil < 30 && currentSavings < targetAmount;
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'target_amount': targetAmount,
    'target_date': targetDate.toIso8601String(),
    'priority': priority?.name,
    'current_savings': currentSavings,
    'preferred_account_id': preferredAccountId,
    'contribution_frequency': contributionFrequency.name,
    'created_at': createdAt.toIso8601String(),
  };

  factory FinancialPlan.fromMap(Map<String, dynamic> map) => FinancialPlan(
    id: map['id'] as String,
    name: map['name'] as String,
    type: PlanType.values.firstWhere(
      (t) => t.name == map['type'],
      orElse: () => PlanType.goal,
    ),
    targetAmount: (map['target_amount'] as num).toDouble(),
    targetDate: DateTime.parse(map['target_date'] as String),
    priority: map['priority'] != null
        ? PlanPriority.values.firstWhere(
            (p) => p.name == map['priority'],
            orElse: () => PlanPriority.medium,
          )
        : null,
    currentSavings: (map['current_savings'] as num? ?? 0).toDouble(),
    preferredAccountId: map['preferred_account_id'] as String?,
    contributionFrequency: ContributionFrequency.values.firstWhere(
      (f) => f.name == map['contribution_frequency'],
      orElse: () => ContributionFrequency.monthly,
    ),
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  FinancialPlan copyWith({
    String? id,
    String? name,
    PlanType? type,
    double? targetAmount,
    DateTime? targetDate,
    PlanPriority? priority,
    double? currentSavings,
    String? preferredAccountId,
    ContributionFrequency? contributionFrequency,
    DateTime? createdAt,
    double? requiredContribution,
    bool? achievable,
    DateTime? estimatedCompletionDate,
    List<String>? suggestions,
  }) => FinancialPlan(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    targetAmount: targetAmount ?? this.targetAmount,
    targetDate: targetDate ?? this.targetDate,
    priority: priority ?? this.priority,
    currentSavings: currentSavings ?? this.currentSavings,
    preferredAccountId: preferredAccountId ?? this.preferredAccountId,
    contributionFrequency: contributionFrequency ?? this.contributionFrequency,
    createdAt: createdAt ?? this.createdAt,
    requiredContribution: requiredContribution ?? this.requiredContribution,
    achievable: achievable ?? this.achievable,
    estimatedCompletionDate:
        estimatedCompletionDate ?? this.estimatedCompletionDate,
    suggestions: suggestions ?? this.suggestions,
  );
}
