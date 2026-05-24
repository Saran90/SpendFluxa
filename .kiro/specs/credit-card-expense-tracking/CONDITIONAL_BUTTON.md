# Conditional Bill Action Button - Implementation Summary

## Overview

The account detail screen now shows a conditional button that displays either "Generate Bill" or "Pay Bill" based on the credit card's state:

- **No Bill Date Set** → Show "Generate Bill" button
- **Bill Date Set but No Bill Exists** → Show "Generate Bill" button  
- **Bill Exists** → Show "Pay Bill" button

## Implementation Details

### 1. Updated AccountDetailScreen

**File**: `lib/features/accounts/account_detail_screen.dart`

**Changes**:
- Converted from `StatelessWidget` to `StatefulWidget` to support `setState()`
- Added `billService` and `billGenerationService` parameters
- Added conditional button logic in hero card
- Implemented three new methods:
  - `_buildBillActionButton()` - Determines which button to show
  - `_buildGenerateBillButton()` - Renders "Generate Bill" button
  - `_buildPayBillButton()` - Renders "Pay Bill" button
  - `_generateBillManually()` - Handles bill generation
  - `_showPaymentSheet()` - Shows payment UI
  - `_showSnackBar()` - Shows notifications

### 2. Button Logic

```dart
Widget _buildBillActionButton(
  BuildContext context,
  Account creditCardAccount,
  NumberFormat fmt,
) {
  // Check if bill date is set
  if (creditCardAccount.billDate == null) {
    return _buildGenerateBillButton(context, creditCardAccount);
  }

  // Check if a bill exists for this account
  final latestBill = widget.billService.getLatestBillForAccount(
    creditCardAccount.id,
  );

  if (latestBill == null) {
    return _buildGenerateBillButton(context, creditCardAccount);
  }

  // Bill exists, show pay bill button
  return _buildPayBillButton(context, creditCardAccount, fmt);
}
```

### 3. Generate Bill Button

**Icon**: `Icons.add_circle_rounded`
**Label**: "Generate Bill"
**Action**: Calls `_generateBillManually()`

```dart
Widget _buildGenerateBillButton(
  BuildContext context,
  Account creditCardAccount,
) {
  return GestureDetector(
    onTap: () => _generateBillManually(context, creditCardAccount),
    child: Container(
      // ... styling
      child: Row(
        children: [
          Icon(Icons.add_circle_rounded, ...),
          Text('Generate Bill', ...),
        ],
      ),
    ),
  );
}
```

### 4. Pay Bill Button

**Icon**: `Icons.payment_rounded`
**Label**: "Pay Bill"
**Action**: Calls `_showPaymentSheet()`

```dart
Widget _buildPayBillButton(
  BuildContext context,
  Account creditCardAccount,
  NumberFormat fmt,
) {
  return GestureDetector(
    onTap: () => _showPaymentSheet(context, creditCardAccount, fmt),
    child: Container(
      // ... styling
      child: Row(
        children: [
          Icon(Icons.payment_rounded, ...),
          Text('Pay Bill', ...),
        ],
      ),
    ),
  );
}
```

### 5. Manual Bill Generation

```dart
Future<void> _generateBillManually(
  BuildContext context,
  Account creditCardAccount,
) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Generate bill
    await widget.billGenerationService.checkAndGenerateBills();

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    // Refresh the screen
    setState(() {});

    _showSnackBar(context, 'Bill generated successfully');
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog
    _showSnackBar(context, 'Error generating bill: $e', isError: true);
  }
}
```

## User Flow

### Scenario 1: No Bill Date Set

```
User navigates to credit card account
↓
Account has no billDate set
↓
"Generate Bill" button appears
↓
User taps "Generate Bill"
↓
Loading dialog shows
↓
BillGenerationService checks account
↓
No bill date → Skip generation
↓
Loading dialog closes
↓
Success message shown
↓
Button remains "Generate Bill"
```

### Scenario 2: Bill Date Set, No Bill Exists

```
User navigates to credit card account
↓
Account has billDate = 15
↓
Today = May 10 (before bill date)
↓
"Generate Bill" button appears
↓
User taps "Generate Bill"
↓
Loading dialog shows
↓
BillGenerationService checks account
↓
Today (10) < billDate (15) → Skip generation
↓
Loading dialog closes
↓
Success message shown
↓
Button remains "Generate Bill"
```

### Scenario 3: Bill Date Arrived, Bill Generated

```
User navigates to credit card account
↓
Account has billDate = 15
↓
Today = May 15 (bill date arrived)
↓
Bill exists for May
↓
"Pay Bill" button appears
↓
User taps "Pay Bill"
↓
BillPaymentSheet opens
↓
User records payment
↓
Payment recorded, account updated
↓
Button remains "Pay Bill"
```

### Scenario 4: Bill Paid, New Bill Generated

```
User navigates to credit card account
↓
Previous bill fully paid
↓
New bill generated for next month
↓
"Pay Bill" button appears
↓
User can record payment for new bill
```

## Service Integration

### AccountDetailScreen Dependencies

```
widget.billService
  ├── getLatestBillForAccount(accountId)
  ├── recordPayment(billId, amount, date, note)
  └── adjustBalance(accountId, delta)

widget.billGenerationService
  └── checkAndGenerateBills()

widget.accountService
  └── adjustBalance(accountId, delta)

widget.currencyService
  └── formatter
```

### HomeScreen Updates

**File**: `lib/features/home/home_screen.dart`

- Added `billGenerationService` parameter
- Passes `billGenerationService` to `AccountDetailScreen`

### MainShell Updates

**File**: `lib/features/shell/main_shell.dart`

- Added `billGenerationService` parameter
- Passes `billGenerationService` to `HomeScreen`

### Main App Updates

**File**: `lib/main.dart`

- Already has `billGenerationService` initialized
- Passes to `MainShell`

## UI/UX Details

### Button Styling

Both buttons have identical styling:
- **Background**: Semi-transparent white (0.2 alpha)
- **Border**: White with 0.3 alpha, 1.5 width
- **Border Radius**: 10px
- **Padding**: 16px horizontal, 12px vertical
- **Icon Size**: 18px
- **Font Size**: 14px
- **Font Weight**: 600

### Spacing

- **Above Button**: 20px (SizedBox)
- **Only for Credit Cards**: Conditional rendering

### Feedback

- **Loading State**: Circular progress indicator
- **Success**: Green snackbar with message
- **Error**: Red snackbar with error message
- **Screen Refresh**: `setState()` called after generation

## State Management

### AccountDetailScreen State

```dart
class _AccountDetailScreenState extends State<AccountDetailScreen> {
  // No additional state variables needed
  // All state comes from services via ListenableBuilder
}
```

### Reactive Updates

```dart
ListenableBuilder(
  listenable: Listenable.merge([
    widget.accountService,
    widget.transactionService,
    widget.currencyService,
    widget.billService,
  ]),
  builder: (context, _) {
    // Rebuilds when any service notifies
    // Button logic re-evaluates
  },
)
```

## Error Handling

### Bill Generation Errors

```dart
try {
  await widget.billGenerationService.checkAndGenerateBills();
} catch (e) {
  _showSnackBar(context, 'Error generating bill: $e', isError: true);
}
```

### Payment Recording Errors

```dart
try {
  await widget.billService.recordPayment(...);
  await widget.accountService.adjustBalance(...);
} catch (e) {
  _showSnackBar(context, 'Error recording payment: $e', isError: true);
}
```

## Testing Scenarios

### Test 1: No Bill Date
- Create CC account without bill date
- Verify "Generate Bill" button appears
- Tap button
- Verify success message
- Verify button still shows "Generate Bill"

### Test 2: Bill Date Not Arrived
- Create CC account with bill date = tomorrow
- Verify "Generate Bill" button appears
- Tap button
- Verify success message
- Verify button still shows "Generate Bill"

### Test 3: Bill Date Arrived
- Create CC account with bill date = today
- Add transactions
- Restart app (triggers auto-generation)
- Verify "Pay Bill" button appears
- Tap button
- Verify payment sheet opens

### Test 4: Bill Paid
- Record payment for full bill amount
- Verify bill status = paid
- Verify "Pay Bill" button still shows
- Can record additional payments if needed

### Test 5: Multiple Credit Cards
- Create 2 CC accounts with different bill dates
- Verify correct buttons appear for each
- Generate bills for both
- Verify both show "Pay Bill" buttons

## Files Modified

1. **lib/features/accounts/account_detail_screen.dart**
   - Converted to StatefulWidget
   - Added billService and billGenerationService parameters
   - Added conditional button logic
   - Added bill generation and payment methods

2. **lib/features/home/home_screen.dart**
   - Added billGenerationService parameter
   - Passes to AccountDetailScreen

3. **lib/features/shell/main_shell.dart**
   - Already had billGenerationService
   - Passes to HomeScreen

4. **lib/main.dart**
   - Already had billGenerationService
   - Passes to MainShell

## Compilation Status

✅ **All files compile successfully**
- No errors
- No warnings
- Ready for testing

## Future Enhancements

1. **Automatic Button Update**: Refresh button when bill is generated
2. **Bill Status Indicator**: Show bill status (pending/partial/paid)
3. **Quick Pay**: Show outstanding balance in button
4. **Animations**: Smooth transition between buttons
5. **Notifications**: Notify when bill is generated
6. **Reminders**: Remind before due date
