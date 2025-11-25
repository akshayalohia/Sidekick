# Sidekick - Claude Code Project Guide

## Project Overview
Sidekick is a macOS native AI chat application built with SwiftUI. It provides a conversational interface with local LLM inference via llama.cpp, featuring experts (personas), RAG capabilities, canvas artifacts, and function calling.

## Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14.0+)
- **Architecture**: MVVM with ObservableObject pattern
- **Storage**: JSON file-based persistence (not CoreData/SwiftData)
- **LLM Backend**: llama.cpp server integration

## Project Structure

```
Sidekick/
├── Logic/
│   ├── Data Models/
│   │   ├── ConversationManager.swift    # Singleton managing conversation persistence
│   │   ├── ExpertManager.swift          # Manages AI personas/experts
│   │   ├── ModelManager.swift           # Manages available models
│   │   └── SourcesManager.swift         # Manages RAG sources
│   ├── Inference/
│   │   ├── Model.swift                  # Main model interface
│   │   ├── Model+Inference.swift        # Inference logic
│   │   └── llama.cpp/                   # llama.cpp server integration
│   ├── View Controllers/
│   │   └── Conversation/
│   │       ├── ConversationState.swift  # Selected conversation/expert state
│   │       └── CanvasController.swift   # Canvas artifact state
│   └── Settings/
│       └── Settings.swift               # App settings and paths
├── Types/
│   └── Conversation/
│       ├── Conversation.swift           # Conversation data model
│       └── Message/
│           ├── Message.swift            # Message data model
│           └── Sender.swift             # Sender enum (user/assistant/system)
├── Views/
│   └── Chat/
│       └── Conversation/
│           ├── ConversationManagerView.swift  # Main split view
│           ├── ConversationView.swift         # Chat area
│           ├── Controls/
│           │   └── Input Field/
│           │       ├── PromptInputField.swift     # Message input + submission
│           │       └── ChatPromptEditor.swift     # Text editor component
│           └── Messages/
│               └── Message/
│                   ├── MessageView.swift          # Individual message display
│                   ├── MessageContentView.swift   # Message content + edit mode
│                   └── MessageOptionsView.swift   # Message options menu
└── Extensions/
    └── [Various utility extensions]
```

## Key Data Models

### Conversation (`Types/Conversation/Conversation.swift`)
```swift
struct Conversation: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var expertId: UUID?
    var createdAt: Date
    var messages: [Message]
    var tokenCount: Int?

    mutating func addMessage(_ message: Message) -> Bool  // Validates sender alternation
    mutating func updateMessage(_ message: Message)
    mutating func dropLastMessage()
}
```

### Message (`Types/Conversation/Message/Message.swift`)
```swift
struct Message: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var sender: Sender  // .user, .assistant, .system
    var model: String
    var expertId: UUID?
    var startTime: Date
    var lastUpdated: Date
    var outputEnded: Bool
    var referencedURLs: [ReferencedURL]
    var functionCallRecords: [FunctionCallRecord]?
    var snapshot: Snapshot?  // Canvas artifact
}
```

## Key State Management

### ConversationManager (Singleton)
- `@Published conversations: [Conversation]` - Auto-saves on change
- `newConversation()` - Creates conversation with date title
- `update(_ conversation)` - Updates existing conversation
- Storage: `~/Library/Containers/.../Conversations/conversations.json`

### ConversationState (ObservableObject)
- `@Published selectedConversationId: UUID?`
- `@Published selectedExpertId: UUID?`
- `@Published useCanvas: Bool`
- `newConversation()` - Creates + selects new conversation

### PromptController (ObservableObject)
- `@Published prompt: String` - Current input text
- `@Published tempResources: [TemporaryResource]` - Attached files
- `@Published useWebSearch: Bool`
- `@Published useFunctions: Bool`

## Message Submission Flow
1. User types in `ChatPromptEditor` (bound to `promptController.prompt`)
2. Presses Cmd+Return or Return → `PromptInputField.onSubmit()`
3. `submit()` validates, creates `Message(sender: .user)`, calls `conversation.addMessage()`
4. `conversationManager.update(conversation)` persists
5. `generateChatResponse()` calls `model.listenThinkRespond()` for AI response
6. Response message created and added to conversation

## Current Edit Functionality
- `MessageOptionsView` shows Edit button (only when `canEdit && !isEditing`)
- `MessageContentView` shows TextEditor when `isEditing = true`
- Save button calls `updateMessage()` which only updates text in place
- **No resubmit/regenerate functionality exists**

## Notifications Used
- `Notifications.newConversation` - Posted when conversation created (legacy)
- `Notifications.requestNewConversation` - Request to enter pending new chat mode
- `Notifications.switchToConversation` - Navigate to specific conversation
- `Notifications.changedInferenceConfig` - Model config changed
- `Notifications.systemPromptChanged` - Expert system prompt changed

## Deferred Chat Creation (New Feature)
When clicking "New Chat" or pressing Cmd+N:
1. App enters "pending" mode (`ConversationState.isPendingNewChat = true`)
2. Shows empty chat view with input field ready
3. NO conversation created in sidebar yet
4. On first message submit, `createPendingConversation()` is called
5. Conversation created and appears in sidebar with the message

## Build & Run
```bash
# Open in Xcode
open Sidekick.xcodeproj

# Build from command line
xcodebuild -project Sidekick.xcodeproj -scheme Sidekick -configuration Debug build
```

## Important Conventions
- All UI state classes are `@MainActor`
- Use `withAnimation(.linear)` for state transitions
- Conversations are prepended to array (newest first)
- Message validation: Can't add consecutive messages from same sender
- Empty user messages are rejected
