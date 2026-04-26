# Recurring Transaction Confirmation - Testing Checklist

## Setup
- [ ] App launches without errors
- [ ] Database migration to version 3 completes successfully
- [ ] Home screen loads properly

## Creating Recurring Transactions
- [ ] Create a recurring transaction with frequency "daily"
- [ ] Create a recurring transaction with frequency "weekly"
- [ ] Create a recurring transaction with frequency "monthly"
- [ ] Verify only template is created (no instances in transaction list)
- [ ] Verify recurring transaction appears in "Recurring Transactions" section on home

## Confirmation Banner Display
- [ ] Set device date to match a recurring transaction's due date
- [ ] Open home screen
- [ ] Verify confirmation banner appears above reminder banner
- [ ] Verify banner shows:
  - Transaction icon and category
  - "DUE TODAY" badge
  - Transaction title (without "(Recurring)" suffix)
  - Transaction amount
  - Category and frequency info
  - "Record this transaction?" question
  - "Not Now" button
  - "Record" button

## Accepting Transaction
- [ ] Tap "Record" button on confirmation banner
- [ ] Verify success SnackBar appears
- [ ] Verify banner disappears
- [ ] Verify transaction appears in "Recent Transactions" list
- [ ] Verify transaction has correct date (today)
- [ ] Verify transaction has correct amount and category
- [ ] Close and reopen app
- [ ] Verify banner doesn't reappear for same occurrence

## Denying Transaction
- [ ] Create another recurring transaction due today
- [ ] Tap "Not Now" button on confirmation banner
- [ ] Verify "Transaction skipped" SnackBar appears
- [ ] Verify banner disappears
- [ ] Verify NO transaction is created in recent list
- [ ] Close and reopen app
- [ ] Verify banner doesn't reappear for same occurrence

## Multiple Recurring Transactions
- [ ] Create 3 recurring transactions all due today
- [ ] Verify all 3 banners appear
- [ ] Accept one, deny one, leave one pending
- [ ] Verify correct behavior for each

## Next Occurrence
- [ ] For a monthly recurring transaction
- [ ] Accept current month's occurrence
- [ ] Change device date to next month's due date
- [ ] Verify banner appears again for new occurrence
- [ ] Verify can accept/deny independently

## Edge Cases
- [ ] Recurring transaction with end date in the past - no banner
- [ ] Recurring transaction starting in the future - no banner until due
- [ ] Multiple recurring transactions with same title - each handled separately
- [ ] Delete recurring template - banner disappears
- [ ] Edit recurring template - banner reflects changes

## Integration with Reminders
- [ ] Set reminder for recurring transaction (2 days before)
- [ ] Verify reminder banner appears 2 days before
- [ ] Verify confirmation banner appears on due date
- [ ] Both banners can coexist
- [ ] Confirmation banner appears above reminder banner

## Performance
- [ ] Home screen loads quickly with confirmation service
- [ ] Banner appears/disappears smoothly
- [ ] No lag when accepting/denying transactions
- [ ] Database queries are efficient

## Data Persistence
- [ ] Accept a transaction
- [ ] Force close app
- [ ] Reopen app
- [ ] Verify transaction is still recorded
- [ ] Verify banner doesn't reappear

## Cleanup
- [ ] Old confirmations (90+ days) can be cleaned up
- [ ] Database doesn't grow indefinitely

