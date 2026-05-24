/// Determines how credit card transactions count toward monthly budget
enum BudgetCountingMethod {
  committed, // Count all CC transactions (for strict budgeting)
  billed, // Count only transactions in current bill (for reconciliation)
  paid, // Count only when bill is paid (for actual spending)
}

extension BudgetCountingMethodExtension on BudgetCountingMethod {
  String get label {
    switch (this) {
      case BudgetCountingMethod.committed:
        return 'Committed';
      case BudgetCountingMethod.billed:
        return 'Billed';
      case BudgetCountingMethod.paid:
        return 'Paid';
    }
  }

  String get description {
    switch (this) {
      case BudgetCountingMethod.committed:
        return 'Count all credit card transactions';
      case BudgetCountingMethod.billed:
        return 'Count only transactions in current bill';
      case BudgetCountingMethod.paid:
        return 'Count only when bill is paid';
    }
  }
}

/// Configuration for credit card accounts
class CreditCardConfig {
  final int billingCycleDay; // Day of month bill is generated (1-28)
  final BudgetCountingMethod budgetCountingMethod;
  final String? issuerName; // e.g., "HDFC", "ICICI"
  final double? creditLimit; // Optional
  final DateTime? statementStartDate; // For tracking cycles
  final int? reminderDaysBefore; // Days before due date to remind (default: 3)

  const CreditCardConfig({
    required this.billingCycleDay,
    this.budgetCountingMethod = BudgetCountingMethod.committed,
    this.issuerName,
    this.creditLimit,
    this.statementStartDate,
    this.reminderDaysBefore = 3,
  });

  CreditCardConfig copyWith({
    int? billingCycleDay,
    BudgetCountingMethod? budgetCountingMethod,
    String? issuerName,
    double? creditLimit,
    DateTime? statementStartDate,
    int? reminderDaysBefore,
  }) {
    return CreditCardConfig(
      billingCycleDay: billingCycleDay ?? this.billingCycleDay,
      budgetCountingMethod: budgetCountingMethod ?? this.budgetCountingMethod,
      issuerName: issuerName ?? this.issuerName,
      creditLimit: creditLimit ?? this.creditLimit,
      statementStartDate: statementStartDate ?? this.statementStartDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    );
  }

  Map<String, dynamic> toMap() => {
    'billingCycleDay': billingCycleDay,
    'budgetCountingMethod': budgetCountingMethod.name,
    'issuerName': issuerName,
    'creditLimit': creditLimit,
    'statementStartDate': statementStartDate?.toIso8601String(),
    'reminderDaysBefore': reminderDaysBefore,
  };

  factory CreditCardConfig.fromMap(Map<String, dynamic> map) =>
      CreditCardConfig(
        billingCycleDay: map['billingCycleDay'] as int,
        budgetCountingMethod: BudgetCountingMethod.values.firstWhere(
          (m) => m.name == map['budgetCountingMethod'],
          orElse: () => BudgetCountingMethod.committed,
        ),
        issuerName: map['issuerName'] as String?,
        creditLimit: map['creditLimit'] != null
            ? (map['creditLimit'] as num).toDouble()
            : null,
        statementStartDate: map['statementStartDate'] != null
            ? DateTime.parse(map['statementStartDate'] as String)
            : null,
        reminderDaysBefore: map['reminderDaysBefore'] as int? ?? 3,
      );
}
