//
//  BrainIntegration.swift
//  Sidekick
//
//  Integration layer that connects the unified brain system to the existing inference pipeline
//

import Foundation
import OSLog
import SimilaritySearchKit

/// Integration between the unified brain and existing Sidekick infrastructure
@MainActor
public class BrainIntegration {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: BrainIntegration.self)
    )

    // MARK: - Main Entry Point

    /// Get context for a user message using the unified brain system
    /// This is the main integration point - call this instead of textWithSources when brain mode is enabled
    public static func getContextForMessage(
        query: String,
        useWebSearch: Bool,
        temporaryResources: [TemporaryResource] = []
    ) async -> BrainContextResult {
        let startTime = Date()

        // Step 1: Classify query intent
        let classification = QueryRouter.shared.classify(query: query)
        Self.logger.info("Query classified as \(classification.intent.rawValue) with confidence \(classification.confidence)")

        // Step 2: Get memory context (always, unless explicitly disabled)
        var memoryContext: UnifiedMemory.MemoryContext?
        if RetrievalSettings.useMemory {
            memoryContext = await UnifiedMemory.shared.recall(for: query)
            if let mem = memoryContext, !mem.isEmpty {
                Self.logger.debug("Recalled \(mem.relevantFacts.count) facts, \(mem.similarInteractions.count) episodes")
            }
        }

        // Step 3: Get RAG results based on intent
        var ragResults: [KnowledgeBrain.RetrievalResult] = []
        let strategy = QueryRouter.shared.determineStrategy(for: query)

        if strategy.useRAG {
            ragResults = await KnowledgeBrain.shared.retrieve(
                query: query,
                maxResults: strategy.maxResults
            )
            Self.logger.debug("Retrieved \(ragResults.count) RAG results")
        }

        // Step 4: Web search if enabled and needed
        var webSources: [Source] = []
        if useWebSearch && (classification.intent == .hybrid || classification.intent == .personal) {
            let resultCount = classification.intent == .personal ? 3 : 2
            if let webResults = try? await WebSearch.search(query: query, resultCount: resultCount) {
                webSources = webResults
                Self.logger.debug("Got \(webSources.count) web results")
            }
        }

        // Step 5: Process temporary resources
        let tempSources = temporaryResources.compactMap { $0.source }

        // Step 6: Assemble context with token budgeting
        let systemPrompt = InferenceSettings.systemPrompt
        let assembledContext = ContextAssembler.assemble(
            query: query,
            intent: classification.intent,
            systemPrompt: systemPrompt,
            memoryContext: memoryContext,
            ragResults: ragResults,
            conversationHistory: [],  // Conversation history handled separately
            budget: .standard
        )

        let duration = Date().timeIntervalSince(startTime)
        Self.logger.info("Context assembly completed in \(String(format: "%.2f", duration))s")

        return BrainContextResult(
            intent: classification.intent,
            intentConfidence: classification.confidence,
            memoryContext: memoryContext,
            ragResults: ragResults,
            webSources: webSources,
            temporarySources: tempSources,
            assembledContext: assembledContext,
            processingTime: duration
        )
    }

    /// Format the brain context result as text to append to the user message
    /// This produces output compatible with the existing textWithSources format
    public static func formatContextAsText(_ result: BrainContextResult) -> (text: String, sourceCount: Int) {
        var parts: [String] = []
        var totalSources = 0

        // Add memory context if present
        if let memoryText = result.memoryContext?.formatForPrompt(), !memoryText.isEmpty {
            parts.append(memoryText)
        }

        // Add RAG results
        if !result.ragResults.isEmpty {
            let ragText = formatRAGResultsForPrompt(result.ragResults)
            parts.append(ragText)
            totalSources += result.ragResults.count
        }

        // Add web sources
        if !result.webSources.isEmpty {
            let webText = formatWebSourcesForPrompt(result.webSources)
            parts.append(webText)
            totalSources += result.webSources.count
        }

        // Add temporary sources
        if !result.temporarySources.isEmpty {
            let tempText = formatTempSourcesForPrompt(result.temporarySources)
            parts.append(tempText)
            totalSources += result.temporarySources.count
        }

        if parts.isEmpty {
            return ("", 0)
        }

        let contextText = """
Below is information that may or may not be relevant to my request.

When multiple sources provide correct, but conflicting information, ALWAYS use sources from files, not websites.

If your response uses information from provided sources, your response MUST be directly followed with a single exhaustive LIST OF FILEPATHS AND URLS of ALL referenced sources, in the format [{"url": "/path/to/file.pdf"}, {"url": "https://website.com"}]

If no sources were provided or used, DO NOT mention sources in your response.

\(parts.joined(separator: "\n\n---\n\n"))
"""

        return (contextText, totalSources)
    }

    // MARK: - Formatting Helpers

    private static func formatRAGResultsForPrompt(_ results: [KnowledgeBrain.RetrievalResult]) -> String {
        var text = "## Relevant information from your documents:\n\n"

        for (index, result) in results.enumerated() {
            text += "[\(index + 1)] Source: \(result.source)\n"

            // Add match type indicator
            let matchIndicator: String
            switch result.matchType {
            case .hybrid: matchIndicator = "(keyword + semantic match)"
            case .keyword: matchIndicator = "(keyword match)"
            case .semantic: matchIndicator = "(semantic match)"
            case .graphExpanded: matchIndicator = "(related context)"
            }
            text += "\(matchIndicator)\n"

            // Add entity context if available
            if let entities = result.entityContext, !entities.isEmpty {
                text += "Related entities: \(entities.joined(separator: ", "))\n"
            }

            text += "\(result.text)\n\n"
        }

        return text
    }

    private static func formatWebSourcesForPrompt(_ sources: [Source]) -> String {
        var text = "## Web search results:\n\n"

        for (index, source) in sources.enumerated() {
            text += "[\(index + 1)] URL: \(source.source ?? "Unknown")\n"
            text += "\(source.text)\n\n"
        }

        return text
    }

    private static func formatTempSourcesForPrompt(_ sources: [Source]) -> String {
        var text = "## Attached files:\n\n"

        for (index, source) in sources.enumerated() {
            text += "[\(index + 1)] File: \(source.source ?? "Unknown")\n"
            text += "\(source.text)\n\n"
        }

        return text
    }

    // MARK: - Post-Response Processing

    /// Process the interaction after a response is generated
    /// This updates memory and can be called after each exchange
    public static func processInteraction(
        userQuery: String,
        assistantResponse: String,
        wasHelpful: Bool? = nil
    ) async {
        guard RetrievalSettings.useMemory else { return }

        await UnifiedMemory.shared.processInteraction(
            userQuery: userQuery,
            assistantResponse: assistantResponse,
            wasHelpful: wasHelpful
        )
    }
}

// MARK: - Result Type

public struct BrainContextResult {
    public let intent: QueryRouter.QueryIntent
    public let intentConfidence: Float
    public let memoryContext: UnifiedMemory.MemoryContext?
    public let ragResults: [KnowledgeBrain.RetrievalResult]
    public let webSources: [Source]
    public let temporarySources: [Source]
    public let assembledContext: ContextAssembler.AssembledContext
    public let processingTime: TimeInterval

    /// Whether any context was found
    public var hasContext: Bool {
        return !(memoryContext?.isEmpty ?? true) ||
               !ragResults.isEmpty ||
               !webSources.isEmpty ||
               !temporarySources.isEmpty
    }

    /// Quick summary for logging
    public var summary: String {
        var parts: [String] = []
        parts.append("intent=\(intent.rawValue)")
        if let mem = memoryContext, !mem.isEmpty {
            parts.append("memory=\(mem.relevantFacts.count)f/\(mem.similarInteractions.count)e")
        }
        if !ragResults.isEmpty {
            parts.append("rag=\(ragResults.count)")
        }
        if !webSources.isEmpty {
            parts.append("web=\(webSources.count)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Extension for existing Message

extension Message {
    /// Alternative to textWithSources that uses the unified brain when enabled
    public func textWithBrain(
        useWebSearch: Bool,
        temporaryResources: [TemporaryResource] = []
    ) async -> (text: String, sources: Int) {
        // Only process user messages
        guard self.sender == .user else {
            return (self.text, 0)
        }

        // Check if brain mode is enabled
        guard RetrievalSettings.useUnifiedBrain else {
            // Fall back to original implementation would go here
            // For now, just return the text without sources
            return (self.text, 0)
        }

        // Use brain integration
        let result = await BrainIntegration.getContextForMessage(
            query: self.text,
            useWebSearch: useWebSearch,
            temporaryResources: temporaryResources
        )

        // If no context found, just return the text
        guard result.hasContext else {
            return (self.text, 0)
        }

        // Format and append context
        let (contextText, sourceCount) = BrainIntegration.formatContextAsText(result)

        let fullText = """
\(self.text)

\(contextText)
"""

        return (fullText, sourceCount)
    }
}
