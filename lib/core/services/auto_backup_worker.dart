import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'auto_backup_service.dart';
import 'backup_service.dart';
import '../../features/assistant/alert_worker.dart';

/// Top-level entry point for the WorkManager background isolate.
///
/// Handles all background tasks registered by the app:
/// - [AutoBackupService.backgroundTaskName] → auto-backup to Google Drive
/// - `flux_ai_alert_evaluation` → daily Flux AI proactive alert evaluation
///
/// Must be a top-level / static function annotated with
/// `@pragma('vm:entry-point')` so AOT-compiled release builds keep it in
/// the tree-shaken binary that WorkManager invokes.
@pragma('vm:entry-point')
void autoBackupDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // ── Alert evaluation ────────────────────────────────────────────────────
    if (task == 'flux_ai_alert_evaluation') {
      return runAlertEvaluationTask();
    }

    // ── Auto-backup ─────────────────────────────────────────────────────────
    if (task != AutoBackupService.backgroundTaskName) {
      return true; // Unknown task — let WorkManager reschedule/retry.
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Make sure auto-backup is still enabled by the user.
      final enabled = prefs.getBool(AutoBackupService.prefKeyEnabled) ?? false;
      if (!enabled) {
        debugPrint('[AutoBackupWorker] Auto-backup is disabled — skipping.');
        return true;
      }

      // 2. Make sure we already have a target Drive file (created during
      //    the user-driven setup flow).  The worker only ever overwrites
      //    a known file — it never creates new ones.
      final targetId = prefs.getString(AutoBackupService.prefKeyTargetId);
      if (targetId == null || targetId.isEmpty) {
        debugPrint('[AutoBackupWorker] No target file ID — skipping.');
        return true;
      }

      // 3. Skip if a backup has already happened today.
      final today = _todayString();
      final lastDate = prefs.getString(AutoBackupService.prefKeyLastDate);
      if (lastDate == today) {
        debugPrint('[AutoBackupWorker] Backup already done today — skipping.');
        return true;
      }

      // 4. Skip if the scheduled time hasn't passed yet.
      final hour = prefs.getInt(AutoBackupService.prefKeyHour) ?? 2;
      final minute = prefs.getInt(AutoBackupService.prefKeyMinute) ?? 0;
      final now = DateTime.now();
      final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (now.isBefore(scheduled)) {
        debugPrint(
          '[AutoBackupWorker] Scheduled time ($hour:$minute) has not yet '
          'passed — skipping.',
        );
        return true;
      }

      // 5. Get a fresh Drive access token.
      final token = await _getValidAccessToken(prefs);
      if (token == null) {
        await _writeStatus(
          prefs,
          status: AutoBackupStatus.failed,
          error: 'No valid Drive access token available.',
        );
        return false;
      }

      // 6. Signal that the worker has started.
      await _writeStatus(prefs, status: AutoBackupStatus.running, error: null);

      // 7. Run the actual upload.
      final service = BackupService();
      final result = await service.overwriteBackupWithToken(
        accessToken: token,
        fileId: targetId,
      );

      if (result.success) {
        if (result.fileId != null && result.fileId != targetId) {
          await prefs.setString(
            AutoBackupService.prefKeyTargetId,
            result.fileId!,
          );
        }
        await prefs.setString(AutoBackupService.prefKeyLastDate, today);
        await _writeStatus(
          prefs,
          status: AutoBackupStatus.success,
          error: null,
        );
        debugPrint(
          '[AutoBackupWorker] Backup completed (id=${result.fileId}).',
        );
        return true;
      } else {
        await _writeStatus(
          prefs,
          status: AutoBackupStatus.failed,
          error: result.error,
        );
        debugPrint('[AutoBackupWorker] Backup failed: ${result.error}');
        return false;
      }
    } catch (e, st) {
      debugPrint('[AutoBackupWorker] Unexpected error: $e\n$st');
      try {
        final prefs = await SharedPreferences.getInstance();
        await _writeStatus(
          prefs,
          status: AutoBackupStatus.failed,
          error: e.toString(),
        );
      } catch (_) {}
      return false;
    }
  });
}

Future<String?> _getValidAccessToken(SharedPreferences prefs) async {
  final token = prefs.getString(AutoBackupService.prefKeyAccessToken);
  final expiryStr = prefs.getString(AutoBackupService.prefKeyTokenExpiry);
  if (token == null || token.isEmpty) return null;
  if (expiryStr != null) {
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry != null && expiry.isBefore(DateTime.now().toUtc())) {
      await prefs.remove(AutoBackupService.prefKeyAccessToken);
      await prefs.remove(AutoBackupService.prefKeyTokenExpiry);
      return null;
    }
  }
  return token;
}

Future<void> _writeStatus(
  SharedPreferences prefs, {
  required AutoBackupStatus status,
  String? error,
}) async {
  await prefs.setString(AutoBackupService.prefKeyWorkerStatus, status.name);
  await prefs.setString(
    AutoBackupService.prefKeyWorkerStatusTime,
    DateTime.now().toIso8601String(),
  );
  if (error != null) {
    await prefs.setString(AutoBackupService.prefKeyWorkerError, error);
  } else {
    await prefs.remove(AutoBackupService.prefKeyWorkerError);
  }
}

String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
