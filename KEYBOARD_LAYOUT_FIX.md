# Fixed: Save Button Moving with Keyboard

## Issue
When clicking on the amount field in the Add Transaction screen, the keyboard appeared and the "Save Expense" button moved up with the keyboard, going to the top of the page instead of staying at the bottom.

## Root Cause
The layout was using a `Stack` with a `Positioned` widget that had:
```dart
bottom: MediaQuery.of(context).viewInsets.bottom
```

This caused the button to move up by the keyboard height (`viewInsets.bottom`), which is the opposite of the intended behavior.

## Solution
Changed the layout structure from:
- `Column` → `Expanded(Stack)` → `Positioned` bottom bar

To:
- `Column` → `Expanded(ListView)` → Fixed bottom bar

### Before (Problematic Layout)
```dart
Column(
  children: [
    _buildHero(),
    Expanded(
      child: Stack(
        children: [
          ListView(...),  // Scrollable content
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom,  // ❌ Moves with keyboard
            child: _buildBottomBar(),
          ),
        ],
      ),
    ),
  ],
)
```

### After (Fixed Layout)
```dart
Column(
  children: [
    _buildHero(),
    Expanded(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          88 + MediaQuery.of(context).padding.bottom + 16,  // Fixed padding for button
        ),
        children: [...],
      ),
    ),
    _buildBottomBar(),  // ✅ Stays at bottom
  ],
)
```

## Changes Made

### 1. Updated Build Method
- Removed `Stack` wrapper
- Moved `_buildBottomBar()` outside of `Expanded` widget
- Made it a direct child of the main `Column`
- Updated ListView padding to account for the fixed bottom bar height

### 2. Simplified Bottom Bar
- Removed keyboard-aware positioning logic
- Changed from:
  ```dart
  final bottom = MediaQuery.of(context).viewInsets.bottom > 0
      ? 0.0
      : MediaQuery.of(context).padding.bottom;
  ```
- To:
  ```dart
  padding: EdgeInsets.fromLTRB(
    20, 10, 20,
    MediaQuery.of(context).padding.bottom + 14,
  )
  ```

## Behavior Now

### When Keyboard is Hidden
- Save button stays at the bottom of the screen
- Content scrolls normally
- Bottom padding accounts for safe area

### When Keyboard Appears
- Save button **stays fixed at the bottom**
- Content area shrinks (Expanded widget adjusts)
- ListView becomes scrollable to access all fields
- User can scroll to see fields hidden by keyboard
- Keyboard can be dismissed by dragging the list

## Benefits

1. **Consistent UI** - Button always in the same position
2. **Better UX** - Users know where to find the save button
3. **Proper Scrolling** - Content scrolls naturally when keyboard appears
4. **No Confusion** - Button doesn't jump around the screen
5. **Standard Pattern** - Follows common mobile app patterns

## Technical Details

### ListView Padding Calculation
```dart
88 + MediaQuery.of(context).padding.bottom + 16
```
- `88`: Approximate height of the bottom bar (container + button)
- `padding.bottom`: Safe area inset (for devices with home indicator)
- `16`: Extra breathing room

### Keyboard Behavior
- `resizeToAvoidBottomInset: true` - Scaffold resizes when keyboard appears
- `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` - Keyboard dismisses when scrolling
- Content automatically scrollable when keyboard covers fields

## Testing Checklist

- [x] Click amount field - keyboard appears, button stays at bottom
- [x] Click title field - keyboard appears, button stays at bottom
- [x] Click note field - keyboard appears, button stays at bottom
- [x] Scroll content while keyboard is open - works smoothly
- [x] Drag to dismiss keyboard - works correctly
- [x] Button remains accessible at all times
- [x] Safe area respected on devices with notches/home indicators
- [x] Works on different screen sizes
- [x] No layout overflow errors

## Files Modified

- `lib/features/transactions/add_transaction_screen.dart`
  - Updated `build()` method layout structure
  - Simplified `_buildBottomBar()` method

## Conclusion

The save button now stays fixed at the bottom of the screen where users expect it, providing a consistent and intuitive experience. The content area properly adjusts when the keyboard appears, allowing users to scroll to access all fields while keeping the save button easily accessible.
