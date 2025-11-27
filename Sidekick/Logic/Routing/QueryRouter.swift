//
//  QueryRouter.swift
//  Sidekick
//
//  Created for unified brain RAG system
//

import Foundation
import OSLog
import SimilaritySearchKit
import SimilaritySearchKitDistilbert

/// Determines whether a query needs personal context (RAG), memory, or can be answered by the LLM alone
@MainActor
public class QueryRouter: ObservableObject {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: QueryRouter.self)
    )

    /// Singleton instance
    public static let shared = QueryRouter()

    /// Query intent classification
    public enum QueryIntent: String, Codable, CaseIterable {
        case personal       // Needs full RAG - "What did John email me about?"
        case memory         // Needs memory recall - "What's my favorite restaurant?"
        case general        // Pure LLM, no retrieval - "Explain quantum computing"
        case hybrid         // Light RAG + creativity - "Help me write an email to my boss"
    }

    /// Result of query classification
    public struct ClassificationResult {
        public let intent: QueryIntent
        public let confidence: Float
        public let reasoning: String
    }

    // MARK: - Keyword Signals

    /// Keywords that strongly indicate personal/RAG queries
    private let personalSignals: Set<String> = [
        "my", "i", "me", "mine", "our", "we",
        "email", "emails", "meeting", "meetings", "notes", "note",
        "calendar", "document", "documents", "file", "files",
        "yesterday", "last week", "last month", "told me", "said to me",
        "sent me", "wrote", "scheduled", "appointment",
        "project", "task", "todo", "reminder"
    ]

    /// Keywords that indicate memory/preference queries
    private let memorySignals: Set<String> = [
        "favorite", "favourite", "prefer", "preference", "like", "dislike",
        "usually", "always", "never", "habit", "routine",
        "remember when", "recall", "last time i"
    ]

    /// Keywords that indicate general knowledge queries
    private let generalSignals: Set<String> = [
        "explain", "define", "what is", "who is", "how does",
        "in general", "typically", "generally speaking",
        "history of", "science", "math", "calculate",
        "code", "programming", "algorithm", "function"
    ]

    /// Keywords that indicate hybrid (creative + context) queries
    private let hybridSignals: Set<String> = [
        "help me write", "draft", "compose", "prepare",
        "suggest", "recommend", "advice", "should i",
        "how should i", "what should i say"
    ]

    // MARK: - Classification

    /// Classify a query to determine the appropriate retrieval strategy
    public func classify(query: String) -> ClassificationResult {
        let lowercased = query.lowercased()
        let words = Set(lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })

        // Count signal matches
        let personalCount = words.intersection(personalSignals).count + countPhraseMatches(lowercased, phrases: ["told me", "sent me", "last week", "last month"])
        let memoryCount = words.intersection(memorySignals).count + countPhraseMatches(lowercased, phrases: ["remember when", "last time i"])
        let generalCount = words.intersection(generalSignals).count + countPhraseMatches(lowercased, phrases: ["what is", "who is", "how does", "in general"])
        let hybridCount = words.intersection(hybridSignals).count + countPhraseMatches(lowercased, phrases: ["help me write", "should i", "what should i"])

        // Determine intent based on strongest signal
        let scores: [(QueryIntent, Int)] = [
            (.personal, personalCount),
            (.memory, memoryCount),
            (.general, generalCount),
            (.hybrid, hybridCount)
        ]

        let maxScore = scores.max(by: { $0.1 < $1.1 })!
        let totalSignals = max(personalCount + memoryCount + generalCount + hybridCount, 1)

        // Calculate confidence
        let confidence: Float
        let intent: QueryIntent
        let reasoning: String

        if maxScore.1 == 0 {
            // No clear signals - default to hybrid (safe choice)
            intent = .hybrid
            confidence = 0.5
            reasoning = "No clear signals detected, using hybrid approach"
        } else if maxScore.1 >= 2 {
            // Strong signal
            intent = maxScore.0
            confidence = min(Float(maxScore.1) / Float(totalSignals) + 0.3, 0.95)
            reasoning = "Strong \(intent.rawValue) signals detected (\(maxScore.1) matches)"
        } else {
            // Weak signal
            intent = maxScore.0
            confidence = Float(maxScore.1) / Float(totalSignals) + 0.2
            reasoning = "Weak \(intent.rawValue) signal detected"
        }

        Self.logger.debug("Query classified as \(intent.rawValue) with confidence \(confidence): \(reasoning)")

        return ClassificationResult(
            intent: intent,
            confidence: confidence,
            reasoning: reasoning
        )
    }

    /// Count phrase matches in text
    private func countPhraseMatches(_ text: String, phrases: [String]) -> Int {
        return phrases.filter { text.contains($0) }.count
    }

    // MARK: - Retrieval Decision

    /// Determine the retrieval strategy based on classification
    public func determineStrategy(for query: String) -> RetrievalStrategy {
        let classification = classify(query: query)

        switch classification.intent {
        case .personal:
            return RetrievalStrategy(
                useRAG: true,
                useMemory: true,
                ragDepth: .full,
                maxResults: 10
            )

        case .memory:
            return RetrievalStrategy(
                useRAG: false,
                useMemory: true,
                ragDepth: .none,
                maxResults: 0
            )

        case .general:
            return RetrievalStrategy(
                useRAG: false,
                useMemory: false,
                ragDepth: .none,
                maxResults: 0
            )

        case .hybrid:
            return RetrievalStrategy(
                useRAG: true,
                useMemory: true,
                ragDepth: .light,
                maxResults: 3
            )
        }
    }
}

// MARK: - Retrieval Strategy

public struct RetrievalStrategy {
    public let useRAG: Bool
    public let useMemory: Bool
    public let ragDepth: RAGDepth
    public let maxResults: Int

    public enum RAGDepth {
        case none       // No document retrieval
        case light      // Top 3 results only
        case full       // Full retrieval with graph enhancement
    }
}
