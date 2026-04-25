# Recurring Transaction Visibility Update

## Overview
Updated the transaction service to hide future recurring transactions and recurring templates from all transaction lists. Transactions only appear when their scheduled date arrives.

## Implementation Details

### Updated Methods in `TransactionService`

All transaction retrieval methods now filter out:
1. **Recurring template/parent transactions** - These are just templates and should never appear in lists
2. **Future recurring instances** - Only show when their date has arrived (today or earlier)

### Filtering Logic

```dart
// Hide recurring template/parent transactions
if (t.isRecurring && t.recurringParentId == null) {
  return false;
}

// Hide future recurring instances
if (t.recurringParentId != null) {
  return t.date.isBefore(DateTime.now().add(const Duration(days: 1)));
}
```

### Updated Methods:

1. **`allTransactions`** - Main transaction list getter
   - Hides recurring templates
   - Hides future recurring instances

2. **`transactionsForMonth(year, month)`** - Monthly transactions
   - Filters by month
   - Hides recurring templates
   - Hides future recurring instances

3. **`recentTransactions({limit})`** - Recent transactions
   - Hides recurring templates
   - Hides future recurring instances
   - Returns up to `limit` transactions

4. **`transactionsWithTag(tagId)`** - Tag-filtered transactions
   - Filters by tag
   - Hides recurring templates
   - Hides future recurring instances

### Affected Calculations

Since the filtering happens at the transaction retrieval level, all calculations automatically respect the visibility rules:

- **`incomeForMonth()`** - Only counts visible transactions
- **`expensesForMonth()`** - Only counts visible transactions
- **`balanceForMonth()`** - Based on visible transactions
- **`incomeForTag()`** - Only counts visible transactions
- **`expensesForTag()`** - Only counts visible transactions
- **`totalForTag()`** - Only counts visible transactions

## User Experience

### What Users See:

1. **Recurring Templates**: Never visible in any list
   - These are just configuration/templates
   - Stored in the database but hidden from UI

2. **Future Recurring Instances**: Hidden until their date arrives
   - Example: If today is April 25, 2026:
     - ✅ Recurring transaction dated April 25, 2026 → **Visible**
     - ✅ Recurring transaction dated April 20, 2026 → **Visible**
     - ❌ Recurring transaction dated April 26, 2026 → **Hidden**
     - ❌ Recurring transaction dated May 1, 2026 → **Hidden**

3. **Past Recurring Instances**: Always visible
   - Show in transaction lists
   - Included in calculations
   - Appear in their respective months

### Benefits:

1. **Clean Transaction Lists**: No clutter from future transactions
2. **Accurate Calculations**: Budgets and totals only include actual/current transactions
3. **Predictable Behavior**: Transactions appear exactly when they're supposed to happen
4. **No Confusion**: Users don't see transactions that haven't occurred yet

## Example Scenario

### Creating a Monthly Rent Recurring Transaction:

**Setup:**
- Amount: $1,200
- Frequency: Monthly
- Start Date: April 1, 2026
- End Date: December 31, 2026

**What Gets Created:**
1. 1 template transaction (hidden)
2. 9 recurring instances (April - December)

**What Users See on April 25, 2026:**
- ✅ April rent ($1,200) - visible
- ❌ May rent ($1,200) - hidden (future)
- ❌ June rent ($1,200) - hidden (future)
- ... all future months hidden

**What Users See on May 1, 2026:**
- ✅ April rent ($1,200) - visible (past)
- ✅ May rent ($1,200) - visible (today)
- ❌ June rent ($1,200) - hidden (future)
- ... all future months hidden

## Technical Notes

### Date Comparison:
- Uses `DateTime.now().add(const Duration(days: 1))` for comparison
- This means transactions dated today or earlier are visible
- Transactions dated tomorrow or later are hidden

### Performance:
- Filtering happens in-memory (fast)
- No database queries needed
- Scales well with reasonable transaction counts

### Future Enhancements:
- Background job to automatically "activate" recurring transactions
- Notification system to alert users of upcoming recurring transactions
- Dashboard widget showing next scheduled recurring transactions
- Ability to view/manage all recurring series
