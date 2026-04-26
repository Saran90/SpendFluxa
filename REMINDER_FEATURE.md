# Recurring Transaction Reminders Feature

## Overview
This feature adds reminder functionality to recurring transactions, allowing users to receive push notifications and see visual banners for upcoming recurring transactions.

## Features

### 1. **Reminder Configuration**
- Users can set multiple reminders for each recurring transaction
- Configurable timing:
  - **Days before**: Same day, 1 day before, 2 days before, 3 days before, 1 week before
  - **Time**: Custom time selection (e.g., 9:00 AM, 6:00 PM)
- Enable/disable individual reminders
- Edit and delete reminders

### 2. **Push Notifications**
- Local push notifications sent at configured times
- Notification includes:
  - Transaction title
  - Amount
  - Due date
- Notifications scheduled for up to 12 upcoming occurrences
- Automatic rescheduling when reminders are updated

### 3. **Reminder Banners**
- Visual banners displayed above the "Recent Transactions" section on home screen
- Shows up to 3 most urgent upcoming reminders
- Color-coded urgency:
  - **Red**: Today (same day)
  - **Orange**: Tomorrow
  - **Blue**: 2-7 days away
- Banner displays:
  - Urgency label (TODAY, TOMORROW, IN X DAYS)
  - Transaction title and category
  - Amount and frequency
  - Reminder time

### 4. **Permission Handling**
- Automatic notification permission request
- Permission status indicator in reminder config screen
- Graceful handling when permissions are denied

## Implementation Details

### Database Schema
New `reminders` table:
```sql
CREATE TABLE reminders (
  id                        TEXT PRIMARY KEY,
  recurring_transaction_id  TEXT NOT NULL,
  days_before               INTEGER NOT NULL DEFAULT 0,
  time_hour                 INTEGER NOT NULL,
  time_minute               INTEGER NOT NULL,
  is_enabled                INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (recurring_transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
)
```

### Services

#### NotificationService
- Manages local notifications using `flutter_local_notifications`
- Handles notification scheduling with timezone support
- Provides methods for:
  - Scheduling reminders
  - Canceling reminders
  - Showing immediate notifications (for testing)

#### ReminderService
- Manages reminder CRUD operations
- Calculates upcoming transaction dates
- Coordinates with NotificationService for scheduling
- Persists reminders to database

### UI Components

#### ReminderConfigScreen
- Full-screen configuration interface
- Accessed from transaction detail screen (for recurring transactions only)
- Features:
  - Transaction info header
  - Permission warning banner
  - List of configured reminders
  - Add/edit/delete reminder functionality

#### ReminderBanner
- Widget displayed on home screen
- Automatically calculates and displays upcoming reminders
- Shows reminders for next 7 days
- Sorted by urgency (closest first)

#### ReminderDialog
- Modal dialog for adding/editing reminders
- Day selection chips
- Time picker integration

## User Flow

### Setting Up a Reminder

1. User creates a recurring transaction
2. User opens transaction detail screen
3. User taps "Manage Reminders" in the recurring card
4. User grants notification permission (if not already granted)
5. User taps "+" to add a reminder
6. User selects:
   - Days before (same day, 1 day before, etc.)
   - Time (using time picker)
7. User taps "Save"
8. Reminder is saved and notifications are scheduled

### Viewing Reminders

1. User opens home screen
2. Reminder banners appear above "Recent Transactions" section
3. Banners show upcoming reminders for next 7 days
4. User can tap banner to view more details (optional enhancement)

### Receiving Notifications

1. At the configured time, user receives push notification
2. Notification shows transaction details
3. User can tap notification to open app (optional enhancement)

## Dependencies Added

```yaml
flutter_local_notifications: ^18.0.1  # Local push notifications
timezone: ^0.9.4                       # Timezone support for scheduling
permission_handler: ^11.3.1            # Permission management
```

## Android Configuration

### Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### Receivers
- `ScheduledNotificationReceiver`: Handles scheduled notifications
- `ScheduledNotificationBootReceiver`: Reschedules notifications after device reboot

## iOS Configuration

### Info.plist (Required for iOS)
Add the following to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

## Future Enhancements

1. **Notification Actions**: Add "Mark as Paid" or "Snooze" actions to notifications
2. **Smart Reminders**: Suggest optimal reminder times based on user behavior
3. **Recurring Reminder Templates**: Save and reuse reminder configurations
4. **Reminder History**: Track which reminders were sent and acknowledged
5. **Custom Notification Sounds**: Allow users to choose notification sounds
6. **Reminder Groups**: Group reminders by category or frequency
7. **Widget Support**: Show upcoming reminders in home screen widget
8. **Wear OS Support**: Display reminders on smartwatches

## Testing

### Manual Testing Steps

1. **Create Recurring Transaction**
   - Create a monthly recurring transaction
   - Verify it appears in recurring templates

2. **Add Reminder**
   - Open transaction detail
   - Tap "Manage Reminders"
   - Grant notification permission
   - Add reminder for "Same day" at current time + 2 minutes
   - Verify reminder appears in list

3. **Test Notification**
   - Wait for scheduled time
   - Verify notification appears
   - Check notification content

4. **Test Banner**
   - Return to home screen
   - Verify reminder banner appears
   - Check urgency color and text

5. **Edit Reminder**
   - Open reminder config
   - Edit reminder time
   - Verify changes are saved

6. **Delete Reminder**
   - Delete a reminder
   - Verify it's removed from list
   - Verify notification is canceled

7. **Toggle Reminder**
   - Disable a reminder
   - Verify notification is canceled
   - Enable reminder
   - Verify notification is rescheduled

## Troubleshooting

### Notifications Not Appearing
1. Check notification permissions in device settings
2. Verify exact alarm permission (Android 12+)
3. Check battery optimization settings
4. Ensure app is not in "Do Not Disturb" mode

### Reminders Not Showing in Banner
1. Verify reminder is enabled
2. Check that recurring transaction has future occurrences
3. Ensure reminder is within 7-day window

### Database Migration Issues
1. If upgrading from version 1, database will auto-migrate to version 2
2. Reminders table will be created automatically
3. No data loss should occur

## Code Structure

```
lib/
├── core/
│   ├── models/
│   │   └── reminder.dart                    # Reminder model
│   ├── services/
│   │   ├── notification_service.dart        # Notification management
│   │   └── reminder_service.dart            # Reminder CRUD & scheduling
│   └── database/
│       └── app_database.dart                # Updated with reminders table
├── features/
│   ├── reminders/
│   │   ├── reminder_config_screen.dart      # Reminder configuration UI
│   │   └── reminder_banner.dart             # Home screen banner widget
│   ├── transactions/
│   │   └── transaction_detail_screen.dart   # Updated with reminder button
│   └── home/
│       └── home_screen.dart                 # Updated with banner integration
└── main.dart                                # Updated with service initialization
```

## Notes

- Reminders are only available for recurring transactions (parent templates)
- Notifications are scheduled for up to 12 future occurrences
- When a recurring transaction is deleted, all associated reminders are automatically deleted (CASCADE)
- Reminders persist across app restarts
- Notifications are rescheduled after device reboot (Android)
