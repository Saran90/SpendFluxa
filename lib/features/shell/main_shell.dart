import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/auto_backup_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/credit_card_bill_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/recurring_confirmation_service.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/services/force_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../home/home_screen.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/add_transaction_screen.dart';
import '../budget/budget_screen.dart';
import '../profile/profile_screen.dart';
import '../onboarding/onboarding_tour_screen.dart';
import 'force_update_dialog.dart';

class MainShell extends StatefulWidget {
  final AuthService authService;
  final TransactionService transactionService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final BudgetService budgetService;
  final TagService tagService;
  final BackupService backupService;
  final AutoBackupService autoBackupService;
  final BiometricService biometricService;
  final ReminderService? reminderService;
  final RecurringConfirmationService recurringConfirmationService;
  final CreditCardBillService billService;

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
    required this.autoBackupService,
    required this.biometricService,
    this.reminderService,
    required this.recurringConfirmationService,
    required this.billService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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

    // Check for forced update
    _checkForceUpdate();

    // Run auto-backup if it's due (silently, in background)
    _runAutoBackupIfDue();

    // Watch app lifecycle so backup also triggers on foreground resume
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workerStatusTimer?.cancel();
    _foregroundPollingTimer?.cancel();
    _navController.dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — check if a backup is now overdue
      _runAutoBackupIfDue();
      // Also pick up any worker status update from the background.
      _checkWorkerStatus();

    // While the app is in the foreground, poll the worker status every
    // 30s so the backup dialog appears the moment the scheduled time
    // arrives (the user may be looking at the app when the worker fires).
    _startForegroundStatusPolling();
    }
  }

  Future<void> _checkForceUpdate() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final storeUrl = await ForceUpdateService().checkForceUpdate();
    if (storeUrl != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ForceUpdateDialog(storeUrl: storeUrl),
      );
    }
  }

  bool _autoBackupRunning = false;
  Timer? _workerStatusTimer;

  /// Long-running foreground polling timer.  Re-checks the worker status
  /// every 30s so the dialog appears the moment the background worker
  /// starts — even if the user is staring at the app when the scheduled
  /// time arrives.
  Timer? _foregroundPollingTimer;

  Future<void> _runAutoBackupIfDue() async {
    // Guard against concurrent runs (lifecycle resume fires multiple times)
    if (_autoBackupRunning) return;

    // Small delay so the app finishes rendering before doing I/O
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Wait until AutoBackupService has loaded its persisted state from prefs
    await widget.autoBackupService.ready;
    if (!mounted) return;

    debugPrint('[AutoBackup] ${widget.autoBackupService.debugStatus}');

    if (!widget.autoBackupService.isDueNow()) return;

    // Try silent sign-in only — auto-backup must never show UI
    final account = widget.authService.googleAccount;
    if (account == null) {
      debugPrint('[AutoBackup] No signed-in account — skipping.');
      return;
    }

    _autoBackupRunning = true;
    debugPrint('[AutoBackup] Starting auto-backup...');

    // Show non-dismissible progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AutoBackupProgressDialog(),
      );
    }

    try {
      final targetId = widget.autoBackupService.targetFileId;
      BackupResult result;
      if (targetId != null) {
        result = await widget.backupService.overwriteBackup(
          account,
          targetId,
          silent: true,
        );
        if (result.success &&
            result.fileId != null &&
            result.fileId != targetId) {
          await widget.autoBackupService.setTargetFileId(result.fileId!);
        }
      } else {
        result = await widget.backupService.backupToGoogleDrive(
          account,
          silent: true,
        );
        if (result.success && result.fileId != null) {
          await widget.autoBackupService.setTargetFileId(result.fileId!);
        }
      }

      // Close the progress dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (result.success) {
        await widget.autoBackupService.markBackedUpToday();
        debugPrint('[AutoBackup] Daily backup completed successfully.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text('Auto-backup completed successfully'),
                ],
              ),
              backgroundColor: const Color(0xFF2D9E6B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('[AutoBackup] Daily backup failed: ${result.error}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-backup failed: ${result.error}'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Safety net — close dialog even on unexpected errors
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint('[AutoBackup] Unexpected error: $e');
    } finally {
      _autoBackupRunning = false;
    }
  }

  /// Polls the persisted WorkManager worker status and surfaces the
  /// non-dismissible loader / success / failure banner to the user.
  ///
  /// Called on init and on every foreground-resume.  Refreshes the
  /// [AutoBackupService] from prefs and reacts to the latest status:
  ///   • [AutoBackupStatus.running] → show the loader dialog
  ///   • [AutoBackupStatus.success] → show the success snackbar
  ///   • [AutoBackupStatus.failed]  → show the error snackbar
  /// The status is then cleared so the next worker run starts fresh.
  Future<void> _checkWorkerStatus() async {
    final status = await widget.autoBackupService.refreshWorkerStatus();
    if (!mounted) return;

    switch (status) {
      case AutoBackupStatus.running:
        _showAutoBackupProgressDialog();
        break;
      case AutoBackupStatus.success:
        await widget.autoBackupService.clearWorkerStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auto-backup completed successfully',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2D9E6B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        break;
      case AutoBackupStatus.failed:
        final err = widget.autoBackupService.workerError ?? 'Unknown error';
        await widget.autoBackupService.clearWorkerStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-backup failed: $err'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        break;
      case AutoBackupStatus.idle:
        // Nothing to surface.
        break;
    }
  }

  /// Shows the non-dismissible backup progress dialog, but only if there
  /// isn't already one on screen (avoids stacking dialogs on top of each
  /// other if the worker status hasn't been cleared yet).
  /// Shows the non-dismissible backup progress dialog and starts a
  /// short polling timer that checks the WorkManager worker status every
  /// 2 seconds.  When the worker reports success or failure, the dialog
  /// is dismissed and a snackbar is shown.
  void _showAutoBackupProgressDialog() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AutoBackupProgressDialog(),
      );
    }
    _startWorkerStatusPolling();
  }

  /// Polls [AutoBackupService.workerStatus] every 2 seconds.  When it
  /// transitions from [AutoBackupStatus.running] to a terminal state
  /// (success / failed), the progress dialog is dismissed and the
  /// appropriate snackbar is shown.
  /// Periodically polls the worker status every 30 seconds while the
  /// app is in the foreground.  When it detects the worker is running,
  /// it shows the non-dismissible dialog.  When the worker reports a
  /// terminal state, it surfaces the success/error snackbar.
  void _startForegroundStatusPolling() {
    _foregroundPollingTimer?.cancel();
    _foregroundPollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        await _checkWorkerStatus();
      },
    );
  }

  void _startWorkerStatusPolling() {
    _workerStatusTimer?.cancel();
    _workerStatusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final status =
            await widget.autoBackupService.refreshWorkerStatus();
        if (status == AutoBackupStatus.running) {
          return; // still running
        }
        // Worker finished — stop polling, close dialog, show result.
        timer.cancel();
        _workerStatusTimer = null;
        if (mounted) {
          // Dismiss whichever dialog is on top (the progress one).
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {}
        }
        if (status == AutoBackupStatus.success) {
          await widget.autoBackupService.clearWorkerStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Auto-backup completed successfully'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF2D9E6B),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (status == AutoBackupStatus.failed) {
          final err =
              widget.autoBackupService.workerError ?? 'Unknown error';
          await widget.autoBackupService.clearWorkerStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto-backup failed: $err'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
    );
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
              billService: widget.billService,
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
              categoryService: widget.categoryService,
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
              autoBackupService: widget.autoBackupService,
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
        transitionDuration: const Duration(milliseconds: 220),
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

// ── Auto-backup progress dialog ───────────────────────────────────────────────

class _AutoBackupProgressDialog extends StatelessWidget {
  const _AutoBackupProgressDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // non-dismissible — back button has no effect
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.backup_rounded,
                  color: Color(0xFF4285F4),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              // Title
              const Text(
                'Backing Up',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Uploading your data to Google Drive...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              // Progress indicator
              const LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                backgroundColor: Color(0xFFE8F0FE),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
