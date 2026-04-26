import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/models/reminder.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';

/// Banner showing upcoming transaction reminders
class ReminderBanner extends StatelessWidget {
  final ReminderService reminderService;
  final TransactionService transactionService;
  final VoidCallback? onTap;

  const ReminderBanner({
    super.key,
    required this.reminderService,
    required this.transactionService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final upcomingReminders = _getUpcomingReminders();

    if (upcomingReminders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: upcomingReminders
            .take(3) // Show max 3 reminders
            .map((item) => _buildReminderCard(context, item))
            .toList(),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Map<String, dynamic> item) {
    final transaction = item['transaction'] as Transaction;
    final nextDate = item['nextDate'] as DateTime;
    final reminder = item['reminder'] as TransactionReminder;
    final reminderDate = item['reminderDate'] as DateTime;

    // Calculate days until the REMINDER triggers (not the transaction date)
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final reminderDateOnly = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
    );
    final daysUntil = reminderDateOnly.difference(nowDate).inDays;

    final timeStr = reminder.time.format(context);
    final dateStr = DateFormat('MMM d').format(nextDate);

    String urgencyText;
    Color urgencyColor;
    IconData urgencyIcon;

    if (daysUntil == 0) {
      urgencyText = 'Today';
      urgencyColor = const Color(0xFFFF6B6B);
      urgencyIcon = Icons.warning_rounded;
    } else if (daysUntil == 1) {
      urgencyText = 'Tomorrow';
      urgencyColor = const Color(0xFFFF9800);
      urgencyIcon = Icons.info_rounded;
    } else if (daysUntil <= 3) {
      urgencyText = 'In $daysUntil days';
      urgencyColor = const Color(0xFF4ECDC4);
      urgencyIcon = Icons.notifications_active_rounded;
    } else {
      urgencyText = 'In $daysUntil days';
      urgencyColor = const Color(0xFF4ECDC4);
      urgencyIcon = Icons.notifications_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            urgencyColor.withValues(alpha: 0.1),
            urgencyColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgencyColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Urgency indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(urgencyIcon, color: urgencyColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Transaction info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          urgencyText.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgencyColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        transaction.category.icon,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        transaction.category.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(transaction.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: transaction.isIncome
                        ? const Color(0xFF2D9E6B)
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: transaction.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.recurringFrequency?.toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: transaction.category.color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get upcoming reminders within the next 7 days
  List<Map<String, dynamic>> _getUpcomingReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingReminders = <Map<String, dynamic>>[];

    // Get all recurring transactions
    final recurringTransactions = transactionService.getRecurringTemplates();

    for (final transaction in recurringTransactions) {
      // Get reminders for this transaction
      final reminders = reminderService
          .getRemindersForTransaction(transaction.id)
          .where((r) => r.isEnabled)
          .toList();

      if (reminders.isEmpty) continue;

      // Calculate next occurrence
      final nextDate = _getNextOccurrence(transaction);
      if (nextDate == null) continue;

      // Check if any reminder should trigger within 7 days
      for (final reminder in reminders) {
        final reminderDate = nextDate.subtract(
          Duration(days: reminder.daysBefore),
        );

        final reminderDateOnly = DateTime(
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
        );
        final daysUntil = reminderDateOnly.difference(today).inDays;

        // Show reminders for next 7 days
        if (daysUntil >= 0 && daysUntil <= 7) {
          upcomingReminders.add({
            'transaction': transaction,
            'nextDate': nextDate,
            'reminder': reminder,
            'reminderDate': reminderDate,
            'daysUntil': daysUntil,
          });
        }
      }
    }

    // Sort by urgency (closest first)
    upcomingReminders.sort((a, b) {
      return (a['daysUntil'] as int).compareTo(b['daysUntil'] as int);
    });

    return upcomingReminders;
  }

  /// Calculate next occurrence of a recurring transaction
  DateTime? _getNextOccurrence(Transaction transaction) {
    if (!transaction.isRecurring || transaction.recurringFrequency == null) {
      return null;
    }

    var currentDate = transaction.date;
    final now = DateTime.now();
    final endDate =
        transaction.recurringEndDate ??
        DateTime.now().add(const Duration(days: 365));

    // Move to next occurrence after today
    while (currentDate.isBefore(now)) {
      currentDate = _getNextDate(currentDate, transaction.recurringFrequency!);
    }

    // Check if within end date
    if (currentDate.isAfter(endDate)) {
      return null;
    }

    return currentDate;
  }

  /// Get next date based on frequency
  DateTime _getNextDate(DateTime current, String frequency) {
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
}
