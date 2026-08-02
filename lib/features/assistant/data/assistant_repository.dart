import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/chat_message.dart';

/// Persistence model for a single chat message.
///
/// Wraps [ChatMessage] with the [sessionId] field for SQLite storage.
/// The transient [isStreaming] flag is never persisted.
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String sessionId;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AssistantMessage.fromMap(Map<String, dynamic> map) =>
      AssistantMessage(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        role: ChatRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => ChatRole.system,
        ),
        content: map['content'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  /// Converts to a [ChatMessage] suitable for the UI.
  ChatMessage toChatMessage() => ChatMessage(
    id: id,
    role: role,
    content: content,
    isStreaming: false,
    sessionId: sessionId,
    timestamp: timestamp,
  );
}

/// SQLite repository for [AssistantMessage] objects.
///
/// Persists only user-visible messages (user and assistant roles).
/// System prompts, tool instructions, and context summaries are never stored.
class AssistantRepository {
  static const _table = 'assistant_messages';
  static const _sessionKey = 'flux_ai_session_id';
  static const _maxMessages = 500;
  static final _uuid = Uuid();

  // ── Session management ─────────────────────────────────────────────────────

  /// Returns the active session ID from SharedPreferences, or creates a new one.
  Future<String> getOrCreateSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_sessionKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = _uuid.v4();
    await prefs.setString(_sessionKey, newId);
    return newId;
  }

  /// Creates and persists a new session ID, discarding the old one.
  Future<String> createNewSession() async {
    final prefs = await SharedPreferences.getInstance();
    final newId = _uuid.v4();
    await prefs.setString(_sessionKey, newId);
    return newId;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the most recent [limit] messages for [sessionId], oldest first.
  Future<List<AssistantMessage>> getRecentSession(
    String sessionId, {
    int limit = 100,
  }) async {
    final rows = await AppDatabase.instance.query(
      _table,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
    );
    // Reverse so oldest is first (chronological display order)
    final messages = rows
        .take(limit)
        .map(AssistantMessage.fromMap)
        .toList()
        .reversed
        .toList();
    return messages;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Persists a single [AssistantMessage].
  ///
  /// Only [ChatRole.user] and [ChatRole.assistant] messages should be stored.
  /// Callers are responsible for filtering system/tool messages.
  Future<void> insertMessage(AssistantMessage message) async {
    await AppDatabase.instance.insert(_table, message.toMap());
  }

  /// Deletes all messages for [sessionId].
  Future<void> deleteSession(String sessionId) async {
    await AppDatabase.instance.delete(
      _table,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Deletes a single message by [id].
  Future<void> deleteMessage(String id) async {
    await AppDatabase.instance.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Ensures total row count stays within [_maxMessages] by deleting the
  /// oldest rows first. Call after each insert.
  Future<void> enforceMessageCap() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
    final count = result.first['cnt'] as int;
    if (count <= _maxMessages) return;

    final excess = count - _maxMessages;
    await db.execute(
      'DELETE FROM $_table WHERE id IN '
      '(SELECT id FROM $_table ORDER BY timestamp ASC LIMIT ?)',
      [excess],
    );
  }
}
