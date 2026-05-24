/// Represents the state of a credit card transaction
enum TransactionState {
  pending, // Created, not yet billed
  billed, // Included in a bill
  paid, // Bill containing this transaction has been paid
}

extension TransactionStateExtension on TransactionState {
  String get label {
    switch (this) {
      case TransactionState.pending:
        return 'Pending';
      case TransactionState.billed:
        return 'Billed';
      case TransactionState.paid:
        return 'Paid';
    }
  }

  String get description {
    switch (this) {
      case TransactionState.pending:
        return 'Not yet included in a bill';
      case TransactionState.billed:
        return 'Included in current bill';
      case TransactionState.paid:
        return 'Bill has been paid';
    }
  }
}

/// Represents the status of a credit card bill
enum BillStatus {
  pending, // Created, not yet paid
  partial, // Partially paid
  paid, // Fully paid
}

extension BillStatusExtension on BillStatus {
  String get label {
    switch (this) {
      case BillStatus.pending:
        return 'Pending';
      case BillStatus.partial:
        return 'Partially Paid';
      case BillStatus.paid:
        return 'Paid';
    }
  }
}

/// Represents a payment made toward a credit card bill
class BillPayment {
  final String id;
  final String billId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;

  const BillPayment({
    required this.id,
    required this.billId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
  });

  BillPayment copyWith({
    String? id,
    String? billId,
    double? amount,
    DateTime? paymentDate,
    String? note,
    DateTime? createdAt,
  }) {
    return BillPayment(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'billId': billId,
    'amount': amount,
    'paymentDate': paymentDate.toIso8601String(),
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BillPayment.fromMap(Map<String, dynamic> map) => BillPayment(
    id: map['id'] as String,
    billId: map['billId'] as String,
    amount: (map['amount'] as num).toDouble(),
    paymentDate: DateTime.parse(map['paymentDate'] as String),
    note: map['note'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

/// Represents a credit card bill/statement
class CreditCardBill {
  final String id;
  final String creditCardAccountId;
  final DateTime billDate;
  final DateTime dueDate;
  final double trackedAmount; // Sum of transactions
  final double actualAmount; // From bank statement
  final double? difference; // Surcharges, interest, fees
  final String? differenceNote; // Explanation of difference
  final List<String> transactionIds; // Transactions in this bill
  final BillStatus status; // pending, partial, paid
  final List<BillPayment> payments; // Payment history
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditCardBill({
    required this.id,
    required this.creditCardAccountId,
    required this.billDate,
    required this.dueDate,
    required this.trackedAmount,
    required this.actualAmount,
    this.difference,
    this.differenceNote,
    this.transactionIds = const [],
    this.status = BillStatus.pending,
    this.payments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Outstanding balance = actualAmount - totalPaid
  double get outstandingBalance => actualAmount - totalPaid;

  /// Total amount paid toward this bill
  double get totalPaid => payments.fold(0, (sum, p) => sum + p.amount);

  /// Whether the bill is fully paid
  bool get isFullyPaid => outstandingBalance <= 0;

  /// Whether the bill is partially paid
  bool get isPartiallyPaid => totalPaid > 0 && !isFullyPaid;

  /// Reconciliation difference (tracked vs actual)
  double get reconciliationDifference => actualAmount - trackedAmount;

  CreditCardBill copyWith({
    String? id,
    String? creditCardAccountId,
    DateTime? billDate,
    DateTime? dueDate,
    double? trackedAmount,
    double? actualAmount,
    double? difference,
    String? differenceNote,
    List<String>? transactionIds,
    BillStatus? status,
    List<BillPayment>? payments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCardBill(
      id: id ?? this.id,
      creditCardAccountId: creditCardAccountId ?? this.creditCardAccountId,
      billDate: billDate ?? this.billDate,
      dueDate: dueDate ?? this.dueDate,
      trackedAmount: trackedAmount ?? this.trackedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      difference: difference ?? this.difference,
      differenceNote: differenceNote ?? this.differenceNote,
      transactionIds: transactionIds ?? this.transactionIds,
      status: status ?? this.status,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'creditCardAccountId': creditCardAccountId,
    'billDate': billDate.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'trackedAmount': trackedAmount,
    'actualAmount': actualAmount,
    'difference': difference,
    'differenceNote': differenceNote,
    'transactionIds': transactionIds,
    'status': status.name,
    'payments': payments.map((p) => p.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CreditCardBill.fromMap(Map<String, dynamic> map) => CreditCardBill(
    id: map['id'] as String,
    creditCardAccountId: map['creditCardAccountId'] as String,
    billDate: DateTime.parse(map['billDate'] as String),
    dueDate: DateTime.parse(map['dueDate'] as String),
    trackedAmount: (map['trackedAmount'] as num).toDouble(),
    actualAmount: (map['actualAmount'] as num).toDouble(),
    difference: map['difference'] != null
        ? (map['difference'] as num).toDouble()
        : null,
    differenceNote: map['differenceNote'] as String?,
    transactionIds: map['transactionIds'] != null
        ? List<String>.from(map['transactionIds'] as List)
        : const [],
    status: BillStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => BillStatus.pending,
    ),
    payments: map['payments'] != null
        ? (map['payments'] as List)
              .map((p) => BillPayment.fromMap(p as Map<String, dynamic>))
              .toList()
        : const [],
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}
