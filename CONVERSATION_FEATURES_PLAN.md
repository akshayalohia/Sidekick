# Conversation Features Implementation Plan

## Overview
This plan outlines the implementation of three major conversation features:
1. **Conversation Branching & Forking** - Edit, resubmit, and continue messages; explore alternate conversation paths
2. **Deferred Chat Creation** - Only create chats in sidebar after first message is sent
3. **Personalized Homepage Greeting** - Show user's name in greeting message

## Current Architecture Understanding

### Key Components
- **ConversationManager**: Manages all conversations, handles creation/updates/deletion
- **ConversationState**: Tracks selected conversation and expert
- **Message**: Individual message structure with ID, text, sender, timestamps
- **Conversation**: Contains messages array, title, ID, creation date
- **PromptInputField**: Handles message submission and response generation
- **Settings.username**: Stores user name (UserDefaults key "username")

### Current Flow
1. "New Chat" button → `ConversationManager.newConversation()` → Immediately creates conversation with date/time title
2. User types message → `PromptInputField.submit()` → Adds user message → Generates response
3. Title generation happens after first message (if enabled)
4. Greeting is hardcoded: "How can I help you?" in `ConversationControlsView`

---

## Feature 1: Conversation Branching & Forking

### Requirements
- Edit messages (already partially implemented)
- Resubmit messages (regenerate from a point)
- Continue messages (add to existing assistant response)
- Fork conversations (create new branch from a message)
- Visual indication of branches/forks
- Navigate between branches

### Data Model Changes

#### 1.1 Add Branching Support to Conversation Model
**File**: `Sidekick/Types/Conversation/Conversation.swift`

**Changes**:
- Add optional `parentConversationId: UUID?` to track forks
- Add optional `branchPointMessageId: UUID?` to track where branch started
- Add optional `branchName: String?` for user-friendly branch labels
- Add `branches: [UUID]` array to track child conversations
- Update `ConversationManager` to handle branch relationships

**Implementation**:
```swift
public struct Conversation: Identifiable, Codable, Hashable {
    // ... existing properties ...
    
    /// ID of parent conversation if this is a branch
    public var parentConversationId: UUID?
    
    /// Message ID where this branch started
    public var branchPointMessageId: UUID?
    
    /// User-friendly name for this branch
    public var branchName: String?
    
    /// IDs of conversations that branch from this one
    public var branchIds: [UUID] = []
    
    /// Computed property: Is this conversation a branch?
    public var isBranch: Bool {
        return parentConversationId != nil
    }
    
    /// Function to create a fork from this conversation at a specific message
    public func fork(at messageId: UUID, branchName: String? = nil) -> Conversation {
        // Implementation
    }
}
```

#### 1.2 Add Message Actions to Message Model
**File**: `Sidekick/Types/Conversation/Message/Message.swift`

**Changes**:
- Add optional `editedAt: Date?` to track edits
- Add optional `originalText: String?` to preserve original before edit
- Add `isEdited: Bool` computed property
- Add `canBranch: Bool` computed property (user messages can branch)

**Implementation**:
```swift
public struct Message: Identifiable, Codable, Hashable {
    // ... existing properties ...
    
    /// Timestamp when message was edited
    public var editedAt: Date?
    
    /// Original text before editing (for undo)
    public var originalText: String?
    
    /// Computed: Has this message been edited?
    public var isEdited: Bool {
        return editedAt != nil
    }
    
    /// Computed: Can this message be branched from?
    public var canBranch: Bool {
        return getSender() == .user || getSender() == .assistant
    }
}
```

### UI Components

#### 1.3 Message Action Menu
**File**: `Sidekick/Views/Chat/Conversation/Messages/Message/MessageOptionsView.swift`

**Changes**:
- Add "Edit" option (already exists, enhance)
- Add "Resubmit" option (regenerate from this point)
- Add "Continue" option (for assistant messages)
- Add "Fork Conversation" option (create branch)
- Add "View Branches" option (if branches exist)

**New Actions**:
- Edit: Opens inline editor (already implemented)
- Resubmit: Drops messages after this one, resubmits
- Continue: Adds continuation prompt, generates more
- Fork: Creates new conversation branch
- View Branches: Shows branch navigation UI

#### 1.4 Branch Navigation UI
**New File**: `Sidekick/Views/Chat/Conversation/BranchNavigationView.swift`

**Purpose**: Visual tree/navigation for conversation branches

**Features**:
- Tree view showing conversation branches
- Visual indicators for current branch
- Click to switch between branches
- Create new branch from any message
- Merge branches (optional future feature)

#### 1.5 Conversation Forking Logic
**File**: `Sidekick/Logic/Data Models/ConversationManager.swift`

**New Methods**:
```swift
/// Create a fork of a conversation starting at a specific message
func forkConversation(
    from conversationId: UUID,
    at messageId: UUID,
    branchName: String? = nil
) -> Conversation?

/// Get all branches of a conversation
func getBranches(of conversationId: UUID) -> [Conversation]

/// Get parent conversation if this is a branch
func getParent(of conversationId: UUID) -> Conversation?

/// Navigate to a branch
func switchToBranch(_ branchId: UUID)
```

#### 1.6 Message Resubmission Logic
**File**: `Sidekick/Views/Chat/Conversation/Controls/Input Field/PromptInputField.swift`

**Enhancement**: Extend existing `retryGeneration` to support:
- Resubmit from any message (not just last)
- Continue generation (append to existing response)
- Edit and resubmit (modify message, then resubmit)

**New Methods**:
```swift
/// Resubmit from a specific message
func resubmitFrom(messageId: UUID)

/// Continue generation from a message
func continueFrom(messageId: UUID)

/// Edit message and resubmit
func editAndResubmit(messageId: UUID, newText: String)
```

### Implementation Steps

**Sub-Agent 1: Data Model & Core Logic**
- Task 1.1: Update `Conversation` model with branching properties
- Task 1.2: Update `Message` model with edit tracking
- Task 1.3: Implement `ConversationManager.forkConversation()`
- Task 1.4: Implement branch navigation methods
- Task 1.5: Update persistence to handle branches
- Task 1.6: Add migration logic for existing conversations

**Sub-Agent 2: Message Actions & UI**
- Task 2.1: Enhance `MessageOptionsView` with new actions
- Task 2.2: Implement "Resubmit" action handler
- Task 2.3: Implement "Continue" action handler
- Task 2.4: Implement "Fork Conversation" action handler
- Task 2.5: Add visual indicators for edited/branched messages
- Task 2.6: Update `MessageView` to show branch indicators

**Sub-Agent 3: Branch Navigation**
- Task 3.1: Create `BranchNavigationView` component
- Task 3.2: Implement branch tree visualization
- Task 3.3: Add branch switching logic
- Task 3.4: Integrate branch navigation into sidebar
- Task 3.5: Add branch creation UI
- Task 3.6: Style branch navigation to match LibreChat aesthetic

**Sub-Agent 4: Resubmission & Continuation**
- Task 4.1: Enhance `retryGeneration` for resubmission
- Task 4.2: Implement continuation logic
- Task 4.3: Update `PromptInputField` to handle resubmission
- Task 4.4: Add loading states for resubmission
- Task 4.5: Handle edge cases (empty conversations, etc.)

---

## Feature 2: Deferred Chat Creation

### Requirements
- "New Chat" button should NOT create a conversation immediately
- Conversation should only be created when first message is sent
- Title should be generated from first message (not date/time)
- Empty conversations should not appear in sidebar
- If user clicks away without sending, no conversation created

### Implementation Changes

#### 2.1 Update ConversationManager
**File**: `Sidekick/Logic/Data Models/ConversationManager.swift`

**Changes**:
- Modify `newConversation()` to create a "pending" conversation
- Add `pendingConversationId: UUID?` to track pending conversation
- Add `commitPendingConversation()` to finalize after first message
- Filter out pending conversations from sidebar list

**New Approach**:
```swift
/// Create a pending conversation (not yet in sidebar)
func createPendingConversation() -> UUID

/// Commit pending conversation after first message
func commitPendingConversation(conversationId: UUID, firstMessage: Message)

/// Check if conversation is pending
func isPending(conversationId: UUID) -> Bool
```

#### 2.2 Update ConversationState
**File**: `Sidekick/Logic/View Controllers/Conversation/ConversationState.swift`

**Changes**:
- Track pending conversation separately
- Only show committed conversations in sidebar
- Handle selection of pending conversation

#### 2.3 Update ConversationManagerView
**File**: `Sidekick/Views/Chat/Conversation/ConversationManagerView.swift`

**Changes**:
- Modify "New Chat" button to create pending conversation
- Filter sidebar to exclude pending conversations
- Handle pending conversation selection

#### 2.4 Update PromptInputField
**File**: `Sidekick/Views/Chat/Conversation/Controls/Input Field/PromptInputField.swift`

**Changes**:
- Check if current conversation is pending
- On first message send, commit the conversation
- Generate title from first message
- Update sidebar to show newly committed conversation

#### 2.5 Update ConversationListView
**File**: `Sidekick/Views/Chat/Conversation/ConversationListView.swift`

**Changes**:
- Filter out pending conversations
- Only show conversations with at least one message

### Implementation Steps

**Sub-Agent 5: Deferred Creation Logic**
- Task 5.1: Add pending conversation state to `ConversationManager`
- Task 5.2: Modify `newConversation()` to create pending conversation
- Task 5.3: Implement `commitPendingConversation()` method
- Task 5.4: Add `isPending` check method
- Task 5.5: Update persistence to handle pending state
- Task 5.6: Add cleanup for abandoned pending conversations

**Sub-Agent 6: UI Updates for Deferred Creation**
- Task 6.1: Update "New Chat" button handler
- Task 6.2: Filter sidebar to exclude pending conversations
- Task 6.3: Update `ConversationListView` filtering
- Task 6.4: Handle pending conversation in `PromptInputField.submit()`
- Task 6.5: Update title generation to use first message
- Task 6.6: Add visual feedback when committing conversation

---

## Feature 3: Personalized Homepage Greeting

### Requirements
- Change greeting from "How can I help you?" to "Hi, [username], how can I help you?"
- Use `Settings.username` if available
- Fallback to system username if not set
- Handle empty/null username gracefully

### Implementation Changes

#### 3.1 Update ConversationControlsView
**File**: `Sidekick/Views/Chat/Conversation/Controls/ConversationControlsView.swift`

**Changes**:
- Replace hardcoded greeting string
- Use `Settings.username` to personalize
- Add fallback logic

**Implementation**:
```swift
var greetingText: String {
    let username = Settings.username
    if username.isEmpty {
        return String(localized: "How can I help you?")
    }
    return String(localized: "Hi, \(username), how can I help you?")
}
```

#### 3.2 Update Localizable Strings
**File**: `Sidekick/Localizable.xcstrings`

**Changes**:
- Add new localized string for personalized greeting
- Support string interpolation for username

### Implementation Steps

**Sub-Agent 7: Personalized Greeting**
- Task 7.1: Update `ConversationControlsView` with personalized greeting
- Task 7.2: Add localized string with username placeholder
- Task 7.3: Test with various username scenarios
- Task 7.4: Handle edge cases (empty username, special characters)
- Task 7.5: Update localization files if needed

---

## Implementation Order & Parallelization

### Phase 1: Foundation (Sequential)
1. **Sub-Agent 1**: Data Model & Core Logic (Feature 1)
   - Must complete before UI work
   - Establishes data structures

### Phase 2: Core Features (Parallel)
2. **Sub-Agent 2**: Message Actions & UI (Feature 1)
3. **Sub-Agent 5**: Deferred Creation Logic (Feature 2)
4. **Sub-Agent 7**: Personalized Greeting (Feature 3)
   - These can run in parallel as they touch different areas

### Phase 3: Advanced Features (Parallel)
5. **Sub-Agent 3**: Branch Navigation (Feature 1)
6. **Sub-Agent 4**: Resubmission & Continuation (Feature 1)
7. **Sub-Agent 6**: UI Updates for Deferred Creation (Feature 2)
   - Can run in parallel after Phase 2

### Dependencies
- Feature 1 (Branching) is independent
- Feature 2 (Deferred Creation) is independent
- Feature 3 (Greeting) is independent
- Sub-Agent 1 must complete before Sub-Agents 2, 3, 4
- Sub-Agent 5 must complete before Sub-Agent 6

---

## Testing Checklist

### Feature 1: Branching & Forking
- [ ] Can edit user messages
- [ ] Can edit assistant messages
- [ ] Can resubmit from any message point
- [ ] Can continue assistant responses
- [ ] Can fork conversation from any message
- [ ] Branch navigation shows correct tree
- [ ] Switching branches works correctly
- [ ] Branches persist across app restarts
- [ ] Visual indicators show edited/branched messages
- [ ] Edge cases: Empty conversations, single message, etc.

### Feature 2: Deferred Creation
- [ ] Clicking "New Chat" doesn't create sidebar entry
- [ ] Conversation appears after first message sent
- [ ] Title generated from first message
- [ ] Abandoned pending conversations cleaned up
- [ ] Multiple pending conversations handled correctly
- [ ] Keyboard shortcut (⌘N) works correctly
- [ ] Edge cases: App quit before sending, etc.

### Feature 3: Personalized Greeting
- [ ] Greeting shows username when set
- [ ] Falls back gracefully when username empty
- [ ] Works with special characters in username
- [ ] Localization works correctly
- [ ] Updates when username changes

---

## Files to Create

### New Files
1. `Sidekick/Views/Chat/Conversation/BranchNavigationView.swift`
2. `Sidekick/Views/Chat/Conversation/BranchNavigationItemView.swift`
3. `Sidekick/Logic/Utilities/ConversationBranching.swift` (optional helper)

### Files to Modify
1. `Sidekick/Types/Conversation/Conversation.swift`
2. `Sidekick/Types/Conversation/Message/Message.swift`
3. `Sidekick/Logic/Data Models/ConversationManager.swift`
4. `Sidekick/Logic/View Controllers/Conversation/ConversationState.swift`
5. `Sidekick/Views/Chat/Conversation/ConversationManagerView.swift`
6. `Sidekick/Views/Chat/Conversation/ConversationListView.swift`
7. `Sidekick/Views/Chat/Conversation/Messages/Message/MessageView.swift`
8. `Sidekick/Views/Chat/Conversation/Messages/Message/MessageOptionsView.swift`
9. `Sidekick/Views/Chat/Conversation/Controls/Input Field/PromptInputField.swift`
10. `Sidekick/Views/Chat/Conversation/Controls/ConversationControlsView.swift`
11. `Sidekick/Localizable.xcstrings`

---

## Reference: LibreChat Implementation

LibreChat (TypeScript/React) implements similar features:
- **Branching**: Uses conversation tree structure with `parentMessageId`
- **Deferred Creation**: Creates conversation only on first message
- **Message Editing**: Inline editing with resubmission
- **Forking**: Creates new conversation branch from any message

Key patterns to adapt:
- Tree structure for branches
- Pending state for new conversations
- Message action menus
- Branch visualization

---

## Success Criteria

1. ✅ Users can edit and resubmit messages
2. ✅ Users can fork conversations from any message
3. ✅ Branch navigation is intuitive and visual
4. ✅ New chats don't appear until first message sent
5. ✅ Conversation titles are relevant (from first message)
6. ✅ Greeting personalizes with user's name
7. ✅ All features work together seamlessly
8. ✅ No regressions in existing functionality
9. ✅ Performance remains good with many branches
10. ✅ UI matches LibreChat aesthetic

---

## Notes

- Migration: Existing conversations will need `parentConversationId = nil` (default)
- Performance: Consider lazy loading for branch trees with many branches
- UX: Branch navigation should be discoverable but not intrusive
- Accessibility: Ensure all new UI elements are accessible
- Localization: All new strings must be localized

