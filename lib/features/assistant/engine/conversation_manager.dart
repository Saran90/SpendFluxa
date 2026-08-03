import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/account.dart';
import '../../../core/models/transaction.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/transaction_service.dart';
import '../constants/system_prompt.dart';
import '../data/tool_result_formatter.dart';
import '../engine/abstract_ai_engine.dart';
import '../engine/context_window_manager.dart';
import '../data/tool_dispatcher.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../models/undo_stack_entry.dart';
import '../validation/tool_call_validator.dart';

/// Maximum number of retries when the LLM responds without a required tool call.
const _maxToolRetries = 3;

/// Maximum entries held in the undo stack per chat session.
const _maxUndoStackSize = 10;

// ── Intent-detection patterns ─────────────────────────────────────────────────

/// Returns `true` if [text] contains an undo intent.
bool _isUndoIntent(String text) {
  final lower = text.toLowerCase().trim();
  return lower == 'undo' ||
      lower.startsWith('undo ') ||
      lower.contains('undo that') ||
      lower.contains('undo last') ||
      lower.contains('undo all') ||
      lower.contains('revert that') ||
      lower.contains('take that back');
}

bool _isUndoAllIntent(String text) {
  final lower = text.toLowerCase().trim();
  return lower.contains('undo all') || lower == 'undo everything';
}

/// Returns `true` if the LLM response looks like it contains user-specific
/// financial data answers without having gone through a tool call first.
///
/// This catches two cases:
/// 1. The model deflects ("I don't have access to...")
/// 2. The model hallucinates specific user amounts (₹X,XXX for "your balance")
///
/// General financial education ("a good savings rate is 20%") is NOT flagged —
/// those are advice-level responses that don't require real user data.
bool _responseNeedsData(String response) {
  final lower = response.toLowerCase();

  // Explicit deflection phrases — always retry
  if (lower.contains("i don't have access") ||
      lower.contains("i can't tell") ||
      lower.contains("i'm unable") ||
      lower.contains("i cannot check") ||
      lower.contains("you would need to check") ||
      lower.contains("i don't know your") ||
      lower.contains("i have no information")) {
    return true;
  }

  // Detect hallucinated personal financial answers:
  // Contains rupee amounts AND first-person possessive phrases that imply
  // the model is claiming to know the USER's specific data.
  final hasRupeeAmount =
      response.contains('₹') ||
      RegExp(
        r'\b\d[\d,]+\s*(rs|rupee|lakh|crore)',
        caseSensitive: false,
      ).hasMatch(response);

  // Phrases that indicate the model is asserting USER-specific values
  final assertsUserData = RegExp(
    r'\b(your (balance|spending|expenses|income|budget|savings|total)'
    r'|you (spent|have|earned|saved|owe)'
    r'|this month (you|your)'
    r'|currently.*₹'
    r'|balance is ₹)',
    caseSensitive: false,
  ).hasMatch(lower);

  if (hasRupeeAmount && assertsUserData) return true;

  return false;
}

// ── Conversation Manager ──────────────────────────────────────────────────────

/// Central orchestrator for the AI assistant chat loop.
///
/// Responsibilities:
/// - Accepts user messages and routes them through the LLM → tool → response pipeline.
/// - Manages the undo stack for reversible transaction mutations.
/// - Delegates context compression to [ContextWindowManager].
/// - Exposes a [messageStream] for the UI to react to new/updated messages.
class ConversationManager {
  ConversationManager({
    required this.engine,
    required this.dispatcher,
    required this.contextManager,
    required this.transactionService,
    required this.accountService,
  });

  final AbstractAiEngine engine;
  final ToolDispatcher dispatcher;
  final ContextWindowManager contextManager;
  final TransactionService transactionService;
  final AccountService accountService;

  final _validator = ToolCallValidator();
  final _uuid = const Uuid();

  // ── Pending account selection ──────────────────────────────────────────────
  Completer<String?>? _pendingAccountCompleter;
  Completer<String?>? _pendingCategoryCompleter;
  String? _pendingPickerMessageId;

  // ── Pending transaction (waiting for amount from user) ─────────────────────
  ToolCall? _pendingTransactionCall;
  String?
  _pendingTransactionOriginalMessage; // original user message for context

  // ── Guided transaction state ───────────────────────────────────────────────
  String? _guidedTransactionType; // 'expense' or 'income'
  double? _guidedTransactionAmount;
  String? _guidedTransactionDescription; // "what for" - user input
  String? _guidedTransactionCategory; // category name - from picker
  String? _guidedTransactionAccount; // final account ID
  DateTime? _guidedTransactionDate;
  String _guidedTransactionStep =
      ''; // 'description','amount','category','account','accountSub','date'

  // ── Message stream ─────────────────────────────────────────────────────────

  final _messageController = StreamController<ChatMessage>.broadcast();

  /// Emits every new or updated [ChatMessage] — UI subscribes to this.
  Stream<ChatMessage> get messageStream => _messageController.stream;

  // ── Undo stack ─────────────────────────────────────────────────────────────

  final List<UndoStackEntry> _undoStack = [];

  List<UndoStackEntry> get undoStack => List.unmodifiable(_undoStack);

  // ── Generation state ───────────────────────────────────────────────────────

  // Counts nested _streamLlmResponse calls so isGenerating stays true until
  // the outermost call (and all tool-triggered inner calls) are fully done.
  int _generatingDepth = 0;
  bool get isGenerating => _generatingDepth > 0;

  /// True when a guided transaction flow is in progress.
  bool get isGuidedFlowActive => _guidedTransactionType != null;

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<String>? _completeSub;
  StreamSubscription<String>? _errorSub;

  // ── Session ID (set by AssistantSessionNotifier) ───────────────────────────

  String _sessionId = '';
  void setSessionId(String id) => _sessionId = id;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Handles a new message from the user.
  ///
  /// Flow:
  /// 1. Check for undo intent — handle without LLM.
  /// 2. Run TransactionExtractor if the message looks like a transaction command.
  ///    If confidence < 0.85, emit a clarification question and stop.
  /// 3. Add the user message to the context window.
  /// 4. Build the prompt and start LLM streaming.
  /// 5. On completion, detect and execute tool calls with up to 2 retries.
  Future<void> handleUserMessage(String text) async {
    if (isGenerating) return;

    final userMsg = _createMessage(ChatRole.user, text);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    // ── Undo intent shortcut ──────────────────────────────────────────────────
    if (_isUndoIntent(text)) {
      if (_isUndoAllIntent(text)) {
        await handleUndoAll();
      } else {
        await handleUndo();
      }
      return;
    }

    // ── Pending amount reply ──────────────────────────────────────────────────
    if (_pendingTransactionCall != null) {
      final amount = _parseAmountFromText(text);
      if (amount != null && amount > 0) {
        final pending = _pendingTransactionCall!;
        final originalMsg = _pendingTransactionOriginalMessage;
        _pendingTransactionCall = null;
        _pendingTransactionOriginalMessage = null;

        final updatedArgs = Map<String, dynamic>.from(pending.arguments)
          ..['amount'] = amount;
        final resumedCall = ToolCall(
          tool: pending.tool,
          arguments: updatedArgs,
        );

        // Inject a synthetic context message that combines the original user
        // message + the amount reply, so account/note/category enrichment
        // sees the full context (not just the bare "500").
        if (originalMsg != null) {
          // Temporarily replace the last user message in context with the
          // enriched version so enrichment helpers can read it.
          final syntheticContent = '$originalMsg for $text';
          contextManager.injectContextMessage(syntheticContent);
        }

        await _dispatchAndRespond(resumedCall);
        return;
      }
      // User didn't give a number — clear pending and let LLM handle it
      _pendingTransactionCall = null;
      _pendingTransactionOriginalMessage = null;
    }

    // ── LLM streaming ─────────────────────────────────────────────────────────
    await _streamLlmResponse();
  }

  /// Cancels any in-progress generation.
  void cancelGeneration() {
    engine.cancelGeneration();
    _generatingDepth = 0;
  }

  /// Reverses the most recent undoable operation.
  Future<void> handleUndo() async {
    if (_undoStack.isEmpty) {
      final msg = _createMessage(
        ChatRole.assistant,
        'Nothing to undo in this session.',
      );
      _emit(msg);
      contextManager.addMessage(msg);
      return;
    }
    final entry = _undoStack.removeLast();
    await _reverseOperation(entry);
    final msg = _createMessage(
      ChatRole.assistant,
      'Undone: ${entry.humanDescription}',
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Reverses all undoable operations from most recent to oldest.
  Future<void> handleUndoAll() async {
    if (_undoStack.isEmpty) {
      final msg = _createMessage(
        ChatRole.assistant,
        'Nothing to undo in this session.',
      );
      _emit(msg);
      contextManager.addMessage(msg);
      return;
    }
    final count = _undoStack.length;
    while (_undoStack.isNotEmpty) {
      await _reverseOperation(_undoStack.removeLast());
    }
    final msg = _createMessage(
      ChatRole.assistant,
      'Reversed $count operation${count == 1 ? '' : 's'}.',
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Called by the UI when the app moves to background during generation.
  void onAppPaused() {
    if (isGenerating) {
      cancelGeneration();
    }
  }

  /// Called by the UI when the app returns to foreground.
  void onAppResumed() {
    // Nothing to do automatically — the user will see the "[cancelled]" marker.
  }

  /// Clears undo stack and context window (called on "Clear chat").
  void clearSession() {
    _undoStack.clear();
    contextManager.clear();
  }

  void dispose() {
    _cancelSubscriptions();
    _messageController.close();
  }

  // ── Private: LLM streaming pipeline ──────────────────────────────────────

  Future<void> _streamLlmResponse({
    int retryCount = 0,
    String? systemPromptOverride,
    bool isSummaryCall = false,
  }) async {
    _generatingDepth++;

    // Create a streaming placeholder message
    final streamingId = _uuid.v4();
    var streamingMsg = ChatMessage(
      id: streamingId,
      role: ChatRole.assistant,
      content: '',
      isStreaming: true,
      sessionId: _sessionId,
      timestamp: DateTime.now(),
    );
    _emit(streamingMsg);

    final prompt = contextManager.buildPrompt();
    final fullSystemPrompt =
        systemPromptOverride ??
        '$fluxAiSystemPrompt\n\n$fluxAiToolInstructions';
    final responseBuffer = StringBuffer();
    bool cancelled = false;

    _cancelSubscriptions();

    _tokenSub = engine.tokenStream.listen((token) {
      responseBuffer.write(token);
      streamingMsg = streamingMsg.copyWith(
        content: responseBuffer.toString(),
        isStreaming: true,
      );
      _emit(streamingMsg);
    });

    final completer = Completer<String>();

    _completeSub = engine.completeStream.listen((fullResponse) {
      if (!completer.isCompleted) completer.complete(fullResponse);
    });

    _errorSub = engine.errorStream.listen((error) {
      if (!completer.isCompleted) completer.completeError(error);
    });

    try {
      await engine.generateResponseStreaming(prompt, fullSystemPrompt);
      final fullResponse = await completer.future;

      // Don't finalise the streaming message yet — _processResponse will
      // decide whether to hide it (tool call) or show it (natural reply).
      // This prevents the one-frame flash of raw JSON in the UI.
      await _processResponse(
        fullResponse,
        streamingId,
        retryCount,
        isSummaryCall: isSummaryCall,
        streamingMsg: streamingMsg,
      );
    } on String catch (error) {
      // Error from errorStream
      final errMsg = _createMessage(ChatRole.system, '⚠️ $error');
      _emit(errMsg);
      contextManager.addMessage(errMsg);
    } catch (e) {
      if (e.toString().contains('cancelled') || cancelled) {
        streamingMsg = streamingMsg.copyWith(
          content: '${streamingMsg.content} [cancelled]',
          isStreaming: false,
        );
        _emit(streamingMsg);
      } else {
        final errMsg = _createMessage(
          ChatRole.system,
          '⚠️ Generation error: $e',
        );
        _emit(errMsg);
        contextManager.addMessage(errMsg);
      }
    } finally {
      _generatingDepth = (_generatingDepth - 1).clamp(0, 999);
      _cancelSubscriptions();
    }
  }

  Future<void> _processResponse(
    String fullResponse,
    String streamingMsgId,
    int retryCount, {
    bool isSummaryCall = false,
    ChatMessage? streamingMsg,
  }) async {
    // DEBUG — remove after confirming tool calls work correctly
    debugPrint(
      '[FluxAI] LLM response (retry=$retryCount, summary=$isSummaryCall):\n$fullResponse',
    );

    // 1. Try to parse a tool call
    final toolCall = _validator.tryParse(fullResponse);
    debugPrint('[FluxAI] Tool call parsed: ${toolCall?.tool ?? "none"}');

    // Helper: finalise the streaming placeholder as visible or hidden.
    void finaliseStreaming({required bool hidden}) {
      final finalised = ChatMessage(
        id: streamingMsgId,
        role: ChatRole.assistant,
        content: fullResponse,
        isStreaming: false,
        isHidden: hidden,
        sessionId: _sessionId,
        timestamp: DateTime.now(),
      );
      _emit(finalised);
    }

    // If this is a post-tool summary call and the model still returned JSON,
    // treat the response as plain text to break the loop.
    if (toolCall != null && isSummaryCall) {
      // Show it as-is (last resort — better than silent failure)
      finaliseStreaming(hidden: false);
      final finalMsg = ChatMessage(
        id: streamingMsgId,
        role: ChatRole.assistant,
        content: fullResponse,
        isStreaming: false,
        sessionId: _sessionId,
        timestamp: DateTime.now(),
      );
      contextManager.addMessage(finalMsg);
      unawaited(contextManager.maybeSummarise(engine));
      return;
    }

    if (toolCall != null) {
      // Hide the raw JSON — emit it as hidden so it's invisible in the UI.
      finaliseStreaming(hidden: true);

      final validation = _validator.validate(toolCall);
      if (!validation.isValid) {
        final errText = 'Tool error: ${validation.errors.join(', ')}';
        final sysMsg = _createMessage(ChatRole.system, errText);
        _emit(sysMsg);
        contextManager.addMessage(sysMsg);
        return;
      }

      // ── Amount guard ────────────────────────────────────────────────────
      // If this is a transaction creation call but the user never mentioned
      // an amount, the model may have hallucinated one. Ask the user first.
      if ((toolCall.tool == 'createTransaction' ||
              toolCall.tool == 'createRecurringTransaction') &&
          _isHallucinatedAmount(toolCall)) {
        final askMsg = _createMessage(
          ChatRole.assistant,
          'How much was the amount?',
        );
        _emit(askMsg);
        contextManager.addMessage(askMsg);
        // Store the pending call AND the original user message for context
        _pendingTransactionCall = toolCall;
        // Find the last user message to preserve full context
        final msgs = contextManager.allMessages;
        for (var i = msgs.length - 1; i >= 0; i--) {
          if (msgs[i].role == ChatRole.user) {
            _pendingTransactionOriginalMessage = msgs[i].content;
            break;
          }
        }
        return;
      }

      // For transaction mutations, extract the account mention from the
      // last user message and inject it if the model omitted the field.
      final enrichedCall = await _enrichTransactionAccount(toolCall);

      // Show category picker so user can confirm or correct the category.
      // Also pass the full user message so candidates are context-aware.
      final enrichedWithCategory = await _enrichTransactionCategory(
        enrichedCall,
      );

      // Inject note from user message if missing (Issue 2)
      final finalCall = _enrichTransactionNote(enrichedWithCategory);

      // Capture snapshot for undo BEFORE dispatch (for update/delete)
      final snapshot = _captureSnapshotIfNeeded(finalCall);

      // Execute tool
      final result = await dispatcher.dispatch(finalCall);
      debugPrint('[FluxAI] Tool result ok=${result.ok}: ${result.result}');

      if (!result.ok) {
        final errMsg = _createMessage(
          ChatRole.system,
          '⚠️ ${result.error ?? 'Tool failed'}',
        );
        _emit(errMsg);
        contextManager.addMessage(errMsg);
        return;
      }

      // Push to undo stack for mutating tools
      _maybePushUndo(finalCall, result, snapshot);

      // Try to format the result deterministically (guaranteed accurate numbers).
      final deterministicSummary = ToolResultFormatter.format(
        finalCall.tool,
        result,
      );

      if (deterministicSummary != null) {
        final toolResultMsg = _createMessage(
          ChatRole.tool,
          '[TOOL RESULT]\n${_resultToContext(finalCall.tool, result)}\n[END TOOL RESULT]',
        );
        contextManager.addMessage(toolResultMsg);

        final summaryMsg = _createMessage(
          ChatRole.assistant,
          deterministicSummary,
        );
        _emit(summaryMsg);
        final contextAck = _createMessage(
          ChatRole.assistant,
          'Here is the data from your records.',
        );
        contextManager.addMessage(contextAck);
        unawaited(contextManager.maybeSummarise(engine));
      } else {
        final toolResultMsg = _createMessage(
          ChatRole.tool,
          '[TOOL RESULT]\n${_resultToContext(finalCall.tool, result)}\n[END TOOL RESULT]',
        );
        contextManager.addMessage(toolResultMsg);

        await _streamLlmResponse(
          retryCount: 0,
          systemPromptOverride: fluxAiToolResultSummaryPrompt,
          isSummaryCall: true,
        );
      }
      return;
    }

    // 2. No tool call — check if data was actually needed
    if (_responseNeedsData(fullResponse) && retryCount < _maxToolRetries) {
      // Hide the hallucinated response.
      finaliseStreaming(hidden: true);

      // Add a reinforcement instruction and retry with an example
      final reinforcement = _createMessage(
        ChatRole.system,
        'IMPORTANT: You must call a tool to get real data. '
        'Do NOT write numbers from memory. '
        'Respond with ONLY a JSON tool call, for example:\n'
        '{"tool":"getSpendingSummary","arguments":{"period":"this_month"}}',
      );
      contextManager.addMessage(reinforcement);
      await _streamLlmResponse(retryCount: retryCount + 1);
      return;
    }

    // 3. Final natural-language response — finalise as visible and add to context.
    finaliseStreaming(hidden: false);
    final finalMsg = ChatMessage(
      id: streamingMsgId,
      role: ChatRole.assistant,
      content: fullResponse,
      isStreaming: false,
      sessionId: _sessionId,
      timestamp: DateTime.now(),
    );
    contextManager.addMessage(finalMsg);

    // Trigger context compression asynchronously (non-blocking)
    unawaited(contextManager.maybeSummarise(engine));
  }

  // ── Private: undo helpers ─────────────────────────────────────────────────

  /// Captures the existing transaction state before a mutating tool executes.
  /// Returns `null` for non-mutating tools or when the transaction isn't found.
  Transaction? _captureSnapshotIfNeeded(ToolCall call) {
    if (call.tool == 'updateTransaction' || call.tool == 'deleteTransaction') {
      final id = call.arguments['id'] as String?;
      if (id != null) {
        try {
          return transactionService.allTransactions.firstWhere(
            (t) => t.id == id,
          );
        } catch (_) {}
      }
    }
    return null;
  }

  void _maybePushUndo(ToolCall call, ToolResult result, Transaction? snapshot) {
    UndoStackEntry? entry;

    switch (call.tool) {
      case 'createTransaction':
        final txId = result.result?['transactionId'] as String?;
        if (txId != null) {
          try {
            final created = transactionService.allTransactions.firstWhere(
              (t) => t.id == txId,
            );
            entry = UndoStackEntry(
              operationId: _uuid.v4(),
              type: UndoOperationType.create,
              snapshot: created,
              humanDescription:
                  result.result?['message'] as String? ?? 'Added transaction',
            );
          } catch (_) {}
        }
      case 'updateTransaction':
        if (snapshot != null) {
          entry = UndoStackEntry(
            operationId: _uuid.v4(),
            type: UndoOperationType.update,
            snapshot: snapshot,
            humanDescription: 'Updated transaction "${snapshot.title}"',
          );
        }
      case 'deleteTransaction':
        if (snapshot != null) {
          entry = UndoStackEntry(
            operationId: _uuid.v4(),
            type: UndoOperationType.delete,
            snapshot: snapshot,
            humanDescription:
                'Deleted transaction "${snapshot.title}" (${snapshot.amount})',
          );
        }
    }

    if (entry != null) {
      if (_undoStack.length >= _maxUndoStackSize) {
        _undoStack.removeAt(0); // discard oldest
      }
      _undoStack.add(entry);
    }
  }

  Future<void> _reverseOperation(UndoStackEntry entry) async {
    try {
      switch (entry.type) {
        case UndoOperationType.create:
          await transactionService.removeTransaction(entry.snapshot.id);
        case UndoOperationType.delete:
          await transactionService.addTransaction(entry.snapshot);
        case UndoOperationType.update:
          await transactionService.updateTransaction(entry.snapshot);
      }
    } catch (_) {
      // Reversal failure is non-fatal — inform the user via the confirmation message
    }
  }

  /// Starts a guided transaction flow for adding an expense or income.
  Future<void> startGuidedTransactionFlow(String type) async {
    _guidedTransactionType = type;
    _guidedTransactionDescription = null;
    _guidedTransactionAmount = null;
    _guidedTransactionCategory = null;
    _guidedTransactionAccount = null;
    _guidedTransactionDate = null;
    _guidedTransactionStep = 'description';

    final greeting = type == 'expense'
        ? '💳 Let\'s add an expense.\n\nWhat are you spending on?'
        : '💰 Let\'s add income.\n\nWhat\'s the source?';

    final msg = _createMessage(
      ChatRole.assistant,
      greeting,
      messageType: ChatMessageType.text,
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Handles user input during guided transaction flow.
  Future<void> handleGuidedTransactionInput(String input) async {
    if (_guidedTransactionType == null) return;

    final trimmed = input.trim();

    // Emit the user message visibly in chat
    final userMsg = _createMessage(ChatRole.user, trimmed);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    switch (_guidedTransactionStep) {
      case 'description':
        // Step 1: What transaction (description/note)
        _guidedTransactionDescription = trimmed;
        _guidedTransactionStep = 'amount';

        final amountMsg = _createMessage(
          ChatRole.assistant,
          'How much?',
          messageType: ChatMessageType.text,
        );
        _emit(amountMsg);
        contextManager.addMessage(amountMsg);
        break;

      case 'amount':
        // Step 2: Amount
        final amount = _parseAmountFromText(trimmed);
        if (amount != null && amount > 0) {
          _guidedTransactionAmount = amount;
          _guidedTransactionStep = 'category';

          final categoryMsg = _createMessage(
            ChatRole.assistant,
            'Which category?',
            messageType: ChatMessageType.guidedCategoryPicker,
          );
          _emit(categoryMsg);
          contextManager.addMessage(categoryMsg);
        } else {
          final errorMsg = _createMessage(
            ChatRole.assistant,
            'Please enter a valid amount, e.g. "500" or "₹200".',
            messageType: ChatMessageType.text,
          );
          _emit(errorMsg);
          contextManager.addMessage(errorMsg);
        }
        break;

      case 'date':
        // Step 5: Date — only reached if user typed a date manually
        final date = _parseDateFromText(trimmed);
        if (date != null) {
          _guidedTransactionDate = date;
          await _confirmAndCreateTransaction();
        } else {
          final errorMsg = _createMessage(
            ChatRole.assistant,
            'Please tap "Today" or pick a date from the calendar.',
            messageType: ChatMessageType.text,
          );
          _emit(errorMsg);
          contextManager.addMessage(errorMsg);
        }
        break;
    }
  }

  /// Called when the user taps a category chip in the guided flow.
  void resolveGuidedCategory(String categoryName, String categoryLabel) {
    if (_guidedTransactionStep != 'category') return;
    _guidedTransactionCategory = categoryName;
    _guidedTransactionStep = 'account';

    // Show user's selection as a chat message
    final userMsg = _createMessage(ChatRole.user, categoryLabel);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    final msg = _createMessage(
      ChatRole.assistant,
      'Which payment method?',
      messageType: ChatMessageType.guidedAccountPicker,
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Called when the user taps a payment type chip (Bank/Card/Wallet/Cash/Savings).
  /// If Cash is selected, skip the sub-picker and go straight to date.
  Future<void> resolveGuidedAccountType(
    String accountTypeKey,
    String accountTypeLabel,
    List<Account> accountsOfType,
  ) async {
    if (_guidedTransactionStep != 'account') return;

    // Show user's selection as a chat message
    final userMsg = _createMessage(ChatRole.user, accountTypeLabel);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    // Cash → no sub-picker needed
    if (accountTypeKey == AccountType.cash.name) {
      final cashAccount = accountsOfType.firstOrNull;
      _guidedTransactionAccount = cashAccount?.id ?? AccountType.cash.name;
      _guidedTransactionStep = 'date';

      final msg = _createMessage(
        ChatRole.assistant,
        'When was this transaction?',
        messageType: ChatMessageType.datePicker,
      );
      _emit(msg);
      contextManager.addMessage(msg);
      return;
    }

    // Other types → show sub-picker with actual named accounts
    _guidedTransactionStep = 'accountSub';

    final msg = _createMessage(
      ChatRole.assistant,
      'Which ${_accountTypeLabel(accountTypeKey)}?',
      messageType: ChatMessageType.guidedAccountSubPicker,
      metadata: {
        'accountType': accountTypeKey,
        'accounts': accountsOfType
            .map((a) => {'id': a.id, 'name': a.name})
            .toList(),
      },
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Called when the user selects a specific account in the sub-picker.
  void resolveGuidedAccountSub(String accountId, String accountName) {
    if (_guidedTransactionStep != 'accountSub') return;
    _guidedTransactionAccount = accountId;
    _guidedTransactionStep = 'date';

    // Show user's selection as a chat message
    final userMsg = _createMessage(ChatRole.user, accountName);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    final msg = _createMessage(
      ChatRole.assistant,
      'When was this transaction?',
      messageType: ChatMessageType.datePicker,
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Called when the user selects a date in the guided flow.
  /// [displayLabel] is the human-readable label ("Today" or "Aug 03, 2026").
  /// [isoDate] is the ISO string passed to the transaction.
  Future<void> resolveGuidedDate(String displayLabel, DateTime date) async {
    if (_guidedTransactionStep != 'date') return;

    // Show user's selection as a chat message
    final userMsg = _createMessage(ChatRole.user, displayLabel);
    _emit(userMsg);
    contextManager.addMessage(userMsg);

    _guidedTransactionDate = date;
    await _confirmAndCreateTransaction();
  }

  String _accountTypeLabel(String key) {
    switch (key) {
      case 'bank':
        return 'Bank Account';
      case 'creditCard':
        return 'Credit Card';
      case 'wallet':
        return 'Wallet';
      case 'savings':
        return 'Savings Account';
      default:
        return 'account';
    }
  }

  /// Called when the user taps a payment method chip in the guided flow.
  void resolveGuidedAccount(String accountName) {
    if (_guidedTransactionStep != 'account') return;
    _guidedTransactionAccount = accountName;
    _guidedTransactionStep = 'date';

    final msg = _createMessage(
      ChatRole.assistant,
      'When was this transaction?',
      messageType: ChatMessageType.datePicker,
    );
    _emit(msg);
    contextManager.addMessage(msg);
  }

  /// Confirms and creates the transaction from guided flow data.
  Future<void> _confirmAndCreateTransaction() async {
    if (_guidedTransactionDescription == null ||
        _guidedTransactionAmount == null ||
        _guidedTransactionCategory == null ||
        _guidedTransactionAccount == null ||
        _guidedTransactionDate == null) {
      return;
    }

    final type = _guidedTransactionType == 'expense'
        ? TransactionType.expense
        : TransactionType.income;

    // Create tool call for the transaction
    final toolCall = ToolCall(
      tool: 'createTransaction',
      arguments: {
        'type': type.name,
        'amount': _guidedTransactionAmount,
        'category': _guidedTransactionCategory,
        'account': _guidedTransactionAccount,
        'dateIso': _guidedTransactionDate
            ?.toIso8601String(), // matches dispatcher
        'note': _guidedTransactionDescription, // fills the notes field
        'payee':
            _guidedTransactionDescription, // also used as transaction title
      },
    );

    // Execute the tool
    final result = await dispatcher.dispatch(toolCall);

    // Clear guided state AFTER execution
    _guidedTransactionType = null;
    _guidedTransactionDescription = null;
    _guidedTransactionAmount = null;
    _guidedTransactionCategory = null;
    _guidedTransactionAccount = null;
    _guidedTransactionDate = null;
    _guidedTransactionStep = '';

    if (result.ok) {
      final confirmMsg = _createMessage(
        ChatRole.assistant,
        '✅ Transaction added successfully!',
      );
      _emit(confirmMsg);
      contextManager.addMessage(confirmMsg);
    } else {
      final errorMsg = _createMessage(
        ChatRole.system,
        '⚠️ Failed to create transaction: ${result.error}',
      );
      _emit(errorMsg);
      contextManager.addMessage(errorMsg);
    }
  }

  /// Called by the UI when the user selects an account from the picker.
  /// Completes the pending [_pendingAccountCompleter] so the pipeline resumes.
  void resolveAccountSelection(String? accountId) {
    if (_pendingAccountCompleter != null &&
        !_pendingAccountCompleter!.isCompleted) {
      // Hide the picker message
      if (_pendingPickerMessageId != null) {
        final hidden = ChatMessage(
          id: _pendingPickerMessageId!,
          role: ChatRole.assistant,
          content: '',
          isHidden: true,
          sessionId: _sessionId,
          timestamp: DateTime.now(),
        );
        _emit(hidden);
      }
      _pendingAccountCompleter!.complete(accountId);
      _pendingAccountCompleter = null;
      _pendingPickerMessageId = null;
    }
  }

  /// Called by the UI when the user selects a category from the picker.
  void resolveCategorySelection(String? categoryName) {
    if (_pendingCategoryCompleter != null &&
        !_pendingCategoryCompleter!.isCompleted) {
      if (_pendingPickerMessageId != null) {
        final hidden = ChatMessage(
          id: _pendingPickerMessageId!,
          role: ChatRole.assistant,
          content: '',
          isHidden: true,
          sessionId: _sessionId,
          timestamp: DateTime.now(),
        );
        _emit(hidden);
      }
      _pendingCategoryCompleter!.complete(categoryName);
      _pendingCategoryCompleter = null;
      _pendingPickerMessageId = null;
    }
  }

  // ── Private: account enrichment ───────────────────────────────────────────

  Future<ToolCall> _enrichTransactionAccount(ToolCall call) async {
    const accountTools = {'createTransaction', 'createRecurringTransaction'};
    if (!accountTools.contains(call.tool)) return call;

    final rawAccount = call.arguments['account'] as String?;

    // Get last user message for fallback
    final allMsgs = contextManager.allMessages;
    ChatMessage? lastUser;
    for (var i = allMsgs.length - 1; i >= 0; i--) {
      if (allMsgs[i].role == ChatRole.user) {
        lastUser = allMsgs[i];
        break;
      }
    }

    // Try sources independently — never concatenate (confuses the scorer)
    final sources = [
      if (rawAccount != null && rawAccount.isNotEmpty) rawAccount,
      if (lastUser != null) lastUser.content,
    ];

    for (final text in sources) {
      final resolved = dispatcher.tryResolveAccountFromText(text);
      debugPrint('[AccountEnrich] text="$text" resolved=$resolved');
      if (resolved != null) {
        final newArgs = Map<String, dynamic>.from(call.arguments)
          ..['account'] = resolved;
        return ToolCall(tool: call.tool, arguments: newArgs);
      }
    }

    // Nothing matched — detect type and show picker pre-filtered to that type
    final typeText = rawAccount?.isNotEmpty == true
        ? rawAccount!
        : (lastUser?.content ?? '');
    final detectedType = typeText.isNotEmpty
        ? dispatcher.detectAccountTypeFromText(typeText)
        : null;
    debugPrint('[AccountEnrich] ambiguous, detectedType=$detectedType');

    final accountId = await _showAccountPicker(preselectedType: detectedType);
    if (accountId != null) {
      final newArgs = Map<String, dynamic>.from(call.arguments)
        ..['account'] = accountId;
      return ToolCall(tool: call.tool, arguments: newArgs);
    }

    return call;
  }

  /// Emits an account-type picker message and waits for the user to complete
  /// the two-step selection. Returns the chosen account ID, or null if skipped.
  /// If [preselectedType] is provided, jumps straight to the account list.
  Future<String?> _showAccountPicker({AccountType? preselectedType}) async {
    final pickerId = _uuid.v4();
    _pendingPickerMessageId = pickerId;
    _pendingAccountCompleter = Completer<String?>();

    final pickerMsg = ChatMessage(
      id: pickerId,
      role: ChatRole.assistant,
      content: 'Which payment method did you use?',
      messageType: preselectedType != null
          ? ChatMessageType.accountPicker
          : ChatMessageType.accountTypePicker,
      metadata: preselectedType != null
          ? {'accountType': preselectedType.name}
          : null,
      sessionId: _sessionId,
      timestamp: DateTime.now(),
    );
    _emit(pickerMsg);

    return _pendingAccountCompleter!.future;
  }

  // ── Private: category enrichment ─────────────────────────────────────────

  Future<ToolCall> _enrichTransactionCategory(ToolCall call) async {
    const categoryTools = {'createTransaction', 'createRecurringTransaction'};
    if (!categoryTools.contains(call.tool)) return call;

    final typeStr = call.arguments['type'] as String? ?? 'expense';
    final type = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );
    final categoryInput = call.arguments['category'] as String?;

    // Build a richer query by combining the LLM's category + last user message.
    // This makes candidates context-aware (Issue 3).
    final allMsgs = contextManager.allMessages;
    String? lastUserText;
    for (var i = allMsgs.length - 1; i >= 0; i--) {
      if (allMsgs[i].role == ChatRole.user) {
        lastUserText = allMsgs[i].content;
        break;
      }
    }

    // Combine: category arg (more specific) + user message words
    final richQuery = [
      if (categoryInput != null && categoryInput.isNotEmpty) categoryInput,
      if (lastUserText != null) lastUserText,
    ].join(' ');

    final candidates = dispatcher.resolveCategoryWithCandidates(
      type,
      richQuery.isNotEmpty ? richQuery : categoryInput,
    );

    final chosen = await _showCategoryPicker(candidates, type);

    if (chosen != null) {
      final newArgs = Map<String, dynamic>.from(call.arguments)
        ..['category'] = chosen;
      return ToolCall(tool: call.tool, arguments: newArgs);
    }
    return call;
  }

  Future<String?> _showCategoryPicker(
    List<TransactionCategory> candidates,
    TransactionType type,
  ) async {
    final pickerId = _uuid.v4();
    _pendingPickerMessageId = pickerId;
    _pendingCategoryCompleter = Completer<String?>();

    final pickerMsg = ChatMessage(
      id: pickerId,
      role: ChatRole.assistant,
      content: 'Select a category:',
      messageType: ChatMessageType.categoryPicker,
      metadata: {
        'candidates': candidates.map((c) => c.name).toList(),
        'suggested': candidates.first.name,
        'transactionType': type.name,
      },
      sessionId: _sessionId,
      timestamp: DateTime.now(),
    );
    _emit(pickerMsg);

    return _pendingCategoryCompleter!.future;
  }

  // ── Private: utilities ────────────────────────────────────────────────────

  /// Extracts a meaningful note from the user message and injects it into
  /// the transaction if note/payee are not already set.
  ///
  /// Logic:
  /// - Strip action verbs and payment phrases from the user message
  /// - What remains (e.g. "toys", "groceries", "mobile recharge") becomes the note
  /// - If the remaining text matches a category, it's still added as a note
  ToolCall _enrichTransactionNote(ToolCall call) {
    const noteTools = {'createTransaction', 'createRecurringTransaction'};
    if (!noteTools.contains(call.tool)) return call;

    // Already has a note or payee — nothing to add
    final existingNote = call.arguments['note'] as String?;
    final existingPayee = call.arguments['payee'] as String?;
    if ((existingNote != null && existingNote.isNotEmpty) ||
        (existingPayee != null && existingPayee.isNotEmpty)) {
      return call;
    }

    // Find last user message
    final allMsgs = contextManager.allMessages;
    String? lastUserText;
    for (var i = allMsgs.length - 1; i >= 0; i--) {
      if (allMsgs[i].role == ChatRole.user) {
        lastUserText = allMsgs[i].content;
        break;
      }
    }
    if (lastUserText == null || lastUserText.trim().isEmpty) return call;

    final extracted = _extractItemFromMessage(lastUserText);
    if (extracted == null || extracted.isEmpty) return call;

    final newArgs = Map<String, dynamic>.from(call.arguments)
      ..['note'] = extracted;
    return ToolCall(tool: call.tool, arguments: newArgs);
  }

  /// Extracts the item/thing the user bought/paid for from their message.
  /// e.g. "bought toys with federal credit card" → "toys"
  /// e.g. "paid electricity bill" → "electricity bill"
  String? _extractItemFromMessage(String text) {
    var cleaned = text.trim().toLowerCase();

    // Remove payment method phrases
    cleaned = cleaned
        .replaceAll(RegExp(r'\b(using|with|via|through|on|by|from)\b.*$'), '')
        .trim();

    // Remove leading action verbs
    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'^(bought|purchased|paid|spent|got|added|add|log|record|created?'
            r'|bought for|paid for|expense for|expense of)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Remove amount patterns
    cleaned = cleaned
        .replaceAll(
          RegExp(
            r'₹[\d,]+(?:\.\d{1,2})?|[\d,]+(?:\.\d{1,2})?\s*(?:₹|rs\.?|rupees?)',
          ),
          '',
        )
        .trim();

    // Remove filler words
    cleaned = cleaned
        .replaceAll(RegExp(r'\b(a|an|the|some|my|for|of)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty || cleaned.length < 2) return null;

    // Capitalise first letter
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  ChatMessage _createMessage(
    ChatRole role,
    String content, {
    ChatMessageType messageType = ChatMessageType.text,
    Map<String, dynamic>? metadata,
  }) => ChatMessage(
    id: _uuid.v4(),
    role: role,
    content: content,
    messageType: messageType,
    metadata: metadata,
    isStreaming: false,
    sessionId: _sessionId,
    timestamp: DateTime.now(),
  );

  void _emit(ChatMessage message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }

  void _cancelSubscriptions() {
    _tokenSub?.cancel();
    _completeSub?.cancel();
    _errorSub?.cancel();
    _tokenSub = null;
    _completeSub = null;
    _errorSub = null;
  }

  // ── Amount helpers ────────────────────────────────────────────────────────

  /// Returns true when the LLM emitted a createTransaction call but the user
  /// never mentioned a specific amount in the conversation — meaning the model
  /// hallucinated the amount.
  bool _isHallucinatedAmount(ToolCall call) {
    final amount = call.arguments['amount'];
    if (amount == null) return true; // no amount at all
    final amtNum = (amount as num?)?.toDouble() ?? 0;
    if (amtNum <= 0) return true;

    // Check if any recent user message contained a number that could be the amount
    final msgs = contextManager.allMessages;
    for (var i = msgs.length - 1; i >= 0 && i >= msgs.length - 4; i--) {
      if (msgs[i].role == ChatRole.user) {
        final text = msgs[i].content;
        if (_parseAmountFromText(text) != null) return false;
      }
    }
    return true; // no amount found in recent user messages
  }

  /// Parses a numeric amount from a user message.
  /// Returns null if no clear number is found.
  double? _parseAmountFromText(String text) {
    // Match: ₹500, Rs 500, 500 rupees, or bare number >= 1
    final patterns = [
      RegExp(
        r'(?:₹|rs\.?|rupees?)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([\d,]+(?:\.\d{1,2})?)\s*(?:₹|rs\.?|rupees?)',
        caseSensitive: false,
      ),
      RegExp(r'\b([\d,]+(?:\.\d{1,2})?)\b'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final cleaned = match.group(1)!.replaceAll(',', '');
        final value = double.tryParse(cleaned);
        if (value != null && value >= 1) return value;
      }
    }
    return null;
  }

  /// Parses a date from user input (e.g., "today", "yesterday", "2024-08-03").
  DateTime? _parseDateFromText(String text) {
    final lower = text.toLowerCase().trim();
    final now = DateTime.now();

    // Handle relative dates
    if (lower == 'today') {
      return DateTime(now.year, now.month, now.day);
    }
    if (lower == 'yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTime(yesterday.year, yesterday.month, yesterday.day);
    }

    // Try parsing ISO format (YYYY-MM-DD)
    try {
      final parsed = DateTime.parse(text);
      return parsed;
    } catch (_) {}

    // Try parsing common formats
    final formats = [
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})', multiLine: false),
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})', multiLine: false),
    ];

    for (final format in formats) {
      final match = format.firstMatch(text);
      if (match != null) {
        try {
          final groups = match.groups([1, 2, 3]);
          int day, month, year;

          if (text.contains(RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}'))) {
            // YYYY-MM-DD format
            year = int.parse(groups[0]!);
            month = int.parse(groups[1]!);
            day = int.parse(groups[2]!);
          } else {
            // DD-MM-YYYY or MM-DD-YYYY format
            day = int.parse(groups[0]!);
            month = int.parse(groups[1]!);
            year = int.parse(groups[2]!);
          }

          return DateTime(year, month, day);
        } catch (_) {}
      }
    }

    return null;
  }

  /// Dispatches a validated tool call and emits the result, bypassing the LLM.
  /// Used when resuming a pending transaction after the user provides the amount.
  Future<void> _dispatchAndRespond(ToolCall call) async {
    _generatingDepth++;
    try {
      final enrichedCall = await _enrichTransactionAccount(call);
      final finalCall = await _enrichTransactionCategory(enrichedCall);
      final snapshot = _captureSnapshotIfNeeded(finalCall);
      final result = await dispatcher.dispatch(finalCall);

      if (!result.ok) {
        final errMsg = _createMessage(
          ChatRole.system,
          '⚠️ ${result.error ?? 'Tool failed'}',
        );
        _emit(errMsg);
        contextManager.addMessage(errMsg);
        return;
      }

      _maybePushUndo(finalCall, result, snapshot);

      final summary = ToolResultFormatter.format(finalCall.tool, result);
      if (summary != null) {
        final toolResultMsg = _createMessage(
          ChatRole.tool,
          '[TOOL RESULT]\n${_resultToContext(finalCall.tool, result)}\n[END TOOL RESULT]',
        );
        contextManager.addMessage(toolResultMsg);
        final summaryMsg = _createMessage(ChatRole.assistant, summary);
        _emit(summaryMsg);
        contextManager.addMessage(
          _createMessage(
            ChatRole.assistant,
            'Here is the data from your records.',
          ),
        );
        unawaited(contextManager.maybeSummarise(engine));
      }
    } finally {
      _generatingDepth = (_generatingDepth - 1).clamp(0, 999);
    }
  }

  String _resultToContext(String tool, ToolResult result) {
    if (result.result == null) return 'ok';
    final map = result.result!;
    // Return a compact JSON-like string for the LLM to summarise
    final entries = map.entries
        .where((e) => e.value != null)
        .map((e) => '"${e.key}": ${_valueToString(e.value)}')
        .join(', ');
    return '{$entries}';
  }

  String _valueToString(dynamic v) {
    if (v is String) return '"$v"';
    if (v is List)
      return '[${v.take(5).map(_valueToString).join(', ')}${v.length > 5 ? '...' : ''}]';
    if (v is Map) return '{...}';
    return v.toString();
  }
}
