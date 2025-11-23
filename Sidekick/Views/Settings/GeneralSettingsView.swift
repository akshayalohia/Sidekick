//
//  GeneralSettingsView.swift
//  Sidekick
//
//  Created by Bean John on 10/14/24.
//

import MarkdownUI
import LaunchAtLogin
import SwiftUI

struct GeneralSettingsView: View {
	
	@AppStorage("username") private var username: String = NSFullUserName()
	
    @AppStorage("useCommandReturn") private var useCommandReturn: Bool = Settings.useCommandReturn
    @AppStorage("playSoundEffects") private var playSoundEffects: Bool = false
    @AppStorage("generateConversationTitles") private var generateConversationTitles: Bool = InferenceSettings.useServer && !InferenceSettings.serverWorkerModelName.isEmpty
    @AppStorage("voiceId") private var voiceId: String = ""
    
    @AppStorage("useFunctions") private var useFunctions: Bool = Settings.useFunctions
    @AppStorage("checkFunctionsCompletion") private var checkFunctionsCompletion: Int = 0

    @StateObject private var speechSynthesizer: SpeechSynthesizer = .shared
	
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // General Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("General")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    launchAtLogin
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                
                // Chat Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Chat")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        usernameEditor
                        sendShortcutToggle
                        soundEffects
                        generateConversationTitlesToggle
                        voice
                    }
                    .padding(.horizontal, 32)
                }
                
                // Functions Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Functions")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        useFunctionsToggle
                        checkFunctionsCompletionPicker
                    }
                    .padding(.horizontal, 32)
                }
                
                // Inline Writing Assistant
                InlineWritingAssistantSettingsView()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .background(Color("surface-primary"))
        .task {
            SpeechSynthesizer.shared.fetchVoices()
        }
    }
	
	var launchAtLogin: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Launch at Login")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Controls whether Sidekick launches automatically at login.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			LaunchAtLogin.Toggle()
				.labelsHidden()
		}
		.padding(.vertical, 8)
	}
	
	var usernameEditor: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Username")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Sidekick will refer to you by this username.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			TextField("", text: $username)
				.textFieldStyle(LibreChatTextFieldStyle())
				.frame(width: 300)
		}
		.padding(.vertical, 8)
	}
	
    var sendShortcutToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Send Message")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Send a message with the selected shortcut.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Picker(
                selection: self.$useCommandReturn.animation(.libreChatDefault)
            ) {
                Settings.SendShortcut(true).label
                    .tag(true)
                Settings.SendShortcut(false).label
                    .tag(false)
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 8)
    }
    
	var soundEffects: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Play Sound Effects")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Play sound effects when text generation begins and ends.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			Toggle("", isOn: $playSoundEffects)
				.toggleStyle(.libreChat)
		}
		.padding(.vertical, 8)
	}
	
	var generateConversationTitlesToggle: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Generate Conversation Titles")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Automatically generate conversation titles based on the first message in each conversation.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			Toggle("", isOn: $generateConversationTitles)
				.toggleStyle(.libreChat)
		}
		.padding(.vertical, 8)
	}
	
	var useFunctionsToggle: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Use Functions")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Encourage models to use functions, which are evaluated to execute actions.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
            Toggle("", isOn: $useFunctions)
				.toggleStyle(.libreChat)
                .onChange(of: useFunctions) {
                    // Send notification to reload model with jinja
                    NotificationCenter.default.post(
                        name: Notifications.changedInferenceConfig.name,
                        object: nil
                    )
                }
		}
		.padding(.vertical, 8)
	}
    
    var checkFunctionsCompletionPicker: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Check Functions Completion")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Check if functions have reached the initial target. Useful for staying on task after long chains of function calls.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Picker(
                selection: $checkFunctionsCompletion.animation(.libreChatDefault)
            ) {
                ForEach(
                    Settings.FunctionCompletionCheckMode.allCases
                ) { mode in
                    Text(mode.description)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 8)
    }
	
	var voice: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Voice")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("The voice used to read responses aloud. Download voices in [System Settings -> Accessibility](x-apple.systempreferences:com.apple.preference.universalaccess?SpeakableItems) -> Spoken Content -> System Voice -> Manage Voices.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			Picker(
				selection: self.$voiceId.animation(.libreChatDefault)
			) {
				ForEach(
					speechSynthesizer.voices,
					id: \.self.identifier
				) { voice in
					Text(voice.prettyName)
						.tag(voice.identifier)
				}
			}
			.pickerStyle(.menu)
		}
		.padding(.vertical, 8)
	}
	
}

#Preview {
    GeneralSettingsView()
}
