import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../data/assistant_repository.dart';
import '../engine/abstract_ai_engine.dart';
import '../engine/conversation_manager.dart';
import '../models/chat_message.dart';
import '../models/undo_stack_entry.dart';
import '../providers/assistant_providers.dart';
import '../validation/tool_call_validator.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Snapshot of all UI-visible assistant session state.
class AssistantSessionState {
  const AssistantSessionState({
    required this.messages,
    required this.isGenerating,
    required this.isModelLoaded,
    required this.modelStatus,
    required this.undoStack,
    required this.sessionId,
  });

  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoaded;
  final ModelLoadStatus modelStatus;
  final List<UndoStackEntry> undoStack;
  final String sessionId;

  AssistantSessionState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isModelLoaded,
    ModelLoadStatus? modelStatus,
    List<UndoStackEntry>? undoStack,
    String? sessionId,
  }) => AssistantSessionState(
    messages: messages ?? this.messages,
    isGenerating: isGenerating ?? this.isGenerating,
    isModelLoaded: isModelLoaded ?? this.isModelLoaded,
    modelStatus: modelStatus ?? this.modelStatus,
    undoStack: undoStack ?? this.undoStack,
    sessionId: sessionId ?? this.sessionId,
  );

  static const empty = AssistantSessionState(
    messages: [],
    isGenerating: false,
    isModelLoaded: false,
    modelStatus: ModelLoadStatus.notDownloaded,
    undoStack: [],
    sessionId: '',
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Riverpod [StateNotifier] that owns the chat session state.
///
/// Delegates message orchestration to [ConversationManager] and persists
/// user + assistant messages via [AssistantRepository].
class AssistantSessionNotifier extends StateNotifier<AssistantSessionState> {
  AssistantSessionNotifier({
    required this.conversationManager,
    required this.repository,
    required this.engine,
  }) : super(AssistantSessionState.empty) {
    _init();
  }

  final ConversationManager conversationManager;
  final AssistantRepository repository;
  final AbstractAiEngine engine;

  StreamSubscription<ChatMessage>? _messageSub;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    // 1. Get or create the active session ID
    final sessionId = await repository.getOrCreateSessionId();
    conversationManager.setSessionId(sessionId);

    // 2. Load recent history from SQLite — filter out any assistant messages
    // that are raw tool-call JSON (leaked from before the isHidden fix).
    final _filterValidator = ToolCallValidator();
    final history = await repository.getRecentSession(sessionId);
    final messages = <ChatMessage>[];
    for (final record in history) {
      final m = record.toChatMessage();
      if (m.role == ChatRole.assistant) {
        final tc = _filterValidator.tryParse(m.content);
        if (tc != null) {
          // Delete leaked tool-call JSON from DB so it never comes back.
          await repository.deleteMessage(record.id);
          continue;
        }
      }
      messages.add(m);
    }

    state = state.copyWith(
      sessionId: sessionId,
      messages: messages,
      isModelLoaded: engine.isModelLoaded,
      modelStatus: engine.isModelLoaded
          ? ModelLoadStatus.ready
          : ModelLoadStatus.loading,
    );

    // 3. Subscribe to ConversationManager message stream
    _messageSub = conversationManager.messageStream.listen(_onNewMessage);
  }

  // ── Message stream handler ────────────────────────────────────────────────

  void _onNewMessage(ChatMessage incoming) {
    final current = List<ChatMessage>.from(state.messages);
    final idx = current.indexWhere((m) => m.id == incoming.id);

    if (idx >= 0) {
      // Update existing (streaming token update or finalisation)
      current[idx] = incoming;
    } else {
      // New message
      current.add(incoming);
    }

    state = state.copyWith(
      messages: current,
      isGenerating: conversationManager.isGenerating,
      undoStack: conversationManager.undoStack,
    );

    // Persist user and assistant messages when finalised (skip hidden/tool messages)
    if (!incoming.isStreaming &&
        !incoming.isHidden &&
        (incoming.role == ChatRole.user ||
            incoming.role == ChatRole.assistant)) {
      _persistMessage(incoming);
    }
  }

  Future<void> _persistMessage(ChatMessage msg) async {
    final sessionId = state.sessionId;
    if (sessionId.isEmpty) return;

    final record = AssistantMessage(
      id: msg.id,
      sessionId: sessionId,
      role: msg.role,
      content: msg.content,
      timestamp: msg.timestamp ?? DateTime.now(),
    );
    await repository.insertMessage(record);
    await repository.enforceMessageCap();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isGenerating) return;
    // Intercept if a guided transaction flow is active
    if (conversationManager.isGuidedFlowActive) {
      await conversationManager.handleGuidedTransactionInput(text);
    } else {
      await conversationManager.handleUserMessage(text);
    }
    state = state.copyWith(isGenerating: false);
  }

  /// Initiates a guided transaction flow (expense or income).
  Future<void> startGuidedTransaction(String type) async {
    await conversationManager.startGuidedTransactionFlow(type);
    state = state.copyWith(isGenerating: false);
  }

  /// Handles user input for guided transaction step.
  Future<void> handleGuidedTransactionInput(String input) async {
    await conversationManager.handleGuidedTransactionInput(input);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the account picker widget when the user selects an account.
  void resolveAccountSelection(String? accountId) {
    conversationManager.resolveAccountSelection(accountId);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the category picker widget when the user selects a category.
  void resolveCategorySelection(String? categoryName) {
    conversationManager.resolveCategorySelection(categoryName);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the guided category picker when the user taps a category chip.
  void resolveGuidedCategory(String categoryName, String categoryLabel) {
    conversationManager.resolveGuidedCategory(categoryName, categoryLabel);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the guided account type picker when the user taps a type chip.
  Future<void> resolveGuidedAccountType(
    String accountTypeKey,
    String accountTypeLabel,
    List<Account> accountsOfType,
  ) async {
    await conversationManager.resolveGuidedAccountType(
      accountTypeKey,
      accountTypeLabel,
      accountsOfType,
    );
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the guided account sub-picker when the user selects a specific account.
  void resolveGuidedAccountSub(String accountId, String accountName) {
    conversationManager.resolveGuidedAccountSub(accountId, accountName);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the date picker when the user selects a date.
  Future<void> resolveGuidedDate(String displayLabel, DateTime date) async {
    await conversationManager.resolveGuidedDate(displayLabel, date);
    state = state.copyWith(isGenerating: false);
  }

  /// Called by the guided account picker when the user taps a payment method chip.
  void resolveGuidedAccount(String accountName) {
    conversationManager.resolveGuidedAccount(accountName);
    state = state.copyWith(isGenerating: false);
  }

  Future<void> undo() async {
    await conversationManager.handleUndo();
  }

  Future<void> undoAll() async {
    await conversationManager.handleUndoAll();
  }

  void cancelGeneration() {
    conversationManager.cancelGeneration();
    state = state.copyWith(isGenerating: false);
  }

  Future<void> clearChat() async {
    // Delete messages from DB
    await repository.deleteSession(state.sessionId);

    // Create a new session
    final newSessionId = await repository.createNewSession();
    conversationManager.setSessionId(newSessionId);
    conversationManager.clearSession();

    state = state.copyWith(
      messages: [],
      isGenerating: false,
      undoStack: [],
      sessionId: newSessionId,
    );
  }

  void updateModelStatus(ModelLoadStatus status) {
    state = state.copyWith(
      modelStatus: status,
      isModelLoaded: status == ModelLoadStatus.ready,
    );
  }

  void onAppPaused() => conversationManager.onAppPaused();
  void onAppResumed() => conversationManager.onAppResumed();

  @override
  void dispose() {
    _messageSub?.cancel();
    conversationManager.dispose();
    super.dispose();
  }
}
