import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/reminder.dart';
import '../models/transaction.dart' as app_models;
import 'notification_service.dart';

/// Service for managing transaction reminders
class ReminderService extends ChangeNotifier {
  final List<TransactionReminder> _reminders = [];
  final NotificationService _notificationService;

  ReminderService({required NotificationService notificationService})
    : _notificationService = notificationService {
    _load();
  }

  List<TransactionReminder> get allReminders => List.unmodifiable(_reminders);

  /// Get reminders for a specific recurring transaction
  List<TransactionReminder> getRemindersForTransaction(String transactionId) {
    return _reminders
        .where((r) => r.recurringTransactionId == transactionId)
        .toList();
  }

  /// Add a new reminder
  Future<void> addReminder(TransactionReminder reminder) async {
    _reminders.add(reminder);
    await _save(reminder);
    notifyListeners();
  }

  /// Update an existing reminder
  Future<void> updateReminder(TransactionReminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
      await _save(reminder);
      notifyListeners();
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
    await _delete(reminderId);
    await _notificationService.cancelReminder(reminderId);
    notifyListeners();
  }

  /// Delete all reminders for a transaction
  Future<void> deleteRemindersForTransaction(String transactionId) async {
    final toDelete = _reminders
        .where((r) => r.recurringTransactionId == transactionId)
        .toList();

    for (final reminder in toDelete) {
      await deleteReminder(reminder.id);
    }
  }

  /// Schedule notifications for a reminder
  Future<void> scheduleNotifications({
    required TransactionReminder reminder,
    required app_models.Transaction recurringTransaction,
  }) async {
    if (!reminder.isEnabled) return;

    // Calculate upcoming dates for this recurring transaction
    final upcomingDates = _calculateUpcomingDates(
      recurringTransaction,
      limit: 12, // Schedule for next 12 occurrences
    );

    await _notificationService.scheduleRemindersForRecurring(
      reminder: reminder,
      recurringTransaction: recurringTransaction,
      upcomingDates: upcomingDates,
    );
  }

  /// Reschedule all notifications for a transaction
  Future<void> rescheduleNotificationsForTransaction({
    required String transactionId,
    required app_models.Transaction recurringTransaction,
  }) async {
    final reminders = getRemindersForTransaction(transactionId);

    // Cancel existing notifications
    await _notificationService.cancelRemindersForTransaction(transactionId);

    // Schedule new notifications
    for (final reminder in reminders) {
      if (reminder.isEnabled) {
        await scheduleNotifications(
          reminder: reminder,
          recurringTransaction: recurringTransaction,
        );
      }
    }
  }

  /// Calculate upcoming dates for a recurring transaction
  List<DateTime> _calculateUpcomingDates(
    app_models.Transaction transaction, {
    int limit = 12,
  }) {
    if (!transaction.isRecurring) return [];

    final dates = <DateTime>[];
    var currentDate = transaction.date;
    final now = DateTime.now();
    final endDate =
        transaction.recurringEndDate ??
        DateTime.now().add(const Duration(days: 365));

    // Start from next occurrence after today
    while (currentDate.isBefore(now)) {
      currentDate = _getNextOccurrence(
        currentDate,
        transaction.recurringFrequency!,
      );
    }

    while (currentDate.isBefore(endDate) && dates.length < limit) {
      dates.add(currentDate);
      currentDate = _getNextOccurrence(
        currentDate,
        transaction.recurringFrequency!,
      );
    }

    return dates;
  }

  /// Get next occurrence date based on frequency
  DateTime _getNextOccurrence(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return DateTime(current.year, current.month, current.day + 1);
      case 'weekly':
        return DateTime(current.year, current.month, current.day + 7);
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current;
    }
  }

  /// Load reminders from database
  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('reminders');
    _reminders.clear();
    _reminders.addAll(rows.map((row) => TransactionReminder.fromMap(row)));
    notifyListeners();
  }

  /// Save reminder to database
  Future<void> _save(TransactionReminder reminder) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete reminder from database
  Future<void> _delete(String reminderId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [reminderId]);
  }
}
