import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/reminder.dart';
import '../../core/models/transaction.dart';
import '../../core/services/reminder_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';

/// Screen for configuring reminders for a recurring transaction
class ReminderConfigScreen extends StatefulWidget {
  final Transaction recurringTransaction;
  final ReminderService reminderService;

  const ReminderConfigScreen({
    super.key,
    required this.recurringTransaction,
    required this.reminderService,
  });

  @override
  State<ReminderConfigScreen> createState() => _ReminderConfigScreenState();
}

class _ReminderConfigScreenState extends State<ReminderConfigScreen> {
  List<TransactionReminder> _reminders = [];
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _checkPermissions();
  }

  void _loadReminders() {
    setState(() {
      _reminders = widget.reminderService.getRemindersForTransaction(
        widget.recurringTransaction.id,
      );
    });
  }

  Future<void> _checkPermissions() async {
    final granted = await NotificationService().requestPermissions();
    setState(() {
      _permissionGranted = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reminders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTransactionInfo(),
          if (!_permissionGranted) _buildPermissionWarning(),
          Expanded(
            child: _reminders.isEmpty
                ? _buildEmptyState()
                : _buildRemindersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: const Color(0xFF4ECDC4),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTransactionInfo() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.recurringTransaction.category.color.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              widget.recurringTransaction.category.icon,
              color: widget.recurringTransaction.category.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recurringTransaction.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recurring ${widget.recurringTransaction.recurringFrequency}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(
              symbol: '₹',
              decimalDigits: 0,
            ).format(widget.recurringTransaction.amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.recurringTransaction.isIncome
                  ? const Color(0xFF2D9E6B)
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE69C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFFF9800), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Permission Required',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF856404),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enable notifications to receive reminders',
                  style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _checkPermissions, child: const Text('Enable')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Reminders Set',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add a reminder',
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(TransactionReminder reminder) {
    final timeStr = TimeOfDay(
      hour: reminder.time.hour,
      minute: reminder.time.minute,
    ).format(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: reminder.isEnabled
                ? const Color(0xFF4ECDC4)
                : AppColors.textLight,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.daysBeforeLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'at $timeStr',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: reminder.isEnabled,
            onChanged: (value) => _toggleReminder(reminder, value),
            activeTrackColor: const Color(0xFF4ECDC4).withValues(alpha: 0.5),
            activeThumbColor: const Color(0xFF4ECDC4),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => _editReminder(reminder),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Colors.red,
            onPressed: () => _deleteReminder(reminder),
          ),
        ],
      ),
    );
  }

  Future<void> _addReminder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ReminderDialog(),
    );

    if (result != null) {
      final reminder = TransactionReminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        recurringTransactionId: widget.recurringTransaction.id,
        daysBefore: result['daysBefore'] as int,
        time: result['time'] as TimeOfDay,
        isEnabled: true,
      );

      await widget.reminderService.addReminder(reminder);
      await widget.reminderService.scheduleNotifications(
        reminder: reminder,
        recurringTransaction: widget.recurringTransaction,
      );

      _loadReminders();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder added')));
      }
    }
  }

  Future<void> _editReminder(TransactionReminder reminder) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReminderDialog(
        initialDaysBefore: reminder.daysBefore,
        initialTime: reminder.time,
      ),
    );

    if (result != null) {
      final updated = reminder.copyWith(
        daysBefore: result['daysBefore'] as int,
        time: result['time'] as TimeOfDay,
      );

      await widget.reminderService.updateReminder(updated);
      await widget.reminderService.rescheduleNotificationsForTransaction(
        transactionId: widget.recurringTransaction.id,
        recurringTransaction: widget.recurringTransaction,
      );

      _loadReminders();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder updated')));
      }
    }
  }

  Future<void> _toggleReminder(
    TransactionReminder reminder,
    bool enabled,
  ) async {
    final updated = reminder.copyWith(isEnabled: enabled);
    await widget.reminderService.updateReminder(updated);

    if (enabled) {
      await widget.reminderService.scheduleNotifications(
        reminder: updated,
        recurringTransaction: widget.recurringTransaction,
      );
    } else {
      await NotificationService().cancelReminder(reminder.id);
    }

    _loadReminders();
  }

  Future<void> _deleteReminder(TransactionReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.reminderService.deleteReminder(reminder.id);
      _loadReminders();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
      }
    }
  }
}

/// Dialog for adding/editing a reminder
class _ReminderDialog extends StatefulWidget {
  final int? initialDaysBefore;
  final TimeOfDay? initialTime;

  const _ReminderDialog({this.initialDaysBefore, this.initialTime});

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late int _daysBefore;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _daysBefore = widget.initialDaysBefore ?? 0;
    _time = widget.initialTime ?? const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialDaysBefore == null ? 'Add Reminder' : 'Edit Reminder',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Remind me',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDayChip(0, 'Same day'),
              _buildDayChip(1, '1 day before'),
              _buildDayChip(2, '2 days before'),
              _buildDayChip(3, '3 days before'),
              _buildDayChip(7, '1 week before'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Time',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _time.format(context),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {'daysBefore': _daysBefore, 'time': _time});
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDayChip(int days, String label) {
    final isSelected = _daysBefore == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _daysBefore = days);
        }
      },
      selectedColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4ECDC4) : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }
}
