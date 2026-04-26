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

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final TagService tagService;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.transactionService,
    required this.categoryService,
    required this.currencyService,
    required this.accountService,
    required this.tagService,
  });

  // ── Gradient colours matching AddTransactionScreen ────────────────────────

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

  String get _typeLabel {
    switch (transaction.type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.expense:
        return 'Expense';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = currencyService.formatter;
    final sign = transaction.isIncome
        ? '+'
        : transaction.isTransfer
        ? ''
        : '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Gradient hero ──────────────────────────────────────────────
          _buildHero(context, fmt, sign),

          // ── Detail cards ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildMainCard(context),
                const SizedBox(height: 14),
                if (transaction.accountId != null ||
                    transaction.toAccountId != null)
                  _buildAccountCard(context),
                if (transaction.accountId != null ||
                    transaction.toAccountId != null)
                  const SizedBox(height: 14),
                if (transaction.tagIds.isNotEmpty) _buildTagsCard(context),
                if (transaction.tagIds.isNotEmpty) const SizedBox(height: 14),
                if (transaction.isEmi) _buildEmiCard(),
                if (transaction.isEmi) const SizedBox(height: 14),
                if (transaction.isRecurring ||
                    transaction.recurringParentId != null)
                  _buildRecurringCard(),
                if (transaction.isRecurring ||
                    transaction.recurringParentId != null)
                  const SizedBox(height: 14),
                if (transaction.excludeFromExpense) _buildExcludedBadge(),
                if (transaction.excludeFromExpense) const SizedBox(height: 14),
                // ── Action buttons ─────────────────────────────────────
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

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
              // Back + type label + edit button
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
                      _typeLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  // Edit button
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

              // Amount
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

              // Title + date row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.title.isEmpty
                            ? transaction.category.label
                            : transaction.title,
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
                      child: Text(
                        DateFormat('MMM d, yyyy').format(transaction.date),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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

  // ── Main info card ────────────────────────────────────────────────────────

  Widget _buildMainCard(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          // Category
          _Row(
            icon: transaction.category.icon,
            iconColor: transaction.category.color,
            label: 'Category',
            value: transaction.category.label,
          ),
          _divider(),
          // Date & time
          _Row(
            icon: Icons.calendar_today_rounded,
            iconColor: _typeColor,
            label: 'Date',
            value: DateFormat(
              'EEEE, MMM d, yyyy  •  h:mm a',
            ).format(transaction.date),
          ),
          // Note
          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
            _divider(),
            _Row(
              icon: Icons.notes_rounded,
              iconColor: AppColors.textSecondary,
              label: 'Note',
              value: transaction.note!,
            ),
          ],
        ],
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _buildAccountCard(BuildContext context) {
    final fromAccount = transaction.accountId != null
        ? accountService.all
              .where((a) => a.id == transaction.accountId)
              .firstOrNull
        : null;
    final toAccount = transaction.toAccountId != null
        ? accountService.all
              .where((a) => a.id == transaction.toAccountId)
              .firstOrNull
        : null;

    if (fromAccount == null && toAccount == null) return const SizedBox();

    return _Card(
      child: Column(
        children: [
          if (fromAccount != null)
            _Row(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: fromAccount.color,
              label: transaction.isTransfer ? 'From' : 'Account',
              value: fromAccount.name,
            ),
          if (fromAccount != null && toAccount != null) _divider(),
          if (toAccount != null)
            _Row(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: toAccount.color,
              label: 'To',
              value: toAccount.name,
            ),
        ],
      ),
    );
  }

  // ── Tags card ─────────────────────────────────────────────────────────────

  Widget _buildTagsCard(BuildContext context) {
    final tags = transaction.tagIds
        .map((id) => tagService.getById(id))
        .whereType<dynamic>()
        .toList();

    if (tags.isEmpty) return const SizedBox();

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.label_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: transaction.tagIds.map((id) {
                final tag = tagService.getById(id);
                if (tag == null) return const SizedBox();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tag.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tag.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tag.icon, size: 13, color: tag.color),
                      const SizedBox(width: 5),
                      Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tag.color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── EMI card ──────────────────────────────────────────────────────────────

  Widget _buildEmiCard() {
    return _Card(
      child: Column(
        children: [
          _Row(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF5C6BC0),
            label: 'EMI',
            value: 'Yes',
          ),
          if (transaction.emiDurationMonths != null) ...[
            _divider(),
            _Row(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFF5C6BC0),
              label: 'Duration',
              value: '${transaction.emiDurationMonths} months',
            ),
          ],
          if (transaction.emiInterestRate != null) ...[
            _divider(),
            _Row(
              icon: Icons.percent_rounded,
              iconColor: const Color(0xFF5C6BC0),
              label: 'Interest Rate',
              value: '${transaction.emiInterestRate}% p.a.',
            ),
          ],
          if (transaction.emiMonthlyAmount != null) ...[
            _divider(),
            _Row(
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF5C6BC0),
              label: 'Monthly EMI',
              value: currencyService.formatter.format(
                transaction.emiMonthlyAmount!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Recurring card ────────────────────────────────────────────────────────

  Widget _buildRecurringCard() {
    return _Card(
      child: Column(
        children: [
          _Row(
            icon: Icons.repeat_rounded,
            iconColor: AppColors.primary,
            label: 'Recurring',
            value: transaction.recurringFrequency != null
                ? _capitalize(transaction.recurringFrequency!)
                : 'Yes',
          ),
          if (transaction.recurringEndDate != null) ...[
            _divider(),
            _Row(
              icon: Icons.event_rounded,
              iconColor: AppColors.primary,
              label: 'Until',
              value: DateFormat(
                'MMM d, yyyy',
              ).format(transaction.recurringEndDate!),
            ),
          ],
        ],
      ),
    );
  }

  // ── Excluded badge ────────────────────────────────────────────────────────

  Widget _buildExcludedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          const Text(
            'Excluded from expense totals',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        // Edit
        Expanded(
          child: _ActionButton(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: _typeColor,
            onTap: () => _openEdit(context),
          ),
        ),
        const SizedBox(width: 12),
        // Delete
        Expanded(
          child: _ActionButton(
            icon: Icons.delete_rounded,
            label: 'Delete',
            color: AppColors.accent,
            onTap: () => _confirmDelete(context),
          ),
        ),
      ],
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

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
    // Pop detail screen too so the list refreshes cleanly
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Transaction?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will permanently remove the transaction and reverse its effect on your account balance.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await transactionService.removeTransaction(transaction.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _divider() => const Divider(
    height: 1,
    indent: 46,
    endIndent: 0,
    color: Color(0xFFF0F2F5),
  );
}

// ── Reusable card ─────────────────────────────────────────────────────────────

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

// ── Detail row ────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _Row({
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

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
