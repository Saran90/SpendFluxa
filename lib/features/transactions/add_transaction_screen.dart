import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/models/custom_category.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import '../accounts/add_account_sheet.dart';
import '../tags/add_tag_sheet.dart';

// Wraps either a built-in TransactionCategory or a user CustomCategory so the
// grid can render both with the same code.
class _CategoryItem {
  final TransactionCategory? builtin;
  final CustomCategory? custom;

  const _CategoryItem.builtin(TransactionCategory c)
    : builtin = c,
      custom = null;
  const _CategoryItem.custom(CustomCategory c) : custom = c, builtin = null;

  String get label => builtin?.label ?? custom!.label;
  IconData get icon => builtin?.icon ?? custom!.icon;
  Color get color => builtin?.color ?? custom!.color;

  bool matches(_CategoryItem other) {
    if (builtin != null && other.builtin != null) {
      return builtin == other.builtin;
    }
    if (custom != null && other.custom != null) {
      return custom!.id == other.custom!.id;
    }
    return false;
  }
}

const _expenseCategories = [
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

const _incomeCategories = [
  TransactionCategory.salary,
  TransactionCategory.freelance,
  TransactionCategory.investment,
  TransactionCategory.gift,
  TransactionCategory.cashback,
  TransactionCategory.other,
];

class AddTransactionScreen extends StatefulWidget {
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final TagService tagService;
  final Transaction? editing; // non-null = edit mode
  final bool editRecurringTemplateOnly;

  const AddTransactionScreen({
    super.key,
    required this.transactionService,
    required this.categoryService,
    required this.currencyService,
    required this.accountService,
    required this.tagService,
    this.editing,
    this.editRecurringTemplateOnly = false,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with TickerProviderStateMixin {
  TransactionType _type = TransactionType.expense;

  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TransactionCategory _selectedCategory = TransactionCategory.food;
  _CategoryItem _selectedItem = const _CategoryItem.builtin(
    TransactionCategory.food,
  );
  CustomCategory? _selectedCustomCategory;
  DateTime _selectedDate = DateTime.now();
  Account? _fromAccount;
  Account? _toAccount;
  final List<String> _selectedTagIds = [];
  bool _isSaving = false;
  bool _isCategoryExpanded = false;

  // EMI fields
  bool _isEmi = false;
  double _emiInterestRate = 0.0;
  int _emiDurationMonths = 3;
  final _emiInterestController = TextEditingController();
  bool _excludeFromExpense = false;
  bool _isMonthly = true; // default ON — counts toward monthly totals

  // Recurring fields
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  DateTime? _recurringEndDate;

  // Animate the header color when type changes
  late AnimationController _colorAnim;

  // Focus node for the amount field — requested once after the transition
  final FocusNode _amountFocus = FocusNode();

  static const _expenseColors = [Color(0xFFFF6B6B), Color(0xFFE53935)];
  static const _incomeColors = [Color(0xFF2D9E6B), Color(0xFF1A7A50)];
  static const _transferColors = [Color(0xFF4ECDC4), Color(0xFF2D9E8F)];

  List<Color> get _currentGradient {
    switch (_type) {
      case TransactionType.expense:
        return _expenseColors;
      case TransactionType.income:
        return _incomeColors;
      case TransactionType.transfer:
        return _transferColors;
    }
  }

  Color get _typeColor => _currentGradient[0];

  /// Merged list of built-in + custom categories for the current transaction type.
  List<_CategoryItem> get _allCategoryItems {
    final builtins =
        (_type == TransactionType.income
                ? _incomeCategories
                : _expenseCategories)
            .map((c) => _CategoryItem.builtin(c))
            .toList();
    final customs =
        (_type == TransactionType.income
                ? widget.categoryService.incomeCategories
                : widget.categoryService.expenseCategories)
            .map((c) => _CategoryItem.custom(c))
            .toList();
    return [...builtins, ...customs];
  }

  @override
  void initState() {
    super.initState();
    _colorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Pre-populate fields when editing an existing transaction
    final tx = widget.editing;
    if (tx != null) {
      _type = tx.type;
      _selectedCategory = tx.category;
      // Restore custom category selection if applicable
      if (tx.customCategoryId != null) {
        final allCustom = [
          ...widget.categoryService.expenseCategories,
          ...widget.categoryService.incomeCategories,
        ];
        final found = allCustom.where((c) => c.id == tx.customCategoryId).firstOrNull;
        if (found != null) {
          _selectedCustomCategory = found;
          _selectedItem = _CategoryItem.custom(found);
        } else {
          _selectedItem = _CategoryItem.builtin(tx.category);
        }
      } else {
        _selectedItem = _CategoryItem.builtin(tx.category);
      }
      _amountController.text = tx.amount.toStringAsFixed(2);
      _titleController.text = tx.title;
      _noteController.text = tx.note ?? '';
      _selectedDate = tx.date;
      _selectedTagIds.addAll(tx.tagIds);
      _excludeFromExpense = tx.excludeFromExpense;
      _isMonthly = tx.isMonthly;
      _isEmi = tx.isEmi;
      _isRecurring = tx.isRecurring;
      if (tx.recurringFrequency != null) {
        _recurringFrequency = tx.recurringFrequency!;
      }
      _recurringEndDate = tx.recurringEndDate;
      if (tx.emiInterestRate != null) {
        _emiInterestRate = tx.emiInterestRate!;
        _emiInterestController.text = tx.emiInterestRate!.toString();
      }
      if (tx.emiDurationMonths != null) {
        _emiDurationMonths = tx.emiDurationMonths!;
      }

      // Auto-expand category grid if the selected category is beyond
      // the first 8 visible items (4 columns ├ù 2 rows).
      const maxVisible = 8;
      final cats = tx.type == TransactionType.income
          ? _incomeCategories
          : _expenseCategories;
      final idx = cats.indexOf(tx.category);
      if (idx >= maxVisible) {
        _isCategoryExpanded = true;
      }
    }

    // Initialize accounts synchronously ΓÇö accountService.all is already loaded
    final accounts = widget.accountService.all;
    if (accounts.isNotEmpty) {
      if (tx != null) {
        _fromAccount = tx.accountId != null
            ? accounts.where((a) => a.id == tx.accountId).firstOrNull
            : widget.accountService.defaultAccount ?? accounts.first;
        _toAccount = tx.toAccountId != null
            ? accounts.where((a) => a.id == tx.toAccountId).firstOrNull
            : accounts.length > 1
            ? accounts.firstWhere(
                (a) => a.id != _fromAccount?.id,
                orElse: () => accounts.first,
              )
            : accounts.first;
      } else {
        _fromAccount = widget.accountService.defaultAccount ?? accounts.first;
        _toAccount = accounts.length > 1
            ? accounts.firstWhere(
                (a) => a.id != _fromAccount!.id,
                orElse: () => accounts.first,
              )
            : accounts.first;
      }
    }

    // Request focus on the amount field once the slide-up transition finishes
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _colorAnim.dispose();
    _amountFocus.dispose();
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _emiInterestController.dispose();
    super.dispose();
  }

  void _setType(TransactionType t) {
    if (_type == t) return;
    final defaultCat = t == TransactionType.income
        ? TransactionCategory.salary
        : TransactionCategory.food;
    setState(() {
      _type = t;
      _selectedCategory = defaultCat;
      _selectedItem = _CategoryItem.builtin(defaultCat);
      _selectedCustomCategory = null;
      _isCategoryExpanded = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    if (_type == TransactionType.transfer) {
      if (_fromAccount == null || _toAccount == null) {
        _snack('Select both accounts');
        return;
      }
      if (_fromAccount!.id == _toAccount!.id) {
        _snack('From and To accounts must be different');
        return;
      }
    }

    // Validate EMI fields if EMI is enabled
    if (_isEmi && _shouldShowEmiOptions()) {
      if (_emiInterestRate <= 0) {
        _snack('Please enter a valid interest rate');
        return;
      }
    }

    setState(() => _isSaving = true);

    final title = _titleController.text.trim().isEmpty
        ? (_type == TransactionType.transfer
              ? 'Transfer'
              : _selectedCustomCategory?.label ?? _selectedCategory.label)
        : _titleController.text.trim();

    if (_isEmi && _shouldShowEmiOptions()) {
      // Create EMI transactions (automatically excluded from expense totals)
      await _createEmiTransactions(title, amount);
    } else if (_isRecurring) {
      // Create or update recurring transactions
      if (widget.editing != null) {
        // Update the template only — do NOT touch already-recorded instances
        await widget.transactionService.updateRecurringTemplate(
          widget.editing!.copyWith(
            title: '$title (Recurring)',
            amount: amount,
            type: _type,
            category: _selectedCategory,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            accountId: _fromAccount?.id,
            toAccountId: _type == TransactionType.transfer
                ? _toAccount?.id
                : null,
            tagIds: _selectedTagIds,
            isRecurring: true,
            recurringFrequency: _recurringFrequency,
            recurringEndDate: _recurringEndDate,
            excludeFromExpense: _excludeFromExpense,
            isMonthly: _isMonthly,
            customCategoryId: _selectedCustomCategory?.id,
          ),
        );
      } else {
        // Create new recurring template
        await _createRecurringTransactions(title, amount);
      }
    } else {
      // Create or update regular transaction
      if (widget.editing != null) {
        await widget.transactionService.updateTransaction(
          widget.editing!.copyWith(
            title: title,
            amount: amount,
            type: _type,
            category: _selectedCategory,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            accountId: _fromAccount?.id,
            toAccountId: _type == TransactionType.transfer
                ? _toAccount?.id
                : null,
            tagIds: _selectedTagIds,
            excludeFromExpense: _excludeFromExpense,
            isMonthly: _isMonthly,
            customCategoryId: _selectedCustomCategory?.id,
          ),
        );
      } else {
        await widget.transactionService.addTransaction(
          Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            amount: amount,
            type: _type,
            category: _selectedCategory,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            accountId: _fromAccount?.id,
            toAccountId: _type == TransactionType.transfer
                ? _toAccount?.id
                : null,
            tagIds: _selectedTagIds,
            excludeFromExpense: _excludeFromExpense,
            isMonthly: _isMonthly,
            customCategoryId: _selectedCustomCategory?.id,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createRecurringTransactions(String title, double amount) async {
    final parentId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create parent/template transaction only
    // Instances will be created when user confirms them via the banner
    widget.transactionService.addTransaction(
      Transaction(
        id: parentId,
        title: '$title (Recurring)',
        amount: amount,
        type: _type,
        category: _selectedCategory,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        accountId: _fromAccount?.id,
        toAccountId: _type == TransactionType.transfer ? _toAccount?.id : null,
        tagIds: _selectedTagIds,
        isRecurring: true,
        recurringFrequency: _recurringFrequency,
        recurringEndDate: _recurringEndDate,
        excludeFromExpense: _excludeFromExpense,
        isMonthly: _isMonthly,
        customCategoryId: _selectedCustomCategory?.id,
      ),
    );
  }

  Future<void> _createEmiTransactions(String title, double amount) async {
    final emiAmount = _calculateEmi();
    final parentId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create parent transaction (original purchase) - excluded from expense totals
    widget.transactionService.addTransaction(
      Transaction(
        id: parentId,
        title: '$title (EMI)',
        amount: amount,
        type: _type,
        category: _selectedCategory,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? 'EMI: $_emiDurationMonths months @ $_emiInterestRate% p.a.'
            : '${_noteController.text.trim()}\nEMI: $_emiDurationMonths months @ $_emiInterestRate% p.a.',
        accountId: _fromAccount?.id,
        tagIds: _selectedTagIds,
        isEmi: true,
        emiInterestRate: _emiInterestRate,
        emiDurationMonths: _emiDurationMonths,
        emiMonthlyAmount: emiAmount,
        excludeFromExpense: true,
        customCategoryId: _selectedCustomCategory?.id,
      ),
    );

    // Create EMI installment transactions for each month - also excluded
    for (int i = 0; i < _emiDurationMonths; i++) {
      final installmentDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + i + 1,
        _selectedDate.day,
      );

      widget.transactionService.addTransaction(
        Transaction(
          id: '${parentId}_emi_$i',
          title: '$title - EMI ${i + 1}/$_emiDurationMonths',
          amount: emiAmount,
          type: _type,
          category: _selectedCategory,
          date: installmentDate,
          note: 'EMI installment ${i + 1} of $_emiDurationMonths',
          accountId: _fromAccount?.id,
          tagIds: _selectedTagIds,
          isEmi: true,
          parentTransactionId: parentId,
          emiMonthlyAmount: emiAmount,
          excludeFromExpense: true,
          customCategoryId: _selectedCustomCategory?.id,
        ),
      );
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: _typeColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ΓöÇΓöÇ Build ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildHero(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  // Add padding for the fixed bottom bar (88) plus safe area
                  88 + MediaQuery.of(context).padding.bottom + 16,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDateCard(),
                  const SizedBox(height: 16),
                  if (_type != TransactionType.transfer) ...[
                    _buildCategoryGrid(),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailsCard(),
                  const SizedBox(height: 16),
                  _buildTagsCard(),
                  const SizedBox(height: 16),
                  _buildAccountCard(),
                  if (_shouldShowEmiOptions()) ...[
                    const SizedBox(height: 16),
                    _buildEmiCard(),
                  ],
                  if (!_shouldShowEmiOptions() || _isRecurring) ...[
                    const SizedBox(height: 16),
                    _buildRecurringCard(),
                  ],
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Hero: gradient header with amount + type switcher ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildHero() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _currentGradient,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close + title
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    widget.editing != null
                        ? (_type == TransactionType.transfer
                              ? 'Edit Transfer'
                              : _type == TransactionType.income
                              ? 'Edit Income'
                              : 'Edit Expense')
                        : (_type == TransactionType.transfer
                              ? 'New Transfer'
                              : _type == TransactionType.income
                              ? 'New Income'
                              : 'New Expense'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Amount ΓÇö the hero element
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.currencyService.symbol,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      focusNode: _amountFocus,
                      autofocus: false,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.4),
                          height: 1.1,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        errorStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter an amount';
                        }
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Type switcher ΓÇö 3 pill buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _typeTab(TransactionType.expense, 'Expense'),
                    _typeTab(TransactionType.income, 'Income'),
                    _typeTab(TransactionType.transfer, 'Transfer'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTab(TransactionType t, String label) {
    final active = _type == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setType(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? _typeColor : Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Category grid ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildCategoryGrid() {
    const maxItemsToShow = 8; // 4 columns x 2 rows

    return ListenableBuilder(
      listenable: widget.categoryService,
      builder: (context, _) {
        final allItems = _allCategoryItems;
        final hasMore = allItems.length > maxItemsToShow;
        final displayed = _isCategoryExpanded
            ? allItems
            : allItems.take(maxItemsToShow).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Category'),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: displayed.length,
                itemBuilder: (_, i) {
                  final item = displayed[i];
                  final sel = _selectedItem.matches(item);
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedItem = item;
                      _selectedCategory =
                          item.builtin ?? TransactionCategory.other;
                      _selectedCustomCategory = item.custom;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: sel
                            ? item.color.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? item.color : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: sel ? 0.0 : 0.04,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.color.withValues(
                                alpha: sel ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(item.icon, color: item.color, size: 19),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? item.color
                                    : AppColors.textSecondary,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (hasMore) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(
                    () => _isCategoryExpanded = !_isCategoryExpanded,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _typeColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isCategoryExpanded ? 'Show Less' : 'Show More',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _typeColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _isCategoryExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: _typeColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ΓöÇΓöÇ Date card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildDateCard() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final isYesterday = _isSameDay(
      _selectedDate,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final dateLabel = isToday
        ? 'Today'
        : isYesterday
        ? 'Yesterday'
        : DateFormat('MMM d, yyyy').format(_selectedDate);

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: _typeColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Details card: title + note ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          _detailRow(
            icon: Icons.title_rounded,
            iconColor: AppColors.textSecondary,
            child: TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: _type == TransactionType.transfer
                    ? 'Label (optional)'
                    : 'Title (optional)',
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textLight,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _divider(),
          // Note
          _detailRow(
            icon: Icons.notes_rounded,
            iconColor: AppColors.textSecondary,
            child: TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Add a note...',
                hintStyle: TextStyle(fontSize: 15, color: AppColors.textLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Monthly transaction toggle (income + expense, not transfer)
          if (_type != TransactionType.transfer) ...[
            _divider(),
            InkWell(
              onTap: () => setState(() => _isMonthly = !_isMonthly),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: _isMonthly ? _typeColor : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly transaction',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMonthly
                                ? 'Counts toward monthly income/expense totals'
                                : 'General — not included in monthly totals',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isMonthly,
                      onChanged: (val) => setState(() => _isMonthly = val),
                      activeTrackColor: _typeColor.withValues(alpha: 0.5),
                      activeThumbColor: _typeColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Exclude from expense toggle (only for expense transactions)
          if (_type == TransactionType.expense) ...[
            _divider(),
            InkWell(
              onTap: () =>
                  setState(() => _excludeFromExpense = !_excludeFromExpense),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exclude from expense totals',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Won\'t be counted in expense calculations',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _excludeFromExpense,
                      onChanged: (val) =>
                          setState(() => _excludeFromExpense = val),
                      activeTrackColor: _typeColor.withValues(alpha: 0.5),
                      activeThumbColor: _typeColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ΓöÇΓöÇ Tags card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildTagsCard() {
    return ListenableBuilder(
      listenable: widget.tagService,
      builder: (context, _) {
        final availableTags = widget.tagService.all;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'TAGS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showCreateTagSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: _typeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _typeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (availableTags.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: GestureDetector(
                    onTap: _showCreateTagSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textLight.withValues(alpha: 0.3),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Create your first tag',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTagIds.remove(tag.id);
                            } else {
                              _selectedTagIds.add(tag.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tag.color.withValues(alpha: 0.15)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? tag.color
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tag.icon,
                                size: 14,
                                color: isSelected
                                    ? tag.color
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? tag.color
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateTagSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTagSheet(tagService: widget.tagService),
    );
    // Rebuild will happen automatically via ListenableBuilder
  }

  // ΓöÇΓöÇ Account card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildAccountCard() {
    final accounts = widget.accountService.all;

    // No accounts yet ΓÇö show a prompt to create one
    if (accounts.isEmpty) {
      return GestureDetector(
        onTap: () async {
          final created = await showAddAccountSheet(
            context,
            widget.accountService,
          );
          if (created != null && mounted) {
            setState(() => _fromAccount = created);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCOUNT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Add an account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_type == TransactionType.transfer) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            _accountTile(
              label: 'From',
              account: _fromAccount,
              accounts: accounts,
              onTap: () => _pickAccount(
                accounts: accounts,
                current: _fromAccount,
                onSelected: (a) => setState(() => _fromAccount = a),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const SizedBox(width: 52),
                  Expanded(
                    child: Divider(height: 1, color: AppColors.background),
                  ),
                ],
              ),
            ),
            _accountTile(
              label: 'To',
              account: _toAccount,
              accounts: accounts,
              onTap: () => _pickAccount(
                accounts: accounts,
                current: _toAccount,
                onSelected: (a) => setState(() => _toAccount = a),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _accountTile(
        label: 'Account',
        account: _fromAccount,
        accounts: accounts,
        onTap: () => _pickAccount(
          accounts: accounts,
          current: _fromAccount,
          onSelected: (a) => setState(() => _fromAccount = a),
        ),
      ),
    );
  }

  Widget _accountTile({
    required String label,
    required Account? account,
    required List<Account> accounts,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: account != null
                    ? account.color.withValues(alpha: 0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                account != null
                    ? account.type.icon
                    : Icons.account_balance_wallet_outlined,
                color: account != null ? account.color : AppColors.textLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account?.name ?? 'Select account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: account != null
                          ? AppColors.textPrimary
                          : AppColors.textLight,
                    ),
                  ),
                  if (account != null)
                    Text(
                      account.type.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAccount({
    required List<Account> accounts,
    required Account? current,
    required ValueChanged<Account> onSelected,
  }) async {
    final picked = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AccountPickerSheet(
        accounts: accounts,
        selected: current,
        accountService: widget.accountService,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  // ΓöÇΓöÇ EMI Card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  bool _shouldShowEmiOptions() {
    // Only show EMI options for expense transactions with credit card account
    if (_type != TransactionType.expense) return false;
    if (_fromAccount == null) return false;
    return _fromAccount!.type == AccountType.creditCard;
  }

  Widget _buildEmiCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EMI Toggle
          InkWell(
            onTap: () => setState(() {
              _isEmi = !_isEmi;
              if (!_isEmi) {
                _emiInterestController.clear();
                _emiInterestRate = 0.0;
                _emiDurationMonths = 3;
              }
            }),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.credit_score_rounded,
                      color: _typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMI TRANSACTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Convert to EMI',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEmi,
                    onChanged: (val) => setState(() {
                      _isEmi = val;
                      if (!val) {
                        _emiInterestController.clear();
                        _emiInterestRate = 0.0;
                        _emiDurationMonths = 3;
                      }
                    }),
                    activeTrackColor: _typeColor.withValues(alpha: 0.5),
                    activeThumbColor: _typeColor,
                  ),
                ],
              ),
            ),
          ),

          // EMI Details (shown when EMI is enabled)
          if (_isEmi) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: AppColors.background),
            ),

            // Interest Rate
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INTEREST RATE (% PER ANNUM)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emiInterestController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g., 12.5',
                      suffixText: '%',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _typeColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      final rate = double.tryParse(val) ?? 0.0;
                      setState(() => _emiInterestRate = rate);
                    },
                  ),
                ],
              ),
            ),

            // Duration
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DURATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [3, 6, 9, 12, 18, 24].map((months) {
                      final isSelected = _emiDurationMonths == months;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _emiDurationMonths = months),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _typeColor.withValues(alpha: 0.15)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _typeColor
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$months months',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? _typeColor
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // EMI Calculation Preview
            if (_emiInterestRate > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, color: AppColors.background),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Monthly EMI:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            widget.currencyService.formatter.format(
                              _calculateEmi(),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _typeColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            widget.currencyService.formatter.format(
                              _calculateEmi() * _emiDurationMonths,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  double _calculateEmi() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0 || _emiInterestRate <= 0 || _emiDurationMonths <= 0) {
      return 0;
    }

    // EMI = [P x R x (1+R)^N]/[(1+R)^N-1]
    // P = Principal (loan amount)
    // R = Monthly interest rate (annual rate / 12 / 100)
    // N = Number of months
    final monthlyRate = _emiInterestRate / 12 / 100;
    final numerator =
        amount * monthlyRate * pow(1 + monthlyRate, _emiDurationMonths);
    final denominator = pow(1 + monthlyRate, _emiDurationMonths) - 1;

    return numerator / denominator;
  }

  // ΓöÇΓöÇ Recurring Card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildRecurringCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recurring Toggle
          InkWell(
            onTap: () => setState(() {
              _isRecurring = !_isRecurring;
              if (!_isRecurring) {
                _recurringFrequency = 'monthly';
                _recurringEndDate = null;
              }
            }),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      color: _typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECURRING TRANSACTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Repeat automatically',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (val) => setState(() {
                      _isRecurring = val;
                      if (!val) {
                        _recurringFrequency = 'monthly';
                        _recurringEndDate = null;
                      }
                    }),
                    activeTrackColor: _typeColor.withValues(alpha: 0.5),
                    activeThumbColor: _typeColor,
                  ),
                ],
              ),
            ),
          ),

          // Recurring Details (shown when recurring is enabled)
          if (_isRecurring) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: AppColors.background),
            ),

            // Frequency
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FREQUENCY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _frequencyChip('Daily', 'daily'),
                      _frequencyChip('Weekly', 'weekly'),
                      _frequencyChip('Monthly', 'monthly'),
                      _frequencyChip('Yearly', 'yearly'),
                    ],
                  ),
                ],
              ),
            ),

            // End Date (Optional)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: AppColors.background),
            ),
            InkWell(
              onTap: _pickRecurringEndDate,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'END DATE (OPTIONAL)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _recurringEndDate != null
                                ? DateFormat(
                                    'MMM d, yyyy',
                                  ).format(_recurringEndDate!)
                                : 'No end date',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _recurringEndDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_recurringEndDate != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        onPressed: () =>
                            setState(() => _recurringEndDate = null),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _frequencyChip(String label, String value) {
    final isSelected = _recurringFrequency == value;
    return GestureDetector(
      onTap: () => setState(() => _recurringFrequency = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _typeColor.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _typeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? _typeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _pickRecurringEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _recurringEndDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _selectedDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: _typeColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _recurringEndDate = picked);
  }

  // ΓöÇΓöÇ Bottom save bar ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _currentGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _typeColor.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isSaving ? null : _save,
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.editing != null
                              ? 'Save Changes'
                              : _type == TransactionType.transfer
                              ? 'Save Transfer'
                              : _type == TransactionType.income
                              ? 'Save Income'
                              : 'Save Expense',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ΓöÇΓöÇ Helpers ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.8,
    ),
  );

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Divider(height: 1, color: AppColors.background),
  );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ΓöÇΓöÇ Account picker bottom sheet ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

// ΓöÇΓöÇ Account picker bottom sheet ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _AccountPickerSheet extends StatefulWidget {
  final List<Account> accounts;
  final Account? selected;
  final AccountService accountService;

  const _AccountPickerSheet({
    required this.accounts,
    required this.selected,
    required this.accountService,
  });

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  Future<void> _createAccount() async {
    // Dismiss this sheet, open add-account sheet, then return the new account
    Navigator.of(context).pop();
    final created = await showAddAccountSheet(
      // ignore: use_build_context_synchronously
      context,
      widget.accountService,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final accounts = widget.accountService.all;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // Account list + "New Account" row
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: accounts.length + 1, // +1 for "New Account"
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              // Last item ΓåÆ "New Account" button
              if (i == accounts.length) {
                return InkWell(
                  onTap: _createAccount,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'New Account',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final a = accounts[i];
              final isSelected = widget.selected?.id == a.id;
              return InkWell(
                onTap: () => Navigator.of(context).pop(a),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? a.color.withValues(alpha: 0.08)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? a.color : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(a.type.icon, color: a.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? a.color
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.type.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: a.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
