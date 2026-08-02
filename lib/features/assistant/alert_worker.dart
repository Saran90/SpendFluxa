import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/database/app_database.dart';
import '../../core/services/account_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/credit_card_bill_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/transaction_service.dart';
import 'data/alert_repository.dart';
import 'engine/alert_engine.dart';
import 'engine/financial_analysis_engine.dart';
import 'engine/plan_manager.dart';
import 'data/plan_repository.dart';

/// WorkManager task name for the daily alert evaluation.
const _alertTaskName = 'flux_ai_alert_evaluation';

/// SharedPreferences key to track whether the alert task has been scheduled.
const _alertTaskScheduledKey = 'flux_ai_alert_task_scheduled';

/// Schedules the daily alert evaluation task via WorkManager.
///
/// Safe to call on every app start — uses a flag in SharedPreferences
/// to avoid re-registering an already-running periodic task.
Future<void> scheduleAlertEvaluation() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_alertTaskScheduledKey) == true) return;

  try {
    await Workmanager().registerPeriodicTask(
      _alertTaskName,
      _alertTaskName,
      frequency: const Duration(hours: 24),
      flexInterval: const Duration(hours: 2),
      constraints: Constraints(
        requiresBatteryNotLow: true,
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    await prefs.setBool(_alertTaskScheduledKey, true);
    debugPrint('[AlertWorker] Periodic alert task scheduled.');
  } catch (e) {
    debugPrint('[AlertWorker] Failed to schedule alert task: $e');
  }
}

/// Executes the alert evaluation inside the WorkManager background isolate.
///
/// Constructs all required services directly (no Riverpod — WorkManager
/// runs in a separate Dart isolate). Returns `true` on success so
/// WorkManager does not retry aggressively.
Future<bool> runAlertEvaluationTask() async {
  try {
    // Ensure DB is open
    await AppDatabase.instance.database;

    final prefs = await SharedPreferences.getInstance();
    final salaryDayOverride = prefs.getInt('flux_ai_salary_day_override');

    // Construct services
    final accountService = AccountService();
    final transactionService = TransactionService(
      accountService: accountService,
    );
    final budgetService = BudgetService();
    final billService = CreditCardBillService(
      accountService: accountService,
      transactionService: transactionService,
    );
    final planRepository = PlanRepository();
    final alertRepository = AlertRepository();
    final analysisEngine = FinancialAnalysisEngine(
      transactionService: transactionService,
      accountService: accountService,
      budgetService: budgetService,
      creditCardBillService: billService,
    );
    final planManager = PlanManager(
      planRepository: planRepository,
      analysisEngine: analysisEngine,
    );
    final notificationService = NotificationService();
    await notificationService.initialize();

    final alertEngine = AlertEngine(
      transactionService: transactionService,
      budgetService: budgetService,
      accountService: accountService,
      creditCardBillService: billService,
      planManager: planManager,
      analysisEngine: analysisEngine,
      alertRepository: alertRepository,
      notificationService: notificationService,
      salaryDayOverride: salaryDayOverride,
    );

    await alertEngine.evaluateAll();
    debugPrint('[AlertWorker] Alert evaluation complete.');
    return true;
  } catch (e, st) {
    debugPrint('[AlertWorker] Error during alert evaluation: $e\n$st');
    return true; // Return true to prevent aggressive WorkManager retries
  }
}
