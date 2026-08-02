import '../constants/system_prompt.dart';
import '../engine/abstract_ai_engine.dart';
import '../models/chat_message.dart';

/// In-memory snapshot of compressed conversation history.
///
/// Holds the summarised text of all messages that have been pushed out
/// of the active 10-message window. Never persisted to SQLite.
class ContextSummary {
  const ContextSummary({
    required this.text,
    required this.summarisedUpToIndex,
    required this.generatedAt,
  });

  /// Compressed summary text (≤ 200 tokens / ~150 words).
  final String text;

  /// The index (into the full message list) of the last message
  /// that has been included in this summary.
  final int summarisedUpToIndex;

  final DateTime generatedAt;
}

/// Manages the conversation history passed to the LLM on each inference call.
///
/// Enforces:
/// - An **active window** of at most the last 10 messages.
/// - A [ContextSummary] of at most ~200 tokens covering older messages.
///
/// Summary generation is triggered automatically after each assistant
/// response via [maybeSummarise]. It uses a non-streaming
/// [AbstractAiEngine.generateResponse] call so the chat UI is not updated.
class ContextWindowManager {
  ContextWindowManager();

  // Keep the active window small so the combined prompt stays under the
  // 2048-token model limit (system prompt ~400 tokens + history + output).
  static const _maxActiveMessages = 6;
  static const _maxSummaryWords = 150; // proxy for ~200 tokens

  /// Full message history for the current session (all roles).
  final List<ChatMessage> _allMessages = [];

  /// Compressed summary of history older than the active window.
  ContextSummary? _summary;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Appends [message] to the full history.
  void addMessage(ChatMessage message) {
    _allMessages.add(message);
  }

  /// Returns all messages in the full history (read-only copy).
  List<ChatMessage> get allMessages => List.unmodifiable(_allMessages);

  /// Builds the prompt string passed as the `prompt` argument to
  /// [AbstractAiEngine.generateResponseStreaming].
  ///
  /// Structure:
  /// ```
  /// [CONTEXT SUMMARY]
  /// <summary text>
  /// [END SUMMARY]
  ///
  /// User: ...
  /// Assistant: ...
  /// ```
  ///
  /// The system prompt is passed separately — it is NOT included here.
  String buildPrompt() {
    final parts = <String>[];

    // Prepend summary if one exists
    if (_summary != null && _summary!.text.isNotEmpty) {
      parts.add('[CONTEXT SUMMARY]\n${_summary!.text}\n[END SUMMARY]\n');
    }

    // Active window: last N messages
    final active = _allMessages.length <= _maxActiveMessages
        ? _allMessages
        : _allMessages.sublist(_allMessages.length - _maxActiveMessages);

    for (final msg in active) {
      if (msg.role == ChatRole.user) {
        parts.add('User: ${msg.content}');
      } else if (msg.role == ChatRole.assistant && !msg.isHidden) {
        parts.add('Assistant: ${msg.content}');
      } else if (msg.role == ChatRole.tool) {
        // Include tool results labelled as DATA so the model knows what was
        // fetched but doesn't copy the format as an assistant pattern.
        parts.add('Data: ${msg.content}');
      }
      // system messages excluded — they're reinforcement injections, not context
    }

    return parts.join('\n');
  }

  /// Checks whether old messages need summarising and, if so, calls the LLM
  /// to generate a new [ContextSummary].
  ///
  /// Should be called after every assistant message is finalised.
  /// Uses [AbstractAiEngine.generateResponse] (non-streaming) so the UI
  /// is not affected.
  Future<void> maybeSummarise(AbstractAiEngine engine) async {
    // Nothing to summarise if we are within the active window
    if (_allMessages.length <= _maxActiveMessages) return;

    // Messages that should be in the summary (everything before active window)
    final summaryEndIndex = _allMessages.length - _maxActiveMessages;
    final alreadyCovered = _summary?.summarisedUpToIndex ?? -1;

    // Only run if there are new messages to add to the summary
    if (summaryEndIndex - 1 <= alreadyCovered) return;

    final newToSummarise = _allMessages.sublist(
      alreadyCovered + 1,
      summaryEndIndex,
    );
    if (newToSummarise.isEmpty) return;

    final excerptLines = <String>[];
    for (final msg in newToSummarise) {
      if (msg.role == ChatRole.user) {
        excerptLines.add('User: ${msg.content}');
      } else if (msg.role == ChatRole.assistant) {
        excerptLines.add('Assistant: ${msg.content}');
      }
    }
    if (excerptLines.isEmpty) return;

    final existingSummary = _summary?.text;
    final summaryPrompt = _buildSummaryPrompt(
      excerptLines.join('\n'),
      existingSummary,
    );

    try {
      final raw = await engine.generateResponse(
        summaryPrompt,
        fluxAiSummarisationPrompt,
      );
      final truncated = _truncateToWordLimit(raw, _maxSummaryWords);

      _summary = ContextSummary(
        text: truncated,
        summarisedUpToIndex: summaryEndIndex - 1,
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      // Summarisation failure is non-fatal — the assistant continues
      // without a summary; older messages simply fall outside the window.
    }
  }

  /// Clears all messages and the current summary.
  /// Called when the user taps "Clear chat".
  void clear() {
    _allMessages.clear();
    _summary = null;
  }

  /// The current context summary, or `null` if none has been generated yet.
  ContextSummary? get currentSummary => _summary;

  // ── Private helpers ────────────────────────────────────────────────────────

  String _buildSummaryPrompt(String excerpt, String? existingSummary) {
    if (existingSummary != null && existingSummary.isNotEmpty) {
      return 'Previous summary:\n$existingSummary\n\n'
          'New conversation excerpt to incorporate:\n$excerpt';
    }
    return excerpt;
  }

  /// Truncates [text] so it contains at most [maxWords] whitespace-delimited
  /// words. Used as a proxy for the 200-token limit.
  static String _truncateToWordLimit(String text, int maxWords) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text.trim();
    return words.take(maxWords).join(' ');
  }
}
