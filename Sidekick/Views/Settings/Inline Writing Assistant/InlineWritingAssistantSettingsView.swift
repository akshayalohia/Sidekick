//
//  InlineWritingAssistantSettingsView.swift
//  Sidekick
//
//  Created by John Bean on 3/25/25.
//

import KeyboardShortcuts
import SwiftUI

struct InlineWritingAssistantSettingsView: View {
	
	@State private var isSettingUpCompletions: Bool = false
	@State private var isManagingExcludedApps: Bool = false
    
	@AppStorage("useCompletions") private var useCompletions: Bool = false
	@AppStorage("didSetUpCompletions") private var didSetUpCompletions: Bool = false
    
    @AppStorage("completionsModelUrl") private var completionsModelUrl: URL?
    @AppStorage("completionSuggestionThreshold") private var completionSuggestionThreshold: Int = Settings.completionSuggestionThreshold
	
	var completionsIsReady: Bool {
		return useCompletions && didSetUpCompletions
	}
	
    var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Inline Writing Assistant")
				.libreChatSectionHeader()
				.padding(.horizontal, 32)
			
			VStack(spacing: 20) {
				commandsShortcut
				completionsConfig
				if self.completionsIsReady {
					completionsModelSelector
					completionSuggestionThresholdPicker
					nextTokenShortcut
					allTokensShortcut
					excludedAppsConfig
				}
			}
			.padding(.horizontal, 32)
		}
		.sheet(
			isPresented: self.$isSettingUpCompletions
		) {
			CompletionsSetupView(
				isPresented: self.$isSettingUpCompletions
			)
			.frame(minWidth: 400)
		}
		.sheet(
			isPresented: self.$isManagingExcludedApps
		) {
			CompletionsExclusionList(
				isPresented: self.$isManagingExcludedApps
			)
			.frame(minWidth: 400)
		}
    }
	
	var commandsShortcut: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text("Shortcut")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("The shortcut used to trigger and dismiss inline writing assistant commands.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			KeyboardShortcuts.Recorder(
				"",
				name: .toggleInlineAssistant
			)
		}
		.padding(.vertical, 8)
	}
	
	var completionsConfig: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Use Completions")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Automatically generate and suggest typing suggestions based on your text.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			if !self.didSetUpCompletions {
				completionsSetupButton
					.libreChatButtonStyle()
			} else {
				completionsToggle
			}
		}
		.padding(.vertical, 8)
		.onChange(
			of: useCompletions
		) {
			// Start or stop controller
			if useCompletions && didSetUpCompletions {
				CompletionsController.shared.setup()
			} else {
				CompletionsController.shared.stop()
			}
			// Refresh completions shortcuts status
			ShortcutController.refreshCompletionsShortcuts()
		}
	}
	
	var completionsSetupButton: some View {
		Button {
			self.isSettingUpCompletions.toggle()
		} label: {
			Text("Set Up")
		}
	}
	
	var completionsToggle: some View {
		Toggle("", isOn: self.$useCompletions.animation(.libreChatDefault))
			.toggleStyle(.libreChat)
			.disabled(!didSetUpCompletions)
	}
    
    var completionsModelSelector: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Completions Model: \(completionsModelUrl?.lastPathComponent ?? String(localized: "No Model Selected"))"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text-primary"))
                Text("This is the selected base model, which handles text completions.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                if let url = try? FileManager.selectFile(
                    rootUrl: self.completionsModelUrl?.deletingLastPathComponent(),
                    dialogTitle: String(localized: "Select a Base Model"),
                    canSelectDirectories: false,
                    allowedContentTypes: [Settings.ggufType]
                ).first {
                    self.completionsModelUrl = url
                    // Reload model
                    CompletionsController.shared.stop()
                    CompletionsController.shared.setup()
                }
            } label: {
                Text("Select")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                guard let modelUrl: URL = InferenceSettings.completionsModelUrl else {
                    return
                }
                FileManager.showItemInFinder(url: modelUrl)
            } label: {
                Text("Show in Finder")
            }
        }
    }
    
    var completionSuggestionThresholdPicker: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Completion Suggestion Threshold")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("The threshold for displayed completion suggestions.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Picker(
                selection: $completionSuggestionThreshold.animation(.libreChatDefault)
            ) {
                ForEach(
                    Settings.CompletionSuggestionThreshold.allCases,
                    id: \.self
                ) { mode in
                    Text(mode.description)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 8)
    }
    
	var nextTokenShortcut: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text("Accept Next Word")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("The shortcut used to accept the next word in completion suggestions.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			KeyboardShortcuts.Recorder(
				"",
				name: .acceptNextToken
			)
		}
		.padding(.vertical, 8)
	}
	
	var allTokensShortcut: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text("Accept All Suggestions")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("The shortcut used to accept the full completion suggestion.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			KeyboardShortcuts.Recorder(
				"",
				name: .acceptAllTokens
			)
		}
		.padding(.vertical, 8)
	}
	
	var excludedAppsConfig: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Excluded Apps")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Completions will be deactivated in these apps.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			Button {
				self.isManagingExcludedApps.toggle()
			} label: {
				Text("Manage")
			}
			.libreChatButtonStyle()
		}
		.padding(.vertical, 8)
	}
	
}

#Preview {
    InlineWritingAssistantSettingsView()
}
