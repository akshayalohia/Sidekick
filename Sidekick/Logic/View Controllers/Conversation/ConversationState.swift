//
//  ConversationState.swift
//  Sidekick
//
//  Created by Bean John on 10/14/24.
//

import Foundation
import SwiftUI

@MainActor
public class ConversationState: ObservableObject {

	@Published var isManagingExperts: Bool = false

	@Published var selectedConversationId: UUID? = topmostConversation?.id

	/// Whether we're in "pending new chat" mode (chat not yet created)
	@Published var isPendingNewChat: Bool = false

	/// The topmost conversation listed in the sidebar
	static var topmostConversation: Conversation? {
		return ConversationManager.shared.conversations.first
	}

	/// The currently selected conversation
	public var selectedConversation: Conversation? {
		guard let selectedConversationId = self.selectedConversationId else {
			return nil
		}
		return ConversationManager.shared.getConversation(
			id: selectedConversationId
		)
	}

	@Published var selectedExpertId: UUID? = ConversationManager.shared.conversations.first?.messages.last?.expertId ?? ExpertManager.shared.default?.id

	@Published var useCanvas: Bool = false

	/// Function to enter pending new conversation mode (deferred creation)
	public func newConversation() {
		// If already pending with no selection, stay on current
		if isPendingNewChat && selectedConversationId == nil {
			return
		}

		// Enter pending mode - don't create conversation yet
		withAnimation(.linear) {
			self.selectedConversationId = nil
			self.isPendingNewChat = true
			self.selectedExpertId = ExpertManager.shared.default?.id
			self.useCanvas = false
		}
	}

	/// Actually create the conversation (called on first message submission)
	public func createPendingConversation() -> Conversation {
		let conversation = ConversationManager.shared.createConversation(
			expertId: selectedExpertId
		)
		withAnimation(.linear) {
			self.isPendingNewChat = false
			self.selectedConversationId = conversation.id
		}
		return conversation
	}

	/// Exit pending mode without creating a conversation (e.g., when selecting existing chat)
	public func exitPendingMode() {
		if isPendingNewChat {
			withAnimation(.linear) {
				self.isPendingNewChat = false
			}
		}
	}

}
