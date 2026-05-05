import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/models/budget.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/sms_transaction_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/recurring_confirmation_service.dart';
import '../../core/theme/app_colors.dart';
import '../accounts/account_detail_screen.dart';
import '../accounts/accounts_screen.dart';
import '../analytics/analytics_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../transactions/recurring_transactions_screen.dart';
import '../reminders/reminder_banner.dart';
import '../reminders/recurring_confirmation_banner.dart';
// import '../sms/sms_transaction_banner.dart'; // hidden for now

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final BudgetService budgetService;
  final AccountService accountService;
  final CategoryService categoryService;
  final TagService tagService;
  final ReminderService? reminderService;
  final RecurringConfirmationService recurringConfirmationService;
  final SmsTransactionService smsTransactionService;
  final ScrollController? scrollController;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.transactionService,
    required this.currencyService,
    required this.budgetService,
    required this.accountService,
    required this.categoryService,
    required this.tagService,
    this.reminderService,
    required this.recurringConfirmationService,
    required this.smsTransactionService,
    this.scrollController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.transactionService,
            widget.currencyService,
            widget.budgetService,
            widget.accountService,
            if (widget.reminderService != null) widget.reminderService!,
            widget.recurringConfirmationService,
          ]),
          builder: (context, _) {
            final fmt = widget.currencyService.formatter;
            final income = widget.transactionService.incomeForMonth(
              _now.year,
              _now.month,
            );
            final expenses = widget.transactionService.expensesForMonth(
              _now.year,
              _now.month,
            );
            final balance = income - expenses;
            final recent = widget.transactionService.recentTransactions(
              limit: 6,
            );
            final recurringTemplates = widget.transactionService
                .getRecurringTemplates();
            final currentBudget = widget.budgetService.budgetFor(
              _now.year,
              _now.month,
            );

            return CustomScrollView(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(balance, fmt)),
                SliverToBoxAdapter(
                  child: _buildSummaryRow(income, expenses, fmt),
                ),
                SliverToBoxAdapter(
                  child: _buildSpendingProgress(expenses, income),
                ),
                // Recurring transaction confirmation banner (for transactions due today)
                SliverToBoxAdapter(
                  child: RecurringConfirmationBanner(
                    confirmationService: widget.recurringConfirmationService,
                    transactionService: widget.transactionService,
                  ),
                ),
                // Reminder banner (for upcoming transactions)
                if (widget.reminderService != null)
                  SliverToBoxAdapter(
                    child: ReminderBanner(
                      reminderService: widget.reminderService!,
                      transactionService: widget.transactionService,
                    ),
                  ),
                // SMS transaction banner — hidden for now
                // SliverToBoxAdapter(
                //   child: SmsTransactionBanner(
                //     smsService: widget.smsTransactionService,
                //     transactionService: widget.transactionService,
                //     accountService: widget.accountService,
                //   ),
                // ),
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Recent Transactions', recent),
                ),
                if (recent.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTransactionTile(
                        recent[index],
                        index,
                        recent.length,
                        fmt,
                      ),
                      childCount: recent.length,
                    ),
                  ),

                // Accounts Section
                SliverToBoxAdapter(
                  child: _buildAccountsSectionHeader(widget.accountService.all),
                ),
                if (widget.accountService.all.isEmpty)
                  SliverToBoxAdapter(child: _buildAccountsEmptyState())
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.accountService.all.length,
                        itemBuilder: (context, index) {
                          final accounts = widget.accountService.all;
                          return _buildAccountCard(
                            accounts[index],
                            index,
                            accounts.length,
                            fmt,
                          );
                        },
                      ),
                    ),
                  ),

                // Recurring Transactions Section
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    'Recurring Transactions',
                    recurringTemplates,
                    onSeeAll: recurringTemplates.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RecurringTransactionsScreen(
                                  transactionService:
                                      widget.transactionService,
                                  currencyService: widget.currencyService,
                                  categoryService: widget.categoryService,
                                  accountService: widget.accountService,
                                  tagService: widget.tagService,
                                ),
                              ),
                            ),
                  ),
                ),
                if (recurringTemplates.isEmpty)
                  SliverToBoxAdapter(child: _buildRecurringEmptyState())
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: recurringTemplates.length,
                        itemBuilder: (context, index) => _buildRecurringCard(
                          recurringTemplates[index],
                          index,
                          recurringTemplates.length,
                          fmt,
                        ),
                      ),
                    ),
                  ),

                // Budget Section
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    'Budgets',
                    currentBudget.categoryLimits.isNotEmpty ||
                            currentBudget.overallLimit != null
                        ? [
                            Transaction(
                              id: 'dummy',
                              title: '',
                              amount: 0,
                              type: TransactionType.expense,
                              category: TransactionCategory.other,
                              date: DateTime.now(),
                            ),
                          ]
                        : [],
                  ),
                ),
                if (currentBudget.categoryLimits.isEmpty &&
                    currentBudget.overallLimit == null)
                  SliverToBoxAdapter(child: _buildBudgetEmptyState())
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _getBudgetItems(
                          currentBudget,
                          expenses,
                        ).length,
                        itemBuilder: (context, index) {
                          final items = _getBudgetItems(
                            currentBudget,
                            expenses,
                          );
                          return _buildBudgetCard(
                            items[index],
                            index,
                            items.length,
                            fmt,
                          );
                        },
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header with gradient ──────────────────────────────────────────────────

  Widget _buildHeader(double balance, NumberFormat fmt) {
    final user = widget.authService.currentUser;
    final firstName = user?.displayName.split(' ').first ?? 'there';
    final monthLabel = DateFormat('MMMM yyyy').format(_now);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: greeting + analytics button + avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $firstName 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Analytics button
                      GestureDetector(
                        onTap: _openAnalytics,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildAvatar(user),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Balance
              Text(
                'Net Balance',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fmt.format(balance),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProfile? user) {
    return GestureDetector(
      onTap: _showProfileMenu,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: user?.photoUrl != null
              ? Image.network(
                  user!.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _avatarFallback(user.displayName),
                )
              : _avatarFallback(user?.displayName ?? '?'),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.authService.currentUser?.displayName ?? '',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.authService.currentUser?.email ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.accent,
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await widget.authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openTransactionDetail(Transaction tx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: tx,
          transactionService: widget.transactionService,
          categoryService: widget.categoryService,
          currencyService: widget.currencyService,
          accountService: widget.accountService,
          tagService: widget.tagService,
          reminderService: widget.reminderService,
        ),
      ),
    );
  }

  void _openAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyticsScreen(
          transactionService: widget.transactionService,
          currencyService: widget.currencyService,
          categoryService: widget.categoryService,
        ),
      ),
    );
  }

  // ── Income / Expense summary row ───────────────────────────────────────────

  Widget _buildSummaryRow(double income, double expenses, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Income',
              amount: income,
              icon: Icons.arrow_downward_rounded,
              color: const Color(0xFF2D9E6B),
              currencyFormat: fmt,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryCard(
              label: 'Expenses',
              amount: expenses,
              icon: Icons.arrow_upward_rounded,
              color: AppColors.accent,
              currencyFormat: fmt,
            ),
          ),
        ],
      ),
    );
  }

  // ── Spending progress bar ─────────────────────────────────────────────────

  Widget _buildSpendingProgress(double expenses, double income) {
    final ratio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).toStringAsFixed(0);
    final isOver = expenses > income;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spending vs Income',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOver
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : const Color(0xFF2D9E6B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pct% spent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOver
                          ? AppColors.accent
                          : const Color(0xFF2D9E6B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? AppColors.accent : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOver
                  ? 'You\'ve exceeded your income this month'
                  : 'You\'re within budget — keep it up!',
              style: TextStyle(
                fontSize: 12,
                color: isOver ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
    String title,
    List<Transaction> transactions, {
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (transactions.isNotEmpty && onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Transaction tile ──────────────────────────────────────────────────────

  Widget _buildTransactionTile(
    Transaction tx,
    int index,
    int total,
    NumberFormat fmt,
  ) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final sign = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome
        ? const Color(0xFF2D9E6B)
        : AppColors.textPrimary;
    final cat = tx.resolveCategory(
      (id) => widget.categoryService.getById(id),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isFirst ? 0 : 0, 20, isLast ? 0 : 0),
      child: GestureDetector(
        onTap: () => _openTransactionDetail(tx),
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
              // Category icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  cat.icon,
                  color: cat.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title + category + date
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          cat.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
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
                        Text(
                          DateFormat('MMM d').format(tx.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!tx.isMonthly) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF95A5A6,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'General',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF95A5A6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '$sign${fmt.format(tx.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your first transaction to get started',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
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
            'Set up recurring transactions for regular expenses',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Recurring transaction card (horizontal scroll) ───────────────────────

  Widget _buildRecurringCard(
    Transaction tx,
    int index,
    int total,
    NumberFormat fmt,
  ) {
    final isLast = index == total - 1;
    final sign = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome
        ? const Color(0xFF2D9E6B)
        : AppColors.textPrimary;
    final cat = tx.resolveCategory(
      (id) => widget.categoryService.getById(id),
    );

    // Format frequency label
    String frequencyLabel = '';
    switch (tx.recurringFrequency) {
      case 'daily':
        frequencyLabel = 'Daily';
        break;
      case 'weekly':
        frequencyLabel = 'Weekly';
        break;
      case 'monthly':
        frequencyLabel = 'Monthly';
        break;
      case 'yearly':
        frequencyLabel = 'Yearly';
        break;
      default:
        frequencyLabel = 'Recurring';
    }

    return GestureDetector(
      onTap: () => _openTransactionDetail(tx),
      child: Container(
        width: 200,
        margin: EdgeInsets.only(right: isLast ? 0 : 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cat.color.withValues(alpha: 0.08),
              cat.color.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cat.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Icon with recurring badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        cat.icon,
                        color: cat.color,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.repeat_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                // Frequency badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    frequencyLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cat.color,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title.replaceAll(' (Recurring)', ''),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.recurringEndDate != null) ...[
                  const SizedBox(height: 4),
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

            // Bottom: Amount
            Text(
              '$sign${fmt.format(tx.amount)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Accounts section ──────────────────────────────────────────────────────

  Widget _buildAccountsSectionHeader(List<Account> accounts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (accounts.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountsScreen(
                      accountService: widget.accountService,
                      currencyService: widget.currencyService,
                    ),
                  ),
                );
              },
              child: const Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    Account account,
    int index,
    int total,
    NumberFormat fmt,
  ) {
    final isLast = index == total - 1;
    final isCreditCard = account.type == AccountType.creditCard;

    return GestureDetector(
      onTap: () => _openAccountDetail(account),
      child: Container(
        width: 180,
        margin: EdgeInsets.only(right: isLast ? 0 : 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              account.color.withValues(alpha: 0.10),
              account.color.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: account.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: icon + type badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: account.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    account.type.icon,
                    color: account.color,
                    size: 20,
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: account.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      account.type.label.split(' ').first,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: account.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: account name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCreditCard && account.creditLimit != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: account.utilizationRatio ?? 0,
                      minHeight: 4,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (account.utilizationRatio ?? 0) > 0.8
                            ? AppColors.accent
                            : account.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Bottom: balance / outstanding
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreditCard ? 'Outstanding' : 'Balance',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                // FittedBox prevents overflow when the formatted amount is long
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    fmt.format(account.balance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isCreditCard ? AppColors.accent : account.color,
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

  void _openAccountDetail(Account account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailScreen(
          account: account,
          accountService: widget.accountService,
          transactionService: widget.transactionService,
          currencyService: widget.currencyService,
        ),
      ),
    );
  }

  Widget _buildAccountsEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          const Text(
            'No accounts yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add an account to track your balances',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Budget empty state ────────────────────────────────────────────────────

  Widget _buildBudgetEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          const Text(
            'No budgets set',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create budgets to track your spending',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Budget helpers ────────────────────────────────────────────────────────

  List<_BudgetItem> _getBudgetItems(
    MonthlyBudget budget,
    double totalExpenses,
  ) {
    final items = <_BudgetItem>[];

    // Add overall budget if set
    if (budget.overallLimit != null) {
      items.add(
        _BudgetItem(
          label: 'Overall Budget',
          limit: budget.overallLimit!,
          spent: totalExpenses,
          category: null,
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
        ),
      );
    }

    // Add category budgets
    for (final entry in budget.categoryLimits.entries) {
      final categoryExpenses = widget.transactionService
          .transactionsForMonth(_now.year, _now.month)
          .where(
            (t) =>
                t.isExpense && !t.excludeFromExpense && t.category == entry.key,
          )
          .fold(0.0, (sum, t) => sum + t.amount);

      items.add(
        _BudgetItem(
          label: entry.key.label,
          limit: entry.value,
          spent: categoryExpenses,
          category: entry.key,
          icon: entry.key.icon,
          color: entry.key.color,
        ),
      );
    }

    return items;
  }

  // ── Budget card (horizontal scroll) ───────────────────────────────────────

  Widget _buildBudgetCard(
    _BudgetItem item,
    int index,
    int total,
    NumberFormat fmt,
  ) {
    final isLast = index == total - 1;
    final remaining = item.limit - item.spent;
    final percentage = (item.spent / item.limit * 100).clamp(0, 100);
    final isOverBudget = item.spent > item.limit;

    return Container(
      width: 200,
      margin: EdgeInsets.only(right: isLast ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.color.withValues(alpha: 0.08),
            item.color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Icon and percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverBudget
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget ? AppColors.accent : item.color,
                  ),
                ),
              ),
            ],
          ),

          // Middle: Title and progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (item.spent / item.limit).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? AppColors.accent : item.color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOverBudget
                    ? 'Over by ${fmt.format(remaining.abs())}'
                    : '${fmt.format(remaining)} left',
                style: TextStyle(
                  fontSize: 10,
                  color: isOverBudget
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // Bottom: Spent / Limit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  fmt.format(item.spent),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget ? AppColors.accent : item.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                ' / ${fmt.format(item.limit)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Summary card widget ───────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final NumberFormat currencyFormat;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget item helper class ──────────────────────────────────────────────────

class _BudgetItem {
  final String label;
  final double limit;
  final double spent;
  final TransactionCategory? category;
  final IconData icon;
  final Color color;

  const _BudgetItem({
    required this.label,
    required this.limit,
    required this.spent,
    required this.category,
    required this.icon,
    required this.color,
  });
}
