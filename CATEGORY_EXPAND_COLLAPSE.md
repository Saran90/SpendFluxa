# Category Grid Expand/Collapse Feature

## Overview
Added expand/collapse functionality to the category grid in the Add Transaction screen. Now only 2 rows (8 categories) are shown initially, with a "Show More" button to expand and see all categories, and a "Show Less" button to collapse back.

## Problem Solved
The category grid was showing all 17 expense categories or 6 income categories at once, taking up too much screen space and requiring excessive scrolling. This made the form feel cluttered and harder to navigate.

## Solution
Implemented a collapsible category grid that:
- Shows only 2 rows (8 categories) by default
- Provides a "Show More" button when there are more categories
- Expands smoothly to show all categories
- Provides a "Show Less" button to collapse back
- Resets to collapsed state when switching transaction types

## Implementation Details

### 1. Added State Variable
```dart
bool _isCategoryExpanded = false;
```

### 2. Updated Category Grid Logic
```dart
const itemsPerRow = 4;
const rowsToShow = 2;
final maxItemsToShow = itemsPerRow * rowsToShow; // 8 categories
final hasMore = _categories.length > maxItemsToShow;
final displayedCategories = _isCategoryExpanded
    ? _categories
    : _categories.take(maxItemsToShow).toList();
```

### 3. Added Expand/Collapse Button
- Positioned in the header row next to "CATEGORY" label
- Color-coded to match transaction type (expense/income/transfer)
- Shows "Show More" with down arrow when collapsed
- Shows "Show Less" with up arrow when expanded
- Only visible when there are more than 8 categories

### 4. Smooth Animation
- Used `AnimatedSize` widget for smooth height transitions
- 300ms duration with easeInOut curve
- Grid expands/collapses smoothly without jarring jumps

### 5. Auto-Reset on Type Change
- When switching between Expense/Income/Transfer, the grid resets to collapsed state
- Prevents confusion when different types have different category counts

## UI/UX Design

### Header Layout
```
┌─────────────────────────────────────┐
│ CATEGORY          [Show More ▼]     │
└─────────────────────────────────────┘
```

### Collapsed State (2 rows)
```
┌─────────────────────────────────────┐
│ CATEGORY          [Show More ▼]     │
├─────────────────────────────────────┤
│ [🍔] [🛒] [🥬] [🥐]                 │
│ [☕] [🚗] [⛽] [🛍️]                 │
└─────────────────────────────────────┘
```

### Expanded State (all categories)
```
┌─────────────────────────────────────┐
│ CATEGORY          [Show Less ▲]     │
├─────────────────────────────────────┤
│ [🍔] [🛒] [🥬] [🥐]                 │
│ [☕] [🚗] [⛽] [🛍️]                 │
│ [🎬] [❤️] [⚡] [🏠]                 │
│ [🎓] [🛡️] [💰] [📦]                 │
│ [📄]                                │
└─────────────────────────────────────┘
```

## Button Styling

### Visual Design
- **Background**: Transaction type color with 10% opacity
- **Text**: Bold, 11px, transaction type color
- **Icon**: 16px, matches text color
- **Padding**: 10px horizontal, 6px vertical
- **Border Radius**: 8px
- **Tappable**: Entire button area

### Color Coding
- **Expense**: Red tint (#FF6B6B)
- **Income**: Green tint (#2D9E6B)
- **Transfer**: Teal tint (#4ECDC4)

## Behavior Details

### Initial State
- Grid shows 2 rows (8 categories)
- "Show More" button visible if more than 8 categories exist
- Most common categories are in the first 2 rows

### Expanding
1. User taps "Show More"
2. Grid smoothly animates to show all categories
3. Button changes to "Show Less" with up arrow
4. User can scroll to see all categories

### Collapsing
1. User taps "Show Less"
2. Grid smoothly animates back to 2 rows
3. Button changes to "Show More" with down arrow
4. Selected category remains selected (even if hidden)

### Type Switching
1. User switches from Expense to Income (or vice versa)
2. Grid automatically resets to collapsed state
3. New category set loads with 2 rows visible
4. Button updates based on new category count

## Category Counts

### Expense Categories (17 total)
- **Visible Initially**: 8 categories (2 rows)
- **Hidden Initially**: 9 categories
- **Show More Button**: Yes

### Income Categories (6 total)
- **Visible Initially**: 6 categories (1.5 rows)
- **Hidden Initially**: 0 categories
- **Show More Button**: No (all fit in 2 rows)

### Transfer Type
- No categories shown (transfers don't use categories)

## Benefits

1. **Cleaner UI** - Less visual clutter on initial load
2. **Faster Navigation** - Less scrolling required
3. **Better Focus** - Common categories are immediately visible
4. **Progressive Disclosure** - Advanced options available when needed
5. **Smooth Experience** - Animated transitions feel polished
6. **Consistent Design** - Matches app's design language

## Technical Implementation

### Files Modified
- `lib/features/transactions/add_transaction_screen.dart`

### Changes Made
1. Added `_isCategoryExpanded` state variable
2. Updated `_buildCategoryGrid()` method with expand/collapse logic
3. Added expand/collapse button in header
4. Wrapped GridView in AnimatedSize widget
5. Updated `_setType()` to reset expansion state

### Code Quality
- ✅ No compilation errors
- ✅ Follows existing patterns
- ✅ Maintains design consistency
- ✅ Smooth animations
- ✅ Proper state management

## Testing Checklist

- [x] Initial load shows 2 rows of categories
- [x] "Show More" button appears when needed
- [x] Tapping "Show More" expands grid smoothly
- [x] All categories visible when expanded
- [x] "Show Less" button appears when expanded
- [x] Tapping "Show Less" collapses grid smoothly
- [x] Button color matches transaction type
- [x] Switching types resets to collapsed state
- [x] Selected category persists when collapsing
- [x] Animation is smooth and not jarring
- [x] Works with both expense and income categories
- [x] No button shown for income (only 6 categories)

## Edge Cases Handled

1. **Income Categories** - Only 6 categories, all fit in 2 rows, no button shown
2. **Selected Hidden Category** - If selected category is hidden when collapsed, it remains selected
3. **Type Switching** - Expansion state resets to prevent confusion
4. **Animation Interruption** - Smooth handling if user taps button during animation

## Performance

- **Minimal Impact** - Only rebuilds category grid section
- **Efficient Rendering** - GridView.builder used for efficient rendering
- **Smooth Animation** - 300ms animation doesn't block UI
- **No Lag** - Instant response to button taps

## Future Enhancements (Optional)

1. **Remember Preference** - Save user's expansion preference
2. **Smart Ordering** - Show most-used categories first
3. **Search/Filter** - Add category search when expanded
4. **Custom Rows** - Allow users to configure how many rows to show
5. **Swipe Gesture** - Swipe up/down to expand/collapse

## Conclusion

The expand/collapse feature significantly improves the user experience by reducing visual clutter while maintaining full access to all categories. The smooth animations and intuitive button placement make the feature feel natural and polished.
