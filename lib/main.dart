import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'core/database/app_database.dart';
import 'core/services/account_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/auto_backup_service.dart';
import 'core/services/auto_backup_worker.dart';
import 'core/services/backup_service.dart';
import 'core/services/biometric_service.dart';
import 'core/services/budget_service.dart';
import 'core/services/category_service.dart';
import 'core/services/credit_card_bill_service.dart';
import 'core/services/currency_service.dart';
import 'core/services/tag_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_service.dart';
import 'core/services/recurring_confirmation_service.dart';
import 'core/theme/app_colors.dart';
import 'features/assistant/alert_worker.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Initialise the database (creates tables + seeds built-in data on first run)
  await AppDatabase.instance.database;

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize WorkManager with the auto-backup dispatcher.  This MUST be
  // called before any Workmanager().register*Task() call (which happens in
  // AutoBackupService on app start).
  try {
    await Workmanager().initialize(autoBackupDispatcher, isInDebugMode: false);
    debugPrint('[main] WorkManager initialised.');
    // Schedule the daily Flux AI alert evaluation task if not already registered.
    await scheduleAlertEvaluation();
  } catch (e) {
    debugPrint('[main] WorkManager init failed: $e');
  }

  runApp(const SpendFluxApp());
}

class SpendFluxApp extends StatefulWidget {
  const SpendFluxApp({super.key});

  @override
  State<SpendFluxApp> createState() => _SpendFluxAppState();
}

class _SpendFluxAppState extends State<SpendFluxApp> {
  final AuthService _authService = AuthService();
  final AccountService _accountService = AccountService();
  late final TransactionService _transactionService = TransactionService(
    accountService: _accountService,
  );
  final CategoryService _categoryService = CategoryService();
  final CurrencyService _currencyService = CurrencyService();
  final BudgetService _budgetService = BudgetService();
  final TagService _tagService = TagService();
  final BackupService _backupService = BackupService();
  final AutoBackupService _autoBackupService = AutoBackupService();
  final BiometricService _biometricService = BiometricService();
  late final ReminderService _reminderService = ReminderService(
    notificationService: NotificationService(),
  );
  final RecurringConfirmationService _recurringConfirmationService =
      RecurringConfirmationService();
  late final CreditCardBillService _billService = CreditCardBillService(
    accountService: _accountService,
    transactionService: _transactionService,
  );

  // Track the last signed-in user so we can detect a new sign-in after sign-out.
  String? _lastSignedInUserId;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onAuthChanged);
  }

  /// Called whenever AuthService notifies listeners.
  ///
  /// When a *different* user signs in (or the first sign-in after a sign-out),
  /// we reload all services so they pick up the clean database instead of
  /// serving the previous user's in-memory state.
  void _onAuthChanged() {
    final user = _authService.currentUser;
    if (user != null && user.id != _lastSignedInUserId) {
      _lastSignedInUserId = user.id;
      _reloadAllServices();
    } else if (user == null) {
      _lastSignedInUserId = null;
    }
  }

  Future<void> _reloadAllServices() async {
    debugPrint('[main] New user detected — reloading all services.');
    await Future.wait([
      _accountService.reload(),
      _categoryService.reload(),
      _tagService.reload(),
      _budgetService.reload(),
      _transactionService.reload(),
    ]);
    debugPrint('[main] All services reloaded for new user.');
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _authService.dispose();
    _transactionService.dispose();
    _categoryService.dispose();
    _currencyService.dispose();
    _accountService.dispose();
    _budgetService.dispose();
    _tagService.dispose();
    _backupService.dispose();
    _autoBackupService.dispose();
    _biometricService.dispose();
    _reminderService.dispose();
    _recurringConfirmationService.dispose();
    _billService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendFlux',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      routes: {
        '/': (context) => SplashScreen(
          authService: _authService,
          biometricService: _biometricService,
        ),
        '/login': (context) => LoginScreen(authService: _authService),
        '/home': (context) => MainShell(
          authService: _authService,
          transactionService: _transactionService,
          categoryService: _categoryService,
          currencyService: _currencyService,
          accountService: _accountService,
          budgetService: _budgetService,
          tagService: _tagService,
          backupService: _backupService,
          autoBackupService: _autoBackupService,
          biometricService: _biometricService,
          reminderService: _reminderService,
          recurringConfirmationService: _recurringConfirmationService,
          billService: _billService,
        ),
      },
      initialRoute: '/',
    );
  }
}
