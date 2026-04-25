# Recurring Transactions Section on Home Page

## Overview
Added a new section on the home page to display all recurring transaction templates, showing users their active recurring transactions at a glance.

## Implementation Details

### 1. TransactionService Update (`lib/core/services/transaction_service.dart`)

Added new method:
```dart
List<Transaction> getRecurringTemplates()
```

**Purpose**: Returns all recurring transaction templates (parent transactions)
- Filters for transactions where `isRecurring == true` and `recurringParentId == null`
- Sorts alphabetically by title
- Only returns the templates, not the individual instances

### 2. Home Screen Updates (`lib/features/home/home_screen.dart`)

#### New Section Added:
- Positioned below "Recent Transactions" section
- Shows all recurring transaction templates
- Includes empty state when no recurring transactions exist

#### New Methods:

**`_buildRecurringEmptyState()`**
- Empty state widget for when no recurring transactions exist
- Shows repeat icon and helpful message
- Encourages users to set up recurring transactions

**`_buildRecurringTile()`**
- Displays recurring transaction template information
- Shows category icon with recurring badge overlay
- Displays frequency (Daily, Weekly, Monthly, Yearly)
- Shows end date if specified
- Distinct visual style with border to differentiate from regular transactions

## UI Design

### Recurring Transaction Tile Features:

1. **Category Icon with Badge**
   - Category icon in colored background
   - Small recurring icon badge in top-right corner
   - White border around badge for visibility

2. **Title**
   - Removes "(Recurring)" suffix for cleaner display
   - Bold font weight
   - Single line with ellipsis overflow

3. **Frequency Badge**
   - Colored pill showing frequency (Daily/Weekly/Monthly/Yearly)
   - Primary color background with transparency
   - Small, compact design

4. **End Date (Optional)**
   - Shows "Until [date]" if end date is set
   - Formatted as "MMM d" (e.g., "Until Dec 31")
   - Separated by bullet point

5. **Amount**
   - Shows with +/- sign
   - Color-coded (green for income, dark for expense)
   - Bold font weight

6. **Visual Distinction**
   - Border with primary color (20% opacity)
   - Differentiates from regular transactions
   - Maintains consistent card style

### Empty State:

- Repeat icon (56px)
- "No recurring transactions" heading
- Helpful subtext encouraging setup
- Consistent with other empty states

## User Experience

### What Users See:

**Recurring Transactions Section shows:**
- All active recurring transaction templates
- Frequency of each recurring transaction
- End date (if specified)
- Amount and category
- Visual indicator (recurring badge)

**Benefits:**
1. **Quick Overview**: See all recurring transactions at a glance
2. **Easy Management**: Identify which transactions are set to recur
3. **Transparency**: Know what automatic transactions to expect
4. **Planning**: Better budget planning with visible recurring expenses/income

### Example Display:

```
Recurring Transactions

┌─────────────────────────────────────────┐
│ 🏠 Apartment Rent                       │
│ [Monthly] • Until Dec 31    -$1,200.00 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 💼 Monthly Salary                       │
│ [Monthly]                   +$4,500.00 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 📺 Netflix Subscription                 │
│ [Monthly]                      -$15.99 │
└─────────────────────────────────────────┘
```

## Section Placement

**Home Page Structure:**
1. Header (Balance, Greeting)
2. Summary Row (Income/Expenses)
3. Spending Progress Bar
4. **Recent Transactions** ← Existing
5. **Recurring Transactions** ← New Section
6. Bottom Padding

## Technical Notes

### Data Flow:
1. `TransactionService.getRecurringTemplates()` fetches templates
2. Home screen builds recurring section
3. Each template rendered as `_buildRecurringTile()`
4. Empty state shown if no templates exist

### Performance:
- Efficient filtering (only templates, not instances)
- Sorted alphabetically for consistency
- No pagination needed (typically few recurring transactions)

### Future Enhancements:
- Tap to view/edit recurring transaction
- Quick toggle to pause/resume recurring transaction
- Show next scheduled date for each recurring transaction
- Swipe actions (edit, delete, pause)
- Filter by frequency or category
- Show count of upcoming instances
