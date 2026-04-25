import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/custom_category.dart';
import '../../core/models/transaction.dart';
import '../../core/services/category_service.dart';
import '../../core/theme/app_colors.dart';
import 'add_category_sheet.dart';

// ── Built-in category lists ───────────────────────────────────────────────────

const _builtInExpense = [
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

const _builtInIncome = [
  TransactionCategory.salary,
  TransactionCategory.freelance,
  TransactionCategory.investment,
  TransactionCategory.gift,
  TransactionCategory.cashback,
];

class CategoriesScreen extends StatefulWidget {
  final CategoryService categoryService;

  /// When non-null the screen acts as a picker.
  /// Tapping a category pops with a [_CategoryResult].
  final TransactionType? filterType;

  const CategoriesScreen({
    super.key,
    required this.categoryService,
    this.filterType,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isPicker => widget.filterType != null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.filterType == TransactionType.income ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Picker callbacks ──────────────────────────────────────────────────────

  void _pickBuiltIn(TransactionCategory cat) {
    Navigator.of(context).pop(_CategoryResult.builtIn(cat));
  }

  void _pickCustom(CustomCategory cat) {
    Navigator.of(context).pop(_CategoryResult.custom(cat));
  }

  // ── Add / edit ────────────────────────────────────────────────────────────

  Future<void> _openAddSheet({CustomCategory? editing}) async {
    final type = _tabController.index == 0
        ? TransactionType.expense
        : TransactionType.income;

    await showAddCategorySheet(
      context,
      widget.categoryService,
      initialType: type,
      editing: editing,
    );
  }

  Future<void> _deleteCustom(CustomCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Category',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Delete "${cat.label}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
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
              'Delete',
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
      await widget.categoryService.remove(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fixed: back button + title ──────────────────────────────────
          _buildHeader(context),

          // ── Fixed: expense / income tab bar ────────────────────────────
          _buildTabBar(),

          // ── Scrollable: tab content ─────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: widget.categoryService,
              builder: (context, _) {
                return TabBarView(
                  controller: _tabController,
                  physics: _isPicker
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  children: [
                    _buildTab(
                      builtIn: _builtInExpense,
                      custom: widget.categoryService.expenseCategories,
                      type: TransactionType.expense,
                    ),
                    _buildTab(
                      builtIn: _builtInIncome,
                      custom: widget.categoryService.incomeCategories,
                      type: TransactionType.income,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // FAB only in browse mode
      floatingActionButton: _isPicker
          ? null
          : FloatingActionButton(
              onPressed: _openAddSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  Widget _buildTab({
    required List<TransactionCategory> builtIn,
    required List<CustomCategory> custom,
    required TransactionType type,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Built-in section ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _sectionLabel(
            'Built-in',
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.88,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final cat = builtIn[index];
              return _BuiltInCard(
                category: cat,
                isPicker: _isPicker,
                onTap: _isPicker ? () => _pickBuiltIn(cat) : null,
              );
            }, childCount: builtIn.length),
          ),
        ),

        // ── Custom section ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _sectionLabel(
            'Custom',
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            trailing: !_isPicker
                ? GestureDetector(
                    onTap: _openAddSheet,
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
          ),
        ),

        if (custom.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyCustom(type))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final cat = custom[index];
                return _CustomCard(
                  category: cat,
                  isPicker: _isPicker,
                  onTap: _isPicker ? () => _pickCustom(cat) : null,
                  onEdit: _isPicker ? null : () => _openAddSheet(editing: cat),
                  onDelete: _isPicker ? null : () => _deleteCustom(cat),
                );
              }, childCount: custom.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmptyCustom(TransactionType type) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.textLight.withValues(alpha: 0.4),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 36,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 10),
            Text(
              'No custom ${type == TransactionType.expense ? 'expense' : 'income'} categories yet',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_isPicker) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _openAddSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Add one',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _isPicker ? 'Select Category' : 'Categories',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 44,
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
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppColors.splashGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(
    String text, {
    EdgeInsets padding = EdgeInsets.zero,
    Widget? trailing,
  }) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ── Built-in category card ────────────────────────────────────────────────────

class _BuiltInCard extends StatelessWidget {
  final TransactionCategory category;
  final bool isPicker;
  final VoidCallback? onTap;

  const _BuiltInCard({
    required this.category,
    required this.isPicker,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom category card ──────────────────────────────────────────────────────

class _CustomCard extends StatelessWidget {
  final CustomCategory category;
  final bool isPicker;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CustomCard({
    required this.category,
    required this.isPicker,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (isPicker ? null : () => _showActions(context)),
      onLongPress: null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: category.color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Card content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(category.icon, color: category.color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      category.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // "Custom" badge top-right
            if (!isPicker)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: category.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: const Text(
                'Edit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Result type returned by picker mode ───────────────────────────────────────

class _CategoryResult {
  final TransactionCategory? builtInCategory;
  final CustomCategory? customCategory;

  const _CategoryResult.builtIn(TransactionCategory cat)
    : builtInCategory = cat,
      customCategory = null;

  const _CategoryResult.custom(CustomCategory cat)
    : builtInCategory = null,
      customCategory = cat;
}
