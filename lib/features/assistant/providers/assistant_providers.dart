import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/account_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/credit_card_bill_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../core/services/transaction_service.dart';
import '../data/alert_repository.dart';
import '../data/assistant_repository.dart';
import '../data/flux_ai_engine.dart';
import '../data/model_download_service.dart';
import '../data/model_storage.dart';
import '../data/plan_repository.dart';
import '../data/tool_dispatcher.dart';
import '../engine/abstract_ai_engine.dart';
import '../engine/alert_engine.dart';
import '../engine/context_window_manager.dart';
import '../engine/conversation_manager.dart';
import '../engine/financial_analysis_engine.dart';
import '../engine/plan_manager.dart';
import '../engine/tag_fuzzy_matcher.dart';
import 'assistant_session_notifier.dart';

// ── Service bridge providers ──────────────────────────────────────────────────
//
// The existing app services are ChangeNotifier instances created manually in
// main.dart and passed down via constructors. These bridge providers allow
// the assistant feature to access them via Riverpod without refactoring the
// rest of the app.
//
// Usage: Override these in the ProviderScope at the assistant screen entry
// point, passing the real service instances from the widget tree.
//
// Example:
//   ProviderScope(
//     overrides: [
//       transactionServiceProvider.overrideWithValue(widget.transactionService),
//       accountServiceProvider.overrideWithValue(widget.accountService),
//       ...
//     ],
//     child: AssistantScreen(),
//   )

final transactionServiceProvider = Provider<TransactionService>((ref) {
  throw UnimplementedError(
    'transactionServiceProvider must be overridden with a real TransactionService instance.',
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError(
    'authServiceProvider must be overridden with a real AuthService instance.',
  );
});

final accountServiceProvider = Provider<AccountService>((ref) {
  throw UnimplementedError(
    'accountServiceProvider must be overridden with a real AccountService instance.',
  );
});

final budgetServiceProvider = Provider<BudgetService>((ref) {
  throw UnimplementedError(
    'budgetServiceProvider must be overridden with a real BudgetService instance.',
  );
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  throw UnimplementedError(
    'categoryServiceProvider must be overridden with a real CategoryService instance.',
  );
});

final tagServiceProvider = Provider<TagService>((ref) {
  throw UnimplementedError(
    'tagServiceProvider must be overridden with a real TagService instance.',
  );
});

final creditCardBillServiceProvider = Provider<CreditCardBillService>((ref) {
  throw UnimplementedError(
    'creditCardBillServiceProvider must be overridden with a real CreditCardBillService instance.',
  );
});

// ── AI engine ─────────────────────────────────────────────────────────────────

/// The concrete AI inference backend.
///
/// Override with [MockAiEngine] in tests:
/// ```dart
/// container = ProviderContainer(
///   overrides: [abstractAiEngineProvider.overrideWithValue(MockAiEngine())],
/// );
/// ```
final abstractAiEngineProvider = Provider<AbstractAiEngine>((ref) {
  final engine = FluxAiEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

// ── Download service ──────────────────────────────────────────────────────────

final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final svc = ModelDownloadService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Streams download progress events from [ModelDownloadService].
final downloadProgressProvider = StreamProvider<DownloadProgress>((ref) {
  return ref.watch(modelDownloadServiceProvider).progressStream;
});

// ── Model status ──────────────────────────────────────────────────────────────

/// Possible states of the local Gemma model.
enum ModelLoadStatus {
  /// Model file not present — show onboarding/download UI.
  notDownloaded,

  /// Model file present but not yet loaded into the native layer.
  loading,

  /// Model is loaded and ready for inference.
  ready,

  /// Model failed to load.
  failed,
}

/// Checks whether the model is available via the asset pack and loaded.
final modelStatusProvider = FutureProvider<ModelLoadStatus>((ref) async {
  final available = await FluxAiModelStorage.isModelAvailable();
  if (!available) return ModelLoadStatus.notDownloaded;

  final engine = ref.watch(abstractAiEngineProvider);
  if (engine.isModelLoaded) return ModelLoadStatus.ready;

  // Asset pack is installed — resolve path and load.
  final path = await FluxAiModelStorage.resolveModelPath();
  if (path == null) return ModelLoadStatus.notDownloaded;

  final ok = await engine.loadModel(path);
  return ok ? ModelLoadStatus.ready : ModelLoadStatus.failed;
});

// ── Additional providers wired in Task 12 ────────────────────────────────────

final planRepositoryProvider = Provider<PlanRepository>(
  (_) => PlanRepository(),
);

final alertRepositoryProvider = Provider<AlertRepository>(
  (_) => AlertRepository(),
);

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (_) => AssistantRepository(),
);

final financialAnalysisEngineProvider = Provider<FinancialAnalysisEngine>((
  ref,
) {
  return FinancialAnalysisEngine(
    transactionService: ref.watch(transactionServiceProvider),
    accountService: ref.watch(accountServiceProvider),
    budgetService: ref.watch(budgetServiceProvider),
    creditCardBillService: ref.watch(creditCardBillServiceProvider),
  );
});

final planManagerProvider = Provider<PlanManager>((ref) {
  return PlanManager(
    planRepository: ref.watch(planRepositoryProvider),
    analysisEngine: ref.watch(financialAnalysisEngineProvider),
  );
});

final tagFuzzyMatcherProvider = Provider<TagFuzzyMatcher>((ref) {
  return TagFuzzyMatcher(tagService: ref.watch(tagServiceProvider));
});

final toolDispatcherProvider = Provider<ToolDispatcher>((ref) {
  return ToolDispatcher(
    transactionService: ref.watch(transactionServiceProvider),
    accountService: ref.watch(accountServiceProvider),
    budgetService: ref.watch(budgetServiceProvider),
    categoryService: ref.watch(categoryServiceProvider),
    planManager: ref.watch(planManagerProvider),
    analysisEngine: ref.watch(financialAnalysisEngineProvider),
    tagFuzzyMatcher: ref.watch(tagFuzzyMatcherProvider),
  );
});

final contextWindowManagerProvider = Provider<ContextWindowManager>(
  (_) => ContextWindowManager(),
);

final conversationManagerProvider = Provider<ConversationManager>((ref) {
  return ConversationManager(
    engine: ref.watch(abstractAiEngineProvider),
    dispatcher: ref.watch(toolDispatcherProvider),
    contextManager: ref.watch(contextWindowManagerProvider),
    transactionService: ref.watch(transactionServiceProvider),
    accountService: ref.watch(accountServiceProvider),
  );
});

/// The main chat session state notifier.
final assistantSessionProvider =
    StateNotifierProvider<AssistantSessionNotifier, AssistantSessionState>((
      ref,
    ) {
      return AssistantSessionNotifier(
        conversationManager: ref.watch(conversationManagerProvider),
        repository: ref.watch(assistantRepositoryProvider),
        engine: ref.watch(abstractAiEngineProvider),
      );
    });

final alertEngineProvider = Provider<AlertEngine>((ref) {
  return AlertEngine(
    transactionService: ref.watch(transactionServiceProvider),
    budgetService: ref.watch(budgetServiceProvider),
    accountService: ref.watch(accountServiceProvider),
    creditCardBillService: ref.watch(creditCardBillServiceProvider),
    planManager: ref.watch(planManagerProvider),
    analysisEngine: ref.watch(financialAnalysisEngineProvider),
    alertRepository: ref.watch(alertRepositoryProvider),
    notificationService: NotificationService(),
  );
});
