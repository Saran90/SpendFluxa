import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Manages the auto-backup schedule preference.
///
/// Auto-backup works as follows:
///   • The user enables the toggle and picks a daily time.
///   • On every app launch, [checkAndTrigger] is called. If the current time
///     is at or past the scheduled time and no backup has been done today,
///     the caller runs the backup.
///   • The target Drive file ID is stored so every daily backup overwrites
///     the same file (keeping a single up-to-date backup rather than
///     accumulating many files).
///   • If no target file exists yet (first run), the caller creates a new
///     backup and stores the resulting file ID as the target.
class AutoBackupService extends ChangeNotifier {
  static const _keyEnabled = 'auto_backup_enabled';
  static const _keyHour = 'auto_backup_hour';
  static const _keyMinute = 'auto_backup_minute';
  static const _keyTargetId = 'auto_backup_target_file_id';
  static const _keyLastDate = 'auto_backup_last_date'; // yyyy-MM-dd

  bool _enabled = false;
  int _hour = 2; // default 02:00
  int _minute = 0;
  String? _targetFileId;
  String? _lastBackupDate;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  String? get targetFileId => _targetFileId;

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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _hour = prefs.getInt(_keyHour) ?? 2;
    _minute = prefs.getInt(_keyMinute) ?? 0;
    _targetFileId = prefs.getString(_keyTargetId);
    _lastBackupDate = prefs.getString(_keyLastDate);
    // Re-register the OS alarm on every app start in case it was cleared
    // (e.g. after a device reboot or app update).
    if (_enabled) await scheduleNotification();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (value) {
      await scheduleNotification();
    } else {
      await cancelNotification();
    }
    notifyListeners();
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    if (_enabled) await scheduleNotification(); // reschedule at new time
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

  /// Returns true when auto-backup is enabled, the scheduled time has passed
  /// today, and no backup has been done yet today.
  /// Also returns true if the last backup was before today (missed backup).
  bool isDueNow() {
    if (!_enabled) return false;
    if (_lastBackupDate == _todayString()) return false; // already done today
    final now = DateTime.now();
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      _hour,
      _minute,
    );
    // Due if: scheduled time has passed today, OR last backup was a previous day
    if (now.isBefore(scheduledToday) && _lastBackupDate != null) {
      // Scheduled time hasn't passed yet today, but check if we missed yesterday
      final lastDate = DateTime.tryParse(_lastBackupDate!);
      if (lastDate == null) return true; // never backed up
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      return lastDate.isBefore(yesterday) ||
          (lastDate.year == yesterday.year &&
              lastDate.month == yesterday.month &&
              lastDate.day == yesterday.day);
    }
    return true; // scheduled time passed and not yet done today
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

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
