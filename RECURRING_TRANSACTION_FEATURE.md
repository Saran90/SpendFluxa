# Recurring Transaction Feature

## Overview
Added the ability to create recurring transactions that automatically repeat at specified intervals (daily, weekly, monthly, yearly).

## Implementation Details

### 1. Transaction Model Updates (`lib/core/models/transaction.dart`)

Added new fields to the Transaction model:
- `isRecurring` (bool): Indicates if this is a recurring transaction template
- `recurringFrequency` (String?): The frequency of recurrence ('daily', 'weekly', 'monthly', 'yearly')
- `recurringEndDate` (DateTime?): Optional end date for the recurring series
- `recurringParentId` (String?): Links recurring instances to their parent template

### 2. Add Transaction Screen Updates (`lib/features/transactions/add_transaction_screen.dart`)

#### New State Variables:
- `_isRecurring`: Toggle for enabling recurring transactions
- `_recurringFrequency`: Selected frequency (default: 'monthly')
- `_recurringEndDate`: Optional end date for the series

#### New Methods:

**`_createRecurringTransactions()`**
- Creates a parent/template transaction marked as recurring
- Generates up to 12 recurring instances based on frequency
- Respects the optional end date if provided
- Each instance is linked to the parent via `recurringParentId`

**`_buildRecurringCard()`**
- UI card for configuring recurring transactions
- Toggle switch to enable/disable recurring
- Frequency selection chips (Daily, Weekly, Monthly, Yearly)
- Optional end date picker
- Only shown when EMI is not enabled (mutually exclusive)

**`_frequencyChip()`**
- Helper method to build frequency selection chips
- Shows selected state with color and border

**`_pickRecurringEndDate()`**
- Date picker for selecting when recurring transactions should stop
- Minimum date is 1 day after the transaction date
- Maximum date is 10 years in the future

## User Experience

### How It Works:

1. **Enable Recurring**: User toggles the "Recurring Transaction" switch
2. **Select Frequency**: Choose from Daily, Weekly, Monthly, or Yearly
3. **Set End Date (Optional)**: Pick when the recurring series should stop
4. **Save**: Creates:
   - One parent/template transaction (marked as recurring)
   - Up to 12 recurring instances automatically scheduled

### Frequency Options:

- **Daily**: Transaction repeats every day
- **Weekly**: Transaction repeats every 7 days
- **Monthly**: Transaction repeats on the same day each month
- **Yearly**: Transaction repeats on the same date each year

### Limitations:

- Maximum of 12 instances created at once (to prevent performance issues)
- If no end date is set, defaults to 1 year from the transaction date
- Recurring transactions and EMI transactions are mutually exclusive
- Recurring card only appears when EMI is not enabled

## UI Design

The recurring card follows the same design pattern as the EMI card:
- White card with rounded corners and shadow
- Toggle switch at the top
- Expandable details section when enabled
- Frequency chips with active state styling
- Optional end date picker with clear button
- Consistent spacing and typography

## Data Structure

### Parent Transaction:
```dart
Transaction(
  id: 'parent_id',
  title: 'Rent (Recurring)',
  isRecurring: true,
  recurringFrequency: 'monthly',
  recurringEndDate: DateTime(2025, 12, 31),
  // ... other fields
)
```

### Recurring Instance:
```dart
Transaction(
  id: 'parent_id_recurring_0',
  title: 'Rent',
  recurringParentId: 'parent_id',
  date: DateTime(2025, 5, 1),
  // ... other fields
)
```

## Use Cases

Perfect for:
- Monthly rent payments
- Weekly grocery shopping
- Daily commute expenses
- Yearly insurance premiums
- Subscription services
- Regular salary income
- Recurring bills and utilities

## Future Enhancements

Potential improvements:
- Edit all future instances of a recurring series
- Delete all future instances
- Skip specific occurrences
- Automatic generation of future instances (background job)
- Custom frequency (e.g., every 2 weeks, every 3 months)
- Notification reminders before recurring transactions
