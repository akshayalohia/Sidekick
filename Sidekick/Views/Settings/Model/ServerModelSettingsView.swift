//
//  ServerModelSettingsView.swift
//  Sidekick
//
//  Created by John Bean on 3/12/25.
//

import SwiftUI

struct ServerModelSettingsView: View {
    
	@AppStorage("useServer") private var useServer: Bool = InferenceSettings.useServer
	@AppStorage("endpoint") private var serverEndpoint: String = InferenceSettings.endpoint

	@State private var inferenceApiKey: String = InferenceSettings.inferenceApiKey
	
	@AppStorage("remoteModelName") private var serverModelName: String = InferenceSettings.serverModelName
    
    @AppStorage("serverModelHasVision") private var serverModelHasVision: Bool = InferenceSettings.serverModelHasVision
    @AppStorage("hasNativeToolCalling") private var hasNativeToolCalling: Bool = InferenceSettings.hasNativeToolCalling
    
	@AppStorage("serverWorkerModelName") private var serverWorkerModelName: String = InferenceSettings.serverWorkerModelName
	
    var popularEndpointsTip: PopularEndpointsTip = .init()
    
	/// A `Bool` representing if the endpoint is valid
	var endpointUrlIsValid: Bool {
		let paths: [String] = ["", "/models", "/chat/completions"]
		let pathsAreValid: [Bool] = paths.map { path in
			return URL(string: self.serverEndpoint + path) != nil
		}
		return !pathsAreValid.contains(false)
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Remote Model")
				.libreChatSectionHeader()
				.padding(.horizontal, 32)
			
			VStack(spacing: 20) {
				useServerToggle
				serverEndpointEditor
				inferenceApiKeyEditor
				Group {
					ServerModelNameEditor(
						serverModelName: $serverModelName,
						modelType: .regular
					)
					serverModelHasVisionToggle
					hasNativeToolCallingToggle
					ServerModelNameEditor(
						serverModelName: $serverWorkerModelName,
						modelType: .worker
					)
				}
				.id(inferenceApiKey)
			}
			.padding(.horizontal, 32)
		}
	}
	
	var useServerToggle: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Use Remote Model")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Controls whether a server is used for inference when it is available.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			Toggle("", isOn: $useServer.animation(.libreChatDefault))
				.toggleStyle(.libreChat)
				.disabled(serverEndpoint.isEmpty || !endpointUrlIsValid)
		}
		.padding(.vertical, 8)
		.onChange(of: useServer) {
			// Send notification to reload model
			NotificationCenter.default.post(
				name: Notifications.changedInferenceConfig.name,
				object: nil
			)
		}
	}
	
	var serverEndpointEditor: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Endpoint")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("The endpoint on the server used for inference. This endpoint must be accessible from this device, and provide an OpenAI compatible API. (e.g. http://localhost:8000/v1/, where http://localhost:8000/v1/chat/completions is accessible)\n\nTo ensure privacy and security of your data, host your own server.")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("", text: $serverEndpoint.animation(.libreChatDefault))
                        .textContentType(.username)
                        .textFieldStyle(LibreChatTextFieldStyle())
                        .frame(maxWidth: 200)
                        .onSubmit {
                            // Run check
                            self.checkProviderForToolCalling()
                        }
                    Menu {
                        ForEach(
                            Provider.popularProviders
                        ) { provider in
                            Button {
                                withAnimation(.libreChatDefault) {
                                    self.serverEndpoint = provider.endpointUrl.absoluteString
                                }
                            } label: {
                                Text(provider.name)
                            }
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.down.fill")
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderedButton)
                    .frame(maxWidth: 25)
                    .popoverTip(self.popularEndpointsTip)
                }
				if !self.endpointUrlIsValid {
					Text("Endpoint is not valid")
						.font(.system(size: 12))
						.fontWeight(.medium)
						.foregroundStyle(.red)
				}
			}
		}
		.padding(.vertical, 8)
        .onChange(of: self.serverEndpoint) {
            // Run check
            self.checkProviderForToolCalling()
        }
	}
	
	var inferenceApiKeyEditor: some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: 4) {
				Text("API Key")
					.font(.system(size: 15, weight: .medium))
					.foregroundColor(Color("text-primary"))
				Text("Needed to access an API for inference")
					.font(.system(size: 13))
					.foregroundColor(Color("text-secondary"))
			}
			Spacer()
			SecureField("", text: $inferenceApiKey)
                .textContentType(.password)
				.textFieldStyle(LibreChatSecureFieldStyle())
				.frame(width: 300)
				.onChange(of: inferenceApiKey) { oldValue, newValue in
					InferenceSettings.inferenceApiKey = newValue
				}
		}
		.padding(.vertical, 8)
	}
    
    var serverModelHasVisionToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Use Vision Capabilities")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Controls whether a remote model can be used for tasks that require vision. Turn it on only when the remote model has vision capabilities.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $serverModelHasVision.animation(.libreChatDefault))
                .toggleStyle(.libreChat)
                .disabled(serverEndpoint.isEmpty || !endpointUrlIsValid)
        }
        .padding(.vertical, 8)
    }
    
    var hasNativeToolCallingToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Native Function Calling")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Controls whether native function calling is available for the remote model. Turn it on only when the inference provider supports native function calling for the selected model.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $hasNativeToolCalling.animation(.libreChatDefault))
                .toggleStyle(.libreChat)
                .disabled(serverEndpoint.isEmpty || !endpointUrlIsValid)
        }
        .padding(.vertical, 8)
    }
    
    private func checkProviderForToolCalling() {
        // Return if invalid or blank
        if !self.endpointUrlIsValid || self.serverEndpoint.isEmpty {
            return
        }
        // Check provider, defaulting to false
        let providerSupportsToolCalling = InferenceSettings.providerSupportsToolCalling() ?? false
        // If no change, exit
        if providerSupportsToolCalling == self.hasNativeToolCalling {
            return
        }
        // Get message
        let message: String = providerSupportsToolCalling ? String(localized: "A new endpoint has been selected, which has been identified as capable of native function calling. Would you like to turn on native function calling?") : String(
            localized: "A new endpoint has been selected, which might not be capable of native function calling. Would you like to turn off native function calling?"
        )
        // Confirm with user
        if Dialogs.dichotomy(
            title: String(localized: "Provider Changed"),
            message: message,
            option1: String(localized: "Yes"),
            option2: String(localized: "No")
        ) {
            withAnimation(.linear) {
                self.hasNativeToolCalling = providerSupportsToolCalling
            }
        }
    }
    
}
