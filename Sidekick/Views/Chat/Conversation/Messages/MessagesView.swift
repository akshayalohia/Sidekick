//
//  MessagesView.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import SwiftUI
import AppKit

struct MessagesView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject private var model: Model
    @EnvironmentObject private var conversationManager: ConversationManager
    @EnvironmentObject private var expertManager: ExpertManager
    @EnvironmentObject private var conversationState: ConversationState
    
    @State private var scrollViewProxy: NSScrollView?
    @State private var savedScrollPosition: CGPoint?
    @State private var wasShowingPreview: Bool = false
    
    var selectedConversation: Conversation? {
        guard let selectedConversationId = conversationState.selectedConversationId else {
            return nil
        }
        return self.conversationManager.getConversation(
            id: selectedConversationId
        )
    }
    
    var messages: [Message] {
        return self.selectedConversation?.messages ?? []
    }
    
    var shouldShowPreview: Bool {
        let statusPass: Bool = self.model.status.isWorking && self.model.status != .backgroundTask
        let conversationPass: Bool = self.selectedConversation?.id == self.model.sentConversationId
        return statusPass && conversationPass
    }
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top) {
                LazyVStack(alignment: .leading, spacing: 13) {
                    Group {
                        self.messagesView
                        if self.shouldShowPreview {
                            self.model.pendingMessageView
                        }
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 175)
                Spacer()
            }
        }
        .background(Color("surface-tertiary"))
        .background(NSScrollViewAccessor(scrollView: $scrollViewProxy))
        .onChange(of: shouldShowPreview) { oldValue, newValue in
            // When preview is showing, continuously track scroll position
            if newValue {
                wasShowingPreview = true
            }
            
            // When preview disappears (message generation finishes)
            if oldValue && !newValue {
                // Save the current scroll position before the view updates
                if let scrollView = scrollViewProxy {
                    savedScrollPosition = scrollView.documentVisibleRect.origin
                }
            }
        }
        .onChange(of: messages.count) { oldCount, newCount in
            // When a message finishes generating and is added to the array
            if wasShowingPreview && newCount > oldCount {
                // Restore the saved scroll position after a brief delay
                // to ensure the new content has been laid out
                if let savedPosition = savedScrollPosition, let scrollView = scrollViewProxy {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollView.contentView.scroll(to: savedPosition)
                        // Clear the saved position after restoring
                        savedScrollPosition = nil
                        wasShowingPreview = false
                    }
                }
            }
        }
    }
    
    var messagesView: some View {
        ForEach(
            self.messages
        ) { message in
            MessageView(message: message)
                .id(message.id)
        }
    }
    
}

/// A helper view to access the underlying NSScrollView
struct NSScrollViewAccessor: NSViewRepresentable {
    
    @Binding var scrollView: NSScrollView?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.findNSScrollView(in: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.findNSScrollView(in: nsView)
        }
    }
    
    private func findNSScrollView(in view: NSView) {
        if let scrollView = view.enclosingScrollView {
            self.scrollView = scrollView
            return
        }
        
        var parent = view.superview
        while parent != nil {
            if let scrollView = parent as? NSScrollView {
                self.scrollView = scrollView
                return
            }
            parent = parent?.superview
        }
    }
}
