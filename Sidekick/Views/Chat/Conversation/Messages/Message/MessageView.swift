//
//  MessageView.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import AppKit
import MarkdownUI
import Splash
import SwiftUI

struct MessageView: View {
	
    @Environment(\.openWindow) var openWindow
    
	@EnvironmentObject private var model: Model
	@EnvironmentObject private var conversationManager: ConversationManager
	@EnvironmentObject private var conversationState: ConversationState
	@EnvironmentObject private var promptController: PromptController
    @EnvironmentObject private var memories: Memories
    
    @State private var isEditing: Bool = false
	@State private var isShowingSources: Bool = false
	
    var message: Message
    var shimmer: Bool = false
    /// Callback for resubmitting edited user message (text, parentMessageId)
    var onResubmit: ((String, UUID?) -> Void)? = nil
    
    private var isGenerating: Bool {
        return !message.outputEnded && message.getSender() == .assistant
    }
    
    var selectedConversation: Conversation? {
        guard let selectedConversationId = conversationState.selectedConversationId else {
            return nil
        }
        return self.conversationManager.getConversation(
            id: selectedConversationId
        )
    }
    
	var sources: Sources? {
		SourcesManager.shared.getSources(
			id: message.id
		)
	}
	
	var showSources: Bool {
		let hasSources: Bool = !(sources?.sources.isEmpty ?? true)
		return hasSources && self.message.getSender() == .user
	}
    
    var memory: Memory? {
        return memories.getMemories(
            id: message.id
        )
    }
    
    var hasMemories: Bool {
        return (memory != nil)
    }
	
	private var timeDescription: String {
		return message.startTime.formatted(
			date: .abbreviated,
			time: .shortened
		)
	}
	
    var body: some View {
		HStack(
			alignment: .top,
			spacing: 0
		) {
			message.icon
				.padding(.trailing, 10)
			VStack(
				alignment: .leading,
				spacing: 8
			) {
				controls
				content
			}
		}
		.padding(.trailing)
		.sheet(isPresented: $isShowingSources) {
			SourcesView(
				isShowingSources: $isShowingSources,
				sources: self.sources!
			)
			.frame(minWidth: 600, minHeight: 650, maxHeight: 700)
		}
    }
    
    var controls: some View {
        HStack {
            Text(timeDescription)
                .foregroundStyle(.secondary)
            SiblingNavigatorView(message: message)
            if showSources {
                sourcesButton
            }
            MessageCopyButton(
                message: message
            )
            if message.getSender() == .assistant {
                MessageReadAloudButton(
                    message: message
                )
                if !self.isGenerating {
                    RegenerateButton {
                        self.retryGeneration(
                            message: message
                        )
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                }
            }
            MessageOptionsView(
                isEditing: $isEditing,
                message: message,
                canEdit: !self.isGenerating
            )
            if self.isGenerating {
                stopButton
            }
            if hasMemories, let memory {
                Spacer()
                // Show memory updated
                PopoverButton(
                    arrowEdge: .bottom
                ) {
                    Label("Memory updated", systemImage: "pencil.and.list.clipboard")
                        .foregroundStyle(.secondary)
                } content: {
                    VStack {
                        Text(memory.text)
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button {
                                self.memories.forget(memory)
                            } label: {
                                Text("Forget")
                                    .foregroundStyle(.red)
                            }
                            Button {
                                self.openWindow(id: "memory")
                            } label: {
                                Text("Manage Memories")
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: 400, maxHeight: 80)
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
            }
        }
    }
	
	var content: some View {
		Group {
			// Check for blank message or function calls
			if message.text.isEmpty && message.imageUrl == nil && message
                .getSender() == .assistant && !model.status.isWorking {
				RegenerateButton {
					self.retryGeneration(
                        message: message
                    )
				}
                .labelStyle(.titleAndIcon)
				.padding(11)
			} else {
                MessageContentView(
                    message: self.message,
                    isEditing: self.$isEditing,
                    shimmer: self.shimmer,
                    onResubmit: self.onResubmit
                )
			}
		}
		.background {
			MessageBackgroundView()
				.contextMenu {
					copyButton
				}
		}
	}
	
	var sourcesButton: some View {
		SourcesButton(showSources: $isShowingSources)
			.menuStyle(.circle)
			.foregroundStyle(.secondary)
			.disabled(!showSources)
			.padding(0)
			.padding(.vertical, 2)
	}
	
	var stopButton: some View {
		StopGenerationButton {
			self.stopGeneration()
		}
		.disabled(!isGenerating)
		.padding(0)
		.padding(.vertical, 2)
	}
	
	var copyButton: some View {
		Button {
			self.message.text.copyWithFormatting()
		} label: {
			Text("Copy to Clipboard")
		}
	}
	
	/// Function to stop generation
	private func stopGeneration() {
		Task.detached { @MainActor in
			await self.model.interrupt()
			self.retryGeneration(
                message: message
            )
		}
	}
	
	private func retryGeneration(
        message: Message
    ) {
		// Get conversation
        guard var conversation = self.selectedConversation else { return }
		// Get drop count
        var count: Int = 0
        if let messageIndex = conversation.messages.firstIndex(where: { currMessage in
            currMessage.id == message.id
        }) {
            count = conversation.messages.count - (messageIndex - 1)
        } else {
            // If index not found, is pending message
            count = 1
        }
        // Check for safety
        count = max(min(count, conversation.messages.count), 0)
        // Set prompt
        let prevMessage: Message? = conversation.messages.previousElement(
            of: message
        ) ?? conversation.messages.last
        self.promptController.prompt = prevMessage?.text ?? ""
        // Set resources
        let urls: [URL] = prevMessage?.referencedURLs.map(
            keyPath: \.url
        ) ?? []
        self.promptController.tempResources += urls.map { url in
            return TemporaryResource(url: url)
        }
        // Delete messages
        conversation.messages = conversation.messages.dropLast(count)
		conversationManager.update(conversation)
	}

}

/// A view that allows navigation between sibling messages at a branch point
struct SiblingNavigatorView: View {

    @EnvironmentObject private var conversationManager: ConversationManager
    @EnvironmentObject private var conversationState: ConversationState

    var message: Message

    private var selectedConversation: Conversation? {
        guard let selectedConversationId = conversationState.selectedConversationId else {
            return nil
        }
        return self.conversationManager.getConversation(
            id: selectedConversationId
        )
    }

    /// Get sibling count for this message's parent
    private var siblingCount: Int {
        guard let conversation = selectedConversation else { return 1 }
        return conversation.getSiblingCount(forParentId: message.parentMessageId)
    }

    /// Get current sibling index (1-based for display)
    private var currentIndex: Int {
        guard let conversation = selectedConversation else { return 1 }
        let activeIndex = conversation.getActiveSiblingIndex(forParentId: message.parentMessageId)
        return activeIndex + 1
    }

    /// Whether there are multiple siblings to navigate
    private var hasMultipleSiblings: Bool {
        return siblingCount > 1
    }

    /// Whether we can go to previous sibling
    private var canGoPrevious: Bool {
        return currentIndex > 1
    }

    /// Whether we can go to next sibling
    private var canGoNext: Bool {
        return currentIndex < siblingCount
    }

    /// Whether the message is still being generated (pending message has nil parentMessageId)
    private var isGenerating: Bool {
        return message.getSender() == .assistant && !message.outputEnded
    }

    var body: some View {
        // Don't show navigator for generating messages (parentMessageId is nil/incorrect)
        if hasMultipleSiblings && !isGenerating {
            HStack(spacing: 2) {
                Button {
                    self.goToPreviousSibling()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canGoPrevious)
                .opacity(canGoPrevious ? 1.0 : 0.3)

                Text("\(currentIndex)/\(siblingCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Button {
                    self.goToNextSibling()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!canGoNext)
                .opacity(canGoNext ? 1.0 : 0.3)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func goToPreviousSibling() {
        guard var conversation = selectedConversation else { return }
        let newIndex = max(0, currentIndex - 2) // Convert to 0-based and go back
        conversation.setActiveSibling(parentId: message.parentMessageId, index: newIndex)
        conversationManager.update(conversation)
    }

    private func goToNextSibling() {
        guard var conversation = selectedConversation else { return }
        let newIndex = currentIndex // currentIndex is 1-based, so this gives next 0-based index
        conversation.setActiveSibling(parentId: message.parentMessageId, index: newIndex)
        conversationManager.update(conversation)
    }

}
