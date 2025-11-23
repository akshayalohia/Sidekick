//
//  ConversationNavigationListView.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import SwiftUI

struct ConversationNavigationListView: View {

	@EnvironmentObject private var conversationManager: ConversationManager
	@EnvironmentObject private var expertManager: ExpertManager
	@EnvironmentObject private var conversationState: ConversationState

	var body: some View {
		List(
			self.$conversationManager.conversations,
			editActions: .move,
			selection: $conversationState.selectedConversationId
		) { conversation in
			NavigationLink(value: conversation.id) {
				ConversationNameEditor(conversation: conversation)
			}
			.buttonStyle(.plain)
			.listRowBackground(
				conversationState.selectedConversationId == conversation.id
					? Color("surface-active-alt")
					: Color.clear
			)
			.listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
			.listRowSeparator(.hidden)
        }
        .listStyle(.sidebar)
        .scrollIndicators(.never)
        .scrollContentBackground(.hidden)
        .background(Color("surface-primary-alt"))
		.navigationSplitViewColumnWidth(
			min: 200,
			ideal: 260,
			max: 320
		)
	}

}
