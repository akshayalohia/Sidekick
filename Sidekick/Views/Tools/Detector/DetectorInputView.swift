//
//  DetectorInputView.swift
//  Sidekick
//
//  Created by John Bean on 2/24/25.
//

import SwiftUI

struct DetectorInputView: View {
	
	@EnvironmentObject private var detectorViewController: DetectorViewController
	
    var body: some View {
		ScrollView {
			TextEditor(
				text: $detectorViewController.text
			)
			.textEditorStyle(.plain)
			.frame(minHeight: 1000)
			.scrollIndicators(.hidden)
			.font(.title3)
			.padding([.vertical, .leading])
		}
		.toolbar {
			ToolbarItemGroup(
				placement: .primaryAction
			) {
				analyzeButton
			}
		}
    }
	
	var analyzeButton: some View {
		Button {
			// Check for local model
			if !checkForLocalModel() {
				return
			}
			// If check passed, start analysis
			Task.detached { @MainActor in
				await self.detectorViewController.evaluateText()
			}
		} label: {
			Text("Analyze")
				.font(.system(size: 15, weight: .medium))
		}
		.libreChatButtonStyle(size: .large)
	}
	
	private func checkForLocalModel() -> Bool {
		// Check if local model is available
		let result: Bool = Settings.modelUrl?.fileExists ?? false
		// If not available, show error
		if !result {
			Dialogs.showAlert(
				title: String(localized: "No Local Model"),
				message: String(localized: "Detector always uses a local model for maximum privacy. Please add a local model in \"Settings\" -> \"Inference\".")
			)
		}
		return result
	}
	
}
