# Requirements Document

## Introduction

SpendFlux AI Assistant is a fully offline, on-device AI-powered personal finance advisor embedded in the SpendFlux Flutter application (Android only). The assistant uses a locally stored Gemma 3 1B model (~529 MB, via MediaPipe LLM Inference on Android) to understand natural language, while all financial analysis, predictions, and data mutations are performed by deterministic rule-based services. The assistant supports conversational chat, proactive smart alerts, future balance prediction, unified goal and event planning, and full transaction management through natural language — all without any internet connection after the one-time model download.

---

## Glossary

- **Assistant**: The SpendFlux AI Assistant feature as a whole.
- **AI_Engine**: The Dart-side component (FluxAiEngine) that bridges to the native Android MediaPipe LLM inference layer via Pigeon.
- **Native_LLM_Layer**: The Android Kotlin component that loads and runs the Gemma 3 1B model using MediaPipe LLM Inference API.
- **Tool_Dispatcher**: The deterministic Dart service that executes whitelisted tool calls against local repositories.
- **Analysis_Engine**: The deterministic rule-based Dart service responsible for all financial computations.
- **Plan_Manager**: The unified service responsible for storing and computing both Financial Goals and Financial Events (distinguished by a `type` field).
- **Alert_Engine**: The service that evaluates proactive financial alert conditions and dispatches notifications.
- **Chat_Session**: An in-memory sequence of ChatMessage objects representing one conversation turn set.
- **Gemma_Model**: The quantized Gemma 3 1B (~529 MB) model file stored in the app documents directory.
- **Pigeon_Bridge**: The auto-generated Pigeon glue code used to communicate between Dart and the Native_LLM_Layer.
- **Tool_Call**: A structured JSON instruction emitted by the LLM requesting a whitelisted operation.
- **Streaming_Token**: A single token emitted by the Gemma_Model during incremental response generation.
- **Model_Onboarding**: The one-time flow that downloads the Gemma_Model to app storage with explicit user confirmation.
- **FinancialPlan**: A unified data model representing either a savings goal or a future event, distinguished by a `type` field (`goal` or `event`).
- **Savings_Schedule**: The computed periodic contribution plan generated for a FinancialPlan.
- **Balance_Forecast**: A day-by-day predicted account balance for the next N days.
- **Proactive_Alert**: A system-generated notification triggered by the Alert_Engine.
- **Confidence_Level**: A percentage (0–100%) attached to a prediction indicating reliability.
- **Spending_Anomaly**: A transaction or category total deviating from historical average by a statistically significant margin.
- **Context_Summary**: A compressed summary of older Chat_Session messages used to keep LLM context within limits.
- **Undo_Stack**: An ordered list of reversible transaction mutations within the current Chat_Session.
- **Tag_Service**: Existing service managing Tag objects (id, name) backed by SQLite.

---

## Requirements


---

### Requirement 1: Model Download and Lifecycle Management

**User Story:** As a user, I want the app to guide me through a one-time model download with clear size information and let me decide whether to proceed, so that the AI assistant is ready to use on my device.

#### Acceptance Criteria

1. WHEN the Assistant screen is opened for the first time and no Gemma_Model file exists, THE Assistant SHALL display the Model_Onboarding screen instead of the chat interface.
2. THE Model_Onboarding screen SHALL display the model name ("Gemma 3 1B"), the download size ("~529 MB"), and a clear warning that this download will use mobile data if the device is not on WiFi.
3. THE Model_Onboarding screen SHALL present two explicit actions: "Download Now" and "Cancel".
4. WHEN the user taps "Cancel", THE Assistant SHALL exit the Model_Onboarding screen without initiating any download.
5. WHEN the user taps "Download Now", THE Assistant SHALL begin downloading the model file from Google AI Edge and display a progress indicator showing download percentage and MB downloaded.
6. WHEN the download completes successfully, THE Assistant SHALL copy the file to the app documents directory, persist the path in SharedPreferences, and transition to the chat interface without requiring a restart.
7. IF the download fails or is interrupted, THE Assistant SHALL display an error message and offer a "Retry" option without requiring the user to restart the app.
8. WHEN the app starts and a model path is present in SharedPreferences, THE AI_Engine SHALL load the Gemma_Model into the Native_LLM_Layer automatically.
9. IF the Native_LLM_Layer fails to load the Gemma_Model, THE AI_Engine SHALL emit an error on the errorStream and THE Assistant SHALL display a "Model failed to load" banner with a "Retry" button.
10. THE Assistant SHALL display the current model status (loading / ready / failed) in the chat interface header.
11. WHEN the user requests model removal from settings, THE Assistant SHALL unload the model from the Native_LLM_Layer, delete the file, and clear the SharedPreferences entry.

---

### Requirement 2: Pigeon Bridge Definition

**User Story:** As a developer, I want a complete Pigeon contract between Dart and Android so that LLM inference calls are type-safe and the generated glue code compiles without errors.

#### Acceptance Criteria

1. THE Pigeon_Bridge SHALL define a `FluxAiHostApi` (Dart-to-Android) with methods: `loadModel(String modelPath) → bool`, `unloadModel() → void`, `getModelStatus() → FluxAiModelStatus`, `generateResponse(String prompt, String systemPrompt) → String`, `generateResponseStreaming(String prompt, String systemPrompt) → bool`, `cancelGeneration() → void`.
2. THE Pigeon_Bridge SHALL define a `FluxAiFlutterApi` (Android-to-Dart) with callbacks: `onToken(String token)`, `onGenerationComplete(String fullResponse)`, `onGenerationError(String message)`.
3. THE Pigeon_Bridge SHALL define a `FluxAiModelStatus` data class with fields: `bool isLoaded`, `String? modelPath`, `String? errorMessage`.
4. THE Pigeon_Bridge definition file SHALL be located at `pigeon/flux_ai_api.dart` in the project root.
5. WHEN `dart run pigeon` is executed against `pigeon/flux_ai_api.dart`, THE Pigeon_Bridge SHALL generate `lib/features/assistant/pigeon/flux_ai_api.g.dart` (Dart) and the corresponding Kotlin file without compilation errors.

---

### Requirement 3: Native Android LLM Inference Layer

**User Story:** As a developer, I want a Kotlin implementation that loads the Gemma model and runs inference via MediaPipe so that on-device LLM responses are generated without internet access.

#### Acceptance Criteria

1. THE Native_LLM_Layer SHALL implement `FluxAiHostApi` and register itself during `FlutterActivity.configureFlutterEngine`.
2. WHEN `loadModel(modelPath)` is called, THE Native_LLM_Layer SHALL initialise a MediaPipe `LlmInference` session using the GPU delegate if available, falling back to CPU.
3. WHEN `generateResponseStreaming(prompt, systemPrompt)` is called, THE Native_LLM_Layer SHALL invoke `LlmInference.generateResponseAsync` and call `FluxAiFlutterApi.onToken` for each received token on the main thread.
4. WHEN streaming completes, THE Native_LLM_Layer SHALL call `FluxAiFlutterApi.onGenerationComplete` with the full concatenated response.
5. WHEN `cancelGeneration()` is called, THE Native_LLM_Layer SHALL cancel the active inference session and stop emitting tokens.
6. IF the MediaPipe session throws an exception, THE Native_LLM_Layer SHALL call `FluxAiFlutterApi.onGenerationError` with the exception message.
7. WHEN `unloadModel()` is called, THE Native_LLM_Layer SHALL close the `LlmInference` session and release all resources.
8. THE Native_LLM_Layer SHALL NOT require any network permissions for inference.


---

### Requirement 4: Conversational Chat Interface

**User Story:** As a user, I want to chat with the AI assistant in natural language about my finances, so that I can get instant answers without navigating multiple screens.

#### Acceptance Criteria

1. THE Assistant chat screen SHALL be accessible from the Settings page as a dedicated "Flux AI Assistant" entry, not from the bottom navigation bar.
2. THE Assistant SHALL display a scrollable message list showing all ChatMessage objects in the current Chat_Session ordered chronologically.
3. WHEN the user submits a text message, THE Assistant SHALL append a user ChatMessage and send it to the AI_Engine for processing.
4. WHEN the AI_Engine begins streaming, THE Assistant SHALL append an assistant ChatMessage with `isStreaming: true` and update it with each received Streaming_Token.
5. WHEN `onGenerationComplete` fires, THE Assistant SHALL mark the streaming message as `isStreaming: false`.
6. WHILE generating, THE Assistant SHALL disable the message input and show a cancel button.
7. WHEN the user taps cancel, THE Assistant SHALL call `AI_Engine.cancelGeneration()` and append "[cancelled]" to the partial response.
8. WHEN `onGenerationError` fires, THE Assistant SHALL show the error as a system message and re-enable the input.
9. THE Chat_Session SHALL persist across app background/foreground within the same app session and SHALL be cleared when the user taps "Clear chat".
10. THE Assistant SHALL support a minimum of 50 messages visible in the scrollable list.
11. WHEN a new assistant message is added, THE Assistant SHALL auto-scroll to the bottom.

---

### Requirement 5: LLM Context Window Management

**User Story:** As a developer, I want the LLM context to stay within memory limits without losing important conversation history, so the assistant remains coherent over long sessions.

#### Acceptance Criteria

1. THE AI_Engine SHALL maintain a Context_Summary — a compressed plain-text representation of the conversation history beyond the most recent 10 messages.
2. WHEN the Chat_Session exceeds 10 messages, THE AI_Engine SHALL periodically regenerate the Context_Summary by prompting the LLM to summarise the oldest messages into a concise paragraph before discarding them from the active window.
3. WHEN building the prompt for each LLM call, THE AI_Engine SHALL prepend the current Context_Summary (if any) before the most recent 10 messages.
4. THE Context_Summary SHALL NOT exceed 200 tokens to ensure it does not crowd out the active message window.
5. THE Context_Summary SHALL be stored in memory only and SHALL NOT be persisted to the chat history SQLite table.

---

### Requirement 6: Tool Call Execution Pipeline

**User Story:** As a developer, I want the assistant to detect and execute structured tool calls from LLM responses so that financial data operations are handled by deterministic code rather than the LLM.

#### Acceptance Criteria

1. WHEN `onGenerationComplete` fires, THE Tool_Dispatcher SHALL scan the response for a JSON object matching `{"tool": "<name>", "arguments": {...}}`.
2. WHEN a valid Tool_Call is detected, THE Tool_Dispatcher SHALL validate the tool name against the whitelist and all required arguments before execution.
3. IF the tool name is unknown, THE Tool_Dispatcher SHALL return `ToolResult.failure` identifying the unknown tool.
4. IF required arguments are missing, THE Tool_Dispatcher SHALL return `ToolResult.failure` listing the missing fields.
5. WHEN a Tool_Call succeeds, THE Tool_Dispatcher SHALL return `ToolResult.success` with a structured result map.
6. WHEN a ToolResult is available, THE AI_Engine SHALL re-prompt the LLM with the tool result appended so the LLM generates a natural language summary.
7. WHEN the LLM response does not contain a Tool_Call but the question clearly requires data, THE AI_Engine SHALL retry up to 2 times with a reinforced tool instruction.
8. THE Tool_Dispatcher SHALL support: `createTransaction`, `updateTransaction`, `deleteTransaction`, `searchTransactions`, `getSpendingSummary`, `comparePeriods`, `getRecurringTransactions`, `createRecurringTransaction`, `cancelRecurringTransaction`, `getBudgetStatus`, `getForecast`, `getFinancialPlans`, `createFinancialPlan`, `updateFinancialPlan`, `deleteFinancialPlan`, `getBalanceForecast`, `getAnomalies`, `getSavingsRate`, `getFinancialSummary`.

---

### Requirement 7: Financial Analysis Engine

**User Story:** As a user, I want the assistant to analyse my spending and income patterns accurately, so that I understand my financial health without manually reviewing transactions.

#### Acceptance Criteria

1. THE Analysis_Engine SHALL compute category-wise spending totals for any given month or date range from the Transaction_Service.
2. WHEN `getSpendingSummary` is called, THE Analysis_Engine SHALL return total expenses, total income, net balance, and a per-category breakdown.
3. WHEN `comparePeriods` is called, THE Analysis_Engine SHALL return absolute and percentage differences in expenses and income between two periods.
4. THE Analysis_Engine SHALL compute savings rate as `((income - expenses) / income) × 100`; IF income is zero, savings rate SHALL be 0%.
5. WHEN `getAnomalies` is called, THE Analysis_Engine SHALL identify category totals exceeding 2× the 3-month rolling average for that category.
6. THE Analysis_Engine SHALL detect recurring transactions where `isRecurring` is true, or where the same title and approximate amount appear across at least 2 consecutive periods.
7. WHEN `getForecast` is called with a number of days, THE Analysis_Engine SHALL project spending using the current month's daily average.
8. THE Analysis_Engine SHALL estimate monthly surplus/deficit as `income - expenses` for the current month to date.
9. WHEN a yearly summary is requested, THE Analysis_Engine SHALL aggregate monthly income, expenses, savings rate, and category breakdowns for all 12 months.
10. THE Analysis_Engine SHALL flag potential unnecessary subscriptions: recurring expenses in entertainment, utilities, or bills categories that appear for 3+ consecutive months with a consistent amount (±5%).


---

### Requirement 8: Future Balance Prediction

**User Story:** As a user, I want to see a predicted day-by-day account balance for the next 30 days so that I can plan large purchases and avoid running short.

#### Acceptance Criteria

1. WHEN `getBalanceForecast` is called, THE Analysis_Engine SHALL produce a Balance_Forecast with a predicted balance for each day from today through the next 30 days.
2. THE Balance_Forecast SHALL initialise from the current actual balance of the specified account, or the sum of all non-credit-card accounts if none specified.
3. THE Analysis_Engine SHALL deduct known recurring expenses on their scheduled dates within the forecast window.
4. THE Analysis_Engine SHALL add known recurring income on their scheduled dates within the forecast window.
5. THE Analysis_Engine SHALL include credit card bill amounts on their due dates within the forecast window.
6. THE Analysis_Engine SHALL include active EMI monthly amounts on their next due dates within the forecast window.
7. THE Balance_Forecast SHALL carry a Confidence_Level: 80–100% if 3+ months of history exists, 50–79% for 1–2 months, below 50% for less than 1 month.
8. IF any predicted day balance falls below zero, THE Analysis_Engine SHALL flag that day with `balanceBelowZero: true`.
9. THE Analysis_Engine SHALL include upcoming FinancialPlan contributions in the forecast if the contribution date falls within the window.

---

### Requirement 9: Proactive Smart Alerts

**User Story:** As a user, I want the assistant to proactively notify me about unusual spending, upcoming obligations, and financial risks, so that I can act before problems occur.

#### Acceptance Criteria

1. THE Alert_Engine SHALL evaluate all alert conditions once per day via a WorkManager background task.
2. WHEN monthly spending in any category exceeds 80% of that category's budget limit, THE Alert_Engine SHALL emit a Proactive_Alert.
3. WHEN total monthly spending exceeds 80% of the overall budget limit, THE Alert_Engine SHALL emit a Proactive_Alert.
4. WHEN spending in any category this month exceeds 130% of the same category last month, THE Alert_Engine SHALL emit a Proactive_Alert with the category name and percentage increase.
5. WHEN a recurring expense is due within 5 days and account balance is less than 2× that expense amount, THE Alert_Engine SHALL emit a Proactive_Alert warning about insufficient balance.
6. WHEN a credit card bill due date is within 7 days, THE Alert_Engine SHALL emit a Proactive_Alert with the outstanding amount and due date.
7. WHEN the salary credit date detection logic (inferred from history or manually set) determines salary is 5+ days overdue and no income transaction exists for the current month, THE Alert_Engine SHALL emit a Proactive_Alert.
8. THE salary credit date SHALL be inferred by calculating the median day-of-month of historical salary-category income transactions over the past 3 months; THE user SHALL also be able to set this day manually in Settings, which takes precedence over the inferred value.
9. WHEN the Balance_Forecast predicts balance will fall below zero within 30 days, THE Alert_Engine SHALL emit a Proactive_Alert with the predicted date and shortfall amount.
10. WHEN rent plus EMI for the next month exceeds 50% of the 3-month average monthly income, THE Alert_Engine SHALL emit a Proactive_Alert with the computed percentage.
11. THE Alert_Engine SHALL NOT emit the same alert type and subject more than once within a 24-hour window.
12. THE Alert_Engine SHALL store each emitted Proactive_Alert (type, subject, timestamp) in a local SQLite table for deduplication.
13. THE Alert_Engine background task SHALL complete its evaluation within 30 seconds to comply with WorkManager limits.

---

### Requirement 10: Unified Financial Plan Management (Goals and Events)

**User Story:** As a user, I want to create both savings goals and event budgets in one place, so that the assistant can calculate how much I need to save and tell me if my plans are achievable.

#### Acceptance Criteria

1. THE Plan_Manager SHALL persist FinancialPlan objects in a single SQLite table with fields: `id`, `name`, `type` (`goal` or `event`), `targetAmount`, `targetDate`, `priority` (low/medium/high, goals only), `currentSavings`, `preferredAccountId`, `contributionFrequency` (weekly/monthly), `createdAt`.
2. WHEN a FinancialPlan is created or updated, THE Plan_Manager SHALL compute the required periodic contribution as `(targetAmount - currentSavings) / remainingPeriods`.
3. THE Plan_Manager SHALL assess achievability by comparing the required contribution against the average monthly surplus over the past 3 months; IF required > surplus, THE Plan_Manager SHALL mark `achievable: false`.
4. WHEN a FinancialPlan is marked `achievable: false`, THE Plan_Manager SHALL generate at least one suggestion: an extended target date achievable at the current surplus rate, or a reduced target amount.
5. THE Plan_Manager SHALL compute an estimated completion date for each active FinancialPlan.
6. IF `targetDate` is in the past when creating a FinancialPlan, THE Plan_Manager SHALL reject the plan and return an error.
7. IF a FinancialPlan of type `event` has an `eventDate` less than 30 days away and current savings are less than `targetAmount`, THE Plan_Manager SHALL flag it as `atRisk: true` and include it in the Alert_Engine's next evaluation.
8. WHEN the user asks the assistant to estimate a budget for a named event (e.g., "3-day Goa trip"), THE Assistant SHALL use the LLM to produce a structured budget estimate, present it to the user for confirmation, then create the FinancialPlan.
9. WHEN `getFinancialPlans` is called, THE Tool_Dispatcher SHALL return all active FinancialPlan objects with computed contributions, achievability, and estimated completion dates.
10. WHEN the user requests plan creation through chat, THE Assistant SHALL collect all required fields through a clarifying conversation before calling `createFinancialPlan`.


---

### Requirement 11: Transaction Management via Chat

**User Story:** As a user, I want to add, edit, delete, and search transactions by talking to the assistant, so that I can manage my finances without switching screens.

#### Acceptance Criteria

1. WHEN the user describes a transaction in natural language, THE Assistant SHALL use the TransactionExtractor to extract amount, type, category, date, and payee before constructing a Tool_Call.
2. IF extraction confidence is below 0.85, THE Assistant SHALL ask a clarifying question for the lowest-confidence field before submitting the Tool_Call.
3. WHEN `createTransaction` succeeds, THE Assistant SHALL confirm the transaction details in one natural language sentence including amount, category, and date.
4. WHEN the user requests an update, THE Assistant SHALL call `searchTransactions` first and present matched transactions for confirmation if more than one match is found.
5. WHEN the user requests deletion, THE Assistant SHALL require a second explicit confirmation message before calling `deleteTransaction`.
6. WHEN `searchTransactions` is called, THE Tool_Dispatcher SHALL filter by any combination of: date range, amount range, category, account, title keyword, and tag.
7. WHEN the user searches by tag name, THE Tool_Dispatcher SHALL query the Tag_Service for tags whose names fuzzy-match the provided keyword; IF no exact match exists, THE Assistant SHALL present up to 5 similar tag names from the database for the user to select before retrying the search.
8. WHEN the user requests to split a transaction, THE Assistant SHALL collect split amounts and categories, delete the original, and create replacement transactions via individual `createTransaction` calls.
9. WHEN the user requests a recurring transaction via chat, THE Assistant SHALL collect title, amount, type, category, frequency, start date, and optional end date before calling `createRecurringTransaction`.
10. WHEN the user requests to cancel a recurring transaction, THE Assistant SHALL confirm the title before calling `cancelRecurringTransaction`.

---

### Requirement 12: Multi-Step Undo

**User Story:** As a user, I want to undo multiple recent transaction operations within my chat session, so that I can correct mistakes without manually finding and editing transactions.

#### Acceptance Criteria

1. THE Assistant SHALL maintain an Undo_Stack within the current Chat_Session containing all reversible mutations (create, update, delete) performed during the session.
2. WHEN the user says "undo" or an equivalent phrase, THE Assistant SHALL pop the most recent entry from the Undo_Stack and reverse it: deleted transactions SHALL be re-created, created transactions SHALL be deleted, updated transactions SHALL be restored to their prior state.
3. WHEN an undo succeeds, THE Assistant SHALL confirm what was reversed in a single natural language sentence.
4. WHEN the Undo_Stack is empty and the user requests undo, THE Assistant SHALL inform the user that there are no more operations to undo in this session.
5. THE Undo_Stack SHALL hold a maximum of 10 entries; the oldest entry SHALL be discarded when the limit is exceeded.
6. THE Undo_Stack SHALL be cleared when the user taps "Clear chat".
7. WHEN the user says "undo all", THE Assistant SHALL reverse all entries in the Undo_Stack in order from most recent to oldest and confirm the total number of operations reversed.

---

### Requirement 13: Natural Language Query Processing

**User Story:** As a user, I want to ask financial questions in plain language and get accurate answers grounded in my actual data, so that I don't need to learn any query syntax.

#### Acceptance Criteria

1. THE Assistant SHALL answer spending questions by executing the appropriate Tool_Call and presenting results in Indian Rupee formatting (₹X,XX,XXX).
2. THE Assistant SHALL answer period comparison questions by calling `comparePeriods` and summarising in under 80 words.
3. THE Assistant SHALL answer account balance questions by reading from Account_Service and formatting per account.
4. THE Assistant SHALL answer budget status questions by calling `getBudgetStatus` and listing over-limit or near-limit categories.
5. WHEN the user asks whether a purchase is affordable, THE Assistant SHALL call `getBalanceForecast` and evaluate whether the amount can be accommodated without the balance going below zero.
6. THE Assistant SHALL NOT invent financial figures; all monetary values SHALL come from Tool_Call results.
7. THE Assistant SHALL keep responses under 150 words unless the user explicitly requests more detail.

---

### Requirement 14: Streaming Response Display

**User Story:** As a user, I want to see the assistant's response appear word-by-word, so that the interface feels responsive even for longer answers.

#### Acceptance Criteria

1. WHEN `onToken` fires, THE Assistant SHALL append the token to the streaming ChatMessage and update the UI within 100ms.
2. WHILE streaming, THE Assistant SHALL display a visual indicator (animated cursor or pulsing dot) at the end of the in-progress message.
3. WHEN streaming is cancelled, THE Assistant SHALL retain the partial text and append "[cancelled]".
4. THE Assistant SHALL NOT wait for `onGenerationComplete` before displaying text — display SHALL begin from the first token.

---

### Requirement 15: Chat History Persistence

**User Story:** As a user, I want my previous conversations saved locally so that I can review past advice and context is not lost when I close the app.

#### Acceptance Criteria

1. THE Assistant SHALL persist user-visible ChatMessages to an `assistant_messages` SQLite table with fields: `id`, `role`, `content`, `timestamp`, `sessionId`.
2. WHEN the app reopens, THE Assistant SHALL load the most recent Chat_Session (up to 100 messages) and display it.
3. WHEN the user taps "Clear chat", THE Assistant SHALL delete all messages in the current session and start a fresh session.
4. THE Assistant SHALL store a maximum of 500 messages across all sessions; the oldest SHALL be deleted first when exceeded.
5. THE Assistant SHALL NOT persist system prompts, tool instructions, or Context_Summary strings to the chat history table.

---

### Requirement 16: Model-Agnostic Inference Backend

**User Story:** As a developer, I want the inference backend to be swappable so a different local model can be plugged in without rewriting chat or tool logic.

#### Acceptance Criteria

1. THE AI_Engine SHALL expose only this public interface: `loadModel(String path) → Future<bool>`, `unloadModel() → Future<void>`, `generateResponseStreaming(String prompt, String systemPrompt) → Future<bool>`, `cancelGeneration() → void`, `tokenStream → Stream<String>`, `completeStream → Stream<String>`, `errorStream → Stream<String>`, `isModelLoaded → bool`.
2. THE Tool_Dispatcher, Chat_Session management, and Analysis_Engine SHALL depend only on this interface and SHALL contain no MediaPipe-specific logic.
3. THE AI_Engine SHALL be provided via a flutter_riverpod provider so it can be replaced with a mock without modifying UI or business logic.

---

### Requirement 17: Data Privacy and Security

**User Story:** As a user, I want my financial data and AI conversations to remain entirely on my device.

#### Acceptance Criteria

1. THE Assistant SHALL NOT make any outbound network requests for model inference; all inference SHALL occur on-device.
2. THE one-time model download SHALL be the only permitted outbound network operation; all other assistant functionality SHALL be offline.
3. THE Assistant SHALL NOT transmit transaction data, account balances, chat messages, or any personally identifiable information to any server.
4. THE Gemma_Model file SHALL be stored in the app's private documents directory.
5. THE chat history SQLite table SHALL be covered by the same app-level database policy as all other SpendFlux data.

---

### Requirement 18: Performance and Resource Constraints

**User Story:** As a developer, I want the AI assistant to operate within acceptable memory and battery limits on mid-range Android devices.

#### Acceptance Criteria

1. THE Native_LLM_Layer SHALL initialise with a maximum context window of 1024 tokens to limit memory on devices with less than 4 GB RAM.
2. THE AI_Engine SHALL pass no more than the last 10 messages plus the current Context_Summary to the LLM per inference call.
3. WHEN the app is sent to background while inference is in progress, THE AI_Engine SHALL cancel the active generation and notify the user upon foreground return.
4. THE Native_LLM_Layer SHALL use the GPU delegate when available and fall back to CPU.
5. THE Alert_Engine WorkManager task SHALL complete within 30 seconds.
