//
//  ContextAssembler.swift
//  Sidekick
//
//  Smart context assembly with token budgeting to prevent RAG from overwhelming the LLM
//

import Foundation
import OSLog

/// Assembles context for LLM prompts with intelligent token budgeting
public class ContextAssembler {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: ContextAssembler.self)
    )

    // MARK: - Types

    /// Token budget allocation
    public struct ContextBudget {
        public let totalTokens: Int
        public let systemPromptBudget: Int
        public let memoryBudget: Int
        public let ragBudget: Int
        public let conversationBudget: Int
        public let responseBudget: Int

        /// Create a budget for a given context window size
        public static func forContextSize(_ size: Int) -> ContextBudget {
            return ContextBudget(
                totalTokens: size,
                systemPromptBudget: min(1000, size / 8),    // 12.5%
                memoryBudget: min(500, size / 16),          // 6.25%
                ragBudget: min(4000, size / 4),             // 25%
                conversationBudget: min(2000, size / 4),    // 25%
                responseBudget: min(2000, size / 4)         // 25%
            )
        }

        /// Default budget for 8K context
        public static let standard = forContextSize(8192)

        /// Large budget for 32K+ context
        public static let large = forContextSize(32768)
    }

    /// Assembled context ready for LLM
    public struct AssembledContext {
        public var systemPrompt: String
        public var memoryContext: String?
        public var ragContext: String?
        public var conversationHistory: [ConversationTurn]
        public var estimatedTokens: Int

        public struct ConversationTurn {
            public let role: String  // "user" or "assistant"
            public let content: String
        }

        /// Check if we're within budget
        public func isWithinBudget(_ budget: ContextBudget) -> Bool {
            return estimatedTokens <= budget.totalTokens - budget.responseBudget
        }
    }

    // MARK: - Assembly

    /// Assemble context based on query intent and available information
    public static func assemble(
        query: String,
        intent: QueryRouter.QueryIntent,
        systemPrompt: String,
        memoryContext: UnifiedMemory.MemoryContext?,
        ragResults: [KnowledgeBrain.RetrievalResult],
        conversationHistory: [Message],
        budget: ContextBudget = .standard
    ) -> AssembledContext {
        var context = AssembledContext(
            systemPrompt: systemPrompt,
            memoryContext: nil,
            ragContext: nil,
            conversationHistory: [],
            estimatedTokens: 0
        )

        var usedTokens = estimateTokens(systemPrompt)

        // 1. Add memory context (high priority for personal assistant)
        if let memory = memoryContext, !memory.isEmpty {
            if let formatted = memory.formatForPrompt() {
                let memoryTokens = estimateTokens(formatted)
                if memoryTokens <= budget.memoryBudget {
                    context.memoryContext = formatted
                    usedTokens += memoryTokens
                } else {
                    // Truncate memory to fit budget
                    context.memoryContext = truncateToTokens(formatted, maxTokens: budget.memoryBudget)
                    usedTokens += budget.memoryBudget
                }
            }
        }

        // 2. Add RAG context (conditional on intent)
        let ragBudgetForIntent: Int
        switch intent {
        case .personal:
            ragBudgetForIntent = budget.ragBudget
        case .hybrid:
            ragBudgetForIntent = budget.ragBudget / 2
        case .memory, .general:
            ragBudgetForIntent = 0
        }

        if ragBudgetForIntent > 0 && !ragResults.isEmpty {
            let formatted = formatRAGResults(ragResults, maxTokens: ragBudgetForIntent)
            context.ragContext = formatted
            usedTokens += estimateTokens(formatted)
        }

        // 3. Add conversation history (most recent first, up to budget)
        let conversationTokenBudget = budget.conversationBudget
        var conversationTokens = 0
        var includedTurns: [AssembledContext.ConversationTurn] = []

        for message in conversationHistory.reversed() {
            let role = message.sender == .user ? "user" : "assistant"
            let content = message.text
            let turnTokens = estimateTokens(content) + 10  // +10 for role overhead

            if conversationTokens + turnTokens > conversationTokenBudget {
                break
            }

            includedTurns.insert(
                AssembledContext.ConversationTurn(role: role, content: content),
                at: 0
            )
            conversationTokens += turnTokens
        }

        context.conversationHistory = includedTurns
        usedTokens += conversationTokens

        context.estimatedTokens = usedTokens

        Self.logger.debug("""
            Assembled context: \(usedTokens) tokens
            - Memory: \(context.memoryContext != nil ? "yes" : "no")
            - RAG: \(ragResults.count) results
            - History: \(includedTurns.count) turns
            """)

        return context
    }

    // MARK: - Formatting

    /// Format RAG results for inclusion in prompt
    public static func formatRAGResults(
        _ results: [KnowledgeBrain.RetrievalResult],
        maxTokens: Int
    ) -> String {
        guard !results.isEmpty else { return "" }

        var formatted = "## Relevant information from your documents:\n\n"
        var currentTokens = estimateTokens(formatted)

        for (index, result) in results.enumerated() {
            let entry: String
            if let entities = result.entityContext, !entities.isEmpty {
                entry = """
                [\(index + 1)] Source: \(result.source)
                Related entities: \(entities.joined(separator: ", "))
                \(result.text)

                """
            } else {
                entry = """
                [\(index + 1)] Source: \(result.source)
                \(result.text)

                """
            }

            let entryTokens = estimateTokens(entry)
            if currentTokens + entryTokens > maxTokens {
                // Add truncation notice if we're cutting off
                if index < results.count - 1 {
                    formatted += "\n[... \(results.count - index) more results truncated for brevity]"
                }
                break
            }

            formatted += entry
            currentTokens += entryTokens
        }

        return formatted
    }

    /// Format assembled context as a prompt
    public static func buildPrompt(from context: AssembledContext) -> String {
        var parts: [String] = []

        // Add memory if present
        if let memory = context.memoryContext {
            parts.append(memory)
        }

        // Add RAG context if present
        if let rag = context.ragContext {
            parts.append(rag)
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Token Estimation

    /// Estimate token count (rough approximation: 4 chars per token)
    public static func estimateTokens(_ text: String) -> Int {
        return max(1, text.count / 4)
    }

    /// Truncate text to fit within token budget
    public static func truncateToTokens(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars {
            return text
        }

        // Try to truncate at sentence boundary
        let truncated = String(text.prefix(maxChars))
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[...lastPeriod]) + "\n[truncated]"
        }

        return truncated + "... [truncated]"
    }

    // MARK: - Context Optimization

    /// Optimize context by removing low-value content when over budget
    public static func optimize(
        context: inout AssembledContext,
        budget: ContextBudget
    ) {
        let targetTokens = budget.totalTokens - budget.responseBudget

        while context.estimatedTokens > targetTokens {
            // Priority order for removal: oldest conversation turns, RAG results, memory
            if context.conversationHistory.count > 2 {
                // Remove oldest turn (but keep at least 2 for context)
                context.conversationHistory.removeFirst()
                context.estimatedTokens = recalculateTokens(context)
                continue
            }

            if let rag = context.ragContext, estimateTokens(rag) > 500 {
                // Truncate RAG context
                context.ragContext = truncateToTokens(rag, maxTokens: estimateTokens(rag) / 2)
                context.estimatedTokens = recalculateTokens(context)
                continue
            }

            if let memory = context.memoryContext, estimateTokens(memory) > 200 {
                // Truncate memory
                context.memoryContext = truncateToTokens(memory, maxTokens: estimateTokens(memory) / 2)
                context.estimatedTokens = recalculateTokens(context)
                continue
            }

            // Can't reduce further
            break
        }
    }

    private static func recalculateTokens(_ context: AssembledContext) -> Int {
        var total = estimateTokens(context.systemPrompt)

        if let memory = context.memoryContext {
            total += estimateTokens(memory)
        }

        if let rag = context.ragContext {
            total += estimateTokens(rag)
        }

        for turn in context.conversationHistory {
            total += estimateTokens(turn.content) + 10
        }

        return total
    }
}
