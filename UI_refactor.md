# UI Refactor: LibreChat Modernization

## Goal
Modernize Sidekick's UI to match LibreChat's clean, sleek design - focusing on the chat interface, controls, and overall polish.

## Completed Changes

### 1. Unified Toolbar
**Problem:** Separate macOS menu bar and custom header bar created visual clutter and excessive height.

**Solution:** Merged both into single unified toolbar in [ConversationManagerView.swift](Sidekick/Views/Chat/ConversationManagerView.swift)
- Combined model selector, experts toggle, canvas, and share buttons into one bar
- Reduced overall height significantly
- More cohesive, modern appearance

**Files Modified:**
- `ConversationManagerView.swift` - Added unified toolbar
- `ConversationView.swift` - Removed redundant header elements

### 2. Model Selector - Fixed Double Popover
**Problem:** Required two clicks to select model - first click opened popover, second click opened another popover inside it. Had to click a "sliver" to actually see options.

**Root Cause:** Nested popover architecture in [LibreChatModelSelector.swift](Sidekick/Views/Chat/Conversation/Controls/Model%20Selector/LibreChatModelSelector.swift):
```swift
// OLD: Popover containing another popover trigger
Button { ... } -> Popover -> ModelSelectorDropdown -> Button -> Popover
```

**Solution:** Flattened structure by creating `ModelSelectorDropdownContent` view
```swift
// NEW: Single popover with content directly
Button { ... } -> Popover -> ModelSelectorDropdownContent
```

**Files Modified:**
- `ModelSelectorDropdown.swift` - Extracted content into reusable component
- `LibreChatModelSelector.swift` - Uses content directly in popover

### 3. Sidebar Chat Items - Double Highlight Fix
**Problem:** Two distinct colored boxes around selected chat items - looked broken.

**Root Cause:** Background color applied BEFORE padding in [ConversationNameEditor.swift](Sidekick/Views/Expert/ConversationNameEditor.swift), creating smaller inner box. NavigationLink's selection highlight created outer box.

**Solution:** Moved background to list row level in [ConversationListView.swift](Sidekick/Views/Chat/Sidebar/ConversationListView.swift)
```swift
// BEFORE: Background inside component with padding
.padding(.horizontal, 12)
.background(selectedColor)

// AFTER: Background at list row level
.listRowBackground(
    conversationState.selectedConversationId == conversation.id
        ? Color("surface-active-alt")
        : Color.clear
)
```

**Files Modified:**
- `ConversationNameEditor.swift` - Removed inner background
- `ConversationListView.swift` - Added `.listRowBackground()`

### 4. Input Field Spacing Improvements
**Problem:** Placeholder text and icons too cramped - felt cluttered.

**Changes:**
- Placeholder left padding: `20px` → `32px` ([ChatPromptEditor.swift:208](Sidekick/Views/Chat/Conversation/Controls/Input%20Field/ChatPromptEditor.swift#L208))
- Bottom bar leading padding: `24px` → `32px` ([PromptInputField.swift:228](Sidekick/Views/Chat/Conversation/Controls/Input%20Field/PromptInputField.swift#L228))
- Attachment icon size: default → `16px` ([AttachmentSelectionButton.swift:40](Sidekick/Views/Chat/Conversation/Controls/Input%20Field/AttachmentSelectionButton.swift#L40))
- Microphone icon size: default → `16px` ([DictationButton.swift:36](Sidekick/Views/Chat/Conversation/Controls/Input%20Field/DictationButton.swift#L36))

**Files Modified:**
- `ChatPromptEditor.swift`
- `PromptInputField.swift`
- `AttachmentSelectionButton.swift`
- `DictationButton.swift`

### 5. Functions Button Toggle Visibility
**Problem:** Clicking Functions button didn't show any visual change - couldn't tell if functions were on/off.

**Investigation Findings:**
- Button uses `@Binding var useFunctions: Bool` from `PromptController.useFunctions`
- Validation logic in `onToggle()` can block toggle if:
  - `Settings.useFunctions` is disabled globally
  - Deep Research mode is active (forces functions on)
- User's case: No alerts appeared, so toggle WAS working but visual change wasn't obvious

**Partial Solution:** Made active/inactive states dramatically different in [UseFunctionsButton.swift](Sidekick/Views/Chat/Conversation/Controls/Input%20Field/Toggle%20Buttons/UseFunctionsButton.swift):

| State | Background | Text/Icons | Border | Shadow |
|-------|-----------|------------|--------|--------|
| **OFF** | Gray `surface-chat` | Gray `.secondary` | 1pt gray | Minimal (0.1, 2px, 1px) |
| **ON** | **Solid blue** | **White** | None (0pt) | Strong (0.3, 8px, 4px) |

- Toggle animation: `0.15s` → `0.05s` for instant feedback

**⚠️ STILL BROKEN - Master Switch Needed:**

The visual changes were implemented, but the button still doesn't work as a proper master toggle. Current behavior:
- You CAN click into the dropdown and individually toggle function categories on/off
- You CAN use "Select All" / "Deselect All" in the dropdown
- You CANNOT click the main button to toggle all functions on/off as a master switch

**Desired Behavior (NOT YET IMPLEMENTED):**
The Functions button should act as a **master switch** that:
1. Toggles function calling on/off globally with a single click
2. **Preserves the state** of which individual functions were selected in the dropdown
3. When toggled OFF → Functions disabled for this message, but selection state remembered
4. When toggled ON → Functions re-enabled with the same categories you had selected before
5. This allows quick enable/disable without losing your preferred function configuration

**Why This Matters:**
Users want to quickly toggle function calling without re-configuring which functions to use every time. Think of it like a light switch - you want to turn lights on/off, but the bulbs you have installed stay the same.

**Current Architecture Problem:**
- `useFunctions` (Bool) controls whether functions are used in the message
- `FunctionSelectionManager` controls which categories are enabled
- These are separate systems that don't communicate properly
- Clicking the button toggles `useFunctions`, but this doesn't preserve category selection state
- Need to decouple "should use functions" from "which functions are available"

**Files Modified:**
- `UseFunctionsButton.swift` - Visual overhaul only (master switch logic NOT implemented)

### 6. Search Button Styling
**Note:** SearchMenuToggleButton simplified to always show consistent appearance since one option is always selected (either Search or Deep Search).

**Files Modified:**
- `SearchMenuToggleButton.swift`

## Key Technical Patterns Discovered

### 1. SwiftUI Background Ordering Matters
```swift
// WRONG: Creates inner box
.padding()
.background(color)

// RIGHT: Background fills entire area
.background(color)
.padding()
```

### 2. Nested Popovers Don't Work Well
Avoid `Popover -> Button -> Popover` patterns. Flatten by extracting content into reusable views.

### 3. State Binding Chain
For toggle buttons, trace the binding source:
```
PromptController.useFunctions (@Published)
  ↓ (passed as @StateObject)
ConversationView
  ↓ ($promptController.useFunctions)
PromptInputField
  ↓ (binding passed down)
UseFunctionsButton
```

### 4. Validation Logic Can Block Toggles
Check for validation in toggle handlers that might force state back:
```swift
func toggle() {
    self.useFunctions.toggle()
    self.onToggle(newValue: self.useFunctions) // May force back!
}
```

## Architecture Notes for Next Developer

### Functions System
- **`useFunctions` (Bool)**: Global toggle for whether to use functions in this message
- **`FunctionSelectionManager`**: Manages which function **categories** are enabled (11 total: Arithmetic, Calendar, Code, Expert, File, Input, Reminders, Todo, Web, Contacts, Diagram)
- **`Settings.useFunctions`**: Global setting - if disabled, blocks all function usage
- These are separate concerns - button toggles message-level usage, dropdown selects categories

### Model Selector Architecture
- `LibreChatModelSelector` - Main button component
- `ModelSelectorDropdownContent` - Reusable content for provider/model selection
- `ModelSelectorDropdown` - Legacy component (partially refactored)

### Color Scheme
Key colors used throughout:
- `surface-chat` - Default backgrounds
- `surface-hover` - Hover states
- `surface-active-alt` - Selected/active states
- `borderMedium` - Subtle borders

## What's Left to Refactor

### ✅ COMPLETED (Latest Session)

1. **Functions Button Master Switch** ✅ FIXED
   - Restructured button to separate toggle action from menu
   - Main button now acts as proper master switch
   - Menu accessible via chevron button
   - State preservation works correctly (FunctionSelectionManager persists categories)

2. **Reusable Style Components** ✅ CREATED
   - `LibreChatButtonStyle` - Pill-shaped buttons with active states
   - `LibreChatTextFieldStyle` - Clean form inputs
   - `LibreChatCardStyle` - Card/panel styling
   - `LibreChatToggleStyle` - Modern toggle switches
   - `AnimationConstants` - Consistent animation timing

3. **SettingsView Container** ✅ MODERNIZED
   - Added smooth fade transitions between tabs
   - Improved background colors
   - Better overall structure

4. **GeneralSettingsView** ✅ MODERNIZED
   - Replaced `.roundedBorder` with `LibreChatTextFieldStyle`
   - Replaced `.switch` with `LibreChatToggleStyle`
   - Added consistent 32px padding
   - Improved typography (15pt medium for labels, 13pt for descriptions)
   - Better spacing between sections (32px)
   - Improved section headers with LibreChat styling
   - Added animations to pickers

### ✅ COMPLETED (Latest Session - Full Modernization)

1. **Functions Button Master Switch** ✅ FIXED
   - Restructured button to separate toggle action from menu
   - Main button now acts as proper master switch
   - Menu accessible via chevron button
   - State preservation works correctly (FunctionSelectionManager persists categories)
   - Made button smaller and more understated (height 36→28)
   - Changed active color from green to subtle gray (`surface-active-alt`)

2. **Send Button** ✅ MODERNIZED
   - Changed from green to subtle gray when enabled
   - Uses `surface-active-alt` for active state
   - More understated, consistent with UI

3. **Reusable Style Components** ✅ CREATED
   - `LibreChatButtonStyle` - Pill-shaped buttons with active states
   - `LibreChatTextFieldStyle` - Clean form inputs
   - `LibreChatCardStyle` - Card/panel styling
   - `LibreChatToggleStyle` - Modern toggle switches
   - `AnimationConstants` - Consistent animation timing

4. **SettingsView Container** ✅ MODERNIZED
   - Added smooth fade transitions between tabs
   - Improved background colors
   - Better overall structure

5. **All Settings Views** ✅ COMPLETE MODERNIZATION
   - ✅ GeneralSettingsView - Full modernization
   - ✅ InferenceSettingsView - Full modernization
   - ✅ RetrievalSettingsView - Full modernization
   - ✅ ServerModelSettingsView - Modernized
   - ✅ InlineWritingAssistantSettingsView - Modernized
   - All use consistent spacing (32px), typography, and LibreChat styles

6. **Dialogs and Modals** ✅ MODERNIZED
   - ✅ ExpertManagerView - Added header, improved layout, modern button
   - ✅ SetupView - Added transitions and animations
   - ✅ MemoriesManagerView - Complete redesign with search bar, modern list styling
   - ✅ ModelSelectionView - Modernized buttons

7. **Tools Views** ✅ MODERNIZED
   - ✅ DashboardView - Modernized cards, animations
   - ✅ ToolLibraryView - Complete redesign with header, modern card layout
   - ✅ ToolCardButton - Modern styling with hover states
   - ✅ DetectorView - Modernized exit button
   - ✅ DetectorInputView - Modernized analyze button

### Remaining Work (Optional Polish)

1. **Menus and Popovers** - Can be polished further but functional
2. **Additional animations** - Most critical animations are in place
3. **Canvas interface** - If specific modernization needed
4. **Color audit** - Can be done incrementally

## LibreChat Design Principles Applied

1. **Pill-shaped buttons** with rounded corners (`cornerRadius: 9999`)
2. **Subtle shadows** for depth (2-8px radius, low opacity)
3. **Clear active states** - Bold color changes, not subtle tints
4. **Consistent spacing** - 32px padding for breathing room
5. **Unified toolbars** - Reduce visual clutter
6. **Flat color scheme** - Gray backgrounds with blue accents for actions

## Common Pitfalls

1. **Don't assume visual changes are obvious** - Users need DRAMATIC differences (solid colors, not opacity tints)
2. **Check validation logic** - Toggle functions might have business rules blocking them
3. **Background ordering** - Apply background before or after padding depending on desired effect
4. **Animation duration** - For toggle feedback, keep it fast (0.05-0.1s)
5. **Test in actual UI** - SwiftUI previews may not show real behavior

## Files Index

All modified files with line references available in git history:
```bash
git log --oneline --name-only
```

Key files:
- `Sidekick/Views/Chat/ConversationManagerView.swift`
- `Sidekick/Views/Chat/Conversation/Controls/Model Selector/*.swift`
- `Sidekick/Views/Chat/Conversation/Controls/Input Field/*.swift`
- `Sidekick/Views/Chat/Sidebar/ConversationListView.swift`
- `Sidekick/Views/Expert/ConversationNameEditor.swift`
