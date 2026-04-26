import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/recurring_confirmation.dart';

/// Service for managing recurring transaction confirmations
class RecurringConfirmationService extends ChangeNotifier {
  final List<RecurringConfirmation> _confirmations = [];

  RecurringConfirmationService() {
    _load();
  }

  List<RecurringConfirmation> get all => List.unmodifiable(_confirmations);

  /// Get pending confirmations for a specific date
  List<RecurringConfirmation> getPendingForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return _confirmations
        .where(
          (c) =>
              c.status == RecurringConfirmationStatus.pending &&
              DateTime(
                c.dueDate.year,
                c.dueDate.month,
                c.dueDate.day,
              ).isAtSameMomentAs(dateOnly),
        )
        .toList();
  }

  /// Get confirmation for a specific recurring transaction and date
  RecurringConfirmation? getConfirmation(
    String recurringTransactionId,
    DateTime dueDate,
  ) {
    final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    try {
      return _confirmations.firstWhere(
        (c) =>
            c.recurringTransactionId == recurringTransactionId &&
            DateTime(
              c.dueDate.year,
              c.dueDate.month,
              c.dueDate.day,
            ).isAtSameMomentAs(dateOnly),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a recurring transaction has been confirmed for a date
  bool isConfirmed(String recurringTransactionId, DateTime dueDate) {
    final confirmation = getConfirmation(recurringTransactionId, dueDate);
    return confirmation != null &&
        confirmation.status == RecurringConfirmationStatus.accepted;
  }

  /// Check if a recurring transaction has been denied for a date
  bool isDenied(String recurringTransactionId, DateTime dueDate) {
    final confirmation = getConfirmation(recurringTransactionId, dueDate);
    return confirmation != null &&
        confirmation.status == RecurringConfirmationStatus.denied;
  }

  /// Create or update a confirmation record
  Future<void> setConfirmation(RecurringConfirmation confirmation) async {
    final existing = getConfirmation(
      confirmation.recurringTransactionId,
      confirmation.dueDate,
    );

    if (existing != null) {
      // Update existing
      final index = _confirmations.indexWhere((c) => c.id == existing.id);
      if (index != -1) {
        _confirmations[index] = confirmation.copyWith(
          status: confirmation.status,
          confirmedAt: DateTime.now(),
        );
      }
    } else {
      // Add new
      _confirmations.add(confirmation);
    }

    await _save(confirmation);
    notifyListeners();
  }

  /// Mark a recurring transaction as accepted for a specific date
  Future<void> accept(String recurringTransactionId, DateTime dueDate) async {
    final existing = getConfirmation(recurringTransactionId, dueDate);
    final confirmation = existing != null
        ? existing.copyWith(
            status: RecurringConfirmationStatus.accepted,
            confirmedAt: DateTime.now(),
          )
        : RecurringConfirmation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            recurringTransactionId: recurringTransactionId,
            dueDate: dueDate,
            status: RecurringConfirmationStatus.accepted,
            confirmedAt: DateTime.now(),
          );

    await setConfirmation(confirmation);
  }

  /// Mark a recurring transaction as denied for a specific date
  Future<void> deny(String recurringTransactionId, DateTime dueDate) async {
    final existing = getConfirmation(recurringTransactionId, dueDate);
    final confirmation = existing != null
        ? existing.copyWith(
            status: RecurringConfirmationStatus.denied,
            confirmedAt: DateTime.now(),
          )
        : RecurringConfirmation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            recurringTransactionId: recurringTransactionId,
            dueDate: dueDate,
            status: RecurringConfirmationStatus.denied,
            confirmedAt: DateTime.now(),
          );

    await setConfirmation(confirmation);
  }

  /// Load confirmations from database
  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('recurring_confirmations');
    _confirmations.clear();
    _confirmations.addAll(
      rows.map((row) => RecurringConfirmation.fromMap(row)),
    );
    notifyListeners();
  }

  /// Save confirmation to database
  Future<void> _save(RecurringConfirmation confirmation) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'recurring_confirmations',
      confirmation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete old confirmations (older than 90 days)
  Future<void> cleanupOldConfirmations() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final db = await AppDatabase.instance.database;
    await db.delete(
      'recurring_confirmations',
      where: 'due_date < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
    await _load();
  }
}
