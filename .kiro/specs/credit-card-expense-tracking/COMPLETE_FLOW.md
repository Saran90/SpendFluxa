# Complete Credit Card Expense Tracking Flow

## End-to-End User Journey

### Phase 1: Setup

#### Step 1: Create Credit Card Account
```
User Action: Tap "Add Account" → Select "Credit Card"
↓
Input:
- Name: "Visa Card"
- Credit Limit: $5,000
- Bill Date: 15 (15th of each month)
- Last 4 Digits: 4242
↓
Result: Account created and saved
```

#### Step 2: Add Transactions
```
User Action: Tap "Add Transaction" → Select Credit Card Account
↓
Input:
- Title: "Grocery Store"
- Amount: $150
- Category: Food
- Date: May 10, 2026
↓
Result: Transaction recorded, account balance updated
```

### Phase 2: Automatic Bill Generation

#### Step 3: Bill Date Arrives
```
Timeline: May 15, 2026 (Bill Date)
↓
Automatic Action:
1. App launches (or comes to foreground)
2. BillGenerationService.checkAndGenerateBills() called
3. Checks all credit card accounts
4. Finds "Visa Card" with billDate = 15
5. Today (15) >= billDate (15) ✓
6. No bill exists for May ✓
7. Creates bill:
   - billDate: May 15, 2026
   - dueDate: June 4, 2026
   - trackedAmount: $150 (sum of transactions)
   - actualAmount: $150
   - status: pending
8. Bill saved to database
↓
Result: Bill automatically generated, no user action needed
```

### Phase 3: View Bill and Pay

#### Step 4: View Account Details
```
User Action: Navigate to Accounts → Tap "Visa Card"
↓
Display:
- Account Name: "Visa Card"
- Outstanding Balance: $150
- Credit Limit: $5,000
- Available Credit: $4,850
- Utilization: 3%
- Bill Date: 15th of every month
- "Pay Bill" Button (visible for CC accounts)
↓
Result: Account detail screen shows all info
```

#### Step 5: Open Payment Sheet
```
User Action: Tap "Pay Bill" button
↓
Display:
- Title: "Record Payment" (centered)
- Account: "Visa Card"
- Outstanding Balance: $150 (prominent display)
- Payment Amount Input Field
- "Same as Outstanding" Toggle
- Payment Date Picker (defaults to today)
- Note Field (optional)
- "Record Payment" Button
↓
Result: Payment sheet opens
```

#### Step 6: Record Payment
```
User Action: 
1. Tap "Same as Outstanding" toggle
2. Amount auto-fills: $150
3. Tap "Record Payment"
↓
Processing:
1. Validate amount ($150 <= $150) ✓
2. Get latest bill for account
3. Record payment in database:
   - billId: bill_001
   - amount: $150
   - paymentDate: May 20, 2026
   - note: null
4. Update account balance:
   - Old: $150
   - New: $0
5. Update bill status:
   - Old: pending
   - New: paid
6. Show success notification
↓
Result: Payment recorded, account updated
```

#### Step 7: Verify Payment
```
User Action: Return to account detail screen
↓
Display:
- Outstanding Balance: $0 (updated)
- Available Credit: $5,000 (updated)
- Utilization: 0% (updated)
↓
Result: All changes reflected in UI
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Creates Account                      │
│                  (Credit Card, Bill Date)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  User Adds Transactions                      │
│              (Expenses charged to card)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Bill Date Arrives (Automatic)                   │
│         BillGenerationService.checkAndGenerateBills()        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Bill Created                               │
│    (billDate, dueDate, trackedAmount, status=pending)        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              User Views Account Details                      │
│         (Outstanding Balance, "Pay Bill" Button)             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              User Taps "Pay Bill" Button                     │
│              BillPaymentSheet Opens                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              User Enters Payment Details                     │
│    (Amount, Date, Note - or use "Same as Outstanding")       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              User Taps "Record Payment"                      │
│              Payment Validation & Recording                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Payment Recorded                            │
│    (Bill updated, Account balance reduced, Status updated)   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Success Notification Shown                      │
│              Account Details Updated                         │
└─────────────────────────────────────────────────────────────┘
```

## Service Interactions

```
┌──────────────────────────────────────────────────────────────┐
│                      Main App                                │
│  (Initializes all services, calls checkAndGenerateBills)     │
└──────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Account    │  │ Transaction  │  │    Bill      │
│   Service    │  │   Service    │  │ Generation   │
│              │  │              │  │   Service    │
└──────────────┘  └──────────────┘  └──────────────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                   MainShell                                  │
│  (Calls checkAndGenerateBills on app foreground)             │
└──────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│    Home      │  │  Accounts    │  │  Account     │
│   Screen     │  │   Screen     │  │   Detail     │
│              │  │              │  │   Screen     │
└──────────────┘  └──────────────┘  └──────────────┘
                                           │
                                           ▼
                                  ┌──────────────┐
                                  │    Bill      │
                                  │   Payment    │
                                  │    Sheet     │
                                  └──────────────┘
                                           │
                                           ▼
                                  ┌──────────────┐
                                  │    Bill      │
                                  │   Service    │
                                  │ (recordPayment)
                                  └──────────────┘
```

## Database Operations

### Bill Generation
```
1. Query: SELECT * FROM credit_card_bills 
   WHERE credit_card_account_id = ? 
   AND bill_date >= ? AND bill_date <= ?

2. If no result:
   INSERT INTO credit_card_bills (
     id, credit_card_account_id, bill_date, due_date,
     tracked_amount, actual_amount, status, created_at, updated_at
   ) VALUES (...)

3. For each transaction:
   INSERT INTO bill_transactions (bill_id, transaction_id) VALUES (...)
```

### Payment Recording
```
1. INSERT INTO bill_payments (
     id, bill_id, amount, payment_date, note, created_at
   ) VALUES (...)

2. UPDATE credit_card_bills 
   SET status = ?, updated_at = ?
   WHERE id = ?

3. UPDATE accounts 
   SET balance = balance - ?
   WHERE id = ?
```

## State Management

### AccountDetailScreen
```
ListenableBuilder(
  listenable: Listenable.merge([
    accountService,      // Listen for account changes
    transactionService,  // Listen for transaction changes
    currencyService,     // Listen for currency changes
    billService,         // Listen for bill changes
  ]),
  builder: (context, _) {
    // Rebuild when any service notifies
    final account = accountService.all.firstWhere(...);
    final outstanding = account.balance;
    // Display updated UI
  },
)
```

### BillPaymentSheet
```
State Management:
- _amountController: TextEditingController
- _noteController: TextEditingController
- _selectedDate: DateTime
- _useSameAsOutstanding: bool
- _isSubmitting: bool

On "Same as Outstanding" toggle:
- Set _useSameAsOutstanding = !_useSameAsOutstanding
- If true: _amountController.text = outstanding.toStringAsFixed(2)
- If false: _amountController.clear()

On "Record Payment":
- Validate amount
- Call onPaymentSubmitted callback
- Show loading state
- Close sheet on success
- Show error on failure
```

## Error Handling

### Bill Generation Errors
```
try {
  await _createBillForAccount(account);
} catch (e) {
  debugPrint('Error: $e');
  // Continue with next account
}
```

### Payment Recording Errors
```
try {
  await billService.recordPayment(...);
  await accountService.adjustBalance(...);
} catch (e) {
  _showError('Error recording payment: $e');
  // Sheet remains open for retry
}
```

### Validation Errors
```
if (amount > outstanding) {
  _showError('Amount exceeds outstanding balance');
  return; // Don't proceed
}
```

## Performance Optimization

### Bill Generation
- Runs only on app launch and foreground
- Checks all accounts in parallel (conceptually)
- Prevents duplicates with database query
- Non-blocking async operations

### Payment Recording
- Validates before database operations
- Uses transactions for data consistency
- Updates UI reactively via Listenable
- Shows loading state during operation

### UI Rendering
- Lazy loads account details
- Caches formatted amounts
- Rebuilds only when services notify
- Efficient list rendering for transactions

## Security Measures

### Input Validation
- Amount must be > 0
- Amount must be <= outstanding balance
- Date must be in past or today
- Note field sanitized

### Database Security
- Foreign key constraints enabled
- Transactions for data consistency
- No SQL injection (parameterized queries)
- Proper error handling

### Data Privacy
- No sensitive data in logs
- Error messages don't expose details
- All operations are local
- No network transmission

## Testing Strategy

### Unit Tests
- Bill generation logic
- Amount calculations
- Status transitions
- Validation rules

### Widget Tests
- Payment sheet UI
- Form validation
- Toggle functionality
- Date picker

### Integration Tests
- End-to-end payment flow
- Database persistence
- Service interactions
- UI updates

### Manual Tests
- Bill generates on correct date
- Payment updates account balance
- Multiple payments work correctly
- Error handling works
- UI displays correctly

## Monitoring & Logging

### Key Log Points
```
[BillGenerationService] Checking for bills to generate...
[BillGenerationService] Generated bill for Visa Card: $150
[BillGenerationService] Bill already exists for Visa Card
[BillGenerationService] Account has no bill date set
[MainShell] Error generating bills: ...
```

### Metrics to Track
- Bills generated per day
- Average bill amount
- Payment success rate
- Error frequency
- Performance metrics

## Future Enhancements

1. **Notifications**
   - Notify when bill is generated
   - Remind before due date
   - Confirm payment recorded

2. **Analytics**
   - Bill history view
   - Payment trends
   - Spending patterns
   - Budget tracking

3. **Automation**
   - Auto-payment scheduling
   - Recurring payments
   - Payment reminders

4. **Customization**
   - Custom due date offset
   - Multiple billing cycles
   - Custom bill names
   - Bill templates

5. **Integration**
   - Export bills as PDF
   - Email statements
   - Bank sync
   - API integration
