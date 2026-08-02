# Design Document: SpendFlux AI Assistant

## Overview

The SpendFlux AI Assistant is a fully on-device conversational finance advisor for the SpendFlux Android app. It uses a locally stored Gemma 3 1B model (via MediaPipe LLM Inference) for natural language understanding and generation, while all financial data operations, analysis, and predictions are performed by deterministic Dart services. The feature is accessed from the Settings page and provides chat, proactive alerts, financial planning, and full transaction management through natural language — all offline after a one-time model download.

The architecture separates two concerns that must never be mixed:

- **LLM Layer**: Parses natural language intent, generates conversational responses, formats results for the user.
- **Deterministic Layer**: Executes all data reads/writes, runs all financial calculations, manages state.

The LLM never has direct access to the database. All data flows through the Tool_Dispatcher, which validates and executes whitelisted operations against existing services.

---

## Architecture

### Layer Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         UI Layer                                │
│  AssistantScreen · ModelOnboardingScreen · ChatMessageWidget   │
│  StreamingMessageTile · ChatInputBar                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │ Riverpod Providers (watch/read)
┌─────────────────────▼───────────────────────────────────────────┐
│                  State / Provider Layer                         │
│  ConversationNotifier · ModelDownloadNotifier                  │
│  AssistantSessionNotifier · AlertNotifier                      │
└──────┬───────────────────────────────────────┬──────────────────┘
       │                                       │
┌──────▼──────────────┐             ┌──────────▼─────────────────┐
│   AI / LLM Layer    │             │  Deterministic Layer        │
│  AbstractAiEngine   │             │  ToolDispatcher             │
│  FluxAiEngine       │             │  FinancialAnalysisEngine    │
│  MockAiEngine       │             │  PlanManager                │
│  ContextWindowMgr   │             │  AlertEngine                │
│  ConversationMgr    │             │  TagFuzzyMatcher            │
└──────┬──────────────┘             └──────────┬─────────────────┘
       │ Pigeon Bridge                          │
┌──────▼──────────────┐             ┌──────────▼─────────────────┐
│  Native LLM Layer   │             │  Service Layer (existing)   │
│  FluxAiHostApiImpl  │             │  TransactionService         │
│  (Kotlin/MediaPipe) │             │  AccountService             │
└─────────────────────┘             │  BudgetService              │
                                    │  CategoryService            │
                                    │  TagService                 │
                                    │  CreditCardBillService      │
                                    └──────────┬─────────────────┘
                                               │
                                    ┌──────────▼─────────────────┐
                                    │  Data Layer                 │
                                    │  AppDatabase (SQLite)       │
                                    │  SharedPreferences          │
                                    └────────────────────────────┘
```

### Clean Architecture Placement

The AI layer is an adapter that lives at the same level as the existing service layer. It does not contain business rules itself — it orchestrates calls to the deterministic services. This preserves the Clean Architecture boundaries already present in the app:

- **Domain/Business logic** stays in existing services (`TransactionService`, `BudgetService`, etc.) and in the new deterministic engines (`FinancialAnalysisEngine`, `PlanManager`, `AlertEngine`).
- **AI layer** acts as a translation adapter: natural language in → tool calls out → natural language out.
- **UI layer** has no direct dependency on the AI engine's implementation; it depends only on Riverpod providers.

### Separation Between LLM and Deterministic Layers

| Responsibility | LLM Layer | Deterministic Layer |
|---|---|---|
| Parse natural language intent | ✓ | ✗ |
| Generate conversational responses | ✓ | ✗ |
| Execute data reads/writes | ✗ | ✓ |
| Calculate spending totals, forecasts | ✗ | ✓ |
| Validate tool arguments | ✗ | ✓ |
| Detect spending anomalies | ✗ | ✓ |
| Manage undo stack | ✗ | ✓ (in-memory) |
| Compress context summary | ✓ (via LLM summarisation) | ✗ |

The LLM is only invoked for two purposes: generating a response, and summarising older context. All data invariants are enforced by deterministic code.

---

## Folder Structure

```
lib/features/assistant/
├── constants/
│   ├── system_prompt.dart          [MODIFY]  — add new tool instructions for 19 tools
│   └── tool_schemas.dart           [MODIFY]  — expand whitelist to 19 tools + schemas
│
├── data/
│   ├── flux_ai_engine.dart         [MODIFY]  — implement AbstractAiEngine interface
│   ├── mock_ai_engine.dart         [NEW]     — MockAiEngine for testing
│   ├── model_storage.dart          [KEEP]    — no changes needed
│   ├── model_download_service.dart [NEW]     — HTTP download, progress, validation
│   ├── tool_dispatcher.dart        [MODIFY]  — expand to 19 tools
│   ├── plan_repository.dart        [NEW]     — SQLite CRUD for FinancialPlan
│   └── alert_repository.dart       [NEW]     — SQLite CRUD for AlertRecord
│
├── engine/
│   ├── abstract_ai_engine.dart     [NEW]     — abstract interface for AI backend
│   ├── context_window_manager.dart [NEW]     — context summary + prompt builder
│   ├── conversation_manager.dart   [NEW]     — orchestrator: message → tool → response
│   ├── financial_analysis_engine.dart [NEW]  — all deterministic financial calculations
│   ├── plan_manager.dart           [NEW]     — FinancialPlan CRUD + achievability
│   ├── alert_engine.dart           [NEW]     — alert condition evaluators
│   └── tag_fuzzy_matcher.dart      [NEW]     — fuzzy tag search
│
├── models/
│   ├── chat_message.dart           [MODIFY]  — add sessionId, persist fields
│   ├── tool_call.dart              [KEEP]    — no changes needed
│   ├── financial_plan.dart         [NEW]     — FinancialPlan model
│   ├── alert_record.dart           [NEW]     — AlertRecord model
│   └── undo_stack_entry.dart       [NEW]     — UndoStackEntry (in-memory)
│
├── pigeon/
│   └── flux_ai_api.g.dart          [GENERATED] — Pigeon output (do not edit)
│
├── preprocessing/
│   ├── amount_parser.dart          [KEEP]
│   ├── date_parser.dart            [KEEP]
│   ├── merchant_dictionary.dart    [KEEP]
│   └── transaction_extractor.dart  [KEEP]
│
├── providers/
│   └── assistant_providers.dart    [NEW]     — all Riverpod providers
│
├── ui/
│   ├── assistant_screen.dart       [NEW]     — entry: routes to onboarding or chat
│   ├── model_onboarding_screen.dart [NEW]    — download flow UI
│   ├── chat_screen.dart            [NEW]     — main chat interface
│   ├── widgets/
│   │   ├── chat_message_tile.dart  [NEW]     — user/assistant message bubble
│   │   ├── streaming_message_tile.dart [NEW] — live-updating streaming bubble
│   │   ├── chat_input_bar.dart     [NEW]     — text field + send/cancel buttons
│   │   └── model_status_banner.dart [NEW]    — loading/ready/failed status
│   └── assistant_settings_tile.dart [NEW]    — Settings page entry tile
│
└── validation/
    └── tool_call_validator.dart    [MODIFY]  — expand to validate 19 tools
```

**Files in `pigeon/` at the project root (not inside lib/):**
```
pigeon/
└── flux_ai_api.dart               [NEW]  — Pigeon definition file
```

**Android native files to create:**
```
android/app/src/main/kotlin/.../
└── FluxAiHostApiImpl.kt           [NEW]  — MediaPipe LLM Inference host implementation
```

---

## Data Models

### FinancialPlan

Represents both savings goals and event budgets, distinguished by the `type` field.

**SQLite table: `financial_plans`**

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `name` | TEXT NOT NULL | User-defined name |
| `type` | TEXT NOT NULL | `goal` or `event` |
| `target_amount` | REAL NOT NULL | Total amount needed |
| `target_date` | TEXT NOT NULL | ISO-8601 date; must be in the future |
| `priority` | TEXT | `low`, `medium`, `high` — goals only |
| `current_savings` | REAL NOT NULL DEFAULT 0 | Amount saved so far |
| `preferred_account_id` | TEXT | FK → accounts.id ON DELETE SET NULL |
| `contribution_frequency` | TEXT NOT NULL | `weekly` or `monthly` |
| `created_at` | TEXT NOT NULL | ISO-8601 timestamp |

**Dart class:**

```dart
enum PlanType { goal, event }
enum PlanPriority { low, medium, high }
enum ContributionFrequency { weekly, monthly }

class FinancialPlan {
  final String id;
  final String name;
  final PlanType type;
  final double targetAmount;
  final DateTime targetDate;
  final PlanPriority? priority;          // goals only
  final double currentSavings;
  final String? preferredAccountId;
  final ContributionFrequency contributionFrequency;
  final DateTime createdAt;

  // Computed fields (not persisted)
  double? get requiredContribution { ... }
  bool? get achievable { ... }
  DateTime? get estimatedCompletionDate { ... }
  bool get atRisk { ... }                // events: < 30 days away & underfunded
}
```

### AlertRecord

Persisted to SQLite for deduplication; the Alert_Engine queries this before emitting any alert.

**SQLite table: `alert_records`**

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `alert_type` | TEXT NOT NULL | e.g. `budget_category_80`, `salary_overdue` |
| `subject` | TEXT NOT NULL | Category name, account id, or empty string |
| `emitted_at` | TEXT NOT NULL | ISO-8601 timestamp |

**Dart class:**

```dart
class AlertRecord {
  final String id;
  final String alertType;
  final String subject;
  final DateTime emittedAt;
}
```

**Alert type constants:**

```
budget_overall_80       budget_category_80
spend_spike_category    recurring_balance_risk
credit_card_due         salary_overdue
balance_forecast_zero   debt_income_ratio
```

### AssistantMessage

Maps to the existing `ChatMessage` model but adds persistence fields.

**SQLite table: `assistant_messages`**

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `session_id` | TEXT NOT NULL | Groups messages into a session |
| `role` | TEXT NOT NULL | `user`, `assistant`, `system`, `tool` |
| `content` | TEXT NOT NULL | Message text |
| `timestamp` | TEXT NOT NULL | ISO-8601 |

Indexes: `CREATE INDEX idx_assistant_messages_session ON assistant_messages(session_id, timestamp DESC)`

System prompts, tool instructions, and Context_Summary strings are **never** inserted into this table.

**Dart class** (extends / replaces ChatMessage for persistence layer):

```dart
class AssistantMessage {
  final String id;
  final String sessionId;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  // Transient UI-only fields (not persisted)
  final bool isStreaming;
}
```

### UndoStackEntry (in-memory only)

```dart
enum UndoOperationType { create, update, delete }

class UndoStackEntry {
  final String operationId;           // UUID
  final UndoOperationType type;
  final Transaction snapshot;         // state before the operation
  final String humanDescription;      // e.g. "Added ₹500 Grocery expense"
}
```

The stack is a `List<UndoStackEntry>` capped at 10 entries, held in the `ConversationNotifier` state. It is never persisted.

### ContextSummary (in-memory only)

```dart
class ContextSummary {
  final String text;                  // max 200 tokens
  final int summarisedUpToIndex;      // index into the message list
  final DateTime generatedAt;
}
```

Held inside `ContextWindowManager`. Never persisted to SQLite or SharedPreferences.

### Changes to Existing Models

- **ChatMessage**: No structural changes. `AssistantMessage` wraps it for persistence. The `sessionId` field is added to `ChatMessage` as an optional field for runtime tracking.
- **Transaction**: No changes required. Existing model fully supports all 19 tools.

---

## Database Schema

### New Tables

```sql
-- Version 11 migration: assistant_messages
CREATE TABLE assistant_messages (
  id          TEXT PRIMARY KEY,
  session_id  TEXT NOT NULL,
  role        TEXT NOT NULL CHECK(role IN ('user','assistant','system','tool')),
  content     TEXT NOT NULL,
  timestamp   TEXT NOT NULL
);
CREATE INDEX idx_assistant_messages_session
  ON assistant_messages(session_id, timestamp DESC);

-- Version 11 migration: financial_plans
CREATE TABLE financial_plans (
  id                       TEXT PRIMARY KEY,
  name                     TEXT NOT NULL,
  type                     TEXT NOT NULL CHECK(type IN ('goal','event')),
  target_amount            REAL NOT NULL,
  target_date              TEXT NOT NULL,
  priority                 TEXT CHECK(priority IN ('low','medium','high')),
  current_savings          REAL NOT NULL DEFAULT 0,
  preferred_account_id     TEXT,
  contribution_frequency   TEXT NOT NULL CHECK(contribution_frequency IN ('weekly','monthly')),
  created_at               TEXT NOT NULL,
  FOREIGN KEY (preferred_account_id) REFERENCES accounts(id) ON DELETE SET NULL
);

-- Version 11 migration: alert_records
CREATE TABLE alert_records (
  id          TEXT PRIMARY KEY,
  alert_type  TEXT NOT NULL,
  subject     TEXT NOT NULL DEFAULT '',
  emitted_at  TEXT NOT NULL
);
CREATE INDEX idx_alert_records_type_subject
  ON alert_records(alert_type, subject, emitted_at DESC);
```

### Migration Strategy

The current `_dbVersion` is `10`. The assistant feature adds version `11`.

**In `app_database.dart`:**

1. Bump `_dbVersion` to `11`.
2. Add a new `if (oldVersion < 11)` block inside `_onUpgrade` that executes the three `CREATE TABLE` statements above.
3. Add the three tables to `_createTables()` so fresh installs also get them.
4. Add `assistant_messages` to the `clearUserData()` transaction so session data is wiped on sign-out.

No existing tables are altered. Foreign key `preferred_account_id` uses `ON DELETE SET NULL` to avoid cascade issues if an account is removed.

**Message cap enforcement**: A trigger or application-level cleanup deletes rows from `assistant_messages` when the total count exceeds 500, ordering by `timestamp ASC` (oldest first).

---

## Pigeon Bridge

### Definition File

**File:** `pigeon/flux_ai_api.dart` (project root, not inside `lib/`)

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/assistant/pigeon/flux_ai_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/app/src/main/kotlin/com/saran/spendsense/FluxAiApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.saran.spendsense'),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)

class FluxAiModelStatus {
  FluxAiModelStatus({
    required this.isLoaded,
    this.modelPath,
    this.errorMessage,
  });

  bool isLoaded;
  String? modelPath;
  String? errorMessage;
}

@HostApi()
abstract class FluxAiHostApi {
  @async
  bool loadModel(String modelPath);

  @async
  void unloadModel();

  @async
  FluxAiModelStatus getModelStatus();

  @async
  String generateResponse(String prompt, String systemPrompt);

  @async
  bool generateResponseStreaming(String prompt, String systemPrompt);

  void cancelGeneration();
}

@FlutterApi()
abstract class FluxAiFlutterApi {
  void onToken(String token);
  void onGenerationComplete(String fullResponse);
  void onGenerationError(String message);
}
```

**Generation command:**
```
dart run pigeon --input pigeon/flux_ai_api.dart
```

This outputs:
- `lib/features/assistant/pigeon/flux_ai_api.g.dart` — Dart glue (do not edit)
- `android/app/src/main/kotlin/com/saran/spendsense/FluxAiApi.g.kt` — Kotlin glue (do not edit)

---

## AI Engine Interface

### Abstract Interface

`lib/features/assistant/engine/abstract_ai_engine.dart`

```dart
abstract class AbstractAiEngine {
  /// Returns true if the model is currently loaded and ready.
  bool get isModelLoaded;

  /// Token stream — emits individual tokens during streaming generation.
  Stream<String> get tokenStream;

  /// Completion stream — emits the full response text on completion.
  Stream<String> get completeStream;

  /// Error stream — emits error messages.
  Stream<String> get errorStream;

  /// Loads model from the given path. Returns true on success.
  Future<bool> loadModel(String path);

  /// Unloads the model and releases native resources.
  Future<void> unloadModel();

  /// Begins streaming generation. Returns immediately; tokens arrive via tokenStream.
  Future<bool> generateResponseStreaming(String prompt, String systemPrompt);

  /// Cancels in-progress generation.
  void cancelGeneration();

  /// Cleans up stream controllers.
  void dispose();
}
```

No MediaPipe-specific types or methods appear in this interface. The `ToolDispatcher`, `ConversationManager`, and all UI code depend only on this abstract type.

### FluxAiEngine (MediaPipe Implementation)

`lib/features/assistant/data/flux_ai_engine.dart` — **MODIFY** existing file to implement `AbstractAiEngine`.

Key design points:
- Implements `AbstractAiEngine` and `FluxAiFlutterApi` (Pigeon callback interface).
- Holds `FluxAiHostApi` instance (Pigeon host handle).
- Streams (`tokenStream`, `completeStream`, `errorStream`) are broadcast `StreamController`s.
- `loadModel` checks `Platform.isAndroid` first; returns `false` on non-Android.
- The `@override` callbacks (`onToken`, `onGenerationComplete`, `onGenerationError`) fan out to the respective stream controllers.
- `dispose()` calls `cancelGeneration()` and closes all three stream controllers.

### MockAiEngine (for Testing)

`lib/features/assistant/data/mock_ai_engine.dart` — **NEW**

```dart
class MockAiEngine implements AbstractAiEngine {
  bool _loaded = false;

  @override bool get isModelLoaded => _loaded;

  // Controllable streams for test injection
  final _tokenCtrl = StreamController<String>.broadcast();
  final _completeCtrl = StreamController<String>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  @override Stream<String> get tokenStream => _tokenCtrl.stream;
  @override Stream<String> get completeStream => _completeCtrl.stream;
  @override Stream<String> get errorStream => _errorCtrl.stream;

  @override Future<bool> loadModel(String path) async { _loaded = true; return true; }
  @override Future<void> unloadModel() async { _loaded = false; }

  // Test helpers
  void emitTokens(List<String> tokens) { ... }
  void emitCompletion(String response) { ... }
  void emitError(String message) { ... }

  @override Future<bool> generateResponseStreaming(String prompt, String systemPrompt) async {
    // Default: echo the prompt as a single token
    _tokenCtrl.add(prompt);
    _completeCtrl.add(prompt);
    return true;
  }

  @override void cancelGeneration() {}
  @override void dispose() { _tokenCtrl.close(); _completeCtrl.close(); _errorCtrl.close(); }
}
```

### Riverpod Provider

```dart
// In assistant_providers.dart
final abstractAiEngineProvider = Provider<AbstractAiEngine>((ref) {
  final engine = FluxAiEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
```

In tests, override with:
```dart
container = ProviderContainer(
  overrides: [abstractAiEngineProvider.overrideWithValue(MockAiEngine())],
);
```

---

## Tool Dispatcher Design

### All 19 Tools

The `ToolDispatcher` is expanded from 6 to 19 whitelisted tools. Each entry shows the tool name, required arguments, optional arguments, and which service it calls.

| # | Tool Name | Required Args | Optional Args | Service(s) |
|---|---|---|---|---|
| 1 | `createTransaction` | `amount`, `type` | `category`, `account`, `dateIso`, `note`, `payee`, `tagIds`, `isRecurring`, `recurringFrequency`, `recurringEndDate` | TransactionService |
| 2 | `updateTransaction` | `id` | `amount`, `type`, `category`, `account`, `dateIso`, `note`, `payee`, `tagIds` | TransactionService |
| 3 | `deleteTransaction` | `id` | — | TransactionService |
| 4 | `searchTransactions` | — | `dateFrom`, `dateTo`, `amountMin`, `amountMax`, `category`, `accountId`, `keyword`, `tagName`, `limit` | TransactionService, TagService |
| 5 | `getSpendingSummary` | `period` | `category` | TransactionService |
| 6 | `comparePeriods` | `current`, `previous` | `category` | TransactionService |
| 7 | `getRecurringTransactions` | — | — | TransactionService |
| 8 | `createRecurringTransaction` | `amount`, `type`, `title`, `category`, `frequency`, `startDateIso` | `endDateIso`, `account`, `note` | TransactionService |
| 9 | `cancelRecurringTransaction` | `id` | — | TransactionService |
| 10 | `getBudgetStatus` | `period` | — | BudgetService, TransactionService |
| 11 | `getForecast` | `days` | — | TransactionService |
| 12 | `getFinancialPlans` | — | `type` | PlanManager |
| 13 | `createFinancialPlan` | `name`, `type`, `targetAmount`, `targetDate`, `contributionFrequency` | `priority`, `preferredAccountId`, `currentSavings` | PlanManager |
| 14 | `updateFinancialPlan` | `id` | `name`, `targetAmount`, `targetDate`, `priority`, `currentSavings`, `preferredAccountId`, `contributionFrequency` | PlanManager |
| 15 | `deleteFinancialPlan` | `id` | — | PlanManager |
| 16 | `getBalanceForecast` | — | `accountId`, `days` | FinancialAnalysisEngine |
| 17 | `getAnomalies` | — | `period` | FinancialAnalysisEngine |
| 18 | `getSavingsRate` | `period` | — | FinancialAnalysisEngine |
| 19 | `getFinancialSummary` | `period` | — | FinancialAnalysisEngine |

### Tag Fuzzy-Matching Flow for `searchTransactions`

When `tagName` is provided in `searchTransactions` arguments:

```
1. TagFuzzyMatcher.exactMatch(tagName)
   → If found: use tag id directly in query
   → If not found: continue

2. TagFuzzyMatcher.fuzzySearch(tagName, allTags, maxResults: 5)
   → Compute Levenshtein distance for each tag name
   → Return top-5 tags sorted by distance ASC

3. ToolDispatcher returns ToolResult.success with:
   {
     "requiresTagSelection": true,
     "suggestions": ["Zomato", "Swiggy Food", "Restaurant", ...],
     "message": "No tag named 'resturant' found. Did you mean one of these?"
   }

4. ConversationManager sees requiresTagSelection: true
   → Sends the suggestions to the LLM as a follow-up prompt
   → LLM presents choices to the user
   → User responds with selection
   → ConversationManager retries searchTransactions with the resolved tag name
```

### `TagFuzzyMatcher` Algorithm

```
levenshtein(a, b):
  standard dynamic programming edit distance

fuzzySearch(query, tags, maxResults):
  for each tag in tags:
    score = levenshtein(query.toLowerCase(), tag.name.toLowerCase())
  sort by score ASC
  return first maxResults where score <= floor(query.length / 2)
```

The threshold `floor(query.length / 2)` ensures only reasonably similar tags surface. A 7-character query allows up to 3 edits.

### Tool Call Schema Updates

`tool_schemas.dart` is expanded to add the 13 new tool names to the `FluxAiTools` constants set and add validation rules for each to `FluxAiToolSchemas`.

`tool_call_validator.dart` gains a `switch` case for each new tool.

---

## Context Window Manager

### Responsibilities

`ContextWindowManager` maintains the conversation history that is passed to the LLM on each inference call. It enforces:
- A **maximum active window** of the last 10 messages.
- A **Context_Summary** of at most 200 tokens representing history older than the active window.

### State

```dart
class ContextWindowManager {
  final List<ChatMessage> _allMessages;   // complete session history
  ContextSummary? _summary;               // compressed summary of old messages

  // Public API
  Future<String> buildPrompt(AbstractAiEngine engine);
  void addMessage(ChatMessage msg);
  Future<void> maybeSummarise(AbstractAiEngine engine);
  void clear();
}
```

### Prompt Construction Algorithm

```
buildPrompt():
  parts = []

  if _summary != null:
    parts.add("[CONTEXT SUMMARY]\n${_summary.text}\n[END SUMMARY]\n")

  activeWindow = last 10 of _allMessages
  for msg in activeWindow:
    role_prefix = msg.role == user ? "User" : "Assistant"
    parts.add("$role_prefix: ${msg.content}")

  return parts.join("\n")
```

The system prompt (`fluxAiSystemPrompt` + `fluxAiToolInstructions`) is passed separately as the `systemPrompt` argument to `generateResponseStreaming`. It is not included in the context window count.

### Summarisation Trigger

`maybeSummarise()` is called by `ConversationManager` after every new assistant message is appended.

```
maybeSummarise():
  if _allMessages.length <= 10:
    return   // nothing to summarise

  // Find messages not yet covered by the existing summary
  alreadySummarisedIndex = _summary?.summarisedUpToIndex ?? -1
  pendingMessages = _allMessages[0 .. (_allMessages.length - 10)]
  newToSummarise = pendingMessages.filter(index > alreadySummarisedIndex)

  if newToSummarise.isEmpty:
    return

  summaryPrompt = buildSummaryPrompt(newToSummarise, existingSummary: _summary?.text)
  // Blocking LLM call (non-streaming)
  newSummaryText = await engine.generateResponse(summaryPrompt, summarisationSystemPrompt)
  // Truncate to ~200 tokens (~150 words heuristic)
  _summary = ContextSummary(
    text: truncateToTokenLimit(newSummaryText, 200),
    summarisedUpToIndex: pendingMessages.last.index,
    generatedAt: DateTime.now(),
  )
```

The `summarisationSystemPrompt` instructs the LLM: "Summarise the following conversation excerpt into a single paragraph of at most 150 words, preserving key financial facts, amounts, and decisions."

Summarisation uses `generateResponse` (non-streaming) to avoid updating the chat UI.

---

## Financial Analysis Engine

### Class Design

`lib/features/assistant/engine/financial_analysis_engine.dart`

```dart
class FinancialAnalysisEngine {
  FinancialAnalysisEngine({
    required this.transactionService,
    required this.accountService,
    required this.budgetService,
    required this.creditCardBillService,
    PeriodResolver? periodResolver,
  });

  // Public API called by ToolDispatcher
  Future<SpendingSummaryResult> getSpendingSummary({required String period, String? category});
  Future<PeriodComparisonResult> comparePeriods({required String current, required String previous, String? category});
  Future<double> getSavingsRate({required String period});
  Future<List<AnomalyResult>> getAnomalies({String period = 'this_month'});
  Future<FinancialSummaryResult> getFinancialSummary({required String period});
  Future<BalanceForecast> getBalanceForecast({String? accountId, int days = 30});
  double estimateMonthlySurplus({int monthsBack = 3});
  List<SubscriptionCandidate> detectSubscriptions();
  double inferAverageMonthlySalary({int monthsBack = 3});
}
```

### Spending Anomaly Detection Algorithm

Called by `getAnomalies()`:

```
For each expense category:
  1. Compute this_month_total = sum of expenses in category for current month to date.
  2. Compute 3-month rolling average:
       avg = mean(expensesForCategory(m-3), expensesForCategory(m-2), expensesForCategory(m-1))
  3. If this_month_total > 2.0 * avg AND avg > 0:
       emit AnomalyResult(category, thisMonth: this_month_total, threeMonthAvg: avg,
                          multiplier: this_month_total / avg)
  4. If avg == 0 and this_month_total > 0:
       emit AnomalyResult(..., multiplier: null, note: "No prior history")

Return list sorted by multiplier DESC.
```

### Savings Rate Calculation

```
getSavingsRate(period):
  range = PeriodResolver.resolve(period)
  income  = sum of isIncome transactions in range
  expenses = sum of isExpense transactions in range
  if income == 0: return 0.0
  return max(0.0, ((income - expenses) / income) * 100)
```

### Subscription Detection Logic

```
detectSubscriptions():
  candidates = []
  recurring = transactionService.getRecurringTemplates()
     .where(cat IN [entertainment, utilities, bills])
  candidates.addAll(recurring.map → SubscriptionCandidate(source: recurring))

  // Pattern-based: same title + amount (±5%) appearing in 3+ consecutive months
  For each unique (title, category) pair in isExpense transactions:
    monthlyGroups = group by (year, month)
    consecutive = longestConsecutiveMonthRun(monthlyGroups)
    if consecutive.length >= 3:
      amountVariance = stddev(consecutive.amounts) / mean(consecutive.amounts)
      if amountVariance <= 0.05:
        candidates.add(SubscriptionCandidate(source: pattern, months: consecutive))

  return candidates.deduplicated()
```

### Balance Forecast Algorithm

```
getBalanceForecast(accountId, days):
  // 1. Starting balance
  accounts = accountId != null
    ? [accountService.getById(accountId)]
    : accountService.all.where(type != creditCard)
  startBalance = sum(accounts.map.balance)

  // 2. Build day-by-day ledger
  today = DateTime.now().startOfDay
  forecast = List<DayForecast>.generate(days, (i) => DayForecast(date: today + i days))

  // 3. Overlay recurring expenses
  for each recurring expense template:
    nextDate = computeNextOccurrence(template, today)
    while nextDate < today + days:
      forecast[dayIndex(nextDate)].deductions.add(template)
      nextDate = nextDate + template.frequency

  // 4. Overlay recurring income
  // (same logic, adds to credits)

  // 5. Overlay credit card bills (due within window)
  for each unpaid CreditCardBill:
    if bill.billDate within window:
      forecast[dayIndex(bill.billDate)].deductions.add(bill)

  // 6. Overlay active EMI monthly amounts
  for each isEmi transaction:
    nextEmiDate = computeNextEmiDate(tx, today)
    if nextEmiDate within window:
      forecast[dayIndex(nextEmiDate)].deductions.add(tx)

  // 7. Overlay FinancialPlan contributions
  for each active FinancialPlan:
    nextContrib = computeNextContribDate(plan, today)
    if nextContrib within window:
      forecast[dayIndex(nextContrib)].deductions.add(plan.requiredContribution)

  // 8. Compute running balance
  running = startBalance
  for each day in forecast:
    running += day.credits - day.deductions
    day.predictedBalance = running
    day.balanceBelowZero = running < 0

  // 9. Confidence level
  historyMonths = countMonthsWithTransactions()
  confidence = historyMonths >= 3 ? (80..100)
              : historyMonths >= 1 ? (50..79)
              : (0..49)

  return BalanceForecast(days: forecast, confidence: confidence)
```

---

## Plan Manager

### Class Design

`lib/features/assistant/engine/plan_manager.dart`

```dart
class PlanManager {
  PlanManager({required this.planRepository, required this.analysisEngine});

  final PlanRepository planRepository;
  final FinancialAnalysisEngine analysisEngine;

  Future<List<FinancialPlan>> getPlans({PlanType? type});
  Future<FinancialPlan> createPlan(FinancialPlan plan);   // validates targetDate
  Future<FinancialPlan> updatePlan(FinancialPlan plan);
  Future<void> deletePlan(String id);
  List<FinancialPlan> getAtRiskPlans();                   // used by AlertEngine
}
```

### Achievability Algorithm

Called after create or update, and when `getFinancialPlans` is called:

```
assessAchievability(plan):
  remainingPeriods = countPeriods(today, plan.targetDate, plan.contributionFrequency)
  if remainingPeriods <= 0:
    return AchievabilityResult(achievable: false, reason: 'Target date is in the past or today')

  required = (plan.targetAmount - plan.currentSavings) / remainingPeriods
  plan.requiredContribution = required

  monthlySurplus = analysisEngine.estimateMonthlySurplus(monthsBack: 3)
  effectiveSurplus = plan.contributionFrequency == weekly
    ? monthlySurplus / 4.33
    : monthlySurplus

  if required <= 0:
    plan.achievable = true   // already fully funded
    return

  plan.achievable = (required <= effectiveSurplus)

  if !plan.achievable:
    // Suggestion 1: extended date at current surplus
    extendedPeriods = (plan.targetAmount - plan.currentSavings) / max(effectiveSurplus, 1)
    suggestedDate = today + extendedPeriods periods

    // Suggestion 2: reduced target achievable by targetDate
    reducedTarget = plan.currentSavings + (effectiveSurplus * remainingPeriods)

    plan.suggestions = [
      'You could reach ₹${plan.targetAmount} by ${formatDate(suggestedDate)} at your current surplus.',
      'Or reduce your target to ₹${reducedTarget} to meet the ${formatDate(plan.targetDate)} date.',
    ]
```

### Savings_Schedule Computation

```
computeSavingsSchedule(plan):
  schedule = []
  date = today (or next contribution date)
  remaining = plan.targetAmount - plan.currentSavings
  contribution = plan.requiredContribution

  while remaining > 0 and date <= plan.targetDate:
    amount = min(contribution, remaining)
    schedule.add(ScheduleEntry(date: date, amount: amount, cumulativeTotal: accumulated))
    remaining -= amount
    date = date + (plan.contributionFrequency == weekly ? 7 days : 1 month)

  return schedule
```

---

## Alert Engine

### All Alert Condition Evaluators

`lib/features/assistant/engine/alert_engine.dart`

```dart
class AlertEngine {
  AlertEngine({
    required this.transactionService,
    required this.budgetService,
    required this.accountService,
    required this.creditCardBillService,
    required this.planManager,
    required this.analysisEngine,
    required this.alertRepository,
    required this.notificationService,
    this.salaryDayOverride,           // from SharedPreferences if manually set
  });

  Future<void> evaluateAll();
}
```

Each evaluator is a private method called from `evaluateAll()`:

| Method | Alert Type | Condition |
|---|---|---|
| `_checkCategoryBudget80` | `budget_category_80` | category spending ≥ 80% of category limit |
| `_checkOverallBudget80` | `budget_overall_80` | total spending ≥ 80% of overall limit |
| `_checkSpendingSpike` | `spend_spike_category` | this month > 130% of same month last year or last month |
| `_checkRecurringBalance` | `recurring_balance_risk` | recurring due in ≤5 days & balance < 2× expense |
| `_checkCreditCardDue` | `credit_card_due` | bill due in ≤7 days |
| `_checkSalaryOverdue` | `salary_overdue` | no salary income this month & salary day passed 5+ days ago |
| `_checkForecastNegative` | `balance_forecast_zero` | forecast predicts negative balance within 30 days |
| `_checkDebtIncomeRatio` | `debt_income_ratio` | (rent + EMI) / 3-month avg monthly income > 50% |

### Salary Date Inference Algorithm

```
inferSalaryDay():
  // If user has manually set a day in Settings, use that
  if salaryDayOverride != null: return salaryDayOverride

  // Look at last 3 months of salary-category income transactions
  salaryTx = transactionService.allTransactions
    .where(category == salary && isIncome)
    .sorted(date DESC)
    .take(3 months worth)

  if salaryTx.isEmpty: return null

  days = salaryTx.map(tx.date.day)
  // Use median to be robust against outliers (e.g., weekend shift)
  sortedDays = days.sorted()
  medianDay = sortedDays[sortedDays.length / 2]
  return medianDay
```

### WorkManager Integration

The daily evaluation is scheduled as a WorkManager `PeriodicWorkRequest`:

```
Task name:      "flux_ai_alert_evaluation"
Period:         24 hours
Flex interval:  2 hours (to allow OS scheduling)
Constraints:    requires battery not low
Dart callback:  "alertEngineTask"
Timeout:        30 seconds
```

The `callbackDispatcher` (registered in `main.dart`) handles `"alertEngineTask"` by:
1. Calling `AppDatabase.instance.database` to ensure DB is open.
2. Constructing `AlertEngine` with all required services.
3. Calling `alertEngine.evaluateAll()`.
4. Returning `Future.value(true)` to signal success.

### Deduplication Logic

Before emitting any alert, `AlertEngine` checks:

```
shouldEmit(alertType, subject):
  recent = alertRepository.findRecentAlert(
    alertType: alertType,
    subject: subject,
    since: DateTime.now() - 24 hours
  )
  return recent == null
```

After emitting:
```
alertRepository.insert(AlertRecord(
  id: uuid.v4(),
  alertType: alertType,
  subject: subject,
  emittedAt: DateTime.now(),
))
```

Old `AlertRecord` rows older than 7 days are purged on each `evaluateAll()` call to prevent unbounded growth.

---

## Conversation Manager / Orchestrator

### End-to-End Message Flow

`lib/features/assistant/engine/conversation_manager.dart`

```
User submits message
  │
  ▼
ConversationManager.handleUserMessage(text)
  │
  ├─ 1. Append user ChatMessage to session
  ├─ 2. Run TransactionExtractor if message looks like transaction creation
  │      └─ If confidence < 0.85 on any field: emit clarificationQuestion, STOP
  │
  ├─ 3. Build prompt via ContextWindowManager.buildPrompt()
  │
  ├─ 4. Call engine.generateResponseStreaming(prompt, systemPrompt)
  │      └─ Append streaming ChatMessage (isStreaming: true) to session
  │
  ├─ 5. Listen for completeStream
  │
  └─ On completion:
       ├─ 6. ToolCallValidator.tryParse(fullResponse)
       │
       ├─ If valid ToolCall found:
       │    ├─ a. ToolCallValidator.validate(call)
       │    │      └─ If invalid: append error message, STOP
       │    ├─ b. ToolDispatcher.dispatch(call)
       │    ├─ c. If mutating tool (create/update/delete): push UndoStackEntry
       │    ├─ d. Build re-prompt:
       │    │      "[TOOL RESULT]\n${toolResult.toJson()}\n[END TOOL RESULT]"
       │    └─ e. Re-call generateResponseStreaming with updated context
       │           (the tool result is appended as a 'tool' role message)
       │
       ├─ If no ToolCall but question requires data (up to 2 retries):
       │    └─ Re-prompt with reinforced tool instruction:
       │         "You must respond with a tool call JSON to answer this question."
       │
       └─ Final response: mark message isStreaming: false
                         persist to assistant_messages table
                         call ContextWindowManager.maybeSummarise()
```

### Tool Call Detection and Re-Prompt Loop

```dart
int _toolRetryCount = 0;
static const _maxRetries = 2;

Future<void> _processResponse(String fullResponse) async {
  final toolCall = _validator.tryParse(fullResponse);

  if (toolCall != null) {
    _toolRetryCount = 0;
    final validation = _validator.validate(toolCall);
    if (!validation.isValid) {
      _emitSystemMessage('Tool error: ${validation.errors.join(', ')}');
      return;
    }
    final result = await _dispatcher.dispatch(toolCall);
    _maybePushUndo(toolCall, result);
    await _rePromptWithResult(result);
  } else if (_responseNeedsData(fullResponse) && _toolRetryCount < _maxRetries) {
    _toolRetryCount++;
    await _rePromptWithReinforcement();
  } else {
    _toolRetryCount = 0;
    _finaliseResponse(fullResponse);
  }
}
```

The `_responseNeedsData` heuristic checks if the response contains hedging phrases like "I don't have access", "I can't tell", "you would need to check" which indicate the LLM avoided calling a tool when it should have.

### Undo Stack Management

```dart
void _maybePushUndo(ToolCall call, ToolResult result) {
  if (!result.ok) return;
  if (call.tool == FluxAiTools.createTransaction) {
    final txId = result.result!['transactionId'] as String;
    final tx = transactionService.getById(txId)!;
    _pushUndo(UndoStackEntry(
      operationId: uuid.v4(),
      type: UndoOperationType.create,
      snapshot: tx,
      humanDescription: result.result!['message'] as String,
    ));
  } else if (call.tool == FluxAiTools.updateTransaction) {
    // snapshot captured BEFORE dispatch
  } else if (call.tool == FluxAiTools.deleteTransaction) {
    // snapshot captured BEFORE dispatch
  }
}

void _pushUndo(UndoStackEntry entry) {
  if (_undoStack.length >= 10) {
    _undoStack.removeAt(0); // discard oldest
  }
  _undoStack.add(entry);
}

Future<void> handleUndo() async {
  if (_undoStack.isEmpty) {
    _emitSystemMessage('No operations to undo in this session.');
    return;
  }
  final entry = _undoStack.removeLast();
  await _reverseOperation(entry);
  _emitSystemMessage('Undone: ${entry.humanDescription}');
}

Future<void> handleUndoAll() async {
  final count = _undoStack.length;
  while (_undoStack.isNotEmpty) {
    await _reverseOperation(_undoStack.removeLast());
  }
  _emitSystemMessage('Reversed $count operation${count == 1 ? '' : 's'}.');
}
```

### Error Handling and Retry Logic

- **Generation errors** (`errorStream`): Emit a system message, re-enable input.
- **Tool dispatch failures**: `ToolResult.failure` is shown as a system message; no undo entry is pushed.
- **App backgrounded during generation**: `cancelGeneration()` is called from `AppLifecycleState.paused` listener. On foreground resume, a "Generation was cancelled" system message is shown.
- **Model not loaded**: `ConversationManager` checks `engine.isModelLoaded` before any call; emits a user-facing error if false.

---

## Model Download Service

### Class Design

`lib/features/assistant/data/model_download_service.dart`

```dart
class DownloadProgress {
  final int bytesDownloaded;
  final int totalBytes;
  final double percentage;         // 0.0 – 1.0
  final bool isComplete;
  final String? error;
}

class ModelDownloadService {
  static const _modelUrl =
    'https://storage.googleapis.com/mediapipe-models/llm_inference/gemma-3n-e2b-it-int4/float32/1/gemma-3n-e2b-it-int4.task';
  static const _expectedMinSizeBytes = 500 * 1024 * 1024; // 500 MB sanity check

  final StreamController<DownloadProgress> _progressController;
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  Future<String?> download();   // returns final path or null on failure
  Future<void> cancel();
  void dispose();
}
```

### Download Flow

```
download():
  1. Determine destination path via FluxAiModelStorage.getExpectedModelPath()
  2. Open HTTP GET request (dart:io HttpClient)
  3. Listen to response.contentLength for totalBytes
  4. Pipe response stream to File sink, tracking bytesDownloaded
  5. Emit DownloadProgress on each chunk (throttled: emit every 512 KB)
  6. On complete:
     a. Validate: file.length >= _expectedMinSizeBytes
     b. If invalid: delete partial file, emit error
     c. If valid: await FluxAiModelStorage.saveModelPath(destPath)
                  emit DownloadProgress(isComplete: true)
                  return destPath
  7. On HttpException / SocketException:
     a. Delete partial file
     b. Emit DownloadProgress(error: message)
     c. Return null
```

### File Validation

After download completes:
1. Check file exists.
2. Check `file.lengthSync() >= _expectedMinSizeBytes` (guard against truncated downloads).
3. No hash verification at this stage (the model file changes with MediaPipe updates; hash would need to be bundled separately and is out of scope).

### SharedPreferences Persistence

`FluxAiModelStorage.saveModelPath(path)` stores the path under key `flux_ai_model_path`. On every cold start, `ModelDownloadNotifier` reads this and attempts `engine.loadModel(path)`.

---

## Chat UI Design

### Screen Structure

The assistant is accessed from the Settings page via an `AssistantSettingsTile`. Tapping it navigates to `AssistantScreen`, which routes based on model availability:

```
Settings Page
  └─ AssistantSettingsTile → Navigator.push(AssistantScreen)
       ├─ modelAvailable == false → ModelOnboardingScreen
       └─ modelAvailable == true  → ChatScreen
```

### Widget Hierarchy

```
AssistantScreen
├── Consumer (watches modelStatusProvider)
│   ├── ModelOnboardingScreen          [when model not available]
│   │   ├── Text: model name + size warning
│   │   ├── LinearProgressIndicator    [shown during download]
│   │   ├── ElevatedButton "Download Now"
│   │   └── TextButton "Cancel"
│   └── ChatScreen                     [when model available]
│       ├── AppBar
│       │   ├── title "Flux AI"
│       │   └── ModelStatusBanner       [loading/ready/failed chip]
│       ├── Expanded
│       │   └── ListView.builder
│       │       └── ChatMessageTile     [for each message]
│       │           ├── UserMessageBubble    [role == user]
│       │           └── AssistantMessageBubble
│       │               └── StreamingMessageTile [isStreaming == true]
│       └── ChatInputBar
│           ├── TextField
│           ├── IconButton Send         [enabled when not streaming]
│           └── IconButton Cancel       [visible while streaming]
```

### State Management with Riverpod

All state is managed through `AssistantSessionNotifier` (a `StateNotifier`):

```dart
class AssistantSessionState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoaded;
  final ModelLoadStatus modelStatus;
  final List<UndoStackEntry> undoStack;
  final String sessionId;
}

class AssistantSessionNotifier extends StateNotifier<AssistantSessionState> {
  // Injected via Riverpod ref
  final ConversationManager _conversationManager;

  Future<void> sendMessage(String text);
  Future<void> undo();
  Future<void> undoAll();
  void cancelGeneration();
  Future<void> clearChat();
}
```

### Streaming Message Rendering

When a streaming message is active:
1. `isStreaming == true` on the `ChatMessage`.
2. `StreamingMessageTile` subscribes to `engine.tokenStream` via a `StreamBuilder`.
3. Each token is appended to a local `StringBuffer` and `setState` is called — updates within 16ms per frame.
4. An animated blinking cursor (`_CursorWidget`) is shown after the last character.
5. When `isStreaming` becomes `false` (set on `completeStream`), the cursor widget is removed and the final text is rendered as static text.

The auto-scroll is implemented by a `ScrollController` whose `animateTo(maxScrollExtent)` is called in a `PostFrameCallback` every time a new message is appended to the list.

---

## Riverpod Providers

All providers live in `lib/features/assistant/providers/assistant_providers.dart`.

```dart
// ── Infrastructure ────────────────────────────────────────────────────────

/// The concrete AI engine (swappable with MockAiEngine in tests)
final abstractAiEngineProvider = Provider<AbstractAiEngine>((ref) {
  final engine = FluxAiEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Model storage helper (static methods, no state)
final modelStorageProvider = Provider<FluxAiModelStorage>((_) => FluxAiModelStorage());

/// Model download service
final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final svc = ModelDownloadService();
  ref.onDispose(svc.dispose);
  return svc;
});

// ── Database repositories ─────────────────────────────────────────────────

final planRepositoryProvider = Provider<PlanRepository>((ref) => PlanRepository());

final alertRepositoryProvider = Provider<AlertRepository>((ref) => AlertRepository());

// ── Analysis engines ──────────────────────────────────────────────────────

final financialAnalysisEngineProvider = Provider<FinancialAnalysisEngine>((ref) {
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

final alertEngineProvider = Provider<AlertEngine>((ref) {
  return AlertEngine(
    transactionService: ref.watch(transactionServiceProvider),
    budgetService: ref.watch(budgetServiceProvider),
    accountService: ref.watch(accountServiceProvider),
    creditCardBillService: ref.watch(creditCardBillServiceProvider),
    planManager: ref.watch(planManagerProvider),
    analysisEngine: ref.watch(financialAnalysisEngineProvider),
    alertRepository: ref.watch(alertRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final tagFuzzyMatcherProvider = Provider<TagFuzzyMatcher>((ref) {
  return TagFuzzyMatcher(tagService: ref.watch(tagServiceProvider));
});

// ── Tool / Conversation layer ─────────────────────────────────────────────

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

final contextWindowManagerProvider = Provider<ContextWindowManager>((ref) {
  return ContextWindowManager();
});

final conversationManagerProvider = Provider<ConversationManager>((ref) {
  return ConversationManager(
    engine: ref.watch(abstractAiEngineProvider),
    dispatcher: ref.watch(toolDispatcherProvider),
    contextManager: ref.watch(contextWindowManagerProvider),
    transactionService: ref.watch(transactionServiceProvider),
  );
});

// ── UI state ──────────────────────────────────────────────────────────────

/// Download progress stream (0.0–1.0)
final downloadProgressProvider = StreamProvider<DownloadProgress>((ref) {
  return ref.watch(modelDownloadServiceProvider).progressStream;
});

/// Model availability and load status
final modelStatusProvider = FutureProvider<ModelLoadStatus>((ref) async {
  final available = await FluxAiModelStorage.isModelAvailable();
  if (!available) return ModelLoadStatus.notDownloaded;
  final engine = ref.watch(abstractAiEngineProvider);
  if (engine.isModelLoaded) return ModelLoadStatus.ready;
  return ModelLoadStatus.loading;
});

/// Main chat session state
final assistantSessionProvider =
    StateNotifierProvider<AssistantSessionNotifier, AssistantSessionState>((ref) {
  return AssistantSessionNotifier(
    conversationManager: ref.watch(conversationManagerProvider),
    engine: ref.watch(abstractAiEngineProvider),
  );
});
```

**Provider dependency chain:**
```
abstractAiEngineProvider
  ↓
conversationManagerProvider ← toolDispatcherProvider ← financialAnalysisEngineProvider
  ↓                                                   ← planManagerProvider
assistantSessionProvider                              ← tagFuzzyMatcherProvider
```

Note: `transactionServiceProvider`, `accountServiceProvider`, etc. are assumed to be existing providers already defined elsewhere in the app (e.g., in a core providers file). If not, they are simple `ChangeNotifierProvider`s wrapping the existing `ChangeNotifier` services.

---

## Security and Privacy

### Data Flow Boundaries

All financial data, chat history, and analysis results remain on the device. The boundaries are:

```
Device boundary:
  ┌─ App private storage ─────────────────────────────────────────┐
  │  SQLite DB (spendflux.db)     — transactions, budgets, etc.   │
  │  SQLite DB (spendflux.db)     — assistant_messages            │
  │  SQLite DB (spendflux.db)     — financial_plans, alert_records│
  │  App documents dir            — Gemma model file (~529 MB)    │
  │  SharedPreferences            — model path, salary day setting│
  └───────────────────────────────────────────────────────────────┘

No data crosses this boundary during inference or analysis.
```

### Network Access Scope

The only permitted outbound network operation is the one-time model download from Google AI Edge servers. This is:
- Initiated explicitly by the user tapping "Download Now".
- A plain HTTPS GET request to a public model distribution URL.
- No user data, financial data, or device identifiers are included in the request.

After the model file is stored locally, the app requires no network access for any assistant functionality. All inference runs on-device via the MediaPipe LLM Inference API.

### Permissions

- `INTERNET` permission is already present (used for Google Sign-In and backup). No new permissions are required.
- The model file is stored in `getApplicationDocumentsDirectory()` which is the app's private storage — not accessible to other apps.
- The `assistant_messages` table is in the same SQLite database as all other SpendFlux data and is subject to the same access controls.

### LLM Isolation

The LLM (Gemma model) operates inside the Native_LLM_Layer. It:
- Has no access to `Context` objects, file system, or network.
- Only receives text (the prompt string) and emits text (tokens/full response).
- Cannot make function calls on its own; all tool calls are parsed from its text output by deterministic Dart code.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection (Redundancy Analysis)

Before listing properties, the following consolidations are applied:

- Req 7.2 (spending summary structure) and Req 7.8 (monthly surplus = income - expenses) are combined — the net balance invariant in 7.2 already covers 7.8.
- Req 9.2 (category budget 80%) and Req 9.3 (overall budget 80%) share the same threshold shape and are combined into one "budget threshold" property.
- Req 7.5 (anomaly detection threshold) and Req 7.10 (subscription detection) are distinct enough to keep separate.
- Req 12.2 (undo reverses operation) and Req 12.7 (undo all reverses in order) are kept as distinct properties since the ordering guarantee of undoAll is a different invariant from single-step reversal.
- Req 15.1 (message round-trip) subsumes a simpler "messages are stored" check — kept as a single round-trip property.
- Req 7.3 (comparePeriods arithmetic) and Req 7.7 (forecast arithmetic) are pure formulas — kept as explicit arithmetic properties.

---

### Property 1: Chat Message Display Order

*For any* list of ChatMessage objects with distinct timestamps, the display order in the chat screen should match ascending chronological order (oldest first).

**Validates: Requirement 4.2**

---

### Property 2: Context Window Active Size

*For any* conversation of N messages where N > 10, the active window passed to the LLM should contain exactly the last 10 messages, and the remaining N–10 messages should be represented only in the Context_Summary (if it exists).

**Validates: Requirements 5.1, 5.2**

---

### Property 3: Prompt Structure Ordering

*For any* non-null Context_Summary and any set of active messages, the string produced by `ContextWindowManager.buildPrompt()` should contain the summary text before the content of any active message.

**Validates: Requirement 5.3**

---

### Property 4: Context Summary Token Limit

*For any* input conversation excerpt of arbitrary length, the Context_Summary text produced by `ContextWindowManager` after truncation should contain no more than 200 tokens (approximated as ≤150 words using whitespace splitting).

**Validates: Requirement 5.4**

---

### Property 5: Tool Call Parser Robustness

*For any* string (arbitrary bytes, valid JSON, partial JSON, JSON embedded in natural language prose), `ToolCallValidator.tryParse()` should never throw an exception, and should return a non-null `ToolCall` if and only if the string contains a well-formed JSON object with a `"tool"` key.

**Validates: Requirement 6.1**

---

### Property 6: Tool Whitelist Enforcement

*For any* tool name string, `ToolCallValidator.validate()` should return `isValid: false` if and only if the tool name is not in the `FluxAiTools.all` constant set.

**Validates: Requirements 6.2, 6.3**

---

### Property 7: Required Argument Validation Completeness

*For any* tool in the whitelist and any argument map with at least one required field removed, `ToolCallValidator.validate()` should return `isValid: false` and the `errors` list should name each missing field.

**Validates: Requirement 6.4**

---

### Property 8: Spending Summary Internal Consistency

*For any* set of transactions and date range, the `SpendingSummaryResult` returned by `FinancialAnalysisEngine.getSpendingSummary()` must satisfy: (1) the sum of all per-category expense totals equals `totalExpenses`, and (2) `totalIncome - totalExpenses == netBalance`.

**Validates: Requirements 7.1, 7.2**

---

### Property 9: Period Comparison Arithmetic

*For any* two period summaries with expense totals A (current) and B (previous), the `PeriodComparisonResult` must satisfy: `expenseDelta == A - B` and, when B > 0, `expenseDeltaPercent == ((A - B) / B) × 100`. When B == 0 and A > 0, the percentage should be treated as undefined (not cause a division error).

**Validates: Requirement 7.3**

---

### Property 10: Savings Rate Formula

*For any* income value I ≥ 0 and expenses value E ≥ 0, `FinancialAnalysisEngine.getSavingsRate()` must return `max(0.0, ((I - E) / I) × 100)` when I > 0, and exactly 0.0 when I == 0.

**Validates: Requirement 7.4**

---

### Property 11: Spending Anomaly Threshold Correctness

*For any* category and 3-month historical average `avg` and current month total `current`, `getAnomalies()` must include that category in its results if and only if `avg > 0 AND current > 2 × avg`.

**Validates: Requirement 7.5**

---

### Property 12: Yearly Summary Aggregation

*For any* 12-month transaction history, `getFinancialSummary(period: "this_year")` must return exactly 12 monthly entries and the total yearly income and expenses must equal the respective sums of all 12 monthly values.

**Validates: Requirement 7.9**

---

### Property 13: Balance Forecast Running Total Invariant

*For any* starting balance B and sequence of day-wise credit and deduction amounts, the `predictedBalance` on day D in the `BalanceForecast` must equal `B + sum(credits[0..D]) - sum(deductions[0..D])`, and `balanceBelowZero` must be `true` if and only if `predictedBalance < 0`.

**Validates: Requirements 8.1, 8.8**

---

### Property 14: Budget Alert Threshold

*For any* (spent, limit) pair where `limit > 0`, the budget alert evaluator must trigger an alert if and only if `spent / limit >= 0.8`. This holds for both overall and per-category limits.

**Validates: Requirements 9.2, 9.3**

---

### Property 15: Spending Spike Alert Threshold

*For any* category with current-month total `C` and prior-period total `P` where `P > 0`, the spending spike evaluator must emit an alert if and only if `C / P > 1.30`.

**Validates: Requirement 9.4**

---

### Property 16: Salary Day Inference from Median

*For any* list of one or more historical salary transaction day-of-month values, `inferSalaryDay()` must return the statistical median of those values. When a manual override is set, the result must equal the override value regardless of transaction history.

**Validates: Requirement 9.8**

---

### Property 17: Alert Deduplication Within 24 Hours

*For any* sequence of alert evaluations that would trigger the same (alertType, subject) pair more than once within a 24-hour window, the `alert_records` table and notification dispatch must show exactly one new entry for that pair during that window.

**Validates: Requirement 9.11**

---

### Property 18: Plan Contribution Formula

*For any* `FinancialPlan` with `remainingPeriods > 0`, the computed `requiredContribution` must equal `(targetAmount - currentSavings) / remainingPeriods`. When `remainingPeriods == 0`, the plan must be rejected with an error.

**Validates: Requirement 10.2**

---

### Property 19: Plan Achievability Binary Condition

*For any* (requiredContribution, effectiveMonthly Surplus) pair, `achievable` must be `true` if and only if `requiredContribution <= effectiveMonthlySurplus`. When `achievable == false`, the suggestions list must be non-empty.

**Validates: Requirements 10.3, 10.4**

---

### Property 20: At-Risk Event Detection

*For any* `FinancialPlan` of type `event`, `atRisk` must be `true` if and only if `daysUntilTargetDate < 30 AND currentSavings < targetAmount`.

**Validates: Requirement 10.7**

---

### Property 21: Clarification Threshold Enforcement

*For any* `ExtractedTransaction` result where at least one of `amountConfidence`, `typeConfidence`, `categoryConfidence`, or `dateConfidence` is below 0.85, the `ConversationManager` must not construct a `createTransaction` tool call but must instead emit a clarifying question.

**Validates: Requirement 11.2**

---

### Property 22: Tag Fuzzy Match Priority

*For any* query string Q and tag list L where at least one tag has name exactly equal to Q (case-insensitive), `TagFuzzyMatcher` must return that exact-match tag as the first result. When no exact match exists, all returned suggestions must have a Levenshtein distance from Q no greater than `floor(Q.length / 2)`.

**Validates: Requirement 11.7**

---

### Property 23: Transaction Split Conservation

*For any* transaction with amount A and any set of split portions `{p1, p2, ..., pN}` where `sum(pi) == A`, after executing the split the original transaction must not exist in the database and N new transactions must exist whose amounts sum to A.

**Validates: Requirement 11.8**

---

### Property 24: Undo Reversal Round-Trip

*For any* mutating tool call (create, update, delete) that succeeds and pushes an `UndoStackEntry`, calling undo once must return the affected transaction to its state immediately before the tool call was made: created transactions must be absent, deleted transactions must be present and equal to their snapshot, and updated transactions must match their pre-update snapshot.

**Validates: Requirement 12.2**

---

### Property 25: Undo Stack Size Cap

*For any* sequence of N > 10 mutating tool calls within a single chat session, the `UndoStack` must contain exactly 10 entries, and the 10 entries must correspond to the N most recent operations (the oldest N-10 are discarded).

**Validates: Requirement 12.5**

---

### Property 26: Undo All Reverse-Chronological Order

*For any* undo stack of N entries, calling `handleUndoAll()` must reverse all N operations in strictly reverse-insertion order (most recent first) and report that N operations were reversed.

**Validates: Requirement 12.7**

---

### Property 27: Message Persistence Round-Trip

*For any* `AssistantMessage` with role `user` or `assistant`, persisting it to the `assistant_messages` table and then reloading by its `id` must produce a structurally equivalent message (same id, sessionId, role, content, timestamp).

**Validates: Requirement 15.1**

---

### Property 28: Message Table Size Cap

*For any* sequence of insertions totalling more than 500 messages into the `assistant_messages` table, the row count after the cap enforcement step must be exactly 500, and the oldest messages (lowest timestamp) must have been removed first.

**Validates: Requirement 15.4**

---

### Property 29: System Content Exclusion from Persistence

*For any* chat session that includes system prompt messages, tool instruction messages, or context summary text, after the session is complete the `assistant_messages` table must not contain any row whose `role` is `system` or whose `content` starts with the system prompt prefix or the context summary marker.

**Validates: Requirement 15.5**

---

## Error Handling

### Model Load Failures

| Scenario | Handling |
|---|---|
| Model file missing at startup | `ModelLoadStatus.notDownloaded` → route to onboarding |
| `loadModel` returns false | Emit on `errorStream`; show "Model failed to load" banner with Retry |
| `loadModel` throws | Catch in `FluxAiEngine`; emit on `errorStream` |
| App backgrounded during load | No special handling (load is fast; happens at startup) |

### Generation Failures

| Scenario | Handling |
|---|---|
| `onGenerationError` fires | Append system error message; re-enable input; no undo push |
| App backgrounded during streaming | `cancelGeneration()` called from lifecycle observer; show cancellation notice on resume |
| LLM produces malformed JSON tool call | `tryParse` returns null → retry up to 2 times with reinforced tool instruction |
| LLM produces valid JSON with unknown tool | `ToolResult.failure` returned; LLM re-prompted with error message |
| LLM produces valid JSON with missing args | `ToolResult.failure` returned; LLM re-prompted with missing fields listed |

### Tool Dispatch Failures

| Scenario | Handling |
|---|---|
| Transaction not found for update/delete | `ToolResult.failure("Transaction not found: <id>")` |
| Plan with past targetDate | `ToolResult.failure("Target date must be in the future")` |
| `searchTransactions` with unknown tag | Returns `requiresTagSelection: true` + suggestions instead of failure |
| Database exception during dispatch | Caught; `ToolResult.failure` with error message; logged via `debugPrint` |

### Download Failures

| Scenario | Handling |
|---|---|
| HTTP error (4xx, 5xx) | Delete partial file; emit `DownloadProgress(error: "HTTP ${statusCode}")` |
| Network timeout | Delete partial file; emit error; show Retry button |
| Insufficient storage | Caught as `FileSystemException`; surface as user-facing error |
| File size validation fails | Delete partial file; show "Download appears corrupt, please retry" |

### Alert Engine Failures

The WorkManager callback wraps `alertEngine.evaluateAll()` in a try-catch. Any exception logs via `debugPrint` and returns `Future.value(true)` to prevent WorkManager from retrying aggressively. Alert failures are silent to the user — they do not interrupt normal app usage.

---

## Testing Strategy

### Dual Testing Approach

The testing strategy combines example-based unit tests and property-based tests. Property tests cover the deterministic computational core; example tests cover UI interactions, integration points, and infrastructure behavior.

### Property-Based Testing

**Library:** [fast_check](https://pub.dev/packages/fast_check) (Dart port of fast-check; MIT license, actively maintained)

**Configuration:** Minimum 100 iterations per property test.

**Tag format:** `// Feature: spendflux-ai-assistant, Property {N}: {property title}`

Each correctness property from the section above maps to exactly one property-based test:

| Property | Target Class | Generators Needed |
|---|---|---|
| 1 (message order) | ChatScreen sort logic | Arbitrary `List<ChatMessage>` with random timestamps |
| 2 (context window size) | `ContextWindowManager` | Arbitrary `List<ChatMessage>` of length 1–100 |
| 3 (prompt structure) | `ContextWindowManager.buildPrompt` | Arbitrary summary + arbitrary message list |
| 4 (summary token limit) | `ContextWindowManager` truncation | Arbitrary long strings |
| 5 (tool parser robustness) | `ToolCallValidator.tryParse` | Arbitrary strings including structured JSON variants |
| 6 (whitelist enforcement) | `ToolCallValidator.validate` | Arbitrary tool name strings |
| 7 (required arg validation) | `ToolCallValidator.validate` | All tools × all subsets of required args |
| 8 (summary consistency) | `FinancialAnalysisEngine.getSpendingSummary` | Arbitrary transaction lists with random dates |
| 9 (comparison arithmetic) | `FinancialAnalysisEngine.comparePeriods` | Arbitrary (double, double) pairs |
| 10 (savings rate) | `FinancialAnalysisEngine.getSavingsRate` | Arbitrary (income, expenses) pairs including income=0 |
| 11 (anomaly threshold) | `FinancialAnalysisEngine.getAnomalies` | Arbitrary category histories with controlled multipliers |
| 12 (yearly aggregation) | `FinancialAnalysisEngine.getFinancialSummary` | 12-month transaction histories |
| 13 (forecast running total) | `FinancialAnalysisEngine.getBalanceForecast` | Random starting balance + scheduled transactions |
| 14 (budget alert threshold) | `AlertEngine._checkBudget` | Arbitrary (spent, limit) pairs |
| 15 (spike alert threshold) | `AlertEngine._checkSpendingSpike` | Arbitrary (current, prior) pairs |
| 16 (salary day median) | `AlertEngine.inferSalaryDay` | Arbitrary lists of day-of-month integers (1–31) |
| 17 (dedup within 24h) | `AlertEngine.shouldEmit` | Sequences of alert evaluations with controlled timestamps |
| 18 (contribution formula) | `PlanManager.assessAchievability` | Arbitrary plan parameters with positive remainingPeriods |
| 19 (achievability condition) | `PlanManager.assessAchievability` | Arbitrary (required, surplus) pairs |
| 20 (atRisk detection) | `PlanManager` / `FinancialPlan` | Arbitrary event plans |
| 21 (clarification threshold) | `ConversationManager` | Arbitrary `ExtractedTransaction` with varied confidences |
| 22 (fuzzy match priority) | `TagFuzzyMatcher` | Arbitrary query strings + tag lists with/without exact match |
| 23 (split conservation) | `ConversationManager` / `ToolDispatcher` | Arbitrary transactions + random split configurations |
| 24 (undo round-trip) | `ConversationManager` undo stack | Arbitrary create/update/delete sequences |
| 25 (undo stack size cap) | `ConversationManager` undo stack | Sequences of N > 10 operations |
| 26 (undo all order) | `ConversationManager.handleUndoAll` | Stacks of 1–10 operations |
| 27 (message round-trip) | `AssistantRepository` (persistence) | Arbitrary `AssistantMessage` instances |
| 28 (table size cap) | `AssistantRepository` | Sequences of 501–1000 message insertions |
| 29 (system content exclusion) | `AssistantRepository` | Sessions with system/tool/summary messages |

### Unit Tests (Example-Based)

Focus areas:
- **Model download flow**: success path, failure path, retry
- **Onboarding routing**: model absent → onboarding, model present → chat
- **Streaming UI**: token emission → UI update latency check (mocked timers)
- **Tool dispatch integration**: each of the 19 tools against a seeded in-memory TransactionService
- **ConversationManager flow**: standard message → no tool; message → tool call; message → retry loop
- **Alert evaluators**: one positive and one negative example per alert type
- **Pigeon bridge compilation**: verified by running `dart run pigeon` in CI

### Integration Tests

- Alert Engine WorkManager task completes within 30 seconds (measured with a stopwatch in a test that injects a fully seeded database).
- Chat history survives app restart: write messages, dispose providers, reinitialise, verify messages load.
- FinancialPlan round-trip: create via SQL, reload from SQL, verify all fields match.

### Test File Locations

```
test/features/assistant/
  engine/
    context_window_manager_test.dart    (Properties 2, 3, 4)
    financial_analysis_engine_test.dart (Properties 8–13)
    plan_manager_test.dart              (Properties 18–20)
    alert_engine_test.dart              (Properties 14–17)
    conversation_manager_test.dart      (Properties 21, 23–26)
    tag_fuzzy_matcher_test.dart         (Property 22)
  data/
    tool_call_validator_test.dart       (Properties 5, 6, 7)
    assistant_repository_test.dart      (Properties 27, 28, 29)
    model_download_service_test.dart    (example-based)
  ui/
    chat_screen_test.dart               (Property 1, UI widget tests)
    model_onboarding_screen_test.dart   (widget tests)
```
