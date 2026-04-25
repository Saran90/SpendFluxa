# Transaction Tagging Feature

## Overview
Added a comprehensive tagging system to the SpendSense expense tracking app. Users can now create custom tags to group transactions by events, projects, or any custom criteria (e.g., "Wedding", "Vacation", "Birthday Party").

## Features Implemented

### 1. Tag Model (`lib/core/models/tag.dart`)
- **Tag Properties:**
  - `id`: Unique identifier
  - `name`: Tag name (e.g., "Wedding")
  - `color`: Custom color from a palette of 20 colors
  - `icon`: Custom icon from a pool of 30 Material Icons
  - `createdAt`: Timestamp for sorting

- **Predefined Palettes:**
  - 20 vibrant colors for tag customization
  - 30 relevant icons (events, travel, celebrations, etc.)

### 2. Tag Service (`lib/core/services/tag_service.dart`)
- Manages tag CRUD operations
- Persists tags using SharedPreferences
- Provides reactive updates via ChangeNotifier
- Methods:
  - `add(Tag)`: Create new tag
  - `update(Tag)`: Edit existing tag
  - `remove(String id)`: Delete tag
  - `getById(String id)`: Retrieve specific tag
  - `all`: Get all tags

### 3. Updated Transaction Model
- Added `tagIds` field (List<String>) to Transaction model
- Supports multiple tags per transaction
- Includes serialization/deserialization support
- Added `copyWith()` method for immutable updates

### 4. Enhanced Transaction Service
- New methods for tag-based queries:
  - `transactionsWithTag(String tagId)`: Get all transactions with a specific tag
  - `totalForTag(String tagId)`: Calculate total amount for tagged transactions
  - `incomeForTag(String tagId)`: Calculate income for tagged transactions
  - `expensesForTag(String tagId)`: Calculate expenses for tagged transactions
- Added `updateTransaction()` method for editing transactions

### 5. Tags Screen (`lib/features/tags/tags_screen.dart`)
- **Main Features:**
  - Beautiful gradient header
  - List of all created tags
  - Each tag card shows:
    - Tag name, icon, and color
    - Transaction count
    - Income, Expenses, and Net amount summary
  - Empty state with call-to-action
  - Floating action button to create new tags

- **Navigation:**
  - Tap on tag card to view detailed tag screen
  - Smooth animations and transitions

### 6. Tag Detail Screen (`lib/features/tags/tag_detail_screen.dart`)
- **Features:**
  - Expandable app bar with tag color gradient
  - Summary cards showing Income, Expenses, and Net amount
  - Complete list of all transactions with the tag
  - Edit button to modify tag properties
  - Transaction tiles with category icons and amounts

### 7. Add/Edit Tag Sheet (`lib/features/tags/add_tag_sheet.dart`)
- **Modal Bottom Sheet with:**
  - Tag name input field
  - Color picker (20 colors in grid layout)
  - Icon picker (30 icons in scrollable grid)
  - Visual feedback for selected color/icon
  - Create/Save button
  - Delete button (edit mode only)
  - Confirmation dialog for deletion

### 8. Updated Add Transaction Screen
- **New Tag Selection Section:**
  - Shows all available tags as chips
  - Multi-select support (tap to toggle)
  - Visual feedback with color-coded borders
  - Only appears if tags exist
  - Integrates seamlessly with existing form

### 9. Navigation Integration
- Added Tags tab to main navigation bar (6 tabs total)
- Position: Between Analytics and Profile
- Icon: label_rounded / label_outlined
- Smooth scroll-to-top on tab re-tap
- Auto-hide navigation on scroll

## User Workflow

### Creating a Tag
1. Navigate to Tags screen
2. Tap "New Tag" floating button
3. Enter tag name (e.g., "Wedding 2026")
4. Select a color from the palette
5. Choose an icon
6. Tap "Create Tag"

### Tagging Transactions
1. Create/edit a transaction
2. Scroll to Tags section
3. Tap on one or more tags to apply
4. Save transaction

### Viewing Tagged Transactions
1. Go to Tags screen
2. Tap on any tag card
3. View summary (income, expenses, net)
4. See all transactions with that tag
5. Track total spending for the event/project

### Editing/Deleting Tags
1. Open tag detail screen
2. Tap edit icon in app bar
3. Modify name, color, or icon
4. Or tap "Delete" to remove tag
5. Confirm deletion (removes tag from all transactions)

## Technical Details

### State Management
- Uses Flutter's built-in ChangeNotifier pattern
- Services notify listeners on data changes
- UI rebuilds automatically via ListenableBuilder

### Data Persistence
- Tags stored in SharedPreferences as JSON
- Transactions include tag IDs array
- Automatic save on all CRUD operations

### UI/UX Highlights
- Material Design 3 principles
- Smooth animations (180-350ms durations)
- Color-coded visual hierarchy
- Responsive layouts
- Keyboard-aware scrolling
- Empty states with helpful messaging
- Confirmation dialogs for destructive actions

### Performance
- Efficient list rendering with ListView.builder
- Lazy loading of transaction lists
- Minimal rebuilds with targeted ListenableBuilder
- In-memory caching of tag data

## Files Modified

### New Files
- `lib/core/models/tag.dart`
- `lib/core/services/tag_service.dart`
- `lib/features/tags/tags_screen.dart`
- `lib/features/tags/tag_detail_screen.dart`
- `lib/features/tags/add_tag_sheet.dart`

### Modified Files
- `lib/core/models/transaction.dart` - Added tagIds field
- `lib/core/services/transaction_service.dart` - Added tag query methods
- `lib/features/transactions/add_transaction_screen.dart` - Added tag selection
- `lib/features/shell/main_shell.dart` - Added Tags tab
- `lib/main.dart` - Integrated TagService

## Example Use Cases

1. **Event Planning:**
   - Tag: "Wedding 2026"
   - Track all wedding-related expenses (venue, catering, decorations)
   - See total spending at a glance

2. **Project Tracking:**
   - Tag: "Home Renovation"
   - Group all renovation expenses
   - Monitor budget vs actual spending

3. **Vacation Budgeting:**
   - Tag: "Europe Trip"
   - Track flights, hotels, meals, activities
   - Calculate total trip cost

4. **Gift Tracking:**
   - Tag: "Christmas 2026"
   - Monitor holiday spending
   - Stay within gift budget

## Future Enhancements (Optional)

- Tag-based budget limits
- Tag analytics and charts
- Tag sharing between users
- Tag templates for common events
- Bulk tag operations
- Tag search and filtering
- Tag-based reports and exports
- Tag color themes
- Tag hierarchies (parent/child tags)

## Testing Recommendations

1. Create multiple tags with different colors/icons
2. Add tags to various transactions
3. Verify tag totals match transaction amounts
4. Test tag editing and deletion
5. Verify tag removal from transactions on delete
6. Test empty states
7. Verify persistence across app restarts
8. Test with many tags (performance)
9. Test multi-tag selection on transactions
10. Verify navigation and scroll behavior

## Conclusion

The tagging feature provides a powerful way to organize and track expenses beyond traditional categories. Users can now group transactions by events, projects, or any custom criteria, making it easier to understand spending patterns and manage budgets for specific purposes.
