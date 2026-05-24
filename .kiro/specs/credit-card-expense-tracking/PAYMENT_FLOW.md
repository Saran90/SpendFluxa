# Bill Payment Flow - Technical Reference

## Component Hierarchy

```
AccountDetailScreen
├── Hero Card (displays account info)
│   └── "Pay Bill" Button (credit cards only)
│       └── onTap → _showPaymentSheet()
│
└── BillPaymentSheet (bottom sheet modal)
    ├── Outstanding Balance Display
    ├── Payment Amount Input
    ├── "Same as Outstanding" Toggle
    ├── Payment Date Picker
    ├── Note Field
    └── Record Payment Button
        └── onPaymentSubmitted callback
```

## Data Flow

### 1. Payment Sheet Display
```dart
_showPaymentSheet(context, creditCardAccount, fmt) {
  // Get outstanding balance from service
  final outstandingBalance = billService.getOutstandingBalance(accountId);
  
  // Show bottom sheet with payment UI
  showModalBottomSheet(
    builder: (ctx) => BillPaymentSheet(
      outstandingBalance: outstandingBalance,
      onPaymentSubmitted: (amount, note) { ... }
    )
  );
}
```

### 2. Payment Recording
```dart
onPaymentSubmitted: (amount, note) async {
  // 1. Get latest bill for account
  final latestBill = billService.getLatestBillForAccount(accountId);
  
  // 2. Record payment in database
  await billService.recordPayment(
    billId: latestBill.id,
    amount: amount,
    paymentDate: DateTime.now(),
    note: note
  );
  
  // 3. Update account balance
  await accountService.adjustBalance(accountId, -amount);
  
  // 4. Show success notification
  _showSnackBar(context, 'Payment recorded');
}
```

### 3. Service Layer Operations

#### CreditCardBillService.recordPayment()
```dart
Future<void> recordPayment(
  String billId,
  double amount,
  DateTime paymentDate,
  String? note,
) async {
  // 1. Create BillPayment object
  final payment = BillPayment(
    id: _generateId(),
    billId: billId,
    amount: amount,
    paymentDate: paymentDate,
    note: note,
    createdAt: DateTime.now(),
  );
  
  // 2. Add to bill's payments list
  final updatedPayments = [...bill.payments, payment];
  
  // 3. Calculate new bill status
  final newStatus = _calculateBillStatus(
    bill.actualAmount,
    updatedPayments
  );
  
  // 4. Update bill in database
  final updatedBill = bill.copyWith(
    payments: updatedPayments,
    status: newStatus,
    updatedAt: DateTime.now(),
  );
  await update(updatedBill);
}
```

#### Bill Status Calculation
```dart
BillStatus _calculateBillStatus(
  double actualAmount,
  List<BillPayment> payments,
) {
  final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
  
  if (totalPaid >= actualAmount) {
    return BillStatus.paid;
  } else if (totalPaid > 0) {
    return BillStatus.partial;
  }
  return BillStatus.pending;
}
```

## UI Components

### "Pay Bill" Button
- **Location**: Hero card in AccountDetailScreen
- **Visibility**: Only for credit card accounts
- **Style**: Semi-transparent white button with payment icon
- **Action**: Opens BillPaymentSheet

### BillPaymentSheet Sections

#### Outstanding Balance Card
```dart
Container(
  padding: EdgeInsets.all(16),
  child: Column(
    children: [
      Text('Outstanding Balance'),
      Text('$symbol $amount'), // Large, prominent display
    ],
  ),
)
```

#### Payment Amount Input
```dart
Row(
  children: [
    Text(symbol), // Currency symbol
    TextField(
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      hintText: '0.00',
    ),
  ],
)
```

#### "Same as Outstanding" Toggle
```dart
GestureDetector(
  onTap: _toggleSameAsOutstanding,
  child: Container(
    decoration: BoxDecoration(
      color: _useSameAsOutstanding ? primary.withAlpha(0.12) : background,
      border: Border.all(
        color: _useSameAsOutstanding ? primary : secondary,
      ),
    ),
    child: Row(
      children: [
        CustomCheckbox(), // Visual indicator
        Column(
          children: [
            Text('Same as Outstanding'),
            Text('Pay the full outstanding balance'),
          ],
        ),
      ],
    ),
  ),
)
```

When toggled:
```dart
void _toggleSameAsOutstanding() {
  setState(() {
    _useSameAsOutstanding = !_useSameAsOutstanding;
    if (_useSameAsOutstanding) {
      _amountController.text = widget.outstandingBalance.toStringAsFixed(2);
    } else {
      _amountController.clear();
    }
  });
}
```

#### Payment Date Picker
```dart
GestureDetector(
  onTap: () async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Can only select past dates
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  },
  child: Container(
    child: Row(
      children: [
        Icon(Icons.calendar_today_rounded),
        Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
      ],
    ),
  ),
)
```

#### Submit Button
```dart
GestureDetector(
  onTap: _isSubmitting ? null : _submitPayment,
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _isSubmitting ? [primary.withAlpha(0.5), ...] : [primary, ...],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isSubmitting)
          CircularProgressIndicator()
        else
          Icon(Icons.check_circle_rounded),
        Text(_isSubmitting ? 'Recording...' : 'Record Payment'),
      ],
    ),
  ),
)
```

## Validation Rules

### Amount Validation
```dart
Future<void> _submitPayment() async {
  final amountText = _amountController.text.trim();
  
  // 1. Check if empty
  if (amountText.isEmpty) {
    _showError('Please enter payment amount');
    return;
  }
  
  // 2. Check if valid number
  final amount = double.tryParse(amountText);
  if (amount == null || amount <= 0) {
    _showError('Please enter a valid amount');
    return;
  }
  
  // 3. Check if exceeds outstanding
  if (amount > widget.outstandingBalance) {
    _showError(
      'Payment amount cannot exceed outstanding balance '
      '(${widget.currencyService.formatter.format(widget.outstandingBalance)})'
    );
    return;
  }
  
  // Proceed with payment
  await _submitPayment();
}
```

## Error Handling

### SnackBar Notifications
```dart
void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.accent, // Red for errors
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
    ),
  );
}

void _showSuccess(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Color(0xFF2D9E6B), // Green for success
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
    ),
  );
}
```

## State Management

### BillPaymentSheet State
```dart
class _BillPaymentSheetState extends State<BillPaymentSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _useSameAsOutstanding = false;
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _selectedDate = DateTime.now();
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
```

### AccountDetailScreen Reactivity
```dart
ListenableBuilder(
  listenable: Listenable.merge([
    accountService,
    transactionService,
    currencyService,
    billService, // Listens for bill updates
  ]),
  builder: (context, _) {
    // Rebuilds when any service notifies listeners
    final current = accountService.all.firstWhere(...);
    final outstandingBalance = billService.getOutstandingBalance(current.id);
    // ...
  },
)
```

## Database Operations

### Insert Payment
```dart
// In CreditCardBillService.recordPayment()
await AppDatabase.instance.insert('bill_payments', {
  'id': payment.id,
  'bill_id': billId,
  'amount': amount,
  'payment_date': paymentDate.toIso8601String(),
  'note': note,
  'created_at': DateTime.now().toIso8601String(),
});
```

### Update Bill Status
```dart
// In CreditCardBillService.update()
await AppDatabase.instance.update(
  'credit_card_bills',
  {
    'status': newStatus.name,
    'updated_at': DateTime.now().toIso8601String(),
  },
  where: 'id = ?',
  whereArgs: [billId],
);
```

## Performance Considerations

1. **Outstanding Balance Calculation**: Cached in service, recalculated on payment
2. **Bill Queries**: Filtered by account ID for efficiency
3. **UI Updates**: Only rebuild when services notify (via Listenable)
4. **Async Operations**: Payment recording is async to prevent UI blocking

## Security Considerations

1. **Input Validation**: All amounts validated before processing
2. **Date Constraints**: Can only select past dates for payments
3. **Database Transactions**: Each payment is atomic
4. **Error Messages**: User-friendly without exposing system details
