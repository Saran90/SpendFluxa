import 'package:flutter/material.dart';

/// Represents a monthly credit card bill
@immutable
class CreditCardBill {
  final String id;
  final String accountId;
  final DateTime billDate;
  final double billAmount;
  final String status; // 'unpaid' or 'paid'
  final DateTime? paidDate;
  final String? paidFromAccountId;

  const CreditCardBill({
    required this.id,
    required this.accountId,
    required this.billDate,
    required this.billAmount,
    required this.status,
    this.paidDate,
    this.paidFromAccountId,
  });

  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'unpaid';

  CreditCardBill copyWith({
    String? id,
    String? accountId,
    DateTime? billDate,
    double? billAmount,
    String? status,
    DateTime? paidDate,
    String? paidFromAccountId,
  }) {
    return CreditCardBill(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      billDate: billDate ?? this.billDate,
      billAmount: billAmount ?? this.billAmount,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'account_id': accountId,
    'bill_date': billDate.toIso8601String(),
    'bill_amount': billAmount,
    'status': status,
    'paid_date': paidDate?.toIso8601String(),
    'paid_from_account_id': paidFromAccountId,
  };

  factory CreditCardBill.fromMap(Map<String, dynamic> map) => CreditCardBill(
    id: map['id'] as String,
    accountId: map['account_id'] as String,
    billDate: DateTime.parse(map['bill_date'] as String),
    billAmount: (map['bill_amount'] as num).toDouble(),
    status: map['status'] as String,
    paidDate: map['paid_date'] != null
        ? DateTime.parse(map['paid_date'] as String)
        : null,
    paidFromAccountId: map['paid_from_account_id'] as String?,
  );
}
