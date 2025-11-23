//
//  ExpertManagerView.swift
//  Sidekick
//
//  Created by Bean John on 10/10/24.
//

import SwiftUI

struct ExpertManagerView: View {
	
	@EnvironmentObject private var expertManager: ExpertManager
	@EnvironmentObject private var conversationState: ConversationState
	
	@State private var selectedExpertId: UUID? = ExpertManager.shared.firstExpert?.id
	
	var selectedExpert: Expert? {
		guard let selectedExpertId = selectedExpertId else { return nil }
		return expertManager.getExpert(id: selectedExpertId)
	}
	
	@State private var editingExpert: Expert = ExpertManager.shared.firstExpert!
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			HStack {
				ExitButton {
					conversationState.isManagingExperts.toggle()
				}
				Spacer()
				Text("Manage Experts")
					.font(.system(size: 17, weight: .semibold))
					.foregroundColor(Color("text-primary"))
				Spacer()
				// Invisible spacer for centering
				ExitButton {
					conversationState.isManagingExperts.toggle()
				}
				.opacity(0)
				.disabled(true)
			}
			.padding(.horizontal, 32)
			.padding(.top, 20)
			.padding(.bottom, 16)
			
			Divider()
			
			// Expert List
			ExpertListView()
				.frame(maxHeight: .infinity)
			
			Divider()
			
			// Footer with Add button
			HStack {
				Spacer()
				newExpertButton
				Spacer()
			}
			.padding(.horizontal, 32)
			.padding(.vertical, 20)
		}
		.background(Color("surface-primary"))
	}
	
	var newExpertButton: some View {
		Button {
			self.newExpert()
		} label: {
			HStack(spacing: 6) {
				Image(systemName: "plus")
					.font(.system(size: 14, weight: .medium))
				Text("Add Expert")
					.font(.system(size: 14, weight: .medium))
			}
		}
		.libreChatButtonStyle()
	}
	
	private func newExpert() {
		let newExpert: Expert = Expert(
			name: "Untitled",
			symbolName: "questionmark.circle.fill",
			color: Color.white
		)
		self.expertManager.add(newExpert)
	}
	
}
