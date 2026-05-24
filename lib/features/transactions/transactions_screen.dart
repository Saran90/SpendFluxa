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
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CategoryService categoryService;
  final AccountService accountService;
  final TagService tagService;
  final ScrollController? scrollController;

  const TransactionsScreen({
    super.key,
    required this.transactionService,
    required this.currencyService,
    required this.categoryService,
    required this.accountService,
    required this.tagService,
    this.scrollController,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late DateTime _selectedMonth;
  TransactionCategory? _selectedCategory;
  bool _searchVisible = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (_searchVisible) {
        Future.microtask(() => _searchFocus.requestFocus());
      } else {
        _searchQuery = '';
        _searchController.clear();
        _searchFocus.unfocus();
      }
    });
  }

  int get _year => _selectedMonth.year;
  int get _month => _selectedMonth.month;

  void _prevMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    _selectedCategory = null;
    _searchQuery = '';
    _searchController.clear();
  });

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() {
        _selectedMonth = next;
        _selectedCategory = null;
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  /// Groups transactions by date label (Today / Yesterday / MMM d, yyyy).
  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<Transaction>>{};
    for (final tx in txs) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMM d, yyyy').format(d);
      }
      (map[label] ??= []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.transactionService,
          widget.currencyService,
        ]),
        builder: (context, _) {
          final fmt = widget.currencyService.formatter;
          final allTxs = widget.transactionService.transactionsForMonth(
            _year,
            _month,
          );
          final income = widget.transactionService.incomeForMonth(
            _year,
            _month,
          );
          final expenses = widget.transactionService.expensesForMonth(
            _year,
            _month,
          );
          final categories = allTxs.map((t) => t.category).toSet().toList()
            ..sort((a, b) => a.label.compareTo(b.label));
          final q = _searchQuery.trim().toLowerCase();
          final txs = allTxs.where((t) {
            if (_selectedCategory != null && t.category != _selectedCategory) {
              return false;
            }
            if (q.isNotEmpty) {
              return t.title.toLowerCase().contains(q) ||
                  t.category.label.toLowerCase().contains(q) ||
                  (t.note?.toLowerCase().contains(q) ?? false) ||
                  t.amount.toString().contains(q) ||
                  fmt
                      .format(t.amount)
                      .replaceAll(RegExp(r'[^0-9.]'), '')
                      .contains(q);
            }
            return true;
          }).toList();
          final grouped = _groupByDate(txs);
          final dateKeys = grouped.keys.toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildMonthSelector(),
              if (_searchVisible) _buildSearchBar(),
              if (!_searchVisible) _buildSummaryCard(income, expenses, fmt),
              if (!_searchVisible && categories.isNotEmpty)
                _buildCategoryFilter(categories),
              Expanded(
                child: txs.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                        controller: widget.scrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          for (final dateKey in dateKeys) ...[
                            // Date group header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      dateKey.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: const Color(0xFFEEF0F3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Transactions for this date
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _TransactionTile(
                                  tx: grouped[dateKey]![i],
                                  fmt: fmt,
                                  categoryService: widget.categoryService,
                                  accountService: widget.accountService,
                                  onTap: () => _openDetail(
                                    context,
                                    grouped[dateKey]![i],
                                  ),
                                ),
                                childCount: grouped[dateKey]!.length,
                              ),
                            ),
                          ],
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Gradient header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
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
                  Icons.receipt_long_rounded,
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
                      'Transactions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Track every rupee you spend',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _toggleSearch,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _searchVisible
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    key: ValueKey(_searchVisible),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.textLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ── Month selector ────────────────────────────────────────────────────────

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(double income, double expenses, NumberFormat fmt) {
    final net = income - expenses;
    final isDeficit = net < 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
            Expanded(
              child: _statItem(
                'Income',
                fmt.format(income),
                const Color(0xFF2D9E6B),
                Icons.arrow_downward_rounded,
              ),
            ),
            Container(width: 1, height: 40, color: const Color(0xFFEEF0F3)),
            Expanded(
              child: _statItem(
                'Expenses',
                fmt.format(expenses),
                AppColors.accent,
                Icons.arrow_upward_rounded,
                align: TextAlign.center,
              ),
            ),
            Container(width: 1, height: 40, color: const Color(0xFFEEF0F3)),
            Expanded(
              child: _statItem(
                'Net',
                fmt.format(net.abs()),
                isDeficit ? AppColors.accent : const Color(0xFF2D9E6B),
                isDeficit
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                align: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    Color valueColor,
    IconData icon, {
    TextAlign align = TextAlign.left,
  }) {
    final crossAxis = align == TextAlign.right
        ? CrossAxisAlignment.end
        : align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: crossAxis,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: valueColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          transactionService: widget.transactionService,
          categoryService: widget.categoryService,
          currencyService: widget.currencyService,
          accountService: widget.accountService,
          tagService: widget.tagService,
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildCategoryFilter(List<TransactionCategory> categories) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedCategory = selected ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? cat.color.withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? cat.color : const Color(0xFFEEF0F3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, size: 14, color: cat.color),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? cat.color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final String message;
    if (_searchQuery.trim().isNotEmpty) {
      message = 'No results for "${_searchQuery.trim()}"';
    } else if (_selectedCategory != null) {
      message = 'No "${_selectedCategory!.label}" transactions this month';
    } else {
      message =
          'Nothing recorded for ${DateFormat('MMMM yyyy').format(_selectedMonth)}';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.trim().isNotEmpty
                ? Icons.search_off_rounded
                : Icons.receipt_long_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
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
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final NumberFormat fmt;
  final CategoryService categoryService;
  final AccountService accountService;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.tx,
    required this.fmt,
    required this.categoryService,
    required this.accountService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sign = tx.isIncome ? '+' : '-';
    final amountColor = tx.isIncome
        ? const Color(0xFF2D9E6B)
        : AppColors.textPrimary;
    final cat = tx.resolveCategory(categoryService.getById);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cat.color,
                            ),
                          ),
                        ),
                        // Payment mode indicator
                        if (tx.accountId != null) ...[
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
                          Flexible(child: _buildPaymentModeChip(tx.accountId!)),
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

              // Amount + time
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
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('h:mm a').format(tx.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeChip(String accountId) {
    final account = accountService.all.firstWhere(
      (a) => a.id == accountId,
      orElse: () => Account(
        id: '',
        name: 'Cash',
        type: AccountType.cash,
        balance: 0,
        color: const Color(0xFF2D9E6B),
        isDefault: false,
      ),
    );

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
}
