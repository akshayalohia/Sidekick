//
//  AttachmentSelectionButton.swift
//  Sidekick
//
//  Created by Bean John on 11/26/24.
//

import FSKit_macOS
import SwiftUI

struct AttachmentSelectionButton: View {
	
	var add: (URL) async -> Void = { _ in }
	
    var body: some View {
		Button {
			guard let selectedUrls: [URL] = try? FileManager.selectFile(
				dialogTitle: String(localized: "Select a File"),
				canSelectDirectories: false,
				allowMultipleSelection: true
			) else { return }
			Task { @MainActor in
				for url in selectedUrls {
					await self.add(url)
				}
			}
		} label: {
			Label("Add Files", systemImage: "paperclip")
				.labelStyle(.iconOnly)
				.font(.system(size: 16))
				.foregroundStyle(.secondary)
		}
		.buttonStyle(.plain)
		.keyboardShortcut("a", modifiers: [.command, .shift])
		.padding(.leading, 10)
    }
	
}
