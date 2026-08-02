# Tasks

## Phase 3 — Task Breakdown: SpendFlux AI Assistant

### Milestones Overview

| Milestone | Description | Tasks |
|---|---|---|
| M1 | Foundation & Infrastructure | 1–5 |
| M2 | Deterministic Analysis Layer | 6–9 |
| M3 | AI Engine & Orchestration | 10–13 |
| M4 | Chat UI | 14–16 |
| M5 | Proactive Alerts | 17–18 |
| M6 | Financial Plans | 19–20 |
| M7 | Integration & Polish | 21–23 |

Dependencies must be respected. Within a milestone, tasks can be worked in parallel unless a dependency is listed.

---

## Milestone 1 — Foundation & Infrastructure

### Task 1: Database Migration (version 11)

**Complexity:** Low
**Depends on:** Nothing
**Files affected:**
- `lib/core/database/app_database.dart` [MODIFY]

**Work:**
1. Bump `_dbVersion` from current value to `11`.
2. Add `if (oldVersion < 11)` block in `_onUpgrade` that executes the three new `CREATE TABLE` statements.
3. Add the three tables to `_createTables()` for fresh installs.
4. Add `assistant_messages` to `clearUserData()` so it is wiped on sign-out.
5. Verify existing migration path is not broken.

**New tables:**
- `assistant_messages` (id, session_id, role, content, timestamp) + index
- `financial_plans` (id, name, type, target_amount, target_date, priority, current_savings, preferred_account_id, contribution_frequency, created_at)
- `alert_records` (id, alert_type, subject, emitted_at) + index

---

### Task 2: Pigeon Bridge Definition & Code Generation

**Complexity:** Medium
**Depends on:** Nothing (can run in parallel with Task 1)
**Files affected:**
- `pigeon/flux_ai_api.dart` [NEW — project root]
- `lib/features/assistant/pigeon/flux_ai_api.g.dart` [GENERATED]
- `android/app/src/main/kotlin/com/saran/spendsense/FluxAiApi.g.kt` [GENERATED]

**Work:**
1. Create `pigeon/flux_ai_api.dart` with the full Pigeon definition:
   - `FluxAiModelStatus` data class (isLoaded, modelPath, errorMessage)
   - `FluxAiHostApi` @HostApi with 6 methods (loadModel, unloadModel, getModelStatus, generateResponse, generateResponseStreaming, cancelGeneration)
   - `FluxAiFlutterApi` @FlutterApi with 3 callbacks (onToken, onGenerationComplete, onGenerationError)
   - `@ConfigurePigeon` options pointing to correct Dart and Kotlin output paths
2. Run `dart run pigeon --input pigeon/flux_ai_api.dart` to generate both files.
3. Confirm generated files compile without errors.

**Note:** Verify the Kotlin package name matches the actual Android app package before running generation.

---

### Task 3: Abstract AI Engine Interface & FluxAiEngine Update

**Complexity:** Medium
**Depends on:** Task 2 (Pigeon generated files must exist)
**Files affected:**
- `lib/features/assistant/engine/abstract_ai_engine.dart` [NEW]
- `lib/features/assistant/data/flux_ai_engine.dart` [MODIFY]
- `lib/features/assistant/data/mock_ai_engine.dart` [NEW]

**Work:**
1. Create `abstract_ai_engine.dart` defining the `AbstractAiEngine` abstract class with: `isModelLoaded`, `tokenStream`, `completeStream`, `errorStream`, `loadModel`, `unloadModel`, `generateResponseStreaming`, `cancelGeneration`, `dispose`.
2. Modify `flux_ai_engine.dart` to `implements AbstractAiEngine`. Wire all `AbstractAiEngine` methods to the Pigeon `FluxAiHostApi` calls. Fix the existing compile errors (the Pigeon file now exists).
3. Create `mock_ai_engine.dart` implementing `AbstractAiEngine` with controllable broadcast streams and test helpers (`emitTokens`, `emitCompletion`, `emitError`).

---

### Task 4: Native Android LLM Inference Layer (Kotlin)

**Complexity:** High
**Depends on:** Task 2 (generated Kotlin Pigeon file must exist)
**Files affected:**
- `android/app/src/main/kotlin/com/saran/spendsense/FluxAiHostApiImpl.kt` [NEW]
- `android/app/src/main/kotlin/com/saran/spendsense/MainActivity.kt` [MODIFY]
- `android/app/build.gradle` [MODIFY — add MediaPipe dependency]

**Work:**
1. Add MediaPipe LLM Inference dependency to `android/app/build.gradle`:
   `implementation 'com.google.mediapipe:tasks-genai:0.10.22'`
2. Create `FluxAiHostApiImpl.kt`:
   - Implements the generated `FluxAiHostApi` interface.
   - Holds a nullable `LlmInference` session.
   - `loadModel`: Creates `LlmInference` with GPU delegate, falls back to CPU on failure.
   - `generateResponseStreaming`: Calls `llm.generateResponseAsync` with a `ProgressListener` that calls `FluxAiFlutterApi.onToken` for each token and `onGenerationComplete` at the end.
   - `cancelGeneration`: Cancels the active session.
   - `unloadModel`: Closes and nulls the session.
   - All exceptions are caught and routed to `onGenerationError`.
3. Register `FluxAiHostApiImpl` in `MainActivity.configureFlutterEngine`.
4. Register the `FluxAiFlutterApi` instance so Android can call back to Dart.

---

### Task 5: Model Download Service & Riverpod Providers

**Complexity:** Medium
**Depends on:** Task 3
**Files affected:**
- `lib/features/assistant/data/model_download_service.dart` [NEW]
- `lib/features/assistant/providers/assistant_providers.dart` [NEW]

**Work:**
1. Create `ModelDownloadService` with:
   - `DownloadProgress` data class (bytesDownloaded, totalBytes, percentage, isComplete, error).
   - `progressStream` as a broadcast `StreamController<DownloadProgress>`.
   - `download()`: HTTP GET to the Gemma 3 1B model URL, streams response to file, emits progress every 512 KB, validates final file size ≥ 500 MB, calls `FluxAiModelStorage.saveModelPath()` on success.
   - `cancel()`: Closes the HTTP connection and deletes partial file.
   - `dispose()`: Closes the stream controller.
2. Create `assistant_providers.dart` with all Riverpod providers:
   - `abstractAiEngineProvider` (Provider<AbstractAiEngine>)
   - `modelStorageProvider`
   - `modelDownloadServiceProvider`
   - `planRepositoryProvider`
   - `alertRepositoryProvider`
   - `financialAnalysisEngineProvider`
   - `planManagerProvider`
   - `alertEngineProvider`
   - `tagFuzzyMatcherProvider`
   - `toolDispatcherProvider`
   - `contextWindowManagerProvider`
   - `conversationManagerProvider`
   - `downloadProgressProvider` (StreamProvider)
   - `modelStatusProvider` (FutureProvider)
   - `assistantSessionProvider` (StateNotifierProvider)


---

## Milestone 2 — Deterministic Analysis Layer

### Task 6: New Data Models & Repositories

**Complexity:** Medium
**Depends on:** Task 1
**Files affected:**
- `lib/features/assistant/models/financial_plan.dart` [NEW]
- `lib/features/assistant/models/alert_record.dart` [NEW]
- `lib/features/assistant/models/undo_stack_entry.dart` [NEW]
- `lib/features/assistant/models/chat_message.dart` [MODIFY — add sessionId]
- `lib/features/assistant/data/plan_repository.dart` [NEW]
- `lib/features/assistant/data/alert_repository.dart` [NEW]

**Work:**
1. Create `FinancialPlan` model class with enums (`PlanType`, `PlanPriority`, `ContributionFrequency`), all persisted fields, `toMap()`, `fromMap()`, and computed getters (`requiredContribution`, `achievable`, `estimatedCompletionDate`, `atRisk`) as nullable (set by `PlanManager`).
2. Create `AlertRecord` model with `toMap()` / `fromMap()`.
3. Create `UndoStackEntry` model (in-memory, no persistence).
4. Modify `ChatMessage` to add an optional `sessionId` field.
5. Create `PlanRepository` with: `getAll({PlanType? type})`, `getById(String id)`, `insert(FinancialPlan)`, `update(FinancialPlan)`, `delete(String id)` — all backed by the `financial_plans` SQLite table.
6. Create `AlertRepository` with: `insert(AlertRecord)`, `findRecent(String alertType, String subject, DateTime since)`, `deleteOlderThan(DateTime cutoff)`.

---

### Task 7: Financial Analysis Engine

**Complexity:** High
**Depends on:** Task 1
**Files affected:**
- `lib/features/assistant/engine/financial_analysis_engine.dart` [NEW]

**Work:**
1. Implement `FinancialAnalysisEngine` class with constructor injecting `TransactionService`, `AccountService`, `BudgetService`, `CreditCardBillService`, and optional `PeriodResolver`.
2. Implement `getSpendingSummary`: aggregate income and expense totals per category for the given period; return `SpendingSummaryResult` with `totalExpenses`, `totalIncome`, `netBalance`, and `categoryBreakdown`.
3. Implement `comparePeriods`: call `getSpendingSummary` for both periods; compute absolute delta and percentage change; guard against division by zero.
4. Implement `getSavingsRate`: `max(0.0, ((income - expenses) / income) * 100)`; return 0.0 when income is 0.
5. Implement `getAnomalies`: for each expense category compute 3-month rolling average; flag categories where current month total > 2× average; sort by multiplier descending.
6. Implement `getFinancialSummary`: aggregate all 12 months for year-to-date or specified year; return monthly breakdown.
7. Implement `getBalanceForecast`: initialise from current account balances; overlay recurring expenses and income on scheduled dates; overlay credit card bills, EMI amounts, and plan contributions; compute running balance per day; attach confidence level.
8. Implement `estimateMonthlySurplus`: mean of (income − expenses) for the past N months.
9. Implement `detectSubscriptions`: scan recurring templates + pattern-based detection (same title/amount ±5% across 3+ consecutive months).
10. Implement `inferAverageMonthlySalary`: sum salary-category income / months with data.
11. Define result types: `SpendingSummaryResult`, `PeriodComparisonResult`, `AnomalyResult`, `FinancialSummaryResult`, `BalanceForecast`, `DayForecast`, `SubscriptionCandidate`.

---

### Task 8: Plan Manager

**Complexity:** Medium
**Depends on:** Task 6, Task 7
**Files affected:**
- `lib/features/assistant/engine/plan_manager.dart` [NEW]

**Work:**
1. Implement `PlanManager` with constructor injecting `PlanRepository` and `FinancialAnalysisEngine`.
2. Implement `getPlans({PlanType? type})`: load from repository, run `assessAchievability` on each, return enriched list.
3. Implement `createPlan(FinancialPlan plan)`: validate `targetDate` is in the future; compute achievability; persist; return enriched plan.
4. Implement `updatePlan`: validate; recompute achievability; persist.
5. Implement `deletePlan(String id)`.
6. Implement `getAtRiskPlans()`: return all event-type plans where `atRisk == true`.
7. Implement `assessAchievability(FinancialPlan)`: compute `requiredContribution`, compare against `estimateMonthlySurplus`, set `achievable` flag, generate suggestions when false (extended date + reduced target).
8. Implement `computeSavingsSchedule(FinancialPlan)`: generate list of `ScheduleEntry` objects.

---

### Task 9: Tag Fuzzy Matcher & Tool Dispatcher Expansion

**Complexity:** Medium
**Depends on:** Task 6
**Files affected:**
- `lib/features/assistant/engine/tag_fuzzy_matcher.dart` [NEW]
- `lib/features/assistant/data/tool_dispatcher.dart` [MODIFY]
- `lib/features/assistant/constants/tool_schemas.dart` [MODIFY]
- `lib/features/assistant/validation/tool_call_validator.dart` [MODIFY]
- `lib/features/assistant/constants/system_prompt.dart` [MODIFY]

**Work:**
1. Create `TagFuzzyMatcher` with `TagService` dependency:
   - `exactMatch(String name) → Tag?`
   - `fuzzySearch(String query, {int maxResults = 5}) → List<Tag>` using Levenshtein distance with threshold `floor(query.length / 2)`.
2. Expand `tool_schemas.dart`: add all 13 new tool names to `FluxAiTools.all` set; add required-argument sets for each.
3. Expand `tool_call_validator.dart`: add validation case for each of the 13 new tools.
4. Expand `tool_dispatcher.dart`:
   - Add `PlanManager`, `FinancialAnalysisEngine`, `TagFuzzyMatcher` as constructor dependencies.
   - Implement `updateTransaction`, `deleteTransaction`, `searchTransactions` (with tag fuzzy-match flow), `createRecurringTransaction`, `cancelRecurringTransaction`.
   - Implement `getFinancialPlans`, `createFinancialPlan`, `updateFinancialPlan`, `deleteFinancialPlan`.
   - Implement `getBalanceForecast`, `getAnomalies`, `getSavingsRate`, `getFinancialSummary`.
   - Move existing `getSpendingSummary`, `comparePeriods`, `getForecast` to delegate to `FinancialAnalysisEngine`.
5. Update `system_prompt.dart`: revise `fluxAiToolInstructions` to list all 19 tools with their signatures.


---

## Milestone 3 — AI Engine & Orchestration

### Task 10: Context Window Manager

**Complexity:** Medium
**Depends on:** Task 3
**Files affected:**
- `lib/features/assistant/engine/context_window_manager.dart` [NEW]

**Work:**
1. Implement `ContextSummary` data class (text, summarisedUpToIndex, generatedAt).
2. Implement `ContextWindowManager`:
   - `_allMessages: List<ChatMessage>` — full session history.
   - `_summary: ContextSummary?` — in-memory only, never persisted.
   - `addMessage(ChatMessage)`: appends to `_allMessages`.
   - `buildPrompt()`: prepends `[CONTEXT SUMMARY]...[END SUMMARY]` block if summary exists, then appends the last 10 messages with `User:` / `Assistant:` prefixes.
   - `maybeSummarise(AbstractAiEngine engine)`: triggered after each assistant response; summarises messages beyond the active window using a non-streaming `generateResponse` call; truncates result to ~150 words (≤200 tokens heuristic); updates `_summary`.
   - `clear()`: clears `_allMessages` and `_summary`.
3. Define the `summarisationSystemPrompt` constant.
4. Implement `truncateToTokenLimit(String text, int maxTokens)` using whitespace word count as a proxy.

---

### Task 11: Conversation Manager (Orchestrator)

**Complexity:** High
**Depends on:** Task 3, Task 9, Task 10
**Files affected:**
- `lib/features/assistant/engine/conversation_manager.dart` [NEW]

**Work:**
1. Implement `ConversationManager` with constructor injecting `AbstractAiEngine`, `ToolDispatcher`, `ContextWindowManager`, `TransactionService`.
2. Implement `handleUserMessage(String text)`:
   - Run `TransactionExtractor` if the message resembles a transaction command.
   - If extraction confidence < 0.85, emit clarification question and stop.
   - Build prompt via `ContextWindowManager.buildPrompt()`.
   - Begin streaming via `engine.generateResponseStreaming`.
   - On `completeStream`: call `_processResponse`.
3. Implement `_processResponse(String fullResponse)`:
   - Try to parse tool call via `ToolCallValidator.tryParse`.
   - If valid tool call: validate → dispatch → maybe push undo → re-prompt with tool result.
   - If no tool call but response looks like it needs data: retry up to 2 times with reinforced instruction.
   - Otherwise: finalise response.
4. Implement undo stack:
   - `_undoStack: List<UndoStackEntry>` capped at 10.
   - `_maybePushUndo(ToolCall, ToolResult)`: snapshot before-state for create/update/delete.
   - `handleUndo()`: pop and reverse last entry; emit confirmation.
   - `handleUndoAll()`: reverse all entries in order; report count.
5. Implement `_responseNeedsData(String response)`: check for hedging phrases.
6. Implement `cancelGeneration()`: calls `engine.cancelGeneration()`.
7. Handle app lifecycle (backgrounded during generation): expose `onAppPaused()` / `onAppResumed()` hooks called by the UI layer.
8. Expose `messageStream: Stream<ChatMessage>` for the UI to react to new/updated messages.

---

### Task 12: Assistant Session Notifier & Chat History Repository

**Complexity:** Medium
**Depends on:** Task 1, Task 11
**Files affected:**
- `lib/features/assistant/data/assistant_repository.dart` [NEW]
- `lib/features/assistant/providers/assistant_providers.dart` [MODIFY — add AssistantSessionNotifier]

**Work:**
1. Create `AssistantRepository`:
   - `insertMessage(AssistantMessage)`.
   - `getRecentSession(int limit) → List<AssistantMessage>`.
   - `deleteSession(String sessionId)`.
   - `enforceMessageCap(int maxMessages)`: delete oldest rows when count > 500.
   - `getOrCreateSessionId()`: returns active session ID from SharedPreferences or creates a new UUID.
2. Create `AssistantSessionState` data class: `messages`, `isGenerating`, `isModelLoaded`, `modelStatus`, `undoStack`, `sessionId`.
3. Create `AssistantSessionNotifier extends StateNotifier<AssistantSessionState>`:
   - Loads last session from `AssistantRepository` on construction.
   - Delegates `sendMessage`, `undo`, `undoAll`, `cancelGeneration` to `ConversationManager`.
   - Subscribes to `ConversationManager.messageStream` to update state.
   - `clearChat()`: deletes session from DB, resets state, creates new session ID.
   - Persists each new user/assistant message to `AssistantRepository` after it is finalised.
   - Calls `enforceMessageCap(500)` after each insertion.

---

### Task 13: System Prompt Update for 19 Tools

**Complexity:** Low
**Depends on:** Task 9
**Files affected:**
- `lib/features/assistant/constants/system_prompt.dart` [MODIFY]

**Work:**
1. Rewrite `fluxAiToolInstructions` to list all 19 tools with their required and optional arguments, valid `type` values, valid `period` values, and `contributionFrequency` values.
2. Ensure the instruction remains under ~400 tokens to leave room in the context window.
3. Add a note that after any tool returns data, the assistant must summarise naturally for the user in under 150 words.
4. Add undo intent instructions: when the user says "undo" or similar, do not emit a tool call — the orchestrator handles it directly.


---

## Milestone 4 — Chat UI

### Task 14: Model Onboarding Screen (Download Flow)

**Complexity:** Medium
**Depends on:** Task 5, Task 12
**Files affected:**
- `lib/features/assistant/ui/model_onboarding_screen.dart` [NEW]
- `lib/features/assistant/ui/assistant_screen.dart` [NEW]
- `lib/features/assistant/ui/assistant_settings_tile.dart` [NEW]
- `lib/features/profile/profile_screen.dart` [MODIFY — add AssistantSettingsTile]

**Work:**
1. Create `AssistantSettingsTile`: a `ListTile` in the Settings page that navigates to `AssistantScreen`. Shows a "Beta" badge.
2. Create `AssistantScreen`: a `Consumer` widget that watches `modelStatusProvider`; routes to `ModelOnboardingScreen` when model is absent, to `ChatScreen` when ready, and shows a loading indicator while the model is loading.
3. Create `ModelOnboardingScreen`:
   - Display model name, size (~529 MB), and a clear data-usage warning.
   - "Download Now" button triggers `ModelDownloadService.download()`.
   - `LinearProgressIndicator` and "X.X MB / 529 MB" label shown during download, driven by `downloadProgressProvider`.
   - "Cancel" button cancels the download.
   - On completion: transition to chat (modelStatusProvider auto-updates).
   - On error: show error message and "Retry" button.

---

### Task 15: Chat Screen & Message Widgets

**Complexity:** High
**Depends on:** Task 12, Task 14
**Files affected:**
- `lib/features/assistant/ui/chat_screen.dart` [NEW]
- `lib/features/assistant/ui/widgets/chat_message_tile.dart` [NEW]
- `lib/features/assistant/ui/widgets/streaming_message_tile.dart` [NEW]
- `lib/features/assistant/ui/widgets/chat_input_bar.dart` [NEW]
- `lib/features/assistant/ui/widgets/model_status_banner.dart` [NEW]

**Work:**
1. Create `ChatScreen`:
   - `AppBar` with title "Flux AI" and `ModelStatusBanner`.
   - `ListView.builder` displaying all messages from `assistantSessionProvider`.
   - `ScrollController` that calls `animateTo(maxScrollExtent)` in a `PostFrameCallback` after each new message.
   - `ChatInputBar` at the bottom.
   - "Clear chat" action in AppBar overflow menu.
   - `AppLifecycleObserver` that calls `conversationManager.onAppPaused()` / `onAppResumed()`.
2. Create `ChatMessageTile`:
   - User messages: right-aligned bubble with app accent color.
   - Assistant messages: left-aligned bubble with surface color.
   - System/error messages: centered italicised text in muted color.
   - Timestamps shown below each bubble.
3. Create `StreamingMessageTile`: same as assistant bubble but appends tokens live via a `StreamBuilder` on `engine.tokenStream`. Shows an animated blinking cursor at the end of the text while `isStreaming == true`.
4. Create `ChatInputBar`:
   - `TextField` with multi-line support and "Send a message" hint.
   - Send `IconButton`: enabled only when input is non-empty and `!isGenerating`.
   - Cancel `IconButton`: visible only when `isGenerating == true`; calls `cancelGeneration`.
5. Create `ModelStatusBanner`: a small chip showing "Loading…", "Ready", or "Failed — Tap to retry" based on `modelStatusProvider`.

---

### Task 16: Settings Page Integration & Navigation

**Complexity:** Low
**Depends on:** Task 14, Task 15
**Files affected:**
- `lib/features/profile/profile_screen.dart` [MODIFY]

**Work:**
1. Add `AssistantSettingsTile` to the Settings/Profile screen in an appropriate section (e.g., "Features" or "AI Tools").
2. Verify navigation pushes `AssistantScreen` correctly.
3. Add a "Remove AI Model" option inside the `AssistantScreen` AppBar overflow menu: calls `engine.unloadModel()` + `FluxAiModelStorage` cleanup + navigates back to onboarding.

---

## Milestone 5 — Proactive Alerts

### Task 17: Alert Engine Implementation

**Complexity:** High
**Depends on:** Task 7, Task 8
**Files affected:**
- `lib/features/assistant/engine/alert_engine.dart` [NEW]

**Work:**
1. Implement `AlertEngine` with constructor injecting all required services and `salaryDayOverride` (nullable int from SharedPreferences).
2. Implement `evaluateAll()` calling all 8 private evaluators in sequence.
3. Implement each evaluator:
   - `_checkCategoryBudget80`: iterate category limits; emit if spent/limit ≥ 0.8.
   - `_checkOverallBudget80`: emit if total spent/overall limit ≥ 0.8.
   - `_checkSpendingSpike`: emit if category this month > 130% of same category last month.
   - `_checkRecurringBalance`: emit if recurring due ≤5 days and balance < 2× amount.
   - `_checkCreditCardDue`: emit if bill due ≤7 days.
   - `_checkSalaryOverdue`: compute salary day via `inferSalaryDay()`; emit if today > salaryDay + 5 and no salary income this month.
   - `_checkForecastNegative`: call `getBalanceForecast`; emit if any day has `balanceBelowZero`.
   - `_checkDebtIncomeRatio`: emit if (rent + EMI) / 3-month avg income > 0.50.
4. Implement `inferSalaryDay()`: median of last 3 months' salary transaction day-of-month; manual override takes precedence.
5. Implement `shouldEmit(alertType, subject)` deduplication check via `AlertRepository`.
6. After each emit: insert `AlertRecord` into repository.
7. At start of `evaluateAll()`: purge `AlertRecord` rows older than 7 days.

---

### Task 18: WorkManager Background Task for Alerts

**Complexity:** Medium
**Depends on:** Task 17
**Files affected:**
- `lib/main.dart` [MODIFY — register callback dispatcher]
- `lib/features/assistant/alert_worker.dart` [NEW]

**Work:**
1. Create `alert_worker.dart` defining the `alertEngineTask` callback function:
   - Opens the database.
   - Constructs `AlertEngine` using service instances (not Riverpod — WorkManager runs in an isolate).
   - Calls `alertEngine.evaluateAll()`.
   - Returns `Future.value(true)`.
2. Register `callbackDispatcher` in `main.dart` via `Workmanager().initialize(callbackDispatcher)`.
3. Schedule the periodic task (24-hour period, 2-hour flex, requires battery not low) on first app launch if not already scheduled — use `Workmanager().isScheduled` check or a SharedPreferences flag.
4. Verify the task completes within 30 seconds on a seeded test database.


---

## Milestone 6 — Financial Plans

### Task 19: Plan Management via Tool Dispatcher

**Complexity:** Medium
**Depends on:** Task 8, Task 9
**Files affected:**
- `lib/features/assistant/data/tool_dispatcher.dart` [MODIFY — plan tools already wired in Task 9, verify]

**Work:**
This task verifies and completes the plan-related tool dispatch wired in Task 9:

1. Confirm `getFinancialPlans` tool returns all plans with computed fields (contribution, achievability, estimatedCompletionDate).
2. Confirm `createFinancialPlan` rejects past target dates and returns an informative error.
3. Confirm `updateFinancialPlan` recomputes achievability after each update.
4. Confirm `deleteFinancialPlan` removes the plan from the repository.
5. Implement the event budget estimation flow: when `createFinancialPlan` is called with `type: event` and no `targetAmount`, the assistant uses the LLM (via a structured prompt) to estimate a budget, presents it to the user for confirmation, and then calls `createFinancialPlan` again with the confirmed amount.
6. Verify `getAtRiskPlans()` is called during `AlertEngine.evaluateAll()` and at-risk events are included in the alert sweep.

---

### Task 20: Salary Credit Date Settings UI

**Complexity:** Low
**Depends on:** Task 17
**Files affected:**
- `lib/features/profile/profile_screen.dart` [MODIFY]
- `lib/core/services/onboarding_service.dart` or a new `lib/features/assistant/data/assistant_settings_service.dart` [MODIFY / NEW]

**Work:**
1. Add a "Salary Credit Day" setting in the Settings/Profile screen (e.g., a number picker or text field showing day 1–31).
2. Persist the selected day to SharedPreferences under key `flux_ai_salary_day_override`.
3. The `AlertEngine` reads this value at construction time; if set, it overrides the inferred median salary day.
4. Display the inferred day as the placeholder/hint text so the user can see what was auto-detected.
5. Add a "Clear override" option to return to auto-detection.

---

## Milestone 7 — Integration & Polish

### Task 21: Property-Based Tests

**Complexity:** High
**Depends on:** Tasks 7, 8, 9, 10, 11, 12
**Files affected:**
- `pubspec.yaml` [MODIFY — add fast_check dev dependency]
- `test/features/assistant/engine/context_window_manager_test.dart` [NEW]
- `test/features/assistant/engine/financial_analysis_engine_test.dart` [NEW]
- `test/features/assistant/engine/plan_manager_test.dart` [NEW]
- `test/features/assistant/engine/alert_engine_test.dart` [NEW]
- `test/features/assistant/engine/conversation_manager_test.dart` [NEW]
- `test/features/assistant/engine/tag_fuzzy_matcher_test.dart` [NEW]
- `test/features/assistant/data/tool_call_validator_test.dart` [NEW]
- `test/features/assistant/data/assistant_repository_test.dart` [NEW]

**Work:**
Implement all 29 correctness properties defined in the design document as property-based tests using `fast_check`:

- **context_window_manager_test**: Properties 1, 2, 3, 4
- **tool_call_validator_test**: Properties 5, 6, 7
- **financial_analysis_engine_test**: Properties 8, 9, 10, 11, 12, 13
- **alert_engine_test**: Properties 14, 15, 16, 17
- **plan_manager_test**: Properties 18, 19, 20
- **conversation_manager_test**: Properties 21, 23, 24, 25, 26
- **tag_fuzzy_matcher_test**: Property 22
- **assistant_repository_test**: Properties 27, 28, 29

Each test must:
- Run a minimum of 100 iterations.
- Use `MockAiEngine` to avoid real LLM calls.
- Use an in-memory SQLite database (`:memory:`) for repository tests.
- Be tagged `// Feature: spendflux-ai-assistant, Property N`.

---

### Task 22: End-to-End Integration Smoke Tests

**Complexity:** Medium
**Depends on:** Task 21
**Files affected:**
- `test/features/assistant/integration/assistant_integration_test.dart` [NEW]

**Work:**
1. **Full conversation round-trip**: Send a message → `MockAiEngine` emits a tool call JSON → `ToolDispatcher` executes → `MockAiEngine` emits summary → assert message appears in state.
2. **Undo round-trip**: Create a transaction via chat → undo → assert transaction no longer exists.
3. **Chat history survival**: Write 5 messages, dispose `AssistantSessionNotifier`, reinitialise → assert same 5 messages loaded.
4. **Tag fuzzy fallback**: `searchTransactions` with a misspelled tag name → assert `requiresTagSelection: true` in result.
5. **Download progress flow**: Mock HTTP response → assert `DownloadProgress` events emitted in order; assert file saved to expected path.
6. **Alert deduplication**: Emit the same alert twice within 1 minute → assert only one `AlertRecord` inserted.

---

### Task 23: Final Wiring & Build Verification

**Complexity:** Medium
**Depends on:** All previous tasks
**Files affected:**
- All modified files (verification pass)

**Work:**
1. Run `flutter analyze` — fix all warnings and errors.
2. Run `flutter test` — all unit and property-based tests must pass.
3. Build a debug APK (`flutter build apk --debug`) — must compile without errors.
4. Verify the Pigeon-generated Kotlin file compiles as part of the Android build.
5. Smoke-test on a physical Android device or emulator:
   - Open Settings → Flux AI → Model Onboarding shows correctly.
   - Download flow shows progress and completes (or mock with a small test file).
   - Chat screen opens; typing and sending a message works.
   - Model status banner updates correctly.
6. Clean up any `TODO`s or placeholder implementations left from earlier tasks.

---

## Dependency Graph Summary

```
Task 1 (DB migration) ─────────────────────────────────────────────────────────┐
Task 2 (Pigeon) ──────────────────────────────────────────────────────────┐    │
                                                                          │    │
Task 3 (AbstractAiEngine) ←── Task 2                                      │    │
Task 4 (Kotlin layer)     ←── Task 2                                      │    │
Task 5 (Download + Providers) ←── Task 3                                  │    │
                                                                          │    │
Task 6 (Models + Repos)   ←── Task 1                                      │    │
Task 7 (AnalysisEngine)   ←── Task 1                                      │    │
Task 8 (PlanManager)      ←── Task 6, Task 7                              │    │
Task 9 (FuzzyMatcher + Dispatcher) ←── Task 6                            │    │
                                                                          │    │
Task 10 (ContextWindowMgr) ←── Task 3                                     │    │
Task 11 (ConversationMgr)  ←── Task 3, Task 9, Task 10                    │    │
Task 12 (SessionNotifier)  ←── Task 1, Task 11                            │    │
Task 13 (System prompt)    ←── Task 9                                     │    │
                                                                          │    │
Task 14 (Onboarding UI)    ←── Task 5, Task 12                            │    │
Task 15 (Chat UI)          ←── Task 12, Task 14                           │    │
Task 16 (Settings nav)     ←── Task 14, Task 15                           │    │
                                                                          │    │
Task 17 (AlertEngine)      ←── Task 7, Task 8                             │    │
Task 18 (WorkManager)      ←── Task 17                                    │    │
                                                                          │    │
Task 19 (Plan tools verify) ←── Task 8, Task 9                            │    │
Task 20 (Salary day UI)    ←── Task 17                                    │    │
                                                                          │    │
Task 21 (PBT tests)        ←── Tasks 7–12                                 │    │
Task 22 (Integration tests) ←── Task 21                                   │    │
Task 23 (Build verify)     ←── All tasks ←────────────────────────────────┘────┘
```

## Complexity Summary

| Complexity | Tasks | Count |
|---|---|---|
| Low | 1, 13, 16, 20 | 4 |
| Medium | 2, 5, 6, 8, 9, 10, 12, 14, 18, 19, 22, 23 | 12 |
| High | 3, 4, 7, 11, 15, 17, 21 | 7 |

**Total tasks: 23**

## Recommended Implementation Order

1. Tasks 1 and 2 in parallel (no dependencies)
2. Tasks 3, 4 (depend on 2) — can be parallel with Tasks 6, 7 (depend on 1)
3. Tasks 5, 8, 9, 10 (depend on 3 or 6+7)
4. Tasks 11, 13 (depend on 9, 10)
5. Tasks 12, 17 (depend on 11 and 7+8 respectively)
6. Tasks 14, 18 (depend on 12 and 17)
7. Tasks 15, 19, 20 (depend on 14, 8+9, and 17)
8. Task 16 (depends on 14, 15)
9. Tasks 21, 22, 23 (testing and final verification)
