import 'package:flutter/material.dart';

/// Model for transaction reminders
class TransactionReminder {
  final String id;
  final String recurringTransactionId; // Parent recurring transaction ID
  final int daysBefore; // 0 = same day, 1 = 1 day before, etc.
  final TimeOfDay time; // Time to send reminder
  final bool isEnabled;

  TransactionReminder({
    required this.id,
    required this.recurringTransactionId,
    required this.daysBefore,
    required this.time,
    this.isEnabled = true,
  });

  TransactionReminder copyWith({
    String? id,
    String? recurringTransactionId,
    int? daysBefore,
    TimeOfDay? time,
    bool? isEnabled,
  }) {
    return TransactionReminder(
      id: id ?? this.id,
      recurringTransactionId:
          recurringTransactionId ?? this.recurringTransactionId,
      daysBefore: daysBefore ?? this.daysBefore,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurring_transaction_id': recurringTransactionId,
      'days_before': daysBefore,
      'time_hour': time.hour,
      'time_minute': time.minute,
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  factory TransactionReminder.fromMap(Map<String, dynamic> map) {
    return TransactionReminder(
      id: map['id'] as String,
      recurringTransactionId: map['recurring_transaction_id'] as String,
      daysBefore: map['days_before'] as int,
      time: TimeOfDay(
        hour: map['time_hour'] as int,
        minute: map['time_minute'] as int,
      ),
      isEnabled: (map['is_enabled'] as int) == 1,
    );
  }

  String get daysBeforeLabel {
    switch (daysBefore) {
      case 0:
        return 'Same day';
      case 1:
        return '1 day before';
      default:
        return '$daysBefore days before';
    }
  }
}
