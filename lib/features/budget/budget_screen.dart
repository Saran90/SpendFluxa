import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';

// Expense-only categories shown in the budget screen
const _budgetableCategories = [
  TransactionCategory.food,
  TransactionCategory.grocery,
  TransactionCategory.vegetables,
  TransactionCategory.bakery,
  TransactionCategory.drinksAndSnacks,
  TransactionCategory.transport,
  TransactionCategory.fuel,
  TransactionCategory.shopping,
  TransactionCategory.entertainment,
  TransactionCategory.health,
  TransactionCategory.utilities,
  TransactionCategory.bills,
  TransactionCategory.rent,
  TransactionCategory.education,
  TransactionCategory.insurance,
  TransactionCategory.expenseInvestment,
  TransactionCategory.other,
];

class BudgetScreen extends StatefulWidget {
  final BudgetService budgetService;
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final ScrollController? scrollController;

  const BudgetScreen({
    super.key,
    required this.budgetService,
    required this.transactionService,
    required this.currencyService,
    this.scrollController,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  int get _year => _selectedMonth.year;
  int get _month => _selectedMonth.month;

  void _prevMonth() => setState(
    () => _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    ),
  );

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.budgetService,
          widget.currencyService,
          widget.transactionService,
        ]),
        builder: (context, _) {
          final fmt = widget.currencyService.formatter;
          final budget = widget.budgetService.budgetFor(_year, _month);
          final spent = widget.transactionService.expensesForMonth(
            _year,
            _month,
          );

          // Per-category spending
          final catSpent = <TransactionCategory, double>{};
          for (final tx
              in widget.transactionService
                  .transactionsForMonth(_year, _month)
                  .where((t) => t.isExpense)) {
            catSpent[tx.category] = (catSpent[tx.category] ?? 0) + tx.amount;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildMonthSelector(),
              Expanded(
                child: CustomScrollView(
                  controller: widget.scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Overall budget card ─────────────────────────────
                    SliverToBoxAdapter(
                      child: _OverallBudgetCard(
                        limit: budget.overallLimit,
                        spent: spent,
                        fmt: fmt,
                        onEdit: () => _showAmountSheet(
                          context,
                          title: 'Overall Monthly Budget',
                          current: budget.overallLimit,
                          onSave: (v) => widget.budgetService.setOverallLimit(
                            _year,
                            _month,
                            v,
                          ),
                        ),
                      ),
                    ),

                    // ── Category budgets header ─────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CATEGORY BUDGETS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (budget.categoryLimits.isNotEmpty)
                              GestureDetector(
                                onTap: () => _confirmClearAll(context),
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Category rows ───────────────────────────────────
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final cat = _budgetableCategories[i];
                        final limit = budget.categoryLimits[cat];
                        final catSpending = catSpent[cat] ?? 0.0;
                        return _CategoryBudgetRow(
                          category: cat,
                          limit: limit,
                          spent: catSpending,
                          fmt: fmt,
                          onTap: () => _showAmountSheet(
                            context,
                            title: cat.label,
                            icon: cat.icon,
                            iconColor: cat.color,
                            current: limit,
                            onSave: (v) => widget.budgetService
                                .setCategoryLimit(_year, _month, cat, v),
                          ),
                        );
                      }, childCount: _budgetableCategories.length),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Set & track your spending limits',
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

  // ── Month selector ────────────────────────────────────────────────────────

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: _prevMonth,
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: _isCurrentMonth
                    ? AppColors.textLight
                    : AppColors.textPrimary,
              ),
              onPressed: _isCurrentMonth ? null : _nextMonth,
            ),
          ],
        ),
      ),
    );
  }

  // ── Amount input sheet ────────────────────────────────────────────────────

  void _showAmountSheet(
    BuildContext context, {
    required String title,
    required void Function(double?) onSave,
    double? current,
    IconData? icon,
    Color? iconColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmountSheet(
        title: title,
        current: current,
        icon: icon,
        iconColor: iconColor,
        currencySymbol: widget.currencyService.symbol,
        onSave: onSave,
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Category Budgets',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Remove all category budget limits for this month?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final budget = widget.budgetService.budgetFor(_year, _month);
      for (final cat in List.of(budget.categoryLimits.keys)) {
        await widget.budgetService.setCategoryLimit(_year, _month, cat, null);
      }
    }
  }
}

// ── Overall budget card ───────────────────────────────────────────────────────

class _OverallBudgetCard extends StatelessWidget {
  final double? limit;
  final double spent;
  final NumberFormat fmt;
  final VoidCallback onEdit;

  const _OverallBudgetCard({
    required this.limit,
    required this.spent,
    required this.fmt,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = limit != null && limit! > 0;
    final ratio = hasLimit ? (spent / limit!).clamp(0.0, 1.0) : 0.0;
    final remaining = hasLimit ? (limit! - spent).clamp(0.0, limit!) : 0.0;
    final isOver = hasLimit && spent > limit!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.splashGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Budget',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLimit ? fmt.format(limit!) : 'Not set',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasLimit ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasLimit ? 'Edit' : 'Set Budget',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (hasLimit) ...[
              const SizedBox(height: 20),
              // Spent / Remaining row
              Row(
                children: [
                  Expanded(
                    child: _statItem('Spent', fmt.format(spent), Colors.white),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _statItem(
                      isOver ? 'Over by' : 'Remaining',
                      fmt.format(isOver ? spent - limit! : remaining),
                      isOver
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF69F0AE),
                      align: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOver
                        ? const Color(0xFFFF5252)
                        : ratio > 0.8
                        ? const Color(0xFFFFD740)
                        : const Color(0xFF69F0AE),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOver
                    ? 'You\'ve exceeded your monthly budget'
                    : '${(ratio * 100).toStringAsFixed(0)}% of budget used',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    Color valueColor, {
    TextAlign align = TextAlign.left,
  }) {
    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Category budget row ───────────────────────────────────────────────────────

class _CategoryBudgetRow extends StatelessWidget {
  final TransactionCategory category;
  final double? limit;
  final double spent;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _CategoryBudgetRow({
    required this.category,
    required this.limit,
    required this.spent,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = limit != null && limit! > 0;
    final ratio = hasLimit ? (spent / limit!).clamp(0.0, 1.0) : 0.0;
    final isOver = hasLimit && spent > limit!;

    Color barColor() {
      if (isOver) return const Color(0xFFFF5252);
      if (ratio > 0.8) return const Color(0xFFFFD740);
      return category.color;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(16),
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
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(category.icon, color: category.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Label + bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // Limit / spent
                      Text(
                        hasLimit
                            ? '${fmt.format(spent)} / ${fmt.format(limit!)}'
                            : spent > 0
                            ? fmt.format(spent)
                            : 'No limit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOver
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (hasLimit) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor()),
                      ),
                    ),
                  ] else if (spent > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap to set a limit',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),
            // Edit / Add indicator
            Icon(
              hasLimit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
              size: 18,
              color: hasLimit ? AppColors.primary : AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Amount input bottom sheet ─────────────────────────────────────────────────

class _AmountSheet extends StatefulWidget {
  final String title;
  final double? current;
  final IconData? icon;
  final Color? iconColor;
  final String currencySymbol;
  final void Function(double?) onSave;

  const _AmountSheet({
    required this.title,
    required this.currencySymbol,
    required this.onSave,
    this.current,
    this.icon,
    this.iconColor,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.current != null ? widget.current!.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // Clear the budget
      widget.onSave(null);
      Navigator.of(context).pop();
      return;
    }
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    widget.onSave(value == 0 ? null : value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Title row
              Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (widget.iconColor ?? AppColors.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor ?? AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount field
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '${widget.currencySymbol}  ',
                  prefixStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  hintText: '0.00',
                  hintStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textLight,
                  ),
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),

              if (widget.current != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onSave(null);
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Remove budget limit',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Budget',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
