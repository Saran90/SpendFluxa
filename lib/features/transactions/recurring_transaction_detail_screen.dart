import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import 'add_transaction_screen.dart';

class RecurringTransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CategoryService categoryService;
  final AccountService accountService;
  final TagService tagService;

  const RecurringTransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.transactionService,
    required this.currencyService,
    required this.categoryService,
    required this.accountService,
    required this.tagService,
  });

  List<Color> get _gradient {
    switch (transaction.type) {
      case TransactionType.income:
        return const [Color(0xFF2D9E6B), Color(0xFF1A7A50)];
      case TransactionType.transfer:
        return const [Color(0xFF4ECDC4), Color(0xFF2D9E8F)];
      case TransactionType.expense:
        return const [Color(0xFFFF6B6B), Color(0xFFE53935)];
    }
  }

  Color get _typeColor => _gradient[0];

  String get _frequencyLabel {
    switch (transaction.recurringFrequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        final f = transaction.recurringFrequency ?? '';
        if (f.startsWith('custom_')) {
          final days = f.substring(7);
          return 'Every $days days';
        }
        return 'Recurring';
    }
  }

  /// Returns the next occurrence date after today, or null if the series has ended.
  DateTime? get _nextOccurrence {
    final frequency = transaction.recurringFrequency;
    if (frequency == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = transaction.recurringEndDate;

    var current = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );

    // Advance until we reach a date on or after today
    while (current.isBefore(today)) {
      current = _nextDate(current, frequency);
    }

    // If it lands exactly on today, show today; otherwise it's a future date
    if (endDate != null && current.isAfter(endDate)) return null;
    return current;
  }

  DateTime _nextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return DateTime(current.year, current.month, current.day + 1);
      case 'weekly':
        return DateTime(current.year, current.month, current.day + 7);
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'quarterly':
        return DateTime(current.year, current.month + 3, current.day);
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7)) ?? 1;
          return DateTime(current.year, current.month, current.day + days);
        }
        return current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = currencyService.formatter;
    final sign = transaction.isIncome ? '+' : '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHero(context, fmt, sign),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 14),
                _buildRecurringCard(),
                const SizedBox(height: 14),
                if (transaction.accountId != null) ...[
                  _buildAccountCard(),
                  const SizedBox(height: 14),
                ],
                if (transaction.note != null &&
                    transaction.note!.isNotEmpty) ...[
                  _buildNoteCard(),
                  const SizedBox(height: 14),
                ],
                _buildEditButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, NumberFormat fmt, String sign) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradient,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Recurring ${transaction.isIncome ? 'Income' : 'Expense'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => _openEdit(context),
                    tooltip: 'Edit',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyService.symbol,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 2.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        fmt
                            .format(transaction.amount)
                            .replaceFirst(currencyService.symbol, ''),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.title.replaceAll(' (Recurring)', ''),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _frequencyLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final isPast = startDate.isBefore(today);
    final next = _nextOccurrence;

    final dateLabel = isPast ? 'Next Date' : 'Start Date';
    final dateValue = isPast && next != null
        ? DateFormat('EEEE, MMM d, yyyy').format(next)
        : DateFormat('EEEE, MMM d, yyyy').format(transaction.date);

    return _Card(
      child: Column(
        children: [
          _InfoRow(
            icon: transaction.category.icon,
            iconColor: transaction.category.color,
            label: 'Category',
            value: transaction.category.label,
          ),
          _divider(),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            iconColor: _typeColor,
            label: dateLabel,
            value: dateValue,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCard() {
    final next = _nextOccurrence;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String nextLabel;
    if (next == null) {
      nextLabel = 'Series ended';
    } else if (next == today) {
      nextLabel = 'Today';
    } else {
      final daysAway = next.difference(today).inDays;
      final dateStr = DateFormat('MMM d, yyyy').format(next);
      nextLabel = daysAway == 1
          ? 'Tomorrow · $dateStr'
          : 'In $daysAway days · $dateStr';
    }

    return _Card(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.repeat_rounded,
            iconColor: AppColors.primary,
            label: 'Frequency',
            value: _frequencyLabel,
          ),
          _divider(),
          _InfoRow(
            icon: Icons.event_available_rounded,
            iconColor: next != null
                ? const Color(0xFF2D9E6B)
                : AppColors.textSecondary,
            label: 'Next Occurrence',
            value: nextLabel,
          ),
          if (transaction.recurringEndDate != null) ...[
            _divider(),
            _InfoRow(
              icon: Icons.event_rounded,
              iconColor: AppColors.primary,
              label: 'End Date',
              value: DateFormat(
                'MMM d, yyyy',
              ).format(transaction.recurringEndDate!),
            ),
          ] else ...[
            _divider(),
            const _InfoRow(
              icon: Icons.all_inclusive_rounded,
              iconColor: AppColors.primary,
              label: 'End Date',
              value: 'No end date',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final account = accountService.all
        .where((a) => a.id == transaction.accountId)
        .firstOrNull;
    if (account == null) return const SizedBox();

    return _Card(
      child: _InfoRow(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: account.color,
        label: 'Account',
        value: account.name,
      ),
    );
  }

  Widget _buildNoteCard() {
    return _Card(
      child: _InfoRow(
        icon: Icons.notes_rounded,
        iconColor: AppColors.textSecondary,
        label: 'Note',
        value: transaction.note!,
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _openEdit(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _typeColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Edit Recurring Transaction',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => AddTransactionScreen(
          transactionService: transactionService,
          categoryService: categoryService,
          currencyService: currencyService,
          accountService: accountService,
          tagService: tagService,
          editing: transaction,
          editRecurringTemplateOnly: true,
        ),
        transitionsBuilder: (context, animation, _, child) {
          final tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Widget _divider() => const Divider(
    height: 1,
    indent: 46,
    endIndent: 0,
    color: Color(0xFFF0F2F5),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
