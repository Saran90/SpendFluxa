import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/recurring_confirmation_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_screen.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../budget/budget_screen.dart';
import '../profile/profile_screen.dart';
import '../onboarding/onboarding_tour_screen.dart';

class MainShell extends StatefulWidget {
  final AuthService authService;
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final BudgetService budgetService;
  final TagService tagService;
  final BackupService backupService;
  final BiometricService biometricService;
  final ReminderService? reminderService;
  final RecurringConfirmationService recurringConfirmationService;

  const MainShell({
    super.key,
    required this.authService,
    required this.transactionService,
    required this.categoryService,
    required this.currencyService,
    required this.accountService,
    required this.budgetService,
    required this.tagService,
    required this.backupService,
    required this.biometricService,
    this.reminderService,
    required this.recurringConfirmationService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Controls the hide/show animation of the nav bar
  late AnimationController _navController;
  late Animation<double> _navSlide;

  // Each tab gets its own scroll controller so we can listen per-tab
  final List<ScrollController> _scrollControllers = List.generate(
    4,
    (_) => ScrollController(),
  );

  double _lastOffset = 0;
  bool _navVisible = true;

  @override
  void initState() {
    super.initState();

    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // 1 = visible
    );
    _navSlide = CurvedAnimation(
      parent: _navController,
      curve: Curves.easeInOut,
    );

    for (final sc in _scrollControllers) {
      sc.addListener(() => _onScroll(sc));
    }

    // Show onboarding tour on first launch
    _checkAndShowOnboarding();
  }

  Future<void> _checkAndShowOnboarding() async {
    // Wait for the first frame to render
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final onboardingService = OnboardingService();
    final hasSeenOnboarding = await onboardingService.hasSeenOnboarding();

    if (!hasSeenOnboarding && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnboardingTourScreen(),
          fullscreenDialog: true,
        ),
      );
      await onboardingService.setOnboardingCompleted();
    }
  }

  void _onScroll(ScrollController sc) {
    if (!sc.hasClients) return;
    final offset = sc.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;

    // Only react after scrolling past 60px to avoid jitter at the top
    if (offset < 60) {
      _showNav();
      return;
    }

    if (delta > 4 && _navVisible) {
      _hideNav();
    } else if (delta < -4 && !_navVisible) {
      _showNav();
    }
  }

  void _showNav() {
    if (_navVisible) return;
    _navVisible = true;
    _navController.forward();
  }

  void _hideNav() {
    if (!_navVisible) return;
    _navVisible = false;
    _navController.reverse();
  }

  @override
  void dispose() {
    _navController.dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      // extendBody lets content flow under the floating nav
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _wrapWithScrollController(
            HomeScreen(
              authService: widget.authService,
              transactionService: widget.transactionService,
              currencyService: widget.currencyService,
              budgetService: widget.budgetService,
              accountService: widget.accountService,
              categoryService: widget.categoryService,
              tagService: widget.tagService,
              reminderService: widget.reminderService,
              recurringConfirmationService: widget.recurringConfirmationService,
              scrollController: _scrollControllers[0],
            ),
            0,
          ),
          _wrapWithScrollController(
            TransactionsScreen(
              transactionService: widget.transactionService,
              currencyService: widget.currencyService,
              categoryService: widget.categoryService,
              accountService: widget.accountService,
              tagService: widget.tagService,
              scrollController: _scrollControllers[1],
            ),
            1,
          ),
          _wrapWithScrollController(
            BudgetScreen(
              budgetService: widget.budgetService,
              transactionService: widget.transactionService,
              currencyService: widget.currencyService,
              scrollController: _scrollControllers[2],
            ),
            2,
          ),
          _wrapWithScrollController(
            ProfileScreen(
              authService: widget.authService,
              categoryService: widget.categoryService,
              currencyService: widget.currencyService,
              accountService: widget.accountService,
              tagService: widget.tagService,
              transactionService: widget.transactionService,
              backupService: widget.backupService,
              budgetService: widget.budgetService,
              biometricService: widget.biometricService,
              scrollController: _scrollControllers[3],
            ),
            3,
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _navSlide,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _navSlide.value) * (80 + bottomPadding)),
            child: child,
          );
        },
        child: _buildFloatingNavBar(bottomPadding),
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? AnimatedBuilder(
              animation: _navSlide,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    (1 - _navSlide.value) * (80 + bottomPadding),
                  ),
                  child: child,
                );
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding + 16),
                child: FloatingActionButton(
                  heroTag: 'main_add_transaction_fab',
                  onPressed: _openAddTransaction,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _openAddTransaction() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddTransactionScreen(
              transactionService: widget.transactionService,
              categoryService: widget.categoryService,
              currencyService: widget.currencyService,
              accountService: widget.accountService,
              tagService: widget.tagService,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
  }

  Widget _wrapWithScrollController(Widget screen, int index) => screen;

  // ── Floating pill nav bar ─────────────────────────────────────────────────

  Widget _buildFloatingNavBar(double bottomPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _navItem(
                1,
                Icons.receipt_long_rounded,
                Icons.receipt_long_outlined,
                'Transactions',
              ),
              _navItem(
                2,
                Icons.account_balance_wallet_rounded,
                Icons.account_balance_wallet_outlined,
                'Budget',
              ),
              _navItem(
                3,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentIndex == index) {
            // Tap active tab → scroll to top
            final sc = _scrollControllers[index];
            if (sc.hasClients) {
              sc.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            }
          } else {
            setState(() => _currentIndex = index);
            _showNav();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            isActive ? activeIcon : inactiveIcon,
            color: isActive ? AppColors.primary : Colors.white54,
            size: 22,
          ),
        ),
      ),
    );
  }
}
