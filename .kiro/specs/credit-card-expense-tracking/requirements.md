# Credit Card Expense Tracking - Requirements

## Introduction

SpendSense currently treats credit card transactions as immediate expenses, creating an accounting mismatch: transactions are recorded when made, but money doesn't leave the account until the bill is paid. Additionally, the actual bill amount may differ from tracked transactions due to surcharges, interest, and fees. This feature introduces a dual-tracking system to accurately reflect credit card accounting while maintaining flexibility for user preferences.

## Problem Statement

**Current State:**
- Credit card transactions recorded as expenses immediately
- No distinction between committed expenses (transactions made) and actual expenses (bill paid)
- Mismatch between tracked transaction total and actual bill amount
- Confusion about whether credit card transactions should count toward monthly budgets
- No way to track credit card balance or reconcile bills

**Impact:**
- Inaccurate monthly expense reporting
- Difficulty reconciling actual spending with tracked transactions
- Unclear account balance when credit card bills are pending
- No visibility into credit card-specific metrics

## Solution Overview

Implement a **three-tier expense tracking system** with transaction states and bill management:

1. **Tier 1: Committed Expenses** - All credit card transactions (for budgeting)
2. **Tier 2: Billed Expenses** - Transactions included in current bill (for reconciliation)
3. **Tier 3: Actual Expenses** - Only when bill is paid (for account balance)

## Glossary

| Term | Definition |
|------|-----------|
| **Credit Card Transaction** | A purchase made on a credit card (e.g., restaurant, shopping) |
| **Credit Card Bill** | Monthly statement from credit card issuer with all transactions and charges |
| **Transaction State** | Current status of a transaction: `pending` → `billed` → `paid` |
| **Committed Expense** | Any credit card transaction, regardless of bill status |
| **Billed Expense** | Credit card transaction included in the current bill |
| **Actual Expense** | Credit card transaction where the bill has been paid |
| **Bill Difference** | Variance between tracked transaction total and actual bill (surcharges, interest, fees) |
| **Credit Card Balance** | Outstanding amount owed on the credit card |

## Requirements

### Requirement 1: Transaction State Management

**User Story:** As a user, I want transactions to have clear states so I can understand whether a credit card transaction is pending, billed, or paid.

#### Acceptance Criteria

1. Each credit card transaction has a state: `pending`, `billed`, or `paid`
2. Transactions start in `pending` state when created
3. State transitions follow the sequence: `pending` → `billed` → `paid`
4. State cannot be reversed (e.g., cannot go from `paid` back to `billed`)
5. Transaction state is persisted and survives app restarts
6. State changes are logged with timestamps for audit trail

### Requirement 2: Credit Card Bill Model

**User Story:** As a user, I want to create and manage credit card bills so I can track what was charged and reconcile with my bank statement.

#### Acceptance Criteria

1. Bills can be created manually with a date, amount, and associated credit card account
2. Bills can be auto-generated from pending transactions on a specified date
3. Each bill displays:
   - Bill date
   - Total tracked transactions amount
   - Actual bill amount (from bank statement)
   - Difference (surcharges, interest, fees)
   - List of transactions included in the bill
4. Bills can be marked as paid, which updates account balance
5. Bills are linked to specific credit card accounts
6. Multiple bills can exist for the same credit card (monthly statements)

### Requirement 3: Budget Counting Options

**User Story:** As a user, I want to choose whether credit card transactions count toward my monthly budget so I can budget based on my preference.

#### Acceptance Criteria

1. User can configure per-account whether credit card transactions count toward monthly budget
2. Configuration options:
   - **Committed**: Count all credit card transactions (for strict budgeting)
   - **Billed**: Count only transactions in current bill (for reconciliation)
   - **Paid**: Count only when bill is paid (for actual spending)
3. Default is **Committed** for new credit card accounts
4. Budget calculations respect the selected counting method
5. User can change the counting method anytime
6. Budget UI shows which counting method is active

### Requirement 4: Credit Card Balance Tracking

**User Story:** As a user, I want to see my credit card balance so I know how much I owe.

#### Acceptance Criteria

1. Credit card accounts display current outstanding balance
2. Balance is calculated as: sum of all pending + billed transactions - paid bills
3. Balance updates in real-time when transactions are added/removed
4. Balance updates when bills are marked as paid
5. Balance is displayed prominently in account detail view
6. Balance is included in account summary on home screen

### Requirement 5: Partial Payment Support

**User Story:** As a user, I want to record partial payments on my credit card bill so I can track payments that don't cover the full amount.

#### Acceptance Criteria

1. Bills can be marked as partially paid with a payment amount
2. Partial payments reduce the outstanding balance
3. Multiple partial payments can be recorded for a single bill
4. Payment history is maintained for each bill
5. Remaining balance is calculated as: bill amount - total payments
6. Transactions remain in `billed` state until full payment is received

### Requirement 6: Multiple Credit Cards

**User Story:** As a user, I want to manage multiple credit cards with different billing cycles so I can track all my cards separately.

#### Acceptance Criteria

1. Multiple credit card accounts can be created
2. Each credit card has independent transaction and bill tracking
3. Each credit card can have different billing cycle dates (e.g., 5th, 15th, 25th)
4. Bills are generated separately for each credit card on their respective dates
5. Account summary shows aggregate balance across all credit cards
6. User can filter transactions/bills by credit card

### Requirement 7: Bill Reconciliation

**User Story:** As a user, I want to reconcile my tracked transactions with my bank statement so I can identify discrepancies.

#### Acceptance Criteria

1. Bill detail view shows side-by-side comparison:
   - Tracked transactions total
   - Actual bill amount from statement
   - Difference with breakdown (surcharges, interest, fees, etc.)
2. User can add/remove transactions from a bill if they were incorrectly included
3. User can add manual charges (surcharges, interest) to a bill
4. Reconciliation status shows: `pending`, `partial`, `reconciled`
5. Reconciliation history is maintained

### Requirement 8: Reporting and Analytics

**User Story:** As a user, I want to see analytics on my credit card spending so I can understand my payment patterns.

#### Acceptance Criteria

1. Analytics show credit card transactions by category
2. Analytics show pending vs. billed vs. paid breakdown
3. Analytics show average bill amount and payment patterns
4. Analytics show outstanding balance trend over time
5. User can filter analytics by credit card and date range
6. Comparison view shows committed vs. actual spending

### Requirement 9: Notifications and Reminders

**User Story:** As a user, I want to be reminded about upcoming credit card bills so I don't miss payment deadlines.

#### Acceptance Criteria

1. User can set reminder date for each credit card (e.g., 3 days before due date)
2. Notification shows bill amount and due date
3. User can snooze or dismiss reminders
4. Reminders are sent even if app is closed
5. User can configure reminder preferences per credit card

### Requirement 10: Data Migration

**User Story:** As an existing user, I want my current credit card transactions to be properly categorized so I don't lose data.

#### Acceptance Criteria

1. Existing credit card transactions are migrated to new system
2. All existing transactions are set to `pending` state initially
3. User can bulk-update transaction states
4. Migration preserves all transaction data (amount, date, category, notes)
5. Migration is one-time and non-reversible
6. Migration progress is shown to user

## Constraints

- Credit card accounts must be explicitly marked as such (not auto-detected)
- Bill dates must be in the past or present (cannot create future bills)
- Transaction state changes must be auditable
- System must support at least 5 credit cards per user
- Bill reconciliation must be manual (no automatic bank API integration in MVP)

## Assumptions

- Users have access to their bank statements for reconciliation
- Credit card transactions are always expenses (no income on credit cards)
- Bills are monthly (quarterly/annual billing not supported in MVP)
- Users want to track credit card balance for informational purposes

## Out of Scope (Future)

- Automatic bank API integration for bill amounts
- Credit card rewards tracking
- Interest calculation and APR tracking
- Credit score impact analysis
- Automatic payment scheduling
- Multi-currency credit cards
