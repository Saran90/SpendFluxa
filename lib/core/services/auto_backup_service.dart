import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

/// Lifecycle status of the background auto-backup worker.
///
/// Written by [autoBackupWorkerDispatcher] in the background isolate and
/// read by the foreground UI (via [AutoBackupService.workerStatus]) so the
/// app can show a loader while the upload is running and a success/error
/// snackbar when it finishes.
enum AutoBackupStatus {
  /// Worker hasn't reported anything since the last successful / failed run.
  idle,

  /// Worker is currently uploading the database to Drive.
  running,

  /// Worker finished successfully.
  success,

  /// Worker finished with an error.
  failed,
}

/// Manages the auto-backup schedule preference.
///
/// Auto-backup works as follows:
///   • The user enables the toggle and picks a daily time.
///   • [schedulePeriodicCheck] registers a WorkManager periodic task that
///     wakes the app up at roughly 15-minute intervals (the OS minimum).
///   • On every wake-up, [AutoBackupWorker] checks the persisted state and
///     only proceeds if the current time is at or past the scheduled time
///     and no backup has been done today.
///   • The target Drive file ID is stored so every daily backup overwrites
///     the same file (keeping a single up-to-date backup rather than
///     accumulating many files).
///   • The worker writes its progress to the prefs keys
///     [prefKeyWorkerStatus] / [prefKeyWorkerStatusTime] so the foreground
///     UI can show a non-dismissible loader / success snackbar the next
///     time the app is opened.
class AutoBackupService extends ChangeNotifier {
  // ── Public preference keys (used by AutoBackupWorker too) ─────────────────
  static const prefKeyEnabled = 'auto_backup_enabled';
  static const prefKeyHour = 'auto_backup_hour';
  static const prefKeyMinute = 'auto_backup_minute';
  static const prefKeyTargetId = 'auto_backup_target_file_id';
  static const prefKeyLastDate = 'auto_backup_last_date'; // yyyy-MM-dd

  /// Cached Drive access token (written by AuthService, read by worker).
  static const prefKeyAccessToken = 'google_drive_access_token';
  static const prefKeyTokenExpiry = 'google_drive_token_expiry';

  /// Worker progress: name of the [AutoBackupStatus] enum value.
  static const prefKeyWorkerStatus = 'auto_backup_worker_status';
  static const prefKeyWorkerStatusTime = 'auto_backup_worker_status_time';
  static const prefKeyWorkerError = 'auto_backup_worker_error';

  /// WorkManager task identifier.  Must match between the schedule call
  /// (foreground) and [autoBackupWorkerDispatcher] (background).
  static const backgroundTaskName = 'spendflux.auto_backup';

  // ── Legacy private keys (kept for backwards compatibility) ───────────────
  static const _keyEnabled = prefKeyEnabled;
  static const _keyHour = prefKeyHour;
  static const _keyMinute = prefKeyMinute;
  static const _keyTargetId = prefKeyTargetId;
  static const _keyLastDate = prefKeyLastDate;

  bool _enabled = false;
  int _hour = 2; // default 02:00
  int _minute = 0;
  String? _targetFileId;
  String? _lastBackupDate;

  /// Most recent worker status reported via prefs.
  AutoBackupStatus _workerStatus = AutoBackupStatus.idle;
  DateTime? _workerStatusTime;
  String? _workerError;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  String? get targetFileId => _targetFileId;
  AutoBackupStatus get workerStatus => _workerStatus;
  DateTime? get workerStatusTime => _workerStatusTime;
  String? get workerError => _workerError;

  /// Human-readable time string, e.g. "02:00 AM"
  String get timeLabel {
    final h = _hour % 12 == 0 ? 12 : _hour % 12;
    final m = _minute.toString().padLeft(2, '0');
    final period = _hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  AutoBackupService() {
    _load();
  }

  /// Completes once the service has loaded its persisted state.
  /// Await this before calling [isDueNow()] to avoid race conditions.
  Future<void> get ready => _readyCompleter.future;
  final _readyCompleter = _Completer();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _hour = prefs.getInt(_keyHour) ?? 2;
    _minute = prefs.getInt(_keyMinute) ?? 0;
    _targetFileId = prefs.getString(_keyTargetId);
    _lastBackupDate = prefs.getString(_keyLastDate);
    _readWorkerStatus(prefs);

    // Re-register the OS alarm on every app start in case it was cleared
    // (e.g. after a device reboot or app update).  We also register the
    // WorkManager periodic task so the worker can fire even when the app
    // is closed.
    if (_enabled) {
      await scheduleNotification();
      await schedulePeriodicCheck();
    }
    _readyCompleter._complete();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (value) {
      await scheduleNotification();
      await schedulePeriodicCheck();
    } else {
      await cancelNotification();
      await cancelPeriodicCheck();
    }
    notifyListeners();
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    if (_enabled) {
      await scheduleNotification(); // reschedule at new time
      await schedulePeriodicCheck();
    }
    notifyListeners();
  }

  /// Stores the Drive file ID that daily backups should overwrite.
  Future<void> setTargetFileId(String fileId) async {
    _targetFileId = fileId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTargetId, fileId);
    notifyListeners();
  }

  /// Clears the target file ID (e.g. when the user disables auto-backup).
  Future<void> clearTargetFileId() async {
    _targetFileId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTargetId);
    notifyListeners();
  }

  /// Records that a backup was done today so we don't repeat it.
  Future<void> markBackedUpToday() async {
    final today = _todayString();
    _lastBackupDate = today;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastDate, today);
  }

  /// Returns true when auto-backup is enabled and a backup is overdue:
  ///   1. Today's scheduled time has already passed AND no backup done today, OR
  ///   2. The last backup was on a previous day (missed backup — run immediately
  ///      whenever the app is opened regardless of scheduled time).
  bool isDueNow() {
    if (!_enabled) return false;

    final today = _todayString();
    if (_lastBackupDate == today) return false; // already done today

    final now = DateTime.now();
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      _hour,
      _minute,
    );

    // If we have never backed up, wait until the scheduled time passes today
    if (_lastBackupDate == null) {
      return !now.isBefore(scheduledToday);
    }

    // If scheduled time hasn't passed yet today, only trigger if we missed
    // a previous day (i.e. last backup was before today)
    if (now.isBefore(scheduledToday)) {
      final lastDate = DateTime.tryParse(_lastBackupDate!);
      if (lastDate == null) return true;
      // Check if last backup date is before today
      final todayMidnight = DateTime(now.year, now.month, now.day);
      return lastDate.isBefore(todayMidnight);
    }

    // Scheduled time has passed today and we haven't backed up yet today
    return true;
  }

  /// Schedule the daily OS-level alarm via [NotificationService].
  Future<void> scheduleNotification() async {
    if (!_enabled) return;
    await NotificationService().scheduleAutoBackup(
      hour: _hour,
      minute: _minute,
    );
  }

  /// Cancel the daily OS-level alarm.
  Future<void> cancelNotification() async {
    await NotificationService().cancelAutoBackup();
  }

  /// Register a WorkManager periodic task that wakes the app every ~15 min
  /// and asks the [autoBackupWorkerDispatcher] to check whether the
  /// scheduled time has passed.  The worker is a no-op until the time is
  /// reached, so the overhead is minimal.
  ///
  /// [Workmanager] requires a minimum periodic interval of 15 minutes.
  /// We initialise WorkManager with the dispatcher in [main.dart].
  Future<void> schedulePeriodicCheck() async {
    if (!_enabled) return;
    try {
      await Workmanager().registerPeriodicTask(
        backgroundTaskName,
        backgroundTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 10),
      );
      debugPrint('[AutoBackup] WorkManager periodic task scheduled.');
    } catch (e) {
      debugPrint('[AutoBackup] Failed to schedule WorkManager task: $e');
    }
  }

  /// Cancel the WorkManager periodic task.
  Future<void> cancelPeriodicCheck() async {
    try {
      await Workmanager().cancelByUniqueName(backgroundTaskName);
      debugPrint('[AutoBackup] WorkManager periodic task cancelled.');
    } catch (e) {
      debugPrint('[AutoBackup] Failed to cancel WorkManager task: $e');
    }
  }

  /// Reads the most recent worker status from prefs and notifies listeners.
  /// Called from the UI on app start / foreground resume so the loader /
  /// success / error banner can be shown.
  Future<AutoBackupStatus> refreshWorkerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _readWorkerStatus(prefs);
    notifyListeners();
    return _workerStatus;
  }

  void _readWorkerStatus(SharedPreferences prefs) {
    final name = prefs.getString(prefKeyWorkerStatus);
    _workerStatus = AutoBackupStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => AutoBackupStatus.idle,
    );
    final t = prefs.getString(prefKeyWorkerStatusTime);
    _workerStatusTime = t == null ? null : DateTime.tryParse(t);
    _workerError = prefs.getString(prefKeyWorkerError);
  }

  /// Clears the worker status (called by the UI after showing a success /
  /// failure banner so the next worker run starts from a clean state).
  Future<void> clearWorkerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKeyWorkerStatus);
    await prefs.remove(prefKeyWorkerStatusTime);
    await prefs.remove(prefKeyWorkerError);
    _workerStatus = AutoBackupStatus.idle;
    _workerStatusTime = null;
    _workerError = null;
    notifyListeners();
  }

  /// Diagnostic helper — returns a human-readable status string for debugging.
  String get debugStatus {
    final today = _todayString();
    return 'AutoBackup: enabled=$_enabled, '
        'time=$timeLabel, '
        'targetId=$_targetFileId, '
        'lastDate=$_lastBackupDate, '
        'today=$today, '
        'isDue=${isDueNow()}, '
        'workerStatus=$_workerStatus';
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// Simple one-shot completer used to signal when async init is done.
class _Completer {
  final _c = Completer<void>();
  bool _done = false;

  void _complete() {
    if (!_done) {
      _done = true;
      _c.complete();
    }
  }

  Future<void> get future => _done ? Future.value() : _c.future;
}
