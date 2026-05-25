import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import '../transactions/transaction_detail_screen.dart';

class CategoryTransactionsScreen extends StatelessWidget {
  final String categoryKey; // customCategoryId or category.name
  final ResolvedCategory resolvedCategory;
  final DateTime month;
  final double totalAmount;
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CategoryService categoryService;
  final AccountService accountService;
  final TagService tagService;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryKey,
    required this.resolvedCategory,
    required this.month,
    required this.totalAmount,
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
        listenable: Listenable.merge([transactionService, currencyService]),
        builder: (context, _) {
          final fmt = currencyService.formatter;

          // Filter transactions for this category and month
          final txs = transactionService
              .transactionsForMonth(month.year, month.month)
              .where(
                (t) =>
                    t.isExpense &&
                    (t.customCategoryId ?? t.category.name) == categoryKey,
              )
              .toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero header ─────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(context, fmt, txs.length)),

              // ── Section label ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRANSACTIONS',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '${txs.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Transaction list ─────────────────────────────────────────
              if (txs.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildTile(context, txs[i], fmt),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, NumberFormat fmt, int count) {
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            resolvedCategory.color,
            resolvedCategory.color.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: resolvedCategory.color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Category icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        resolvedCategory.icon,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedCategory.label,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            monthLabel,
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

              const SizedBox(height: 24),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _statItem(
                      'Total Spent',
                      currencyService.formatter.format(totalAmount),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.white.withValues(alpha: 0.25),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _statItem('Transactions', '$count'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ── Transaction tile ──────────────────────────────────────────────────────

  Widget _buildTile(BuildContext context, Transaction tx, NumberFormat fmt) {
    final cat = tx.resolveCategory(categoryService.getById);

    // Resolve account for payment mode chip
    final Account? account = tx.accountId != null
        ? accountService.all.firstWhere(
            (a) => a.id == tx.accountId,
            orElse: () => accountService.all.first,
          )
        : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
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
      ),
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
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
                      Text(
                        DateFormat('MMM d').format(tx.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (account != null) ...[
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
                        Flexible(child: _paymentChip(account)),
                      ],
                      if (tx.note != null && tx.note!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.notes_rounded,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Amount
            Text(
              '-${fmt.format(tx.amount)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChip(Account account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: account.type.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: account.type.color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(account.type.icon, size: 9, color: account.type.color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              account.name,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: account.type.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(resolvedCategory.icon, size: 56, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Text(
            'No transactions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No expenses recorded in this category',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
