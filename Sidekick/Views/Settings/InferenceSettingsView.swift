//
//  InferenceSettingsView.swift
//  Sidekick
//
//  Created by Bean John on 10/14/24.
//

import FSKit_macOS
import MarkdownUI
import SwiftUI
import UniformTypeIdentifiers

struct InferenceSettingsView: View {
    
    @AppStorage("modelUrl") private var modelUrl: URL?
    @AppStorage("workerModelUrl") private var workerModelUrl: URL?
    @AppStorage("specularDecodingModelUrl") private var specularDecodingModelUrl: URL?
    @AppStorage("projectorModelUrl") private var projectorModelUrl: URL?
    
    @State private var isEditingSystemPrompt: Bool = false
    
    @State private var isSelectingModel: Bool = false
    @State private var isSelectingWorkerModel: Bool = false
    @State private var isSelectingSpeculativeDecodingModel: Bool = false
    
    @State private var isConfiguringServerArguments: Bool = false
    
    @AppStorage("temperature") private var temperature: Double = InferenceSettings.temperature
    @AppStorage("useGPUAcceleration") private var useGPUAcceleration: Bool = InferenceSettings.useGPUAcceleration
    @AppStorage("useSpeculativeDecoding") private var useSpeculativeDecoding: Bool = InferenceSettings.useSpeculativeDecoding
    
    @AppStorage("localModelUseVision") private var localModelUseVision: Bool = InferenceSettings.localModelUseVision
    
    @AppStorage("contextLength") private var contextLength: Int = InferenceSettings.contextLength
    @AppStorage("enableContextCompression") private var enableContextCompression: Bool = InferenceSettings.enableContextCompression
    @AppStorage("compressionTokenThreshold") private var compressionTokenThreshold: Int = InferenceSettings.compressionTokenThreshold
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Models Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Models")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        model
                        workerModel
                        speculativeDecoding
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                
                // Vision Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Vision")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        multimodal
                    }
                    .padding(.horizontal, 32)
                }
                
                // Parameters Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Parameters")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        parameters
                    }
                    .padding(.horizontal, 32)
                }
                
                // Server Model Settings
                ServerModelSettingsView()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .background(Color("surface-primary"))
        .sheet(isPresented: $isEditingSystemPrompt) {
            SystemPromptEditor(
                isEditingSystemPrompt: $isEditingSystemPrompt
            )
            .frame(maxHeight: 700)
        }
        .sheet(isPresented: $isConfiguringServerArguments) {
            ServerArgumentsEditor(
                isPresented: self.$isConfiguringServerArguments
            )
            .frame(
                minWidth: 575,
                maxWidth: 600,
                minHeight: 350,
                maxHeight: 400
            )
            .interactiveDismissDisabled(true)
        }
    }
    
    var model: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Model: \(modelUrl?.lastPathComponent ?? String(localized: "No Model Selected"))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("This is the default local model used.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.isSelectingModel.toggle()
            } label: {
                Text("Manage")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                guard let modelUrl: URL = Settings.modelUrl else { return }
                FileManager.showItemInFinder(url: modelUrl)
            } label: {
                Text("Show in Finder")
            }
        }
        .sheet(isPresented: $isSelectingModel) {
            ModelListView(
                isPresented: $isSelectingModel,
                modelType: .regular
            )
            .frame(minWidth: 450, maxHeight: 600)
        }
    }
    
    var workerModel: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Worker Model: \(workerModelUrl?.lastPathComponent ?? String(localized: "No Model Selected"))"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text-primary"))
                Text("This is the local worker model used for simpler tasks like generating chat titles.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.isSelectingWorkerModel.toggle()
            } label: {
                Text("Manage")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                guard let modelUrl: URL = InferenceSettings.workerModelUrl else {
                    return
                }
                FileManager.showItemInFinder(url: modelUrl)
            } label: {
                Text("Show in Finder")
            }
        }
        .sheet(isPresented: $isSelectingWorkerModel) {
            ModelListView(
                isPresented: $isSelectingWorkerModel,
                modelType: .worker
            )
            .frame(minWidth: 450, maxHeight: 600)
        }
    }
    
    var speculativeDecoding: some View {
        Group {
            useSpeculativeDecodingToggle
            if useSpeculativeDecoding {
                speculativeDecodingModel
            }
        }
    }
    
    var useSpeculativeDecodingToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Use Speculative Decoding")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Improve inference speed by running a second model in parallel with the main model. This may use more memory.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $useSpeculativeDecoding.animation(.libreChatDefault))
                .toggleStyle(.libreChat)
        }
        .padding(.vertical, 8)
        .onChange(of: useSpeculativeDecoding) {
            // Send notification to reload model
            NotificationCenter.default.post(
                name: Notifications.changedInferenceConfig.name,
                object: nil
            )
        }
    }
    
    var speculativeDecodingModel: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Draft Model: \(specularDecodingModelUrl?.lastPathComponent ?? String(localized: "No Model Selected"))"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text-primary"))
                Text("This is the model used for speculative decoding. It should be in the same family as the main model, but with less parameters.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.isSelectingSpeculativeDecodingModel.toggle()
            } label: {
                Text("Manage")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                guard let modelUrl: URL = InferenceSettings.speculativeDecodingModelUrl else {
                    return
                }
                FileManager.showItemInFinder(url: modelUrl)
            } label: {
                Text("Show in Finder")
            }
        }
        .sheet(isPresented: $isSelectingSpeculativeDecodingModel) {
            ModelListView(
                isPresented: $isSelectingSpeculativeDecodingModel,
                modelType: .speculative
            )
            .frame(minWidth: 450, maxHeight: 600)
        }
    }
    
    var multimodal: some View {
        Group {
            useVisionToggle
            projectorModelSelector
        }
    }
    
    var useVisionToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Use Vision")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Use a vision capable local model.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $localModelUseVision.animation(.libreChatDefault))
                .toggleStyle(.libreChat)
        }
        .padding(.vertical, 8)
    }
    
    var projectorModelSelector: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Projector Model: \(projectorModelUrl?.lastPathComponent ?? String(localized: "No Model Selected"))"
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text-primary"))
                Text("This is the multimodal projector corresponding to the selected local model, which handles image encoding and projection.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                if let url = try? FileManager.selectFile(
                    dialogTitle: String(localized: "Select a Model"),
                    canSelectDirectories: false,
                    allowedContentTypes: [Settings.ggufType]
                ).first {
                    self.projectorModelUrl = url
                }
            } label: {
                Text("Select")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                guard let modelUrl: URL = InferenceSettings.projectorModelUrl else {
                    return
                }
                FileManager.showItemInFinder(url: modelUrl)
            } label: {
                Text("Show in Finder")
            }
        }
    }
    
    var parameters: some View {
        Group {
            systemPromptEditor
            temperatureEditor
            contextLengthEditor
            contextCompressionToggle
            contextCompressionThresholdEditor
            useGPUAccelerationToggle
            advancedParameters
        }
    }
    
    var systemPromptEditor: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Customize the system prompt used by the model.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.isEditingSystemPrompt.toggle()
            } label: {
                Text("Customise")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
    }
    
    var contextLengthEditor: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Context Length")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Context length is the maximum amount of information it can take as input for a query. A larger context length allows an LLM to recall more information, at the cost of slower output and more memory usage.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            TextField(
                "",
                value: $contextLength,
                formatter: NumberFormatter()
            )
            .textFieldStyle(LibreChatTextFieldStyle())
            .frame(width: 100)
        }
        .padding(.vertical, 8)
    }
    
    var temperatureEditor: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Temperature")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color("text-primary"))
                    PopoverButton {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color("text-secondary"))
                            .font(.system(size: 13))
                    } content: {
                        temperaturePopup
                    }
                    .buttonStyle(.plain)
                }
                Text("Temperature is a parameter that influences LLM output, determining whether it is more random and creative or more predictable. The lower the setting the more predictable the model acts.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            .frame(minWidth: 250)
            Spacer()
            HStack(spacing: 12) {
                Slider(
                    value: $temperature,
                    in: 0...2,
                    step: 0.1
                )
                .frame(minWidth: 200)
                Text(String(format: "%g", self.temperature))
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
    
    var temperaturePopup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended values:")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            HStack {
                Text("Coding / Math")
                Spacer()
                Text("0")
            }
            HStack {
                Text("Data Cleaning / Data Analysis")
                Spacer()
                Text("0.6")
            }
            HStack {
                Text("General Conversation")
                Spacer()
                Text("0.8")
            }
            HStack {
                Text("Translation")
                Spacer()
                Text("0.8")
            }
            HStack {
                Text("Creative Writing / Poetry")
                Spacer()
                Text("1.3")
            }
        }
        .font(.system(size: 11))
        .padding(10)
    }
    
    var useGPUAccelerationToggle: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use GPU Acceleration")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color("text-primary"))
                    Text("Controls whether the GPU is used for inference.")
                        .font(.system(size: 13))
                        .foregroundColor(Color("text-secondary"))
                }
                Spacer()
                Toggle("", isOn: $useGPUAcceleration)
                    .toggleStyle(.libreChat)
            }
            .onChange(of: useGPUAcceleration) {
                // Send notification to reload model
                NotificationCenter.default.post(
                    name: Notifications.changedInferenceConfig.name,
                    object: nil
                )
            }
            PerformanceGaugeView()
        }
        .padding(.vertical, 8)
    }
    
    var contextCompressionToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enable Context Compression")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Automatically compresses tool call results during agentic loops to prevent context window errors.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $enableContextCompression)
                .toggleStyle(.libreChat)
        }
        .padding(.vertical, 8)
    }
    
    var contextCompressionThresholdEditor: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compression Token Threshold")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Tool call results exceeding this token count will be summarized to save context space.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            TextField(
                "",
                value: $compressionTokenThreshold,
                formatter: NumberFormatter()
            )
            .textFieldStyle(LibreChatTextFieldStyle())
            .frame(width: 100)
        }
        .disabled(!enableContextCompression)
        .opacity(enableContextCompression ? 1.0 : 0.5)
        .padding(.vertical, 8)
    }
    
    var advancedParameters: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Advanced Parameters")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Configure the inference server directly by injecting flags and arguments. Arguments configured here will override other settings if needed.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
                Text("Find more information [here](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.isConfiguringServerArguments.toggle()
            } label: {
                Text("Configure")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
    }
    
}
