import '../models/transaction.dart';

/// Utility functions for recurring transactions
class RecurringUtils {
  /// Calculate the next occurrence date for a recurring transaction
  static DateTime? getNextOccurrence(Transaction transaction) {
    if (!transaction.isRecurring || transaction.recurringFrequency == null) {
      return null;
    }

    var currentDate = transaction.date;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final endDate =
        transaction.recurringEndDate ??
        DateTime.now().add(const Duration(days: 365));

    // Move to next occurrence on or after today
    // Use a safety counter to prevent infinite loops
    int iterations = 0;
    const maxIterations = 10000;

    while (currentDate.isBefore(todayMidnight) && iterations < maxIterations) {
      currentDate = _getNextDate(currentDate, transaction.recurringFrequency!);
      iterations++;
    }

    // Check if within end date
    if (currentDate.isAfter(endDate)) {
      return null;
    }

    return currentDate;
  }

  /// Get next date based on frequency
  static DateTime _getNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return _addMonths(current, 1);
      case 'quarterly':
        return _addMonths(current, 3);
      case 'yearly':
        return _addMonths(current, 12);
      default:
        return current;
    }
  }

  /// Helper to safely add months, handling day overflow
  static DateTime _addMonths(DateTime date, int months) {
    var month = date.month + months;
    var year = date.year;

    // Handle year overflow
    while (month > 12) {
      month -= 12;
      year += 1;
    }

    // Handle day overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    var day = date.day;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (day > lastDayOfMonth) {
      day = lastDayOfMonth;
    }

    return DateTime(year, month, day);
  }
}
