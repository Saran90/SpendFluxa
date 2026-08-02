import '../../../core/database/app_database.dart';
import '../models/alert_record.dart';

/// SQLite repository for [AlertRecord] objects.
///
/// Used by [AlertEngine] for 24-hour deduplication and to purge stale records.
class AlertRepository {
  static const _table = 'alert_records';

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the most recent [AlertRecord] matching [alertType] and [subject]
  /// that was emitted at or after [since]. Returns `null` if none found.
  Future<AlertRecord?> findRecent({
    required String alertType,
    required String subject,
    required DateTime since,
  }) async {
    final rows = await AppDatabase.instance.query(
      _table,
      where: 'alert_type = ? AND subject = ? AND emitted_at >= ?',
      whereArgs: [alertType, subject, since.toIso8601String()],
      orderBy: 'emitted_at DESC',
    );
    if (rows.isEmpty) return null;
    return AlertRecord.fromMap(rows.first);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Persists a new [AlertRecord].
  Future<void> insert(AlertRecord record) async {
    await AppDatabase.instance.insert(_table, record.toMap());
  }

  /// Deletes all [AlertRecord] rows with [emitted_at] older than [cutoff].
  ///
  /// Called at the start of each [AlertEngine.evaluateAll] run to prevent
  /// unbounded table growth.
  Future<void> deleteOlderThan(DateTime cutoff) async {
    await AppDatabase.instance.delete(
      _table,
      where: 'emitted_at < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Returns `true` if an alert of the same type and subject was emitted
  /// within the past 24 hours. Convenience wrapper around [findRecent].
  Future<bool> wasRecentlyEmitted({
    required String alertType,
    required String subject,
  }) async {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final record = await findRecent(
      alertType: alertType,
      subject: subject,
      since: since,
    );
    return record != null;
  }
}
