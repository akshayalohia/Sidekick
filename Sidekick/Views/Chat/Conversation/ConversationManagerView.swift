//
//  ConversationManagerView.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import Combine
import SwiftUI

struct ConversationManagerView: View {
    
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("remoteModelName") private var serverModelName: String = InferenceSettings.serverModelName
    
    @StateObject private var model: Model = .shared
    @StateObject private var canvasController: CanvasController = .init()
    
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var expertManager: ExpertManager
    @EnvironmentObject private var conversationManager: ConversationManager
    @EnvironmentObject private var conversationState: ConversationState
    
    var selectedExpert: Expert? {
        guard let selectedExpertId = conversationState.selectedExpertId else {
            return nil
        }
        return expertManager.getExpert(id: selectedExpertId)
    }

    var selectedConversation: Conversation? {
        guard let selectedConversationId = conversationState.selectedConversationId else {
            return nil
        }
        return self.conversationManager.getConversation(
            id: selectedConversationId
        )
    }
    
    var body: some View {
        NavigationSplitView {
            conversationList
        } detail: {
            conversationView
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle("")
        .toolbar {
            // Left side: Model selector and Experts toggle
            ToolbarItemGroup(placement: .navigation) {
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

            // Right side: Canvas toggle and Share menu
            ToolbarItemGroup(placement: .primaryAction) {
                canvasToggleButton

                MessageShareMenu()
                    .environmentObject(model)
                    .environmentObject(conversationManager)
                    .environmentObject(conversationState)
            }
        }
        .onChange(of: selectedExpert) {
            self.refreshSystemPrompt()
        }
        .onChange(
            of: conversationState.selectedConversationId
        ) {
            // Exit pending mode if selecting an existing conversation
            if conversationState.selectedConversationId != nil {
                conversationState.exitPendingMode()
            }
            withAnimation(.linear) {
                // Use most recently selected expert
                let expertId: UUID? = selectedConversation?.messages.last?.expertId ?? expertManager.default?.id
                self.conversationState.selectedExpertId = expertId
                // Turn off artifacts
                self.conversationState.useCanvas = false
            }
        }
        .onChange(
            of: self.selectedConversation?.messagesWithSnapshots
        ) {
            self.loadLatestSnapshot()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.systemPromptChanged.name
            )
        ) { output in
            self.refreshSystemPrompt()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.changedInferenceConfig.name
            )
        ) { output in
            self.refreshModel()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.requestNewConversation.name
            )
        ) { _ in
            // Enter pending new chat mode (deferred creation)
            self.conversationState.newConversation()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.newConversation.name
            )
        ) { output in
            // Only handle if not in pending mode (legacy path)
            guard !conversationState.isPendingNewChat else { return }
            withAnimation(.linear) {
                self.conversationState.selectedExpertId = expertManager.default?.id
            }
            if let recentConversationId = conversationManager.recentConversation?.id {
                withAnimation(.linear) {
                    self.conversationState.selectedConversationId = recentConversationId
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.switchToConversation.name
            )
        ) { output in
            guard let targetId = output.object as? UUID else {
                return
            }
            withAnimation(.linear) {
                self.conversationState.selectedConversationId = targetId
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notifications.didCommandSelectExpert.name
            )
        ) { output in
            // Update expert if needed
            if self.appearsActive {
                withAnimation(.linear) {
                    self.conversationState.selectedExpertId = self.appState.commandSelectedExpertId
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.willTerminateNotification
            )
        ) { output in
            /// Stop server before app is quit
            Task {
                await self.model.stopServers()
            }
        }
        .environmentObject(model)
        .environmentObject(canvasController)
    }
    
    var conversationList: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            // New Chat button at top
            Button(action: {
                self.conversationState.newConversation()
            }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                    Text("New Chat")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("surface-active-alt"))
                )
                .foregroundColor(Color("text-primary"))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // Search bar placeholder
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField("Search conversations...", text: .constant(""))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .disabled(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 8)

            ConversationNavigationListView()
            Spacer()
            ConversationSidebarButtons()
        }
        .padding(.vertical, 8)
        .background(Color("surface-primary-alt"))
    }
    
    var conversationView: some View {
        Group {
            if conversationState.isPendingNewChat {
                // Pending new chat - show empty conversation view ready for input
                ConversationView()
                    .frame(minWidth: 450, minHeight: 500)
            } else if conversationState.selectedConversationId == nil || selectedConversation == nil {
                noSelectedConversation
            } else {
                HSplitView {
                    ConversationView()
                        .frame(minWidth: 450, minHeight: 500)
                    if self.conversationState.useCanvas {
                        CanvasView()
                            .frame(
                                minWidth: 500,
                                idealWidth: 700,
                                maxWidth: 800
                            )
                    }
                }
            }
        }
        .background(Color("surface-primary"))
    }
    
    var noSelectedConversation: some View {
        HStack {
            Text("Hit")
            Button("Command ⌘ + N") {
                self.conversationState.newConversation()
            }
            Text("to start a conversation.")
        }
    }

    var canToggleCanvas: Bool {
        let hasAssistantMessages = self.selectedConversation?.messages.contains {
            $0.getSender() == .assistant
        } ?? false
        let hasMessages = !(self.selectedConversation?.messages.isEmpty ?? true)
        return hasAssistantMessages && hasMessages
    }

    var canvasToggleButton: some View {
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

    /// Function to load latest snapshot
    private func loadLatestSnapshot() {
        // Get latest message message with snapshot
        guard let selectedConversation = self.selectedConversation else {
            return
        }
        guard let message = selectedConversation.messagesWithSnapshots.last else {
            return
        }
        // Show latest snapshot in canvas
        withAnimation(.linear) {
            self.canvasController.selectedMessageId = message.id
            self.conversationState.useCanvas = true
        }
    }

    private func refreshModel() {
        // Refresh model
        Task {
            await self.model.refreshModel()
        }
    }
    
    private func refreshSystemPrompt() {
        // Set new prompt
        var prompt: String = InferenceSettings.systemPrompt
        if let systemPrompt = self.selectedExpert?.systemPrompt {
            prompt = systemPrompt
        }
        Task {
            await self.model.setSystemPrompt(prompt)
        }
    }

    private func toggleCanvas() {
        withAnimation(.linear) {
            // Select a version if possible
            if let message = self.selectedConversation?.messagesWithSnapshots.last {
                self.canvasController.selectedMessageId = message.id
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
            if !self.canvasController.isExtractingSnapshot {
                Task { @MainActor in
                    try? await self.canvasController.extractSnapshot(
                        selectedConversation: selectedConversation
                    )
                }
            }
        }
    }

}

