import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import '../models/reminder.dart';

/// Service for managing local notifications and reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation when notification is tapped
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Schedule a daily auto-backup notification/alarm at the given time.
  /// Uses DateTimeComponents.time so it repeats every day at that time,
  /// even when the app is closed.
  Future<void> scheduleAutoBackup({required int hour, required int minute}) async {
    if (!_initialized) await initialize();

    const id = _autoBackupNotificationId;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    // If the time has already passed today, start from tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      'SpendSense Auto-Backup',
      'Daily backup is running in the background.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'auto_backup',
          'Auto Backup',
          channelDescription: 'Daily automatic backup to Google Drive',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('[AutoBackup] Scheduled daily alarm at $hour:${minute.toString().padLeft(2, '0')}');
  }

  /// Cancel the daily auto-backup alarm.
  Future<void> cancelAutoBackup() async {
    if (!_initialized) await initialize();
    await _notifications.cancel(_autoBackupNotificationId);
    debugPrint('[AutoBackup] Cancelled daily alarm');
  }

  static const int _autoBackupNotificationId = 999001;

  /// Schedule a reminder for a recurring transaction
  Future<void> scheduleReminder({
    required TransactionReminder reminder,
    required Transaction transaction,
    required DateTime nextOccurrenceDate,
  }) async {
    if (!_initialized) await initialize();
    if (!reminder.isEnabled) return;

    // Calculate reminder date/time
    final reminderDate = nextOccurrenceDate.subtract(
      Duration(days: reminder.daysBefore),
    );
    final scheduledDate = DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    // Don't schedule if in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    final notificationId = _generateNotificationId(
      reminder.id,
      nextOccurrenceDate,
    );

    await _notifications.zonedSchedule(
      notificationId,
      'Upcoming Transaction Reminder',
      '${transaction.title} - ${transaction.amount.toStringAsFixed(2)} on ${_formatDate(nextOccurrenceDate)}',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminders',
          'Recurring Transaction Reminders',
          channelDescription: 'Reminders for upcoming recurring transactions',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: transaction.id,
    );
  }

  /// Schedule reminders for all upcoming instances of a recurring transaction
  Future<void> scheduleRemindersForRecurring({
    required TransactionReminder reminder,
    required Transaction recurringTransaction,
    required List<DateTime> upcomingDates,
  }) async {
    for (final date in upcomingDates) {
      await scheduleReminder(
        reminder: reminder,
        transaction: recurringTransaction,
        nextOccurrenceDate: date,
      );
    }
  }

  /// Cancel all reminders for a specific reminder configuration
  Future<void> cancelReminder(String reminderId) async {
    if (!_initialized) await initialize();

    // Cancel all notifications for this reminder
    // We'll need to track which notification IDs belong to which reminder
    final pendingNotifications = await _notifications
        .pendingNotificationRequests();

    for (final notification in pendingNotifications) {
      if (notification.id.toString().startsWith(
        reminderId.hashCode.toString(),
      )) {
        await _notifications.cancel(notification.id);
      }
    }
  }

  /// Cancel all reminders for a recurring transaction
  Future<void> cancelRemindersForTransaction(String transactionId) async {
    if (!_initialized) await initialize();

    final pendingNotifications = await _notifications
        .pendingNotificationRequests();

    for (final notification in pendingNotifications) {
      if (notification.payload == transactionId) {
        await _notifications.cancel(notification.id);
      }
    }
  }

  /// Get all pending notification requests
  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    if (!_initialized) await initialize();
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancel all notifications
  Future<void> cancelAllReminders() async {
    if (!_initialized) await initialize();
    await _notifications.cancelAll();
  }

  /// Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'recurring_reminders',
          'Recurring Transaction Reminders',
          channelDescription: 'Reminders for upcoming recurring transactions',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Generate unique notification ID
  int _generateNotificationId(String reminderId, DateTime date) {
    return '${reminderId.hashCode}${date.millisecondsSinceEpoch}'.hashCode
            .abs() %
        2147483647;
  }

  /// Format date for notification
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
