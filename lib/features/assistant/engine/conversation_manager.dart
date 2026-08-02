import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
import '../preprocessing/transaction_extractor.dart';
import '../validation/tool_call_validator.dart';

/// Maximum number of retries when the LLM responds without a required tool call.
const _maxToolRetries = 3;

/// Maximum entries held in the undo stack per chat session.
const _maxUndoStackSize = 10;

// ── Intent-detection patterns ─────────────────────────────────────────────────

/// Returns `true` when [text] looks like a "log a transaction" command
/// (as opposed to a general question, analysis request, or greeting).
///
/// The extractor pre-check is only applied to these messages so that
/// queries like "What's my balance?" or "How are you?" aren't interrupted
/// by the clarification gate.
bool _looksLikeTransactionCommand(String text) {
  final lower = text.toLowerCase();
  // Action verbs that strongly signal a new transaction entry
  return RegExp(
    r'\b(spent|paid|bought|purchased|expense|debited|charged'
    r'|received|got|earned|salary|credited|income'
    r'|transfer(red)?|moved|add transaction|log transaction'
    r'|record transaction|new transaction|add expense|add income)\b',
    caseSensitive: false,
  ).hasMatch(lower);
}

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

/// Returns `true` if the LLM response looks like it contains financial data
/// answers without having gone through a tool call first — which means the
/// model is hallucinating numbers.
bool _responseNeedsData(String response) {
  final lower = response.toLowerCase();

  // Explicit deflection phrases
  if (lower.contains("i don't have access") ||
      lower.contains("i can't tell") ||
      lower.contains("i'm unable") ||
      lower.contains("i cannot check") ||
      lower.contains("you would need to check") ||
      lower.contains("i don't know your") ||
      lower.contains("i have no information")) {
    return true;
  }

  // Detect hallucinated financial answers: contains rupee symbol or financial
  // keywords paired with numbers — but NO tool call was emitted.
  final hasRupeeAmount =
      response.contains('₹') ||
      RegExp(
        r'\b\d[\d,]+\s*(rs|rupee|lakh|crore)',
        caseSensitive: false,
      ).hasMatch(response);
  final hasFinancialKeywords = RegExp(
    r'\b(spent|spend|balance|income|expense|budget|saving|transaction|amount'
    r'|total|month|week|year|forecast|summary)\b',
    caseSensitive: false,
  ).hasMatch(lower);

  // If the reply looks like a financial answer with made-up numbers, retry.
  if (hasRupeeAmount && hasFinancialKeywords) return true;

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
  final _extractor = TransactionExtractor();
  final _uuid = const Uuid();

  // ── Pending account selection ──────────────────────────────────────────────
  // When the account cannot be resolved from the user's message, we pause the
  // pipeline and wait for the user to pick one from the UI.
  Completer<String?>? _pendingAccountCompleter;
  String? _pendingPickerMessageId;

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

    // ── Transaction extraction pre-check ─────────────────────────────────────
    // Only run the extractor when the message looks like a transaction log
    // command (contains action keywords). Skip it for general questions,
    // summaries, plan queries, greetings, etc. — those go straight to the LLM.
    if (_looksLikeTransactionCommand(text)) {
      final extracted = _extractor.extract(text);
      if (extracted.needsClarification &&
          extracted.overallConfidence < 0.85 &&
          extracted.clarificationQuestion != null) {
        final clarifyMsg = _createMessage(
          ChatRole.assistant,
          extracted.clarificationQuestion!,
        );
        _emit(clarifyMsg);
        contextManager.addMessage(clarifyMsg);
        return;
      }
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

      // For transaction mutations, extract the account mention from the
      // last user message and inject it if the model omitted the field.
      final enrichedCall = _enrichTransactionAccount(toolCall);

      // Capture snapshot for undo BEFORE dispatch (for update/delete)
      final snapshot = _captureSnapshotIfNeeded(enrichedCall);

      // Execute tool
      final result = await dispatcher.dispatch(enrichedCall);
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
      _maybePushUndo(enrichedCall, result, snapshot);

      // Try to format the result deterministically (guaranteed accurate numbers).
      final deterministicSummary = ToolResultFormatter.format(
        enrichedCall.tool,
        result,
      );

      if (deterministicSummary != null) {
        // Store the real data as a tool message (excluded from buildPrompt)
        // so the model doesn't learn to copy these number patterns.
        final toolResultMsg = _createMessage(
          ChatRole.tool,
          '[TOOL RESULT]\n${_resultToContext(toolCall.tool, result)}\n[END TOOL RESULT]',
        );
        contextManager.addMessage(toolResultMsg);

        // Emit the accurate summary to the UI.
        final summaryMsg = _createMessage(
          ChatRole.assistant,
          deterministicSummary,
        );
        _emit(summaryMsg);
        // Add a short neutral acknowledgement to context (not the number-filled
        // summary) so the model doesn't learn to copy financial number patterns.
        final contextAck = _createMessage(
          ChatRole.assistant,
          'Here is the data from your records.',
        );
        contextManager.addMessage(contextAck);
        unawaited(contextManager.maybeSummarise(engine));
      } else {
        // No deterministic formatter for this tool — fall back to LLM summary.
        final toolResultMsg = _createMessage(
          ChatRole.tool,
          '[TOOL RESULT]\n${_resultToContext(enrichedCall.tool, result)}\n[END TOOL RESULT]',
        );
        contextManager.addMessage(toolResultMsg);

        // Use a tool-free system prompt so the model summarises naturally
        // instead of emitting another tool call.
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

  // ── Private: account enrichment ───────────────────────────────────────────

  /// For transaction creation/update tools, tries to resolve the account from
  /// the last user message. If the account field is already set, returns the
  /// call unchanged. If no account can be inferred, shows an interactive picker
  /// in the chat and awaits the user's selection.
  Future<ToolCall> _enrichTransactionAccount(ToolCall call) async {
    const accountTools = {'createTransaction', 'createRecurringTransaction'};
    if (!accountTools.contains(call.tool)) return call;

    // Already has an account argument — nothing to do.
    if (call.arguments['account'] != null &&
        (call.arguments['account'] as String).isNotEmpty) {
      return call;
    }

    // Try to extract account mention from the last user message in context.
    final allMsgs = contextManager.allMessages;
    ChatMessage? lastUser;
    for (var i = allMsgs.length - 1; i >= 0; i--) {
      if (allMsgs[i].role == ChatRole.user) {
        lastUser = allMsgs[i];
        break;
      }
    }
    if (lastUser != null) {
      final resolved = dispatcher.tryResolveAccountFromText(lastUser.content);
      if (resolved != null) {
        final newArgs = Map<String, dynamic>.from(call.arguments)
          ..['account'] = resolved;
        return ToolCall(tool: call.tool, arguments: newArgs);
      }
    }

    // No account found — show the two-step picker.
    final accountId = await _showAccountPicker();
    if (accountId != null) {
      final newArgs = Map<String, dynamic>.from(call.arguments)
        ..['account'] = accountId;
      return ToolCall(tool: call.tool, arguments: newArgs);
    }

    return call; // user dismissed — proceed with default
  }

  /// Emits an account-type picker message and waits for the user to complete
  /// the two-step selection. Returns the chosen account ID, or null if skipped.
  Future<String?> _showAccountPicker() async {
    final pickerId = _uuid.v4();
    _pendingPickerMessageId = pickerId;
    _pendingAccountCompleter = Completer<String?>();

    final pickerMsg = ChatMessage(
      id: pickerId,
      role: ChatRole.assistant,
      content: 'Which payment method did you use?',
      messageType: ChatMessageType.accountTypePicker,
      sessionId: _sessionId,
      timestamp: DateTime.now(),
    );
    _emit(pickerMsg);

    return _pendingAccountCompleter!.future;
  }

  ChatMessage _createMessage(ChatRole role, String content) => ChatMessage(
    id: _uuid.v4(),
    role: role,
    content: content,
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
