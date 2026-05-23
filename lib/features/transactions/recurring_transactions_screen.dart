import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/recurring_utils.dart';
import 'recurring_transaction_detail_screen.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CategoryService categoryService;
  final AccountService accountService;
  final TagService tagService;

  const RecurringTransactionsScreen({
    super.key,
    required this.transactionService,
    required this.currencyService,
    required this.categoryService,
    required this.accountService,
    required this.tagService,
  });

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: transactionService,
        builder: (context, _) {
          final templates = transactionService.getRecurringTemplates();

          return Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: templates.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: templates.length,
                        itemBuilder: (_, i) => _RecurringTile(
                          tx: templates[i],
                          fmt: currencyService.formatter,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecurringTransactionDetailScreen(
                                transaction: templates[i],
                                transactionService: transactionService,
                                currencyService: currencyService,
                                categoryService: categoryService,
                                accountService: accountService,
                                tagService: tagService,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 24),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurring Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'All your scheduled transactions',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 56, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Text(
            'No recurring transactions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a recurring transaction to see it here',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final Transaction tx;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _RecurringTile({
    required this.tx,
    required this.fmt,
    required this.onTap,
  });

  String get _frequencyLabel {
    switch (tx.recurringFrequency) {
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
        return 'Recurring';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sign = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome
        ? const Color(0xFF2D9E6B)
        : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tx.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    tx.category.icon,
                    color: tx.category.color,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.repeat_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title.replaceAll(' (Recurring)', ''),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _frequencyLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tx.category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tx.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tx.category.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Next payment date
                  if (RecurringUtils.getNextOccurrence(tx) != null) ...[
                    Text(
                      'Next: ${DateFormat('MMM d, yyyy').format(RecurringUtils.getNextOccurrence(tx)!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (tx.recurringEndDate != null) ...[
                    Text(
                      'Until ${DateFormat('MMM d, yyyy').format(tx.recurringEndDate!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${fmt.format(tx.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
