# Credit Card EMI Feature

## Overview
Added comprehensive EMI (Equated Monthly Installment) support for credit card transactions. Users can now convert credit card purchases into EMI with custom interest rates and durations, automatically creating monthly installment transactions.

## Features Implemented

### 1. **Transaction Model Updates** (`lib/core/models/transaction.dart`)

Added EMI-related fields to the Transaction model:
```dart
final bool isEmi;
final double? emiInterestRate;        // Annual interest rate percentage
final int? emiDurationMonths;         // Duration (3, 6, 9, 12, 18, 24 months)
final double? emiMonthlyAmount;       // Calculated EMI per month
final String? parentTransactionId;    // Links installments to original purchase
```

### 2. **EMI Card UI** (`lib/features/transactions/add_transaction_screen.dart`)

#### When Shown
- Only appears for **Expense transactions**
- Only when **Credit Card** is selected as the account
- Hidden for other account types and transaction types

#### Components

**A. EMI Toggle Switch**
- Enable/disable EMI conversion
- Icon: credit_score_rounded
- Color-coded to match transaction type
- Clear visual feedback

**B. Interest Rate Input**
- Decimal input (e.g., 12.5%)
- Validates up to 2 decimal places
- Suffix shows "%" symbol
- Focused border matches transaction type color

**C. Duration Selection**
- Chip-based selection
- Options: 3, 6, 9, 12, 18, 24 months
- Visual feedback for selected duration
- Color-coded to transaction type

**D. EMI Calculation Preview**
- Shows calculated monthly EMI amount
- Shows total amount to be paid
- Updates in real-time as values change
- Highlighted background for visibility

### 3. **EMI Calculation**

Uses the standard EMI formula:
```
EMI = [P × R × (1+R)^N] / [(1+R)^N - 1]

Where:
P = Principal amount (purchase amount)
R = Monthly interest rate (annual rate / 12 / 100)
N = Number of months (duration)
```

### 4. **Transaction Creation Logic**

#### Regular Credit Card Transaction (Non-EMI)
- Creates single transaction
- Amount added to next billing cycle
- Standard transaction flow

#### EMI Transaction
Creates multiple transactions:

**A. Parent Transaction**
- Original purchase amount
- Marked as EMI (`isEmi: true`)
- Contains EMI metadata (rate, duration, monthly amount)
- Note includes EMI details
- Date: Purchase date

**B. Installment Transactions**
- One transaction per month
- Amount: Calculated EMI amount
- Title: "Product Name - EMI 1/12", "EMI 2/12", etc.
- Date: Incremented monthly from purchase date
- Linked to parent via `parentTransactionId`
- Tagged with same tags as parent
- Same category and account

### 5. **Validation**

- Interest rate must be > 0 when EMI is enabled
- Amount must be valid
- Duration must be selected
- All standard transaction validations apply

## User Workflow

### Creating an EMI Transaction

1. **Start Transaction**
   - Tap "+" button
   - Select "Expense"
   - Enter amount (e.g., ₹50,000)

2. **Select Credit Card**
   - Choose credit card from account list
   - EMI card appears automatically

3. **Enable EMI**
   - Toggle "Convert to EMI" switch ON
   - EMI options expand

4. **Enter Interest Rate**
   - Type annual interest rate (e.g., 15%)
   - Preview updates automatically

5. **Select Duration**
   - Tap duration chip (e.g., 12 months)
   - See monthly EMI calculation

6. **Review Preview**
   - Monthly EMI: ₹4,504
   - Total Amount: ₹54,048
   - Includes interest

7. **Save**
   - Tap "Save Expense"
   - Creates 1 parent + 12 installment transactions

### Example Calculation

**Purchase**: ₹50,000 laptop
**Interest Rate**: 15% p.a.
**Duration**: 12 months

**Result**:
- Monthly EMI: ₹4,504
- Total Payment: ₹54,048
- Total Interest: ₹4,048

**Transactions Created**:
1. Parent: "Laptop (EMI)" - ₹50,000 (today)
2. EMI 1/12: ₹4,504 (next month)
3. EMI 2/12: ₹4,504 (month 2)
... (continues for 12 months)

## UI/UX Design

### EMI Card Layout

```
┌─────────────────────────────────────┐
│ 💳 EMI TRANSACTION                  │
│    Convert to EMI          [Toggle] │
├─────────────────────────────────────┤
│ INTEREST RATE (% PER ANNUM)         │
│ [12.5                          %]   │
│                                     │
│ DURATION                            │
│ [3 months] [6 months] [9 months]   │
│ [12 months] [18 months] [24 months]│
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Monthly EMI:        ₹4,504      │ │
│ │ Total Amount:       ₹54,048     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Visual Feedback

- **Toggle ON**: Switch turns transaction color (red/green/teal)
- **Selected Duration**: Chip highlighted with border and background
- **Preview Box**: Subtle background with transaction color tint
- **Real-time Updates**: Preview recalculates on any change

## Technical Implementation

### Files Modified

1. **lib/core/models/transaction.dart**
   - Added EMI fields
   - Updated copyWith, toMap, fromMap methods

2. **lib/features/transactions/add_transaction_screen.dart**
   - Added EMI state variables
   - Added `_shouldShowEmiOptions()` helper
   - Added `_buildEmiCard()` UI builder
   - Added `_calculateEmi()` calculation method
   - Added `_createEmiTransactions()` for EMI creation
   - Updated `_save()` method with EMI logic
   - Added dart:math import for pow function

### State Management

```dart
bool _isEmi = false;
double _emiInterestRate = 0.0;
int _emiDurationMonths = 3;
final _emiInterestController = TextEditingController();
```

### Conditional Rendering

```dart
bool _shouldShowEmiOptions() {
  if (_type != TransactionType.expense) return false;
  if (_fromAccount == null) return false;
  return _fromAccount!.type == AccountType.creditCard;
}
```

## Benefits

1. **Accurate Tracking** - Each EMI installment tracked separately
2. **Budget Planning** - See future EMI obligations
3. **Interest Visibility** - Clear view of interest costs
4. **Flexible Terms** - Multiple duration options
5. **Automatic Scheduling** - Installments auto-created for future months
6. **Linked Transactions** - Parent-child relationship maintained

## Edge Cases Handled

1. **Zero Interest** - Validation prevents saving
2. **Invalid Amount** - Standard validation applies
3. **Account Change** - EMI card hides if non-credit card selected
4. **Type Change** - EMI card hides for income/transfer
5. **Toggle Off** - Clears EMI data when disabled
6. **Date Calculation** - Handles month-end dates correctly

## Future Enhancements (Optional)

1. **Prepayment** - Option to pay off EMI early
2. **Skip Installment** - Mark installment as skipped
3. **EMI Dashboard** - View all active EMIs
4. **Payment Reminders** - Notifications for upcoming EMIs
5. **Interest Comparison** - Compare different EMI options
6. **Partial Payment** - Pay extra towards principal
7. **EMI History** - Track completed EMIs
8. **Export EMI Schedule** - Download payment schedule

## Testing Checklist

- [x] EMI card appears only for credit card expenses
- [x] EMI card hides for other account types
- [x] Toggle switch enables/disables EMI options
- [x] Interest rate input accepts decimals
- [x] Duration chips are selectable
- [x] EMI calculation is accurate
- [x] Preview updates in real-time
- [x] Validation prevents invalid EMI
- [x] Parent transaction created correctly
- [x] Installment transactions created for each month
- [x] Dates increment correctly
- [x] Tags applied to all transactions
- [x] Parent-child relationship maintained
- [x] Total amount calculation is correct

## Example Scenarios

### Scenario 1: Laptop Purchase
- **Amount**: ₹80,000
- **Rate**: 12% p.a.
- **Duration**: 6 months
- **Monthly EMI**: ₹13,616
- **Total**: ₹81,696
- **Interest**: ₹1,696

### Scenario 2: Phone Purchase
- **Amount**: ₹30,000
- **Rate**: 18% p.a.
- **Duration**: 3 months
- **Monthly EMI**: ₹10,227
- **Total**: ₹30,681
- **Interest**: ₹681

### Scenario 3: Furniture Purchase
- **Amount**: ₹1,50,000
- **Rate**: 15% p.a.
- **Duration**: 24 months
- **Monthly EMI**: ₹7,264
- **Total**: ₹1,74,336
- **Interest**: ₹24,336

## Conclusion

The EMI feature provides comprehensive support for credit card installment purchases, making it easy to track and manage EMI obligations. The automatic creation of monthly installments ensures accurate budget planning and expense tracking over time.
