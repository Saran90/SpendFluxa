# Budget Section on Home Page

## Overview
Added a horizontal scrollable budget section to the home page, displaying all active budgets (overall and category-specific) with visual progress indicators. Uses the same card-based design as the recurring transactions section.

## Implementation Details

### 1. Home Screen Updates (`lib/features/home/home_screen.dart`)

#### New Dependencies:
- Added `BudgetService` parameter
- Added `MonthlyBudget` import
- Listens to budget service changes

#### New Section Added:
- Positioned below "Recurring Transactions" section
- Shows all budgets for the current month
- Horizontal scrollable cards (140px height)
- Includes empty state when no budgets exist

#### New Methods:

**`_buildBudgetEmptyState()`**
- Empty state widget for when no budgets are set
- Shows wallet icon and helpful message
- Encourages users to create budgets

**`_getBudgetItems()`**
- Converts MonthlyBudget into list of _BudgetItem objects
- Includes overall budget if set
- Includes all category budgets
- Calculates spent amount for each budget

**`_buildBudgetCard()`**
- Displays budget information in card format
- Shows progress bar and percentage
- Color-coded based on budget status
- Displays spent/limit amounts

#### Helper Class:

**`_BudgetItem`**
- Data class for budget card information
- Contains: label, limit, spent, category, icon, color
- Used to standardize budget display

### 2. Main Shell Updates (`lib/features/shell/main_shell.dart`)

- Passed `budgetService` to HomeScreen
- Removed unused `tags_screen.dart` import

## Visual Design

### Budget Card Layout:

```
┌─────────────────────────┐
│ 🏠  [85%]              │  ← Icon + Percentage
│                         │
│ Food & Dining           │  ← Budget name
│ ████████░░ 85%          │  ← Progress bar
│ $150 left               │  ← Remaining amount
│                         │
│ $850 / $1,000          │  ← Spent / Limit
└─────────────────────────┘
```

### Card Features:

1. **Category Icon** (44px)
   - Colored background (15% opacity)
   - Category-specific icon
   - Overall budget uses wallet icon

2. **Percentage Badge**
   - Shows % of budget spent
   - Color changes when over budget (red)
   - Positioned in top-right

3. **Budget Name**
   - Bold, clear label
   - "Overall Budget" or category name
   - Single line with ellipsis

4. **Progress Bar**
   - Visual representation of spending
   - Color-coded (category color or red if over)
   - 6px height, rounded corners

5. **Remaining/Over Amount**
   - Shows "$X left" or "Over by $X"
   - Color changes when over budget
   - Small, secondary text

6. **Spent / Limit**
   - Large spent amount (bold)
   - Smaller limit amount
   - Clear visual hierarchy

### Color Scheme:

**Normal State:**
- Background: Category color gradient (8% to 2%)
- Border: Category color (30% opacity)
- Icon background: Category color (15% opacity)
- Progress bar: Category color
- Text: Category color

**Over Budget State:**
- Percentage badge: Red background
- Progress bar: Red
- Remaining text: Red
- Spent amount: Red

## User Experience

### What Users See:

**Budget Section displays:**
- Overall budget (if set)
- All category budgets
- Current spending vs limit
- Visual progress indicators
- Percentage spent
- Remaining amount or overage

### Benefits:

1. **Quick Overview** - See all budgets at a glance
2. **Visual Feedback** - Progress bars show spending status
3. **Early Warning** - Red indicators when over budget
4. **Space Efficient** - Fixed 140px height
5. **Easy Browsing** - Swipe to view all budgets

### Example Display:

```
Budgets

← [💰 Overall]  [🍔 Food]  [🚗 Transport]  [🏠 Rent] →
  85% spent     90% spent   45% spent      100% spent
  $750 left     $100 left   $550 left      Over by $50
```

## Data Flow

1. **Fetch Current Budget**
   ```dart
   final currentBudget = budgetService.budgetFor(_now.year, _now.month);
   ```

2. **Convert to Display Items**
   ```dart
   final items = _getBudgetItems(currentBudget, totalExpenses);
   ```

3. **Calculate Spending**
   - Overall budget: Uses total expenses
   - Category budgets: Filters transactions by category
   - Excludes transactions marked as `excludeFromExpense`

4. **Render Cards**
   - Horizontal ListView with fixed height
   - Each budget rendered as `_buildBudgetCard()`
   - Smooth scrolling with bouncing physics

## Budget Status Indicators

### Progress Bar Colors:
- **Green/Category Color**: Within budget
- **Red**: Over budget

### Percentage Badge:
- **Category Color**: < 100%
- **Red**: ≥ 100%

### Text Indicators:
- **"$X left"**: Under budget (normal color)
- **"Over by $X"**: Over budget (red color)

## Technical Notes

### Performance:
- Efficient filtering for category expenses
- Lazy loading via ListView.builder
- Fixed height prevents layout recalculations

### Calculations:
- Spent amount calculated from filtered transactions
- Excludes transactions with `excludeFromExpense = true`
- Percentage clamped to 0-100 range for display
- Progress bar value clamped to 0.0-1.0

### Responsive Design:
- 200px card width
- 12px gap between cards
- 20px horizontal padding
- Bouncing scroll physics

## Future Enhancements

Potential improvements:
- Tap to view budget details
- Long press for quick edit
- Swipe to delete budget
- Budget trend indicators (up/down arrows)
- Comparison with previous month
- Projected end-of-month spending
- Budget recommendations based on spending patterns
- Notification when approaching budget limit
