import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/recurring_confirmation_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';

/// Banner showing recurring transactions that need user confirmation today
class RecurringConfirmationBanner extends StatelessWidget {
  final RecurringConfirmationService confirmationService;
  final TransactionService transactionService;

  const RecurringConfirmationBanner({
    super.key,
    required this.confirmationService,
    required this.transactionService,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final pendingTransactions = _getPendingTransactionsForToday(today);

    if (pendingTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: pendingTransactions
            .map((tx) => _buildConfirmationCard(context, tx, today))
            .toList(),
      ),
    );
  }

  /// Get recurring transactions that are due today and haven't been confirmed
  List<Transaction> _getPendingTransactionsForToday(DateTime today) {
    final recurringTemplates = transactionService.getRecurringTemplates();
    final pending = <Transaction>[];

    for (final template in recurringTemplates) {
      final nextOccurrence = _getNextOccurrence(template);
      if (nextOccurrence == null) continue;

      // Check if it's due today
      final isToday =
          nextOccurrence.year == today.year &&
          nextOccurrence.month == today.month &&
          nextOccurrence.day == today.day;

      if (!isToday) continue;

      // Check if already confirmed or denied
      final confirmation = confirmationService.getConfirmation(
        template.id,
        nextOccurrence,
      );

      if (confirmation == null) {
        // Not yet confirmed or denied
        pending.add(template);
      }
    }

    return pending;
  }

  Widget _buildConfirmationCard(
    BuildContext context,
    Transaction transaction,
    DateTime dueDate,
  ) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9800).withValues(alpha: 0.15),
            const Color(0xFFFF9800).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  transaction.category.icon,
                  color: transaction.category.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DUE TODAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.repeat_rounded,
                          size: 16,
                          color: Color(0xFFFF9800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transaction.title.replaceAll(' (Recurring)', ''),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                fmt.format(transaction.amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: transaction.isIncome
                      ? const Color(0xFF2D9E6B)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Row(
            children: [
              Icon(
                transaction.category.icon,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                transaction.category.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Recurring ${transaction.recurringFrequency}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Question and action buttons
          const Text(
            'Record this transaction?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Not Now',
                  icon: Icons.close_rounded,
                  color: AppColors.textSecondary,
                  onTap: () => _handleDeny(context, transaction, dueDate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: 'Record',
                  icon: Icons.check_rounded,
                  color: const Color(0xFF2D9E6B),
                  isPrimary: true,
                  onTap: () => _handleAccept(context, transaction, dueDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept(
    BuildContext context,
    Transaction template,
    DateTime dueDate,
  ) async {
    // Mark as accepted
    await confirmationService.accept(template.id, dueDate);

    // Create the actual transaction
    final newTransaction = Transaction(
      id: '${template.id}_${dueDate.millisecondsSinceEpoch}',
      title: template.title.replaceAll(' (Recurring)', ''),
      amount: template.amount,
      type: template.type,
      category: template.category,
      date: dueDate,
      note: template.note,
      accountId: template.accountId,
      toAccountId: template.toAccountId,
      tagIds: template.tagIds,
      recurringParentId: template.id,
      excludeFromExpense: template.excludeFromExpense,
    );

    await transactionService.addTransaction(newTransaction);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${template.title} recorded successfully'),
          backgroundColor: const Color(0xFF2D9E6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleDeny(
    BuildContext context,
    Transaction template,
    DateTime dueDate,
  ) async {
    // Mark as denied
    await confirmationService.deny(template.id, dueDate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction skipped'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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

    // Move to next occurrence after or on today
    while (currentDate.isBefore(DateTime(now.year, now.month, now.day))) {
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isPrimary ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
