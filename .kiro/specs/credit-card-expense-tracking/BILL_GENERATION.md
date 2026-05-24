# Automatic Bill Generation - Technical Documentation

## Overview

The bill generation system automatically creates credit card bills on their scheduled bill dates. This ensures users always have up-to-date bills without manual intervention.

## How It Works

### 1. Bill Date Configuration
- Each credit card account has a `billDate` field (day of month, 1-31)
- Example: Bill date = 15 means bills are generated on the 15th of each month

### 2. Automatic Generation Triggers

#### On App Launch
- `BillGenerationService.checkAndGenerateBills()` is called in `main.dart`
- Checks all credit card accounts for bills that need to be generated
- Runs silently in the background

#### When App Comes to Foreground
- `MainShell` calls `_checkAndGenerateBills()` in `initState`
- Ensures bills are generated even if the app was closed on the bill date

### 3. Bill Generation Logic

```dart
Future<void> _generateBillIfDue(Account creditCardAccount) async {
  // 1. Check if bill date is set
  if (creditCardAccount.billDate == null) return;
  
  // 2. Check if bill already exists for this month
  final existingBill = await _getBillForCurrentMonth(accountId);
  if (existingBill != null) return; // Already generated
  
  // 3. Check if today >= bill date
  final today = DateTime.now();
  if (today.day >= creditCardAccount.billDate!) {
    // 4. Create the bill
    await _createBillForAccount(creditCardAccount);
  }
}
```

### 4. Bill Creation Process

When a bill is created:

1. **Gather Transactions**
   - Fetch all transactions for the credit card account
   - Filter by account ID

2. **Calculate Amounts**
   - `trackedAmount` = sum of all expenses - income
   - `actualAmount` = trackedAmount (user can adjust later)
   - `difference` = null (user can add fees/interest later)

3. **Set Dates**
   - `billDate` = current month, bill date day
   - `dueDate` = billDate + 20 days

4. **Create Bill Record**
   ```dart
   CreditCardBill(
     id: generateId(),
     creditCardAccountId: accountId,
     billDate: billDate,
     dueDate: dueDate,
     trackedAmount: trackedAmount,
     actualAmount: actualAmount,
     status: BillStatus.pending,
     payments: [],
     transactionIds: [tx1, tx2, ...],
   )
   ```

5. **Save to Database**
   - Insert into `credit_card_bills` table
   - Insert transaction IDs into `bill_transactions` junction table

## Service Architecture

### BillGenerationService

**Location**: `lib/core/services/bill_generation_service.dart`

**Key Methods**:

```dart
// Main entry point - check all accounts
Future<void> checkAndGenerateBills()

// Generate bill for specific account if due
Future<void> _generateBillIfDue(Account creditCardAccount)

// Create the actual bill record
Future<void> _createBillForAccount(Account creditCardAccount)

// Check if bill exists for current month
Future<CreditCardBill?> _getBillForCurrentMonth(String accountId)
```

**Dependencies**:
- `AccountService` - Get credit card accounts
- `TransactionService` - Get transactions for bill
- `AppDatabase` - Persist bills

### Integration Points

#### 1. Main App (`lib/main.dart`)
```dart
class _SpendFluxAppState extends State<SpendFluxApp> {
  late final BillGenerationService _billGenerationService =
      BillGenerationService(
    accountService: _accountService,
    transactionService: _transactionService,
  );

  @override
  void initState() {
    super.initState();
    // Check and generate bills on app launch
    _billGenerationService.checkAndGenerateBills();
  }
}
```

#### 2. MainShell (`lib/features/shell/main_shell.dart`)
```dart
@override
void initState() {
  super.initState();
  // ... other initialization
  
  // Check and generate bills if due
  _checkAndGenerateBills();
}

Future<void> _checkAndGenerateBills() async {
  await Future.delayed(const Duration(milliseconds: 500));
  if (!mounted) return;
  
  try {
    await widget.billGenerationService.checkAndGenerateBills();
  } catch (e) {
    debugPrint('[MainShell] Error generating bills: $e');
  }
}
```

## Database Schema

### credit_card_bills Table
```sql
CREATE TABLE credit_card_bills (
  id                        TEXT PRIMARY KEY,
  credit_card_account_id    TEXT NOT NULL,
  bill_date                 TEXT NOT NULL,
  due_date                  TEXT NOT NULL,
  tracked_amount            REAL NOT NULL,
  actual_amount             REAL NOT NULL,
  difference                REAL,
  difference_note           TEXT,
  status                    TEXT NOT NULL DEFAULT 'pending',
  created_at                TEXT NOT NULL,
  updated_at                TEXT NOT NULL,
  FOREIGN KEY (credit_card_account_id) REFERENCES accounts(id)
)
```

### bill_transactions Table
```sql
CREATE TABLE bill_transactions (
  bill_id                   TEXT NOT NULL,
  transaction_id            TEXT NOT NULL,
  PRIMARY KEY (bill_id, transaction_id),
  FOREIGN KEY (bill_id) REFERENCES credit_card_bills(id),
  FOREIGN KEY (transaction_id) REFERENCES transactions(id)
)
```

## Example Scenarios

### Scenario 1: Bill Date = 15th, Today = 15th
```
Account: Visa Card
Bill Date: 15
Today: May 15, 2026

Action:
1. Check if bill exists for May 2026 → No
2. Check if today (15) >= bill date (15) → Yes
3. Create bill for May 15, 2026
4. Due date: June 4, 2026
5. Bill status: pending
```

### Scenario 2: Bill Date = 15th, Today = 20th
```
Account: Visa Card
Bill Date: 15
Today: May 20, 2026

Action:
1. Check if bill exists for May 2026 → No
2. Check if today (20) >= bill date (15) → Yes
3. Create bill for May 15, 2026 (retroactive)
4. Due date: June 4, 2026
```

### Scenario 3: Bill Already Generated
```
Account: Visa Card
Bill Date: 15
Today: May 20, 2026
Existing Bill: May 15, 2026 (already created)

Action:
1. Check if bill exists for May 2026 → Yes
2. Skip generation (already exists)
```

### Scenario 4: Bill Date Not Yet Arrived
```
Account: Visa Card
Bill Date: 25
Today: May 20, 2026

Action:
1. Check if today (20) >= bill date (25) → No
2. Skip generation (not due yet)
```

## Bill Amount Calculation

### Tracked Amount
```dart
double trackedAmount = 0;
for (final tx in accountTransactions) {
  if (tx.type.name == 'expense') {
    trackedAmount += tx.amount;
  } else if (tx.type.name == 'income') {
    trackedAmount -= tx.amount;
  }
}
```

**Example**:
- Expense 1: $100
- Expense 2: $250
- Income: $50
- **Tracked Amount = $100 + $250 - $50 = $300**

### Actual Amount
Initially set to `trackedAmount`, but users can adjust:
- Add fees/interest
- Add surcharges
- Correct discrepancies

### Difference
```dart
difference = actualAmount - trackedAmount
```

**Example**:
- Tracked: $300
- Actual: $315 (includes $15 interest)
- Difference: $15

## Error Handling

### Missing Bill Date
```dart
if (creditCardAccount.billDate == null) {
  debugPrint('Account has no bill date set');
  return;
}
```

### Database Errors
```dart
try {
  await _createBillForAccount(creditCardAccount);
} catch (e) {
  debugPrint('Error creating bill: $e');
  rethrow;
}
```

### Duplicate Prevention
```dart
final existingBill = await _getBillForCurrentMonth(accountId);
if (existingBill != null) {
  debugPrint('Bill already exists for this month');
  return;
}
```

## Performance Considerations

1. **Lazy Loading**: Bills are only generated when needed
2. **Duplicate Prevention**: Checks for existing bills before creating
3. **Batch Processing**: All accounts checked in one call
4. **Async Operations**: Non-blocking database operations
5. **Delayed Execution**: Small delay before checking to avoid UI blocking

## Testing Checklist

- [ ] Bill generates on correct date
- [ ] Bill doesn't generate before bill date
- [ ] Bill doesn't generate twice in same month
- [ ] Bill amount calculated correctly
- [ ] Transactions linked to bill correctly
- [ ] Bill status set to 'pending'
- [ ] Due date calculated correctly (billDate + 20 days)
- [ ] Works for multiple credit cards
- [ ] Handles accounts without bill date
- [ ] Handles accounts with no transactions
- [ ] Database records created correctly
- [ ] No errors in logs

## Future Enhancements

1. **Configurable Due Date**: Allow users to set custom due date offset
2. **Bill Notifications**: Notify user when bill is generated
3. **Recurring Bills**: Support for multiple billing cycles
4. **Bill History**: View past bills and their status
5. **Auto-Payment**: Schedule automatic payments
6. **Bill Reminders**: Remind user before due date
7. **Statement Export**: Export bills as PDF/CSV
8. **Multi-Currency**: Support for multiple currencies per account

## Troubleshooting

### Bills Not Generating

**Check**:
1. Is bill date set on the account?
2. Is today >= bill date?
3. Does a bill already exist for this month?
4. Are there any database errors in logs?

**Solution**:
- Verify bill date is set: `account.billDate != null`
- Check app logs for errors
- Manually trigger: `billGenerationService.checkAndGenerateBills()`

### Wrong Bill Amount

**Check**:
1. Are all transactions included?
2. Is the calculation correct?
3. Are income transactions subtracted?

**Solution**:
- Verify transactions are linked to account
- Check transaction types (expense vs income)
- Manually adjust `actualAmount` if needed

### Duplicate Bills

**Check**:
1. Is duplicate prevention working?
2. Are there database issues?

**Solution**:
- Check `_getBillForCurrentMonth()` logic
- Verify database query is correct
- Clear duplicate bills manually if needed

## Code Examples

### Manual Bill Generation
```dart
final billGenerationService = BillGenerationService(
  accountService: accountService,
  transactionService: transactionService,
);

// Generate bills for all accounts
await billGenerationService.checkAndGenerateBills();

// Or generate for specific account
final account = accountService.creditCards.first;
await billGenerationService._generateBillIfDue(account);
```

### Check if Bill Exists
```dart
final bill = await billGenerationService._getBillForCurrentMonth(accountId);
if (bill != null) {
  print('Bill exists: ${bill.actualAmount}');
} else {
  print('No bill for this month');
}
```

### Access Generated Bills
```dart
final bills = billService.billsForAccount(accountId);
for (final bill in bills) {
  print('Bill: ${bill.billDate} - ${bill.actualAmount}');
}
```
