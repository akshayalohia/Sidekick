//
//  SetupView.swift
//  Sidekick
//
//  Created by Bean John on 9/22/24.
//

import SwiftUI

struct SetupView: View {
	
	@EnvironmentObject private var conversationState: ConversationState
	
	@State private var selectedModel: Bool = Settings.hasModel
	
	@Binding var showSetup: Bool
	
    var body: some View {
		Group {
			if !selectedModel {
				// If no model, download or select a model
				ModelSelectionView(selectedModel: $selectedModel)
					.padding(.vertical, 32)
					.padding(.horizontal, 32)
					.transition(.libreChatFade)
			} else {
				// Else, show setup complete screen
				IntroductionView(showSetup: $showSetup)
					.padding(.vertical, 32)
					.padding(.horizontal, 32)
					.transition(.libreChatFade)
			}
		}
		.background(Color("surface-primary"))
		.animation(.libreChatDefault, value: selectedModel)
		.interactiveDismissDisabled(true)
    }
	
}
