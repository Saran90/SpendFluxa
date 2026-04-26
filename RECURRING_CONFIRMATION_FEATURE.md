# Recurring Transaction Confirmation Feature

## Overview
Implemented a user-confirmation system for recurring transactions. Instead of automatically creating recurring transaction instances, the app now shows a confirmation banner on the home screen when a recurring transaction is due, allowing users to accept or deny each occurrence.

## Key Changes

### 1. New Models & Services

#### `lib/core/models/recurring_confirmation.dart`
- New model to track confirmation status for recurring transactions
- Statuses: `pending`, `accepted`, `denied`
- Stores: transaction ID, due date, status, and confirmation timestamp

#### `lib/core/services/recurring_confirmation_service.dart`
- ChangeNotifier service to manage confirmations
- Methods:
  - `getPendingForDate()` - Get pending confirmations for a specific date
  - `getConfirmation()` - Check if a transaction has been confirmed/denied
  - `accept()` - Mark transaction as accepted
  - `deny()` - Mark transaction as denied
  - `cleanupOldConfirmations()` - Remove old records (90+ days)

### 2. Database Changes

#### `lib/core/database/app_database.dart`
- Updated database version from 2 to 3
- Added `recurring_confirmations` table with columns:
  - `id` (PRIMARY KEY)
  - `recurring_transaction_id` (FOREIGN KEY)
  - `due_date`
  - `status` (pending/accepted/denied)
  - `confirmed_at`
  - UNIQUE constraint on (recurring_transaction_id, due_date)

### 3. UI Components

#### `lib/features/reminders/recurring_confirmation_banner.dart`
- New banner widget displayed on home screen
- Shows recurring transactions due TODAY
- Features:
  - Transaction details (title, amount, category, frequency)
  - "DUE TODAY" badge with orange gradient styling
  - Two action buttons:
    - **"Not Now"** - Denies the transaction (skips this occurrence)
    - **"Record"** - Accepts and creates the transaction
  - Success/skip feedback via SnackBar

### 4. Modified Components

#### `lib/features/transactions/add_transaction_screen.dart`
- **Removed** auto-creation of recurring instances
- Now only creates the template/parent transaction
- Instances are created on-demand when user confirms via banner

#### `lib/features/home/home_screen.dart`
- Added `RecurringConfirmationService` to constructor
- Added service to `ListenableBuilder` merge for reactive updates
- Integrated `RecurringConfirmationBanner` above `ReminderBanner`
- Banner order:
  1. Spending Progress
  2. **Recurring Confirmation Banner** (transactions due today)
  3. Reminder Banner (upcoming transactions)
  4. Recent Transactions

#### `lib/features/shell/main_shell.dart`
- Added `RecurringConfirmationService` parameter
- Passes service to `HomeScreen`

#### `lib/main.dart`
- Initialized `RecurringConfirmationService`
- Added to disposal chain
- Passed to `MainShell`

## User Flow

### Creating a Recurring Transaction
1. User creates a recurring transaction (e.g., "Netflix Subscription - Monthly")
2. Only the template is saved (marked with `isRecurring: true`)
3. No instances are pre-created

### On Transaction Due Date
1. Home screen checks for recurring transactions due today
2. If found and not yet confirmed, shows confirmation banner
3. User sees:
   - Transaction details
   - "DUE TODAY" badge
   - Two options: "Not Now" or "Record"

### User Actions
- **Record**: 
  - Creates actual transaction with today's date
  - Marks as `accepted` in confirmations table
  - Shows success message
  - Transaction appears in recent transactions list
  
- **Not Now**:
  - Marks as `denied` in confirmations table
  - Shows "Transaction skipped" message
  - No transaction is created
  - Won't show banner again for this occurrence

### Next Occurrence
- On the next due date (based on frequency), banner appears again
- Each occurrence requires separate confirmation
- User has full control over which instances to record

## Benefits

1. **User Control**: Users explicitly approve each transaction occurrence
2. **Flexibility**: Can skip transactions when needed (e.g., cancelled subscription)
3. **No Clutter**: Doesn't pre-create future transactions that may never happen
4. **Clear Intent**: Users know exactly when transactions are recorded
5. **Reactive UI**: Banner appears/disappears automatically via ChangeNotifier

## Technical Details

### Reactive Updates
- `RecurringConfirmationService` extends `ChangeNotifier`
- Home screen listens to service changes
- Banner automatically updates when confirmations change
- No manual refresh needed

### Data Persistence
- Confirmations stored in SQLite database
- Survives app restarts
- Old confirmations (90+ days) can be cleaned up

### Date Handling
- Uses date-only comparison (ignores time)
- Calculates next occurrence based on frequency (daily/weekly/monthly/yearly)
- Respects recurring end date if set

## Future Enhancements

Potential improvements:
- Bulk accept/deny for multiple recurring transactions
- Edit transaction details before recording
- Snooze option (remind again later today)
- Notification when recurring transaction is due
- History view of accepted/denied transactions

