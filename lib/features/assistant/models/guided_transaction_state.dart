/// Represents the state of a guided transaction being filled out step-by-step in chat.
class GuidedTransactionState {
  const GuidedTransactionState({
    required this.type, // 'expense' or 'income'
    this.amount,
    this.category,
    this.account,
    this.description,
    this.date,
    required this.currentStep, // 'amount', 'category', 'account', 'date', 'confirm'
  });

  final String type; // 'expense' or 'income'
  final double? amount;
  final String? category;
  final String? account;
  final String? description;
  final DateTime? date;
  final String currentStep;

  GuidedTransactionState copyWith({
    String? type,
    double? amount,
    String? category,
    String? account,
    String? description,
    DateTime? date,
    String? currentStep,
  }) {
    return GuidedTransactionState(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      account: account ?? this.account,
      description: description ?? this.description,
      date: date ?? this.date,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  bool get isComplete =>
      amount != null && category != null && account != null && date != null;
}
