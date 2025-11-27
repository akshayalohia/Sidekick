//
//  UnifiedMemory.swift
//  Sidekick
//
//  Three-tier memory system: Semantic (facts), Episodic (interactions), Procedural (behaviors)
//

import Foundation
import OSLog
import SimilaritySearchKit
import SimilaritySearchKitDistilbert

/// Unified memory system with semantic, episodic, and procedural memory
@MainActor
public class UnifiedMemory: ObservableObject {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: UnifiedMemory.self)
    )

    /// Singleton instance
    public static let shared = UnifiedMemory()

    // MARK: - Memory Types

    /// Semantic memory - facts about the user
    public struct SemanticMemory: Codable, Identifiable, Equatable {
        public let id: UUID
        public let fact: String              // "The user prefers dark mode"
        public let category: FactCategory
        public var confidence: Float         // 0-1, how certain we are
        public let createdAt: Date
        public var lastAccessed: Date
        public var accessCount: Int
        public var embedding: [Float]?

        public enum FactCategory: String, Codable, CaseIterable {
            case preference = "preference"       // Likes/dislikes
            case personalInfo = "personal_info"  // Name, job, location
            case relationship = "relationship"   // People they know
            case opinion = "opinion"             // Views on topics
            case behavior = "behavior"           // How they work
        }

        public init(
            fact: String,
            category: FactCategory,
            confidence: Float = 0.8,
            embedding: [Float]? = nil
        ) {
            self.id = UUID()
            self.fact = fact
            self.category = category
            self.confidence = confidence
            self.createdAt = Date()
            self.lastAccessed = Date()
            self.accessCount = 0
            self.embedding = embedding
        }
    }

    /// Episodic memory - past successful interactions
    public struct EpisodicMemory: Codable, Identifiable {
        public let id: UUID
        public let userQuery: String
        public let assistantResponseSummary: String
        public var wasHelpful: Bool?          // User feedback
        public let context: String            // What was happening
        public let timestamp: Date
        public var embedding: [Float]?

        public init(
            userQuery: String,
            responseSummary: String,
            context: String,
            wasHelpful: Bool? = nil,
            embedding: [Float]? = nil
        ) {
            self.id = UUID()
            self.userQuery = userQuery
            self.assistantResponseSummary = responseSummary
            self.context = context
            self.wasHelpful = wasHelpful
            self.timestamp = Date()
            self.embedding = embedding
        }
    }

    /// Procedural memory - learned behaviors and patterns
    public struct ProceduralMemory: Codable, Identifiable {
        public let id: UUID
        public let trigger: String            // Pattern that triggers this
        public let behavior: String           // What to do
        public var examples: [String]         // Past examples
        public var successRate: Float         // How often it works
        public let createdAt: Date

        public init(
            trigger: String,
            behavior: String,
            examples: [String] = [],
            successRate: Float = 0.8
        ) {
            self.id = UUID()
            self.trigger = trigger
            self.behavior = behavior
            self.examples = examples
            self.successRate = successRate
            self.createdAt = Date()
        }
    }

    // MARK: - Properties

    @Published public private(set) var semanticMemories: [SemanticMemory] = []
    @Published public private(set) var episodicMemories: [EpisodicMemory] = []
    @Published public private(set) var proceduralMemories: [ProceduralMemory] = []
    @Published public private(set) var isLoaded: Bool = false

    private var similarityIndex: SimilarityIndex?

    // MARK: - Storage URLs

    private static var memoryDirUrl: URL {
        Settings.containerUrl.appendingPathComponent("UnifiedMemory")
    }

    private static var semanticUrl: URL {
        memoryDirUrl.appendingPathComponent("semantic.json")
    }

    private static var episodicUrl: URL {
        memoryDirUrl.appendingPathComponent("episodic.json")
    }

    private static var proceduralUrl: URL {
        memoryDirUrl.appendingPathComponent("procedural.json")
    }

    // MARK: - Initialization

    private init() {
        Task {
            await load()
        }
    }

    /// Load all memories from disk
    public func load() async {
        createDirectoryIfNeeded()

        // Initialize similarity index
        similarityIndex = await SimilarityIndex(
            model: DistilbertEmbeddings(),
            metric: CosineSimilarity()
        )

        // Load semantic memories
        if let data = try? Data(contentsOf: Self.semanticUrl),
           let decoded = try? JSONDecoder().decode([SemanticMemory].self, from: data) {
            semanticMemories = decoded
            Self.logger.info("Loaded \(decoded.count) semantic memories")
        }

        // Load episodic memories
        if let data = try? Data(contentsOf: Self.episodicUrl),
           let decoded = try? JSONDecoder().decode([EpisodicMemory].self, from: data) {
            episodicMemories = decoded
            Self.logger.info("Loaded \(decoded.count) episodic memories")
        }

        // Load procedural memories
        if let data = try? Data(contentsOf: Self.proceduralUrl),
           let decoded = try? JSONDecoder().decode([ProceduralMemory].self, from: data) {
            proceduralMemories = decoded
            Self.logger.info("Loaded \(decoded.count) procedural memories")
        }

        isLoaded = true
    }

    private func createDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: Self.memoryDirUrl.path) {
            try? FileManager.default.createDirectory(
                at: Self.memoryDirUrl,
                withIntermediateDirectories: true
            )
        }
    }

    /// Save all memories to disk
    public func save() {
        do {
            try JSONEncoder().encode(semanticMemories).write(to: Self.semanticUrl, options: .atomic)
            try JSONEncoder().encode(episodicMemories).write(to: Self.episodicUrl, options: .atomic)
            try JSONEncoder().encode(proceduralMemories).write(to: Self.proceduralUrl, options: .atomic)
        } catch {
            Self.logger.error("Failed to save memories: \(error.localizedDescription)")
        }
    }

    // MARK: - Memory Recall

    /// Recall context for a query
    public struct MemoryContext {
        public let relevantFacts: [SemanticMemory]
        public let similarInteractions: [EpisodicMemory]
        public let applicableBehaviors: [ProceduralMemory]

        public var isEmpty: Bool {
            relevantFacts.isEmpty && similarInteractions.isEmpty && applicableBehaviors.isEmpty
        }

        /// Format memories for inclusion in prompt
        public func formatForPrompt() -> String? {
            guard !isEmpty else { return nil }

            var parts: [String] = []

            if !relevantFacts.isEmpty {
                parts.append("## Known facts about the user:")
                parts.append(relevantFacts.map { "- \($0.fact)" }.joined(separator: "\n"))
            }

            if !similarInteractions.isEmpty {
                parts.append("\n## Similar past interactions:")
                for interaction in similarInteractions.prefix(3) {
                    let helpful = interaction.wasHelpful == true ? "(worked well)" : ""
                    parts.append("- User asked: \"\(interaction.userQuery.prefix(80))...\" \(helpful)")
                }
            }

            if !applicableBehaviors.isEmpty {
                parts.append("\n## User preferences for this type of request:")
                parts.append(applicableBehaviors.map { "- \($0.behavior)" }.joined(separator: "\n"))
            }

            return parts.joined(separator: "\n")
        }
    }

    /// Recall memories relevant to a query
    public func recall(for query: String, maxFacts: Int = 5, maxEpisodes: Int = 3) async -> MemoryContext {
        guard isLoaded else {
            return MemoryContext(relevantFacts: [], similarInteractions: [], applicableBehaviors: [])
        }

        let queryEmbedding = await generateEmbedding(for: query)

        // Recall semantic memories
        let relevantFacts = await recallSemantic(queryEmbedding: queryEmbedding, maxResults: maxFacts)

        // Recall episodic memories
        let similarInteractions = await recallEpisodic(queryEmbedding: queryEmbedding, maxResults: maxEpisodes)

        // Recall procedural memories
        let applicableBehaviors = recallProcedural(query: query)

        // Update access times for recalled memories
        for fact in relevantFacts {
            if let index = semanticMemories.firstIndex(where: { $0.id == fact.id }) {
                semanticMemories[index].lastAccessed = Date()
                semanticMemories[index].accessCount += 1
            }
        }

        return MemoryContext(
            relevantFacts: relevantFacts,
            similarInteractions: similarInteractions,
            applicableBehaviors: applicableBehaviors
        )
    }

    private func recallSemantic(queryEmbedding: [Float]?, maxResults: Int) async -> [SemanticMemory] {
        guard let queryEmb = queryEmbedding else { return [] }

        // Score memories by similarity with recency boost
        var scored: [(memory: SemanticMemory, score: Float)] = []

        for memory in semanticMemories {
            guard let memEmb = memory.embedding else { continue }

            // Base similarity
            var score = cosineSimilarity(queryEmb, memEmb)

            // Recency decay (30-day half-life)
            let daysSinceAccess = Date().timeIntervalSince(memory.lastAccessed) / 86400
            let recencyBoost = Float(exp(-daysSinceAccess / 30))
            score *= (0.7 + 0.3 * recencyBoost)

            // Confidence weight
            score *= memory.confidence

            scored.append((memory, score))
        }

        return scored
            .filter { $0.score > 0.5 }
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map { $0.memory }
    }

    private func recallEpisodic(queryEmbedding: [Float]?, maxResults: Int) async -> [EpisodicMemory] {
        guard let queryEmb = queryEmbedding else { return [] }

        var scored: [(memory: EpisodicMemory, score: Float)] = []

        for memory in episodicMemories {
            guard let memEmb = memory.embedding else { continue }

            var score = cosineSimilarity(queryEmb, memEmb)

            // Boost helpful interactions
            if memory.wasHelpful == true {
                score *= 1.2
            }

            scored.append((memory, score))
        }

        return scored
            .filter { $0.score > 0.6 }
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map { $0.memory }
    }

    private func recallProcedural(query: String) -> [ProceduralMemory] {
        let lowercased = query.lowercased()

        // Simple keyword matching for procedural triggers
        return proceduralMemories.filter { memory in
            lowercased.contains(memory.trigger.lowercased()) ||
            memory.trigger.lowercased().split(separator: " ").contains { lowercased.contains($0) }
        }.sorted { $0.successRate > $1.successRate }
    }

    // MARK: - Memory Formation

    /// Process an interaction and potentially create memories
    public func processInteraction(
        userQuery: String,
        assistantResponse: String,
        wasHelpful: Bool? = nil
    ) async {
        guard RetrievalSettings.useMemory else { return }

        // Extract semantic memories from user message
        await extractSemanticMemories(from: userQuery)

        // Store as episodic memory (summarized)
        await storeEpisodicMemory(
            query: userQuery,
            response: assistantResponse,
            helpful: wasHelpful
        )

        save()
    }

    /// Extract facts from user message
    private func extractSemanticMemories(from text: String) async {
        // Simple heuristic extraction (can be replaced with LLM extraction)
        let patterns: [(pattern: String, category: SemanticMemory.FactCategory)] = [
            ("i prefer", .preference),
            ("i like", .preference),
            ("i don't like", .preference),
            ("my favorite", .preference),
            ("i work at", .personalInfo),
            ("i am a", .personalInfo),
            ("i live in", .personalInfo),
            ("i think", .opinion),
            ("i believe", .opinion),
            ("i usually", .behavior),
            ("i always", .behavior)
        ]

        let lowercased = text.lowercased()

        for (pattern, category) in patterns {
            if lowercased.contains(pattern) {
                // Extract the relevant sentence
                let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                for sentence in sentences {
                    if sentence.lowercased().contains(pattern) {
                        let fact = "The user " + sentence.trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "^[Ii] ", with: "", options: .regularExpression)

                        // Check for duplicates
                        let isDuplicate = semanticMemories.contains { existing in
                            existing.fact.lowercased() == fact.lowercased()
                        }

                        if !isDuplicate && fact.count > 15 && fact.count < 300 {
                            let embedding = await generateEmbedding(for: fact)
                            let memory = SemanticMemory(
                                fact: fact,
                                category: category,
                                confidence: 0.7,
                                embedding: embedding
                            )
                            semanticMemories.append(memory)
                            Self.logger.debug("Created semantic memory: \(fact.prefix(50))")
                        }
                        break
                    }
                }
            }
        }
    }

    /// Store an interaction as episodic memory
    private func storeEpisodicMemory(
        query: String,
        response: String,
        helpful: Bool?
    ) async {
        // Create summary of response (first 200 chars)
        let summary = String(response.prefix(200))

        let embedding = await generateEmbedding(for: query)

        let memory = EpisodicMemory(
            userQuery: query,
            responseSummary: summary,
            context: "chat",
            wasHelpful: helpful,
            embedding: embedding
        )

        episodicMemories.append(memory)

        // Keep only last 500 episodic memories
        if episodicMemories.count > 500 {
            episodicMemories = Array(episodicMemories.suffix(500))
        }

        Self.logger.debug("Stored episodic memory for query: \(query.prefix(50))")
    }

    /// Add a procedural memory manually
    public func addProceduralMemory(trigger: String, behavior: String) {
        let memory = ProceduralMemory(trigger: trigger, behavior: behavior)
        proceduralMemories.append(memory)
        save()
    }

    // MARK: - Memory Management

    /// Delete a semantic memory
    public func forgetFact(_ memory: SemanticMemory) {
        semanticMemories.removeAll { $0.id == memory.id }
        save()
    }

    /// Update fact confidence
    public func updateConfidence(for memory: SemanticMemory, newConfidence: Float) {
        if let index = semanticMemories.firstIndex(where: { $0.id == memory.id }) {
            semanticMemories[index].confidence = newConfidence
            save()
        }
    }

    /// Mark episodic memory as helpful/unhelpful
    public func markInteraction(_ memory: EpisodicMemory, wasHelpful: Bool) {
        if let index = episodicMemories.firstIndex(where: { $0.id == memory.id }) {
            episodicMemories[index].wasHelpful = wasHelpful
            save()
        }
    }

    /// Clear all memories
    public func clearAll() {
        semanticMemories.removeAll()
        episodicMemories.removeAll()
        proceduralMemories.removeAll()
        save()
        Self.logger.notice("Cleared all unified memories")
    }

    // MARK: - Consolidation

    /// Consolidate memories (remove duplicates, decay old ones)
    public func consolidate() async {
        // Remove low-confidence, old, unused semantic memories
        let cutoffDate = Date().addingTimeInterval(-90 * 24 * 3600)  // 90 days
        semanticMemories = semanticMemories.filter { memory in
            // Keep if accessed recently or has high confidence
            memory.lastAccessed > cutoffDate || memory.confidence > 0.9 || memory.accessCount > 5
        }

        // Deduplicate semantic memories
        var seen: Set<String> = []
        semanticMemories = semanticMemories.filter { memory in
            let normalized = memory.fact.lowercased().trimmingCharacters(in: .whitespaces)
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }

        save()
        Self.logger.info("Consolidated memories: \(semanticMemories.count) semantic, \(episodicMemories.count) episodic")
    }

    // MARK: - Utilities

    private func generateEmbedding(for text: String) async -> [Float]? {
        let embeddings = DistilbertEmbeddings()
        return await embeddings.encode(sentence: text)
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }

        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        return magnitude > 0 ? dotProduct / magnitude : 0
    }

    // MARK: - Stats

    public var stats: (semantic: Int, episodic: Int, procedural: Int) {
        (semanticMemories.count, episodicMemories.count, proceduralMemories.count)
    }
}
