# Exclude from Expense Feature

## Overview
Added functionality to exclude specific transactions from expense calculations. This is particularly useful for EMI transactions and credit card purchases where you don't want the full amount counted in your monthly expense totals.

## Features Implemented

### 1. **Transaction Model Update**

Added `excludeFromExpense` field to the Transaction model:
```dart
final bool excludeFromExpense; // If true, not included in expense totals
```

- Default value: `false` (transactions are included by default)
- Persisted in database via toMap/fromMap methods
- Included in copyWith method for updates

### 2. **Automatic Exclusion for EMI Transactions**

**EMI Parent Transaction:**
- Automatically excluded from expense totals
- Represents the original purchase amount
- Not counted in monthly expense calculations

**EMI Installment Transactions:**
- Automatically excluded from expense totals
- Represent monthly EMI payments
- Not counted in monthly expense calculations

**Rationale:**
- Prevents double-counting (original amount + installments)
- EMI installments are payment obligations, not new expenses
- Provides clearer view of actual spending vs. payment schedules

### 3. **Manual Toggle for Regular Transactions**

Added a toggle switch in the transaction details card:

**Location:** Below the "Note" field in the Details card
**Visibility:** Only shown for Expense transactions
**Label:** "Exclude from expense totals"
**Description:** "Won't be counted in expense calculations"

**UI Components:**
- Icon: calculate_outlined
- Switch control (color-coded to transaction type)
- Explanatory text
- Tappable row for easy toggling

### 4. **Updated Expense Calculations**

Modified TransactionService methods to respect the exclusion flag:

**expensesForMonth():**
```dart
.where((t) => t.isExpense && !t.excludeFromExpense)
```

**expensesForTag():**
```dart
.where((t) => t.isExpense && !t.excludeFromExpense)
```

**Impact:**
- Home screen expense totals
- Budget tracking
- Analytics calculations
- Tag-based expense summaries
- All expense-related calculations

## User Workflows

### Workflow 1: EMI Transaction (Automatic)

1. **Create EMI Transaction**
   - Select Credit Card account
   - Enable EMI toggle
   - Enter interest rate and duration
   - Save transaction

2. **Result**
   - Parent transaction: Excluded automatically
   - 12 installment transactions: All excluded automatically
   - Monthly expense totals: Not affected by EMI amounts
   - Transactions still visible in transaction list

### Workflow 2: Manual Exclusion

1. **Create Regular Expense**
   - Enter amount (e.g., ₹10,000)
   - Select category
   - Add details

2. **Toggle Exclusion**
   - Scroll to "Exclude from expense totals"
   - Toggle switch ON
   - Save transaction

3. **Result**
   - Transaction created
   - Not counted in expense totals
   - Still visible in transaction list
   - Can be filtered/searched normally

### Workflow 3: Credit Card Purchase (Non-EMI)

1. **Regular Credit Card Purchase**
   - Select Credit Card account
   - Don't enable EMI
   - Optionally toggle "Exclude from expense totals"
   - Save transaction

2. **Result**
   - Single transaction created
   - Included/excluded based on toggle
   - Added to next billing cycle

## Use Cases

### 1. **EMI Purchases**
- **Problem**: Buying a ₹50,000 laptop on EMI shows ₹50,000 expense this month + ₹4,500 every month for 12 months
- **Solution**: EMI transactions excluded, only actual monthly payments tracked separately if needed

### 2. **Reimbursable Expenses**
- **Problem**: ₹20,000 business expense will be reimbursed but inflates personal expense totals
- **Solution**: Toggle "Exclude from expense totals" to keep it out of calculations

### 3. **Investment Purchases**
- **Problem**: Buying ₹1,00,000 in stocks/gold shows as huge expense
- **Solution**: Exclude from expense totals as it's an investment, not consumption

### 4. **Loan Payments**
- **Problem**: ₹30,000 loan payment counted as expense
- **Solution**: Exclude as it's debt repayment, not new spending

### 5. **Inter-Account Transfers**
- **Problem**: Moving money between accounts shows as expense
- **Solution**: Use Transfer type or exclude from expense

## UI/UX Design

### Toggle in Details Card

```
┌─────────────────────────────────────┐
│ 📝 Title (optional)                 │
├─────────────────────────────────────┤
│ 📄 Add a note...                    │
├─────────────────────────────────────┤
│ 🧮 Exclude from expense totals      │
│    Won't be counted in calculations │
│                            [Toggle] │
└─────────────────────────────────────┘
```

### Visual Feedback
- **Toggle OFF** (default): Gray/inactive
- **Toggle ON**: Transaction type color (red/green/teal)
- **Icon**: Calculator outline
- **Tappable**: Entire row is clickable

## Technical Implementation

### Files Modified

1. **lib/core/models/transaction.dart**
   - Added `excludeFromExpense` field
   - Updated constructor, copyWith, toMap, fromMap

2. **lib/core/services/transaction_service.dart**
   - Updated `expensesForMonth()` to filter excluded transactions
   - Updated `expensesForTag()` to filter excluded transactions

3. **lib/features/transactions/add_transaction_screen.dart**
   - Added `_excludeFromExpense` state variable
   - Added toggle UI in `_buildDetailsCard()`
   - Updated `_save()` to pass exclusion flag
   - Updated `_createEmiTransactions()` to auto-exclude EMI transactions

### State Management

```dart
bool _excludeFromExpense = false;
```

- Initialized to `false` (include by default)
- Updated via toggle switch
- Passed to Transaction constructor on save
- Automatically set to `true` for all EMI transactions

### Backward Compatibility

- Existing transactions without the field default to `false`
- No migration needed
- Old transactions continue to work normally

## Benefits

1. **Accurate Expense Tracking** - Only count actual consumption expenses
2. **Better Budgeting** - EMI obligations don't inflate monthly expenses
3. **Flexible Categorization** - Users control what counts as expense
4. **Clear Financial Picture** - Separate spending from payment obligations
5. **Investment Clarity** - Distinguish between expenses and investments
6. **Reimbursement Handling** - Track reimbursable expenses separately

## Edge Cases Handled

1. **EMI Transactions** - Always excluded automatically
2. **Income Transactions** - Toggle not shown (only for expenses)
3. **Transfer Transactions** - Toggle not shown (not expenses)
4. **Existing Transactions** - Default to included (backward compatible)
5. **Tag Calculations** - Respect exclusion flag
6. **Budget Tracking** - Respect exclusion flag

## Testing Checklist

- [x] Toggle appears only for expense transactions
- [x] Toggle hidden for income/transfer transactions
- [x] Toggle state persists when saving
- [x] EMI transactions automatically excluded
- [x] EMI installments automatically excluded
- [x] Expense totals exclude flagged transactions
- [x] Tag expense totals exclude flagged transactions
- [x] Home screen shows correct expense totals
- [x] Budget calculations respect exclusion
- [x] Transaction still visible in lists
- [x] Toggle works with all transaction types
- [x] Backward compatibility with old transactions

## Example Scenarios

### Scenario 1: Laptop EMI
- **Purchase**: ₹80,000 laptop on 12-month EMI
- **Monthly EMI**: ₹7,264
- **Expense Impact**: ₹0 (all excluded automatically)
- **Benefit**: Clean monthly expense tracking

### Scenario 2: Business Expense
- **Amount**: ₹15,000 client dinner (reimbursable)
- **Action**: Toggle "Exclude from expense totals" ON
- **Expense Impact**: ₹0
- **Benefit**: Personal expense totals remain accurate

### Scenario 3: Investment
- **Amount**: ₹50,000 gold purchase
- **Action**: Toggle "Exclude from expense totals" ON
- **Expense Impact**: ₹0
- **Benefit**: Investment tracked separately from consumption

### Scenario 4: Regular Expense
- **Amount**: ₹5,000 groceries
- **Action**: Leave toggle OFF (default)
- **Expense Impact**: ₹5,000
- **Benefit**: Normal expense tracking

## Future Enhancements (Optional)

1. **Bulk Toggle** - Exclude/include multiple transactions at once
2. **Category Rules** - Auto-exclude certain categories
3. **Conditional Exclusion** - Exclude based on amount threshold
4. **Temporary Exclusion** - Exclude until reimbursement received
5. **Exclusion Reports** - View all excluded transactions
6. **Budget Override** - Include excluded transactions in specific budgets
7. **Analytics Filter** - Toggle to show/hide excluded transactions
8. **Smart Suggestions** - AI suggests which transactions to exclude

## Conclusion

The exclude from expense feature provides fine-grained control over expense calculations, ensuring that EMI obligations, reimbursable expenses, and investments don't inflate monthly expense totals. The automatic exclusion for EMI transactions combined with manual control for regular transactions offers the perfect balance of automation and flexibility.
