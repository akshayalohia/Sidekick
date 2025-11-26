//
//  Conversation.swift
//  Sidekick
//
//  Created by Bean John on 10/4/24.
//

import Foundation

public struct Conversation: Identifiable, Codable, Hashable {
	
	/// Stored property for `Identifiable` conformance
	public var id: UUID = UUID()
	
	/// Stored property for conversation title
	public var title: String
	
	/// Stored property for the selected expert's ID
	public var expertId: UUID? = ExpertManager.shared.firstExpert?.id
	
	/// Computed property returning the selected expert
	public var expert: Expert? {
		guard let expertId else { return nil }
		return ExpertManager.shared.getExpert(id: expertId)
	}
	
	/// Computed property returning the system prompt used
	public var systemPrompt: String? {
		return expert?.systemPrompt
	}
	
	/// Stored property for creation date
	public var createdAt: Date = .now
	
	/// Stored property for messages
	public var messages: [Message] = []

	/// Track which sibling is active at each branch point
	/// Key: parent message ID as string (or "root" for top-level), Value: active sibling index
	public var activeSiblingIndices: [String: Int] = [:]

	/// An array of messages with snapshots
	public var messagesWithSnapshots: [Message] {
		return self.messages.filter { message in
			return message.snapshot != nil
		}
	}

	// MARK: - Tree Structure Methods

	/// Get sibling messages for a given parent ID
	public func getSiblings(forParentId parentId: UUID?) -> [Message] {
		return self.messages.filter { $0.parentMessageId == parentId }
			.sorted { $0.siblingIndex < $1.siblingIndex }
	}

	/// Get the count of siblings for a given parent ID
	public func getSiblingCount(forParentId parentId: UUID?) -> Int {
		return getSiblings(forParentId: parentId).count
	}

	/// Get the key for activeSiblingIndices dictionary
	private func siblingKey(for parentId: UUID?) -> String {
		return parentId?.uuidString ?? "root"
	}

	/// Get the active sibling index for a parent ID
	public func getActiveSiblingIndex(forParentId parentId: UUID?) -> Int {
		return activeSiblingIndices[siblingKey(for: parentId)] ?? 0
	}

	/// Set the active sibling at a branch point
	public mutating func setActiveSibling(parentId: UUID?, index: Int) {
		let key = siblingKey(for: parentId)
		let siblings = getSiblings(forParentId: parentId)
		// Clamp index to valid range
		let clampedIndex = max(0, min(index, siblings.count - 1))
		activeSiblingIndices[key] = clampedIndex
	}

	/// Get the currently active message path for rendering
	public func getActiveMessagePath() -> [Message] {
		var path: [Message] = []
		var currentParentId: UUID? = nil

		while true {
			let siblings = getSiblings(forParentId: currentParentId)
			guard !siblings.isEmpty else { break }

			let activeIndex = getActiveSiblingIndex(forParentId: currentParentId)
			let clampedIndex = min(activeIndex, siblings.count - 1)

			guard clampedIndex >= 0 && clampedIndex < siblings.count else { break }

			let activeMessage = siblings[clampedIndex]
			path.append(activeMessage)
			currentParentId = activeMessage.id
		}

		return path
	}

	/// Add a message as a sibling, returns the sibling index
	@discardableResult
	public mutating func addMessageAsSibling(_ message: inout Message, parentId: UUID?) -> Int {
		let existingSiblings = getSiblings(forParentId: parentId)
		let siblingIndex = existingSiblings.count
		message.parentMessageId = parentId
		message.siblingIndex = siblingIndex
		self.messages.append(message)
		// Set this as the active sibling
		setActiveSibling(parentId: parentId, index: siblingIndex)
		return siblingIndex
	}
	
	/// A `Bool` representing whether the conversation contains snapshots
	public var hasSnapshots: Bool {
		return !self.messagesWithSnapshots.isEmpty
	}
	
	/// Computed property for most recent update
	public var lastUpdated: Date {
		if let lastUpdate: Date = self.messages.map({
			$0.lastUpdated
		}).max() {
			return lastUpdate
		} else {
			return self.createdAt
		}
	}
	
	/// The length of the conversation in tokens, of type `Int`
	public var tokenCount: Int?
	
	/// Function to add a new message, returns `true` if successful
	public mutating func addMessage(_ message: Message) -> Bool {
		// Get the active path to find the last message
		let activePath = getActiveMessagePath()
		let lastMessage = activePath.last

		// Check if different sender (based on active path)
		let lastSender: Sender? = lastMessage?.getSender()
		if lastSender != nil {
			let differentSender: Bool = lastSender != message.getSender()
			if !differentSender {
				return false
			}
		}
		// Check if blank if user
		if message.text.isEmpty && message.getSender() == .user {
			return false
		}
		// Create message with parent ID set
		var newMessage = message
		newMessage.parentMessageId = lastMessage?.id
		// Calculate sibling index
		let siblings = getSiblings(forParentId: newMessage.parentMessageId)
		newMessage.siblingIndex = siblings.count
		// Add message
		self.messages.append(newMessage)
		// Set this as active sibling
		setActiveSibling(parentId: newMessage.parentMessageId, index: newMessage.siblingIndex)
		// Set title if needed
		if activePath.isEmpty {
			self.title = message.text
		}
		return true
	}
	
	/// Function to update an existing message
	public mutating func updateMessage(_ message: Message) {
		for index in self.messages.indices {
			if self.messages[index].id == message.id {
				self.messages[index] = message
				return
			}
		}
	}
	
	/// Function to get a message with an ID
	public func getMessage(
		_ id: UUID
	) -> Message? {
		return self.messages.filter({ $0.id == id }).first
	}
	
	/// Function to drop last message
	public mutating func dropLastMessage() {
		self.messages.removeLast()
	}
	
	/// Static function for equatable conformance
	public static func == (lhs: Conversation, rhs: Conversation) -> Bool {
		return lhs.id == rhs.id
	}
	
}
