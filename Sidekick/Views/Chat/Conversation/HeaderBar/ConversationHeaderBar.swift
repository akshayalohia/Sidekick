//
//  ConversationHeaderBar.swift
//  Sidekick
//
//  Created for LibreChat UI transformation
//

import SwiftUI

struct ConversationHeaderBar: View {

    @EnvironmentObject private var conversationState: ConversationState
    @EnvironmentObject private var conversationManager: ConversationManager
    @EnvironmentObject private var model: Model

    var selectedConversation: Conversation? {
        guard let selectedConversationId = conversationState.selectedConversationId else {
            return nil
        }
        return self.conversationManager.getConversation(
            id: selectedConversationId
        )
    }

    var isGenerating: Bool {
        let statusPass: Bool = self.model.status.isWorking
        let conversationPass: Bool = self.selectedConversation?.id == self.model.sentConversationId
        return statusPass && conversationPass
    }

    var canToggleCanvas: Bool {
        let hasAssistantMessages = self.selectedConversation?.messages.contains {
            $0.getSender() == .assistant
        } ?? false
        let hasMessages = !(self.selectedConversation?.messages.isEmpty ?? true)
        return hasAssistantMessages && hasMessages
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Model selector and Experts toggle
            HStack(spacing: 8) {
                LibreChatModelSelector()
                    .environmentObject(model)

                LibreChatExpertsToggle()
                    .environmentObject(conversationState)
                    .onChange(
                        of: conversationState.selectedExpertId
                    ) {
                        guard var selectedConversation = self.selectedConversation else {
                            return
                        }
                        selectedConversation.expertId = self.conversationState.selectedExpertId
                        self.conversationManager.update(selectedConversation)
                    }
            }

            Spacer()

            // Right side: Canvas toggle and Share menu
            HStack(spacing: 8) {
                canvasToggle
                MessageShareMenu()
                    .environmentObject(model)
                    .environmentObject(conversationManager)
                    .environmentObject(conversationState)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 44)
        .background(Color("surface-secondary"))
    }

    var canvasToggle: some View {
        Button {
            self.toggleCanvas()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cube")
                    .font(.system(size: 14))
                Text("Canvas")
                    .font(.system(size: 14))
                    .fontWeight(.medium)
            }
            .foregroundColor(Color("text-primary"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(conversationState.useCanvas ? Color("surface-tertiary") : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("borderLight"), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!canToggleCanvas)
        .opacity(canToggleCanvas ? 1.0 : 0.5)
        .keyboardShortcut(.return, modifiers: [.command, .option])
    }

    private func toggleCanvas() {
        withAnimation(.linear) {
            // Select a version if possible
            if let message = self.selectedConversation?.messagesWithSnapshots.last {
                CanvasController().selectedMessageId = message.id
            }
            // Confirm whether content should be extracted
            if self.selectedConversation?.messagesWithSnapshots.isEmpty ?? true {
                // If no snapshots, confirm extraction
                if !Dialogs.showConfirmation(
                    title: String(localized: "No Content Found"),
                    message: String(localized: "No content found. Would you like to extract content from your most recent message?")
                ) {
                    return // If no, exit
                }
            }
            // Toggle canvas
            self.conversationState.useCanvas.toggle()
            // Extract snapshot if needed
            let canvasController = CanvasController()
            if !canvasController.isExtractingSnapshot {
                Task { @MainActor in
                    try? await canvasController.extractSnapshot(
                        selectedConversation: selectedConversation
                    )
                }
            }
        }
    }
}
