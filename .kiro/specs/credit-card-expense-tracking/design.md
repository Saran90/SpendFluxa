# Credit Card Expense Tracking - Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     UI Layer                                 │
├─────────────────────────────────────────────────────────────┤
│  • Account Detail Screen (with CC balance)                   │
│  • Bill Management Screen                                    │
│  • Bill Detail & Reconciliation Screen                       │
│  • Transaction State Indicator                               │
│  • Analytics & Reporting                                     │
├─────────────────────────────────────────────────────────────┤
│                   Service Layer                              │
├─────────────────────────────────────────────────────────────┤
│  • CreditCardBillService (CRUD, state management)            │
│  • TransactionStateService (state transitions)               │
│  • BillReconciliationService (reconciliation logic)          │
│  • CreditCardAnalyticsService (reporting)                    │
├─────────────────────────────────────────────────────────────┤
│                   Model Layer                                │
├─────────────────────────────────────────────────────────────┤
│  • CreditCardBill (new model)                                │
│  • Transaction (extended with state, CC fields)              │
│  • Account (extended with CC config)                         │
│  • BillPayment (new model for partial payments)              │
└─────────────────────────────────────────────────────────────┘
```

## Data Models

### 1. Extended Transaction Model

```dart
class Transaction {
  // Existing fields...
  
  // New credit card fields
  String? creditCardAccountId;        // Links to CC account
  TransactionState state;             // pending, billed, paid
  String? creditCardBillId;           // Links to bill (if billed)
  DateTime? stateChangedAt;           // Audit trail
  
  // Getters
  bool get isCreditCardTransaction => creditCardAccountId != null;
  bool get isPending => state == TransactionState.pending;
  bool get isBilled => state == TransactionState.billed;
  bool get isPaid => state == TransactionState.paid;
}

enum TransactionState {
  pending,  // Created, not yet billed
  billed,   // Included in a bill
  paid,     // Bill containing this transaction has been paid
}
```

### 2. CreditCardBill Model (New)

```dart
class CreditCardBill {
  final String id;
  final String creditCardAccountId;
  final DateTime billDate;
  final DateTime dueDate;
  final double trackedAmount;         // Sum of transactions
  final double actualAmount;          // From bank statement
  final double? difference;           // Surcharges, interest, fees
  final String? differenceNote;       // Explanation of difference
  final List<String> transactionIds;  // Transactions in this bill
  final BillStatus status;            // pending, partial, paid
  final List<BillPayment> payments;   // Payment history
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Getters
  double get outstandingBalance => actualAmount - totalPaid;
  double get totalPaid => payments.fold(0, (sum, p) => sum + p.amount);
  bool get isFullyPaid => outstandingBalance <= 0;
  bool get isPartiallyPaid => totalPaid > 0 && !isFullyPaid;
}

enum BillStatus {
  pending,   // Created, not yet paid
  partial,   // Partially paid
  paid,      // Fully paid
}
```

### 3. BillPayment Model (New)

```dart
class BillPayment {
  final String id;
  final String billId;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;
}
```

### 4. Extended Account Model

```dart
class Account {
  // Existing fields...
  
  // New credit card fields
  bool isCreditCard;                  // Is this a CC account?
  CreditCardConfig? creditCardConfig; // CC-specific settings
}

class CreditCardConfig {
  final int billingCycleDay;          // Day of month bill is generated (1-28)
  final BudgetCountingMethod budgetCountingMethod;
  final String? issuerName;           // e.g., "HDFC", "ICICI"
  final String? lastFourDigits;       // e.g., "1234"
  final double? creditLimit;          // Optional
  final DateTime? statementStartDate; // For tracking cycles
}

enum BudgetCountingMethod {
  committed,  // Count all CC transactions
  billed,     // Count only billed transactions
  paid,       // Count only paid transactions
}
```

## Service Layer Design

### CreditCardBillService

```dart
class CreditCardBillService extends ChangeNotifier {
  // CRUD Operations
  Future<void> createBill(CreditCardBill bill);
  Future<void> updateBill(CreditCardBill bill);
  Future<void> deleteBill(String billId);
  CreditCardBill? getBillById(String billId);
  List<CreditCardBill> getBillsByAccount(String accountId);
  List<CreditCardBill> getBillsByDateRange(DateTime start, DateTime end);
  
  // Bill Management
  Future<void> addTransactionToBill(String billId, String transactionId);
  Future<void> removeTransactionFromBill(String billId, String transactionId);
  Future<void> recordPayment(String billId, BillPayment payment);
  Future<void> markBillAsPaid(String billId);
  
  // Auto-generation
  Future<void> generateBillsForDate(DateTime date);
  Future<List<CreditCardBill>> generateBillsForAccount(
    String accountId,
    DateTime date,
  );
  
  // Reconciliation
  Future<void> updateBillAmount(String billId, double actualAmount);
  Future<void> addDifference(String billId, double amount, String note);
  
  // Queries
  double getOutstandingBalance(String accountId);
  List<CreditCardBill> getPendingBills(String accountId);
  List<CreditCardBill> getUnpaidBills(String accountId);
}
```

### TransactionStateService

```dart
class TransactionStateService {
  // State Transitions
  Future<void> markAsBilled(String transactionId, String billId);
  Future<void> markAsPaid(String transactionId);
  Future<void> revertToPending(String transactionId);
  
  // Bulk Operations
  Future<void> markMultipleAsBilled(
    List<String> transactionIds,
    String billId,
  );
  Future<void> markMultipleAsPaid(List<String> transactionIds);
  
  // Queries
  List<Transaction> getTransactionsByState(
    String accountId,
    TransactionState state,
  );
  List<Transaction> getTransactionsByBill(String billId);
}
```

### BillReconciliationService

```dart
class BillReconciliationService {
  // Reconciliation
  ReconciliationReport generateReport(String billId);
  Future<void> reconcileBill(String billId, double actualAmount);
  
  // Discrepancy Detection
  List<DiscrepancyItem> findDiscrepancies(String billId);
  
  // Adjustment
  Future<void> addAdjustment(
    String billId,
    double amount,
    String reason,
  );
}

class ReconciliationReport {
  final String billId;
  final double trackedTotal;
  final double actualTotal;
  final double difference;
  final List<DiscrepancyItem> discrepancies;
  final ReconciliationStatus status;
}

enum ReconciliationStatus {
  pending,
  partial,
  reconciled,
}
```

### CreditCardAnalyticsService

```dart
class CreditCardAnalyticsService {
  // Spending Analysis
  Map<String, double> getSpendingByCategory(
    String accountId,
    DateTime start,
    DateTime end,
  );
  
  // State Breakdown
  StateBreakdown getStateBreakdown(String accountId);
  
  // Payment Patterns
  PaymentPattern getPaymentPattern(String accountId);
  
  // Trends
  List<BalanceTrendPoint> getBalanceTrend(
    String accountId,
    DateTime start,
    DateTime end,
  );
}

class StateBreakdown {
  final double pendingAmount;
  final double billedAmount;
  final double paidAmount;
}

class PaymentPattern {
  final double averageBillAmount;
  final double averagePaymentAmount;
  final int averageDaysToPayBill;
  final double totalPaidThisYear;
}

class BalanceTrendPoint {
  final DateTime date;
  final double balance;
}
```

## UI Components

### 1. Transaction State Indicator

```dart
// Shows transaction state with color coding
// pending: orange, billed: blue, paid: green
Widget _buildStateIndicator(TransactionState state) {
  // Visual indicator in transaction tiles
}
```

### 2. Credit Card Balance Widget

```dart
// Displays on account detail and home screen
// Shows: Outstanding Balance, Last Bill Date, Next Due Date
Widget _buildCreditCardBalance(Account account) {
  // Prominent display of CC balance
}
```

### 3. Bill Management Screen

```dart
// New screen for managing bills
// Features:
// - List of bills (pending, partial, paid)
// - Create new bill
// - View bill details
// - Record payments
// - Reconcile bill
```

### 4. Bill Detail Screen

```dart
// Shows:
// - Bill summary (date, amount, status)
// - Transactions in bill
// - Payment history
// - Reconciliation section
// - Actions (mark paid, add payment, reconcile)
```

### 5. Transaction Detail Enhancement

```dart
// Add to existing transaction detail screen:
// - Transaction state badge
// - Credit card account info
// - Bill link (if billed)
// - State change history
```

## Database Schema Changes

### New Tables

```sql
-- Credit Card Bills
CREATE TABLE credit_card_bills (
  id TEXT PRIMARY KEY,
  credit_card_account_id TEXT NOT NULL,
  bill_date TEXT NOT NULL,
  due_date TEXT NOT NULL,
  tracked_amount REAL NOT NULL,
  actual_amount REAL NOT NULL,
  difference REAL,
  difference_note TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (credit_card_account_id) REFERENCES accounts(id)
);

-- Bill Payments
CREATE TABLE bill_payments (
  id TEXT PRIMARY KEY,
  bill_id TEXT NOT NULL,
  amount REAL NOT NULL,
  payment_date TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (bill_id) REFERENCES credit_card_bills(id)
);

-- Bill Transactions (junction table)
CREATE TABLE bill_transactions (
  bill_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  PRIMARY KEY (bill_id, transaction_id),
  FOREIGN KEY (bill_id) REFERENCES credit_card_bills(id),
  FOREIGN KEY (transaction_id) REFERENCES transactions(id)
);
```

### Modified Tables

```sql
-- Extend transactions table
ALTER TABLE transactions ADD COLUMN credit_card_account_id TEXT;
ALTER TABLE transactions ADD COLUMN transaction_state TEXT DEFAULT 'pending';
ALTER TABLE transactions ADD COLUMN credit_card_bill_id TEXT;
ALTER TABLE transactions ADD COLUMN state_changed_at TEXT;

-- Extend accounts table
ALTER TABLE accounts ADD COLUMN is_credit_card BOOLEAN DEFAULT FALSE;
ALTER TABLE accounts ADD COLUMN billing_cycle_day INTEGER;
ALTER TABLE accounts ADD COLUMN budget_counting_method TEXT DEFAULT 'committed';
ALTER TABLE accounts ADD COLUMN issuer_name TEXT;
ALTER TABLE accounts ADD COLUMN last_four_digits TEXT;
ALTER TABLE accounts ADD COLUMN credit_limit REAL;
```

## State Management Flow

```
User Creates CC Transaction
    ↓
Transaction created with state = pending
    ↓
User Creates/Receives Bill
    ↓
Transactions marked as billed (state = billed)
    ↓
User Records Payment
    ↓
Bill marked as paid (state = paid)
    ↓
Transactions marked as paid (state = paid)
    ↓
Account balance updated
```

## Budget Calculation Logic

```dart
// Committed: All CC transactions count
double committedExpenses = transactions
  .where((t) => t.isCreditCardTransaction)
  .fold(0, (sum, t) => sum + t.amount);

// Billed: Only billed transactions count
double billedExpenses = transactions
  .where((t) => t.isCreditCardTransaction && t.isBilled)
  .fold(0, (sum, t) => sum + t.amount);

// Paid: Only paid transactions count
double paidExpenses = transactions
  .where((t) => t.isCreditCardTransaction && t.isPaid)
  .fold(0, (sum, t) => sum + t.amount);

// Select based on account config
double expensesToCount = switch(account.creditCardConfig?.budgetCountingMethod) {
  BudgetCountingMethod.committed => committedExpenses,
  BudgetCountingMethod.billed => billedExpenses,
  BudgetCountingMethod.paid => paidExpenses,
  null => 0,
};
```

## Integration Points

### With Existing Systems

1. **TransactionService**: Extended to handle CC fields and state
2. **AccountService**: Extended to handle CC configuration
3. **BudgetService**: Modified to respect budget counting method
4. **AnalyticsService**: Extended to show CC-specific metrics
5. **NotificationService**: New reminders for bill due dates

### Data Flow

```
Add Transaction
    ↓
TransactionService.addTransaction()
    ↓
If CC account: set state = pending
    ↓
Notify listeners
    ↓
UI updates with pending badge

Create Bill
    ↓
CreditCardBillService.createBill()
    ↓
Link transactions to bill
    ↓
Update transaction states to billed
    ↓
Notify listeners
    ↓
UI updates, budget recalculates

Record Payment
    ↓
CreditCardBillService.recordPayment()
    ↓
Update bill status
    ↓
If fully paid: mark transactions as paid
    ↓
Update account balance
    ↓
Notify listeners
    ↓
UI updates
```

## Error Handling

- Invalid state transitions (e.g., paid → pending) → throw exception
- Bill amount mismatch → show reconciliation warning
- Missing transactions in bill → show discrepancy alert
- Duplicate bill creation → prevent with date/account check
- Orphaned transactions → handle gracefully in queries

## Performance Considerations

- Index on `credit_card_account_id` and `transaction_state` for fast queries
- Cache outstanding balance per account
- Lazy load bill transactions (paginate if > 100)
- Batch update operations for bulk state changes
- Debounce balance recalculation
