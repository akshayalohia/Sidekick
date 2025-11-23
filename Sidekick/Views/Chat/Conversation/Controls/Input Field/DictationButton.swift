//
//  DictationButton.swift
//  Sidekick
//
//  Created by Bean John on 10/23/24.
//

import SwiftUI

struct DictationButton: View {
	
	@EnvironmentObject private var promptController: PromptController
	
	var microphoneIcon: String {
		if #unavailable(macOS 15) {
			return "mic.fill"
		}
		return "microphone.fill"
	}
	
    var body: some View {
		Button {
			withAnimation(.linear) {
				self.promptController.toggleRecording()
			}
		} label: {
			Label("", systemImage: self.microphoneIcon)
				.font(.system(size: 16))
				.foregroundStyle(
					promptController.isRecording ? .red : .secondary
				)
		}
		.buttonStyle(.plain)
		.keyboardShortcut("d", modifiers: [.command])
		.padding([.trailing, .bottom], 3)
    }
}

#Preview {
    DictationButton()
}
