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
import '../transactions/transaction_detail_screen.dart';

class CategoryTransactionsScreen extends StatelessWidget {
  /// The display key — either a customCategoryId or a built-in category name.
  final String categoryKey;
  final ResolvedCategory resolved;
  final DateTime month;
  final bool includeGeneral;
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final TagService tagService;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryKey,
    required this.resolved,
    required this.month,
    this.includeGeneral = false,
    required this.transactionService,
    required this.categoryService,
    required this.currencyService,
    required this.accountService,
    required this.tagService,
  });

  /// Returns all expense transactions for this category in the given month.
  List<Transaction> _transactions() {
    return transactionService
        .transactionsForMonth(month.year, month.month)
        .where((t) {
          if (!t.isExpense) return false;
          if (!includeGeneral && !t.isMonthly) return false;
          final key = t.customCategoryId ?? t.category.name;
          return key == categoryKey;
        })
        .toList();
  }

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
        listenable: Listenable.merge([transactionService, currencyService]),
        builder: (context, _) {
          final txs = _transactions();
          final total = txs.fold(0.0, (s, t) => s + t.amount);
          final fmt = currencyService.formatter;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Gradient hero header ──────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHero(context, total, txs.length, fmt),
              ),

              // ── Transaction list ──────────────────────────────────────
              if (txs.isEmpty)
                SliverFillRemaining(child: _buildEmpty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _TransactionTile(
                        transaction: txs[i],
                        categoryService: categoryService,
                        currencyService: currencyService,
                        fmt: fmt,
                        onTap: () => _openDetail(context, txs[i]),
                      ),
                      childCount: txs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(
    BuildContext context,
    double total,
    int count,
    NumberFormat fmt,
  ) {
    // Derive two gradient shades from the category color
    final base = resolved.color;
    final dark = Color.lerp(base, Colors.black, 0.28)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, dark],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),

              // Category icon + name
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(resolved.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolved.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$count transaction${count == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Total amount
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spent',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(total),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
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

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolved.icon, size: 56, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            'No transactions in ${DateFormat('MMMM').format(month)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetail(BuildContext context, Transaction tx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          transactionService: transactionService,
          categoryService: categoryService,
          currencyService: currencyService,
          accountService: accountService,
          tagService: tagService,
        ),
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.categoryService,
    required this.currencyService,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = transaction.resolveCategory(categoryService.getById);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(cat.icon, color: cat.color, size: 21),
            ),
            const SizedBox(width: 14),

            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title.isEmpty ? cat.label : transaction.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(transaction.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (transaction.note != null &&
                          transaction.note!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            transaction.note!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Amount
            Text(
              '-${fmt.format(transaction.amount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
