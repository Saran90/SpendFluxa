/// Tracks whether a user has confirmed or denied a recurring transaction
/// for a specific date
class RecurringConfirmation {
  final String id;
  final String recurringTransactionId; // Links to the recurring template
  final DateTime dueDate; // The date this instance is due
  final RecurringConfirmationStatus status;
  final DateTime? confirmedAt;

  const RecurringConfirmation({
    required this.id,
    required this.recurringTransactionId,
    required this.dueDate,
    required this.status,
    this.confirmedAt,
  });

  RecurringConfirmation copyWith({
    RecurringConfirmationStatus? status,
    DateTime? confirmedAt,
  }) {
    return RecurringConfirmation(
      id: id,
      recurringTransactionId: recurringTransactionId,
      dueDate: dueDate,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'recurring_transaction_id': recurringTransactionId,
    'due_date': dueDate.toIso8601String(),
    'status': status.name,
    'confirmed_at': confirmedAt?.toIso8601String(),
  };

  factory RecurringConfirmation.fromMap(Map<String, dynamic> map) =>
      RecurringConfirmation(
        id: map['id'] as String,
        recurringTransactionId: map['recurring_transaction_id'] as String,
        dueDate: DateTime.parse(map['due_date'] as String),
        status: RecurringConfirmationStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => RecurringConfirmationStatus.pending,
        ),
        confirmedAt: map['confirmed_at'] != null
            ? DateTime.parse(map['confirmed_at'] as String)
            : null,
      );
}

enum RecurringConfirmationStatus {
  pending, // Waiting for user action
  accepted, // User accepted, transaction created
  denied, // User denied, skip this occurrence
}
