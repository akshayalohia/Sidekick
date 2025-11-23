//
//  ConversationSidebarButtons.swift
//  Sidekick
//
//  Created by John Bean on 3/19/25.
//

import SwiftUI

struct ConversationSidebarButtons: View {
	
	@EnvironmentObject private var lengthyTasksController: LengthyTasksController
	@EnvironmentObject private var conversationState: ConversationState
	
	@State private var isViewingToolbox: Bool = false
	
	var tryToolsTip: TryToolsTip = .init()
	
    var body: some View {
		Group {
			if self.lengthyTasksController.hasTasks {
				LengthyTasksNavigationButton()
					.buttonStyle(.plain)
					.foregroundStyle(.secondary)
			}
			SidebarButtonView(
				title: String(localized: "Toolbox"),
				systemImage: "wrench.adjustable"
			) {
				self.isViewingToolbox.toggle()
			}
			.keyboardShortcut("t", modifiers: [.command])
			.sheet(isPresented: $isViewingToolbox) {
				ToolboxLibraryView(
					isPresented: $isViewingToolbox
				)
                .frame(maxWidth: 500, minHeight: 600)
			}
			.popoverTip(tryToolsTip)
		}
		.padding(.horizontal, 8)
    }
	
}

#Preview {
    ConversationSidebarButtons()
}
