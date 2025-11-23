//
//  ConversationNameEditor.swift
//  Sidekick
//
//  Created by Bean John on 10/10/24.
//

import SwiftUI

struct ConversationNameEditor: View {

	@EnvironmentObject private var conversationManager: ConversationManager
	@EnvironmentObject private var conversationState: ConversationState

	@State private var isEditing: Bool = false
	@Binding var conversation: Conversation

	var rowBackgroundColor: Color {
		if conversationState.selectedConversationId == conversation.id {
			return Color("surface-active-alt")
		}
		return Color.clear
	}
	
    @State private var newTitle: String = ""
    
	@FocusState private var isFocused: Bool
	
    var body: some View {
		Group {
			if !isEditing {
				Text(conversation.title)
					.font(.system(size: 14))
					.foregroundColor(Color("text-primary"))
					.lineLimit(1)
					.contentTransition(.numericText())
			} else {
                TextField("Title", text: self.$newTitle)
					.font(.system(size: 14))
					.focused($isFocused)
					.textFieldStyle(.plain)
					.onSubmit {
						self.toggleEditingMode()
					}
					.onExitCommand {
						self.toggleEditingMode()
					}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 6)
		.padding(.horizontal, 12)
		.contentShape(Rectangle())
		.contextMenu {
			Group {
				Button {
					self.toggleEditingMode()
				} label: {
					Text("Rename")
				}
				Button {
					self.delete()
				} label: {
					Text("Delete")
				}
			}
		}
		.animation(.easeOut(duration: 0.2), value: conversationState.selectedConversationId)
	}
	
	private func delete() {
		// If deleting selected conversation, reset selected conversation
		if self.conversationState.selectedConversationId == self.conversation.id {
			self.conversationState.selectedConversationId = nil
		}
        // Delete temp resources
        let resourcesUrl: URL = Settings.cacheUrl
            .appendingPathComponent("Temporary Resources")
            .appendingPathComponent(self.conversation.id.uuidString)
        try? FileManager.default.removeItem(at: resourcesUrl)
        // Delete
		self.conversationManager.delete(conversation)
		// If no conversations, create new
		if self.conversationManager.conversations.isEmpty {
			// Create new conversation
			self.conversationState.newConversation()
		}
	}
	
	private func toggleEditingMode() {
        // Sync
        if !self.isEditing {
            self.newTitle = self.conversation.title
        } else {
            self.conversation.title = self.newTitle
        }
        // Exit editing mode
		self.isFocused.toggle()
		self.isEditing.toggle()
	}
	
}
