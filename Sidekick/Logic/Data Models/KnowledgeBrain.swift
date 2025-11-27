//
//  KnowledgeBrain.swift
//  Sidekick
//
//  Unified knowledge base that replaces fragmented experts with a single "brain"
//  containing all personal data with intelligent retrieval
//

import Foundation
import OSLog
import SimilaritySearchKit
import SimilaritySearchKitDistilbert

/// Unified personal knowledge base with hybrid retrieval and smart routing
@MainActor
public class KnowledgeBrain: ObservableObject {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: KnowledgeBrain.self)
    )

    /// Singleton instance
    public static let shared = KnowledgeBrain()

    // MARK: - Types

    /// Category of knowledge source for filtering
    public enum SourceCategory: String, Codable, CaseIterable {
        case email = "email"
        case notes = "notes"
        case documents = "documents"
        case calendar = "calendar"
        case messages = "messages"
        case web = "web"
        case other = "other"

        public var displayName: String {
            switch self {
            case .email: return "Emails"
            case .notes: return "Notes"
            case .documents: return "Documents"
            case .calendar: return "Calendar"
            case .messages: return "Messages"
            case .web: return "Web"
            case .other: return "Other"
            }
        }
    }

    /// Metadata for an indexed chunk
    public struct ChunkMetadata: Codable {
        public let id: UUID
        public let source: String
        public let category: SourceCategory
        public let chunkIndex: Int
        public let timestamp: Date
        public var customMetadata: [String: String]

        public init(
            id: UUID = UUID(),
            source: String,
            category: SourceCategory,
            chunkIndex: Int,
            timestamp: Date = Date(),
            customMetadata: [String: String] = [:]
        ) {
            self.id = id
            self.source = source
            self.category = category
            self.chunkIndex = chunkIndex
            self.timestamp = timestamp
            self.customMetadata = customMetadata
        }
    }

    /// Unified retrieval result
    public struct RetrievalResult {
        public let id: UUID
        public let text: String
        public let source: String
        public let category: SourceCategory?
        public let score: Double
        public let matchType: MatchType
        public let entityContext: [String]?
        public let communitySummary: String?

        public enum MatchType {
            case semantic       // Vector similarity match
            case keyword        // BM25 keyword match
            case hybrid         // Both matched
            case graphExpanded  // Found via graph traversal
        }
    }

    // MARK: - Properties

    /// Whether the brain has been initialized
    @Published public private(set) var isInitialized: Bool = false

    /// Whether the brain is currently indexing
    @Published public private(set) var isIndexing: Bool = false

    /// Current indexing progress (0-1)
    @Published public var indexingProgress: Double = 0

    /// Number of indexed chunks
    @Published public private(set) var indexedChunkCount: Int = 0

    /// Vector similarity index
    private var vectorIndex: SimilarityIndex?

    /// BM25 keyword index
    private var bm25Index: BM25Index = BM25Index()

    /// Unified knowledge graph
    private var knowledgeGraph: KnowledgeGraph?

    /// Hybrid retriever
    private let hybridRetriever = HybridRetriever()

    /// Query router
    private let queryRouter = QueryRouter.shared

    /// Chunk metadata storage
    private var chunkMetadata: [UUID: ChunkMetadata] = [:]

    // MARK: - Directory URLs

    private static var brainDirUrl: URL {
        Settings.containerUrl.appendingPathComponent("Brain")
    }

    private static var vectorIndexUrl: URL {
        brainDirUrl.appendingPathComponent("vector_index")
    }

    private static var bm25IndexUrl: URL {
        brainDirUrl.appendingPathComponent("bm25_index.json")
    }

    private static var metadataUrl: URL {
        brainDirUrl.appendingPathComponent("metadata.json")
    }

    private static var graphDatabaseUrl: URL {
        brainDirUrl.appendingPathComponent("knowledge_graph.sqlite")
    }

    // MARK: - Initialization

    private init() {
        Task {
            await initialize()
        }
    }

    /// Initialize the brain, loading existing indices if available
    public func initialize() async {
        let signpost = StartupMetrics.begin("KnowledgeBrain.initialize")
        defer { StartupMetrics.end("KnowledgeBrain.initialize", signpost) }

        // Create directory if needed
        createDirectoryIfNeeded()

        // Initialize vector index
        vectorIndex = await SimilarityIndex(
            model: DistilbertEmbeddings(),
            metric: CosineSimilarity()
        )

        // Load existing BM25 index
        if FileManager.default.fileExists(atPath: Self.bm25IndexUrl.path) {
            do {
                try bm25Index.load(from: Self.bm25IndexUrl)
                Self.logger.info("Loaded existing BM25 index with \(self.bm25Index.documentCount) documents")
            } catch {
                Self.logger.error("Failed to load BM25 index: \(error.localizedDescription)")
            }
        }

        // Load chunk metadata
        if FileManager.default.fileExists(atPath: Self.metadataUrl.path) {
            do {
                let data = try Data(contentsOf: Self.metadataUrl)
                let decoded = try JSONDecoder().decode([UUID: ChunkMetadata].self, from: data)
                chunkMetadata = decoded
                Self.logger.info("Loaded metadata for \(decoded.count) chunks")
            } catch {
                Self.logger.error("Failed to load metadata: \(error.localizedDescription)")
            }
        }

        // Load knowledge graph
        if FileManager.default.fileExists(atPath: Self.graphDatabaseUrl.path) {
            do {
                let database = try GraphDatabase(dbPath: Self.graphDatabaseUrl.path)
                knowledgeGraph = try database.loadAllGraphs()
                Self.logger.info("Loaded knowledge graph with \(self.knowledgeGraph?.entityCount ?? 0) entities")
            } catch {
                Self.logger.error("Failed to load knowledge graph: \(error.localizedDescription)")
            }
        }

        indexedChunkCount = bm25Index.documentCount
        isInitialized = true
        Self.logger.notice("KnowledgeBrain initialized with \(self.indexedChunkCount) chunks")
    }

    private func createDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: Self.brainDirUrl.path) {
            do {
                try FileManager.default.createDirectory(
                    at: Self.brainDirUrl,
                    withIntermediateDirectories: true
                )
            } catch {
                Self.logger.error("Failed to create brain directory: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ingestion

    /// Ingest content into the unified brain
    public func ingest(
        content: String,
        source: String,
        category: SourceCategory,
        customMetadata: [String: String] = [:],
        progressCallback: ((Double, String) -> Void)? = nil
    ) async {
        guard !content.isEmpty else { return }

        isIndexing = true
        indexingProgress = 0

        let chunks = chunkContent(content, targetSize: 400)
        let totalChunks = chunks.count

        progressCallback?(0, "Chunking content...")

        for (index, chunkText) in chunks.enumerated() {
            let metadata = ChunkMetadata(
                source: source,
                category: category,
                chunkIndex: index,
                customMetadata: customMetadata
            )

            // Add to BM25 index
            bm25Index.addDocument(
                id: metadata.id,
                text: chunkText,
                source: source,
                chunkIndex: index
            )

            // Add to vector index
            if let vectorIndex = vectorIndex {
                await vectorIndex.addItem(
                    id: metadata.id.uuidString,
                    text: chunkText,
                    metadata: [
                        "source": source,
                        "category": category.rawValue,
                        "itemIndex": "\(index)"
                    ]
                )
            }

            // Store metadata
            chunkMetadata[metadata.id] = metadata

            let progress = Double(index + 1) / Double(totalChunks)
            indexingProgress = progress
            progressCallback?(progress, "Indexing chunk \(index + 1) of \(totalChunks)")
        }

        // Save indices
        progressCallback?(0.95, "Saving indices...")
        await saveIndices()

        indexedChunkCount = bm25Index.documentCount
        isIndexing = false
        indexingProgress = 1.0
        progressCallback?(1.0, "Complete")

        Self.logger.notice("Ingested \(chunks.count) chunks from \(source)")
    }

    /// Save all indices to disk
    private func saveIndices() async {
        // Save BM25 index
        do {
            try bm25Index.save(to: Self.bm25IndexUrl)
        } catch {
            Self.logger.error("Failed to save BM25 index: \(error.localizedDescription)")
        }

        // Save metadata
        do {
            let data = try JSONEncoder().encode(chunkMetadata)
            try data.write(to: Self.metadataUrl, options: .atomic)
        } catch {
            Self.logger.error("Failed to save metadata: \(error.localizedDescription)")
        }
    }

    // MARK: - Chunking

    /// Chunk content into smaller pieces
    private func chunkContent(_ content: String, targetSize: Int) -> [String] {
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentLength = 0

        for sentence in sentences {
            if currentLength + sentence.count > targetSize && !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: ". "))
                currentChunk = []
                currentLength = 0
            }

            currentChunk.append(sentence)
            currentLength += sentence.count + 2  // +2 for ". "
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: ". "))
        }

        return chunks
    }

    // MARK: - Retrieval

    /// Smart retrieval that uses query routing to determine strategy
    public func retrieve(
        query: String,
        maxResults: Int = 10,
        categories: [SourceCategory]? = nil
    ) async -> [RetrievalResult] {
        guard isInitialized, let vectorIndex = vectorIndex else {
            Self.logger.warning("Brain not initialized, returning empty results")
            return []
        }

        // Determine retrieval strategy
        let strategy = queryRouter.determineStrategy(for: query)

        Self.logger.debug("Query strategy: useRAG=\(strategy.useRAG), depth=\(String(describing: strategy.ragDepth))")

        // If no RAG needed, return empty
        guard strategy.useRAG else {
            return []
        }

        // Determine how many results based on depth
        let retrievalCount: Int
        switch strategy.ragDepth {
        case .none:
            return []
        case .light:
            retrievalCount = min(3, maxResults)
        case .full:
            retrievalCount = maxResults
        }

        // Perform hybrid retrieval
        let hybridResults = await hybridRetriever.search(
            query: query,
            vectorIndex: vectorIndex,
            bm25Index: bm25Index,
            topK: retrievalCount * 2  // Get more for filtering
        )

        // Convert to RetrievalResults with metadata
        var results: [RetrievalResult] = []

        for hybrid in hybridResults {
            let metadata = chunkMetadata[hybrid.id]

            // Filter by category if specified
            if let categories = categories,
               let category = metadata?.category,
               !categories.contains(category) {
                continue
            }

            let matchType: RetrievalResult.MatchType
            if hybrid.hasKeywordMatch && hybrid.hasSemanticMatch {
                matchType = .hybrid
            } else if hybrid.hasKeywordMatch {
                matchType = .keyword
            } else {
                matchType = .semantic
            }

            results.append(RetrievalResult(
                id: hybrid.id,
                text: hybrid.text,
                source: hybrid.source,
                category: metadata?.category,
                score: hybrid.fusedScore,
                matchType: matchType,
                entityContext: nil,
                communitySummary: nil
            ))

            if results.count >= retrievalCount {
                break
            }
        }

        // If graph RAG is enabled and we have a knowledge graph, enhance results
        if RetrievalSettings.graphRAGEnabled,
           let graph = knowledgeGraph,
           strategy.ragDepth == .full {
            results = await enhanceWithGraph(results: results, query: query, graph: graph)
        }

        Self.logger.debug("Retrieved \(results.count) results for query: \(query.prefix(50))")

        return results
    }

    /// Enhance results with knowledge graph context
    private func enhanceWithGraph(
        results: [RetrievalResult],
        query: String,
        graph: KnowledgeGraph
    ) async -> [RetrievalResult] {
        // Convert to SearchResult format for GraphRetriever
        var searchResults: [SearchResult] = []
        for result in results {
            // Create a minimal SearchResult - this is a workaround
            // In a real implementation, we'd refactor GraphRetriever to work with our types
            let sr = SearchResult(searchResult: SimilaritySearchKit.SearchResult(
                id: result.id.uuidString,
                text: result.text,
                score: Float(result.score),
                metadata: [
                    "source": result.source,
                    "itemIndex": "0"
                ]
            ))
            searchResults.append(sr)
        }

        // Get enhanced results from graph
        let enhanced = await GraphRetriever.retrieve(
            query: query,
            vectorResults: searchResults,
            graph: graph,
            maxResults: results.count
        )

        // Merge graph enhancements back
        var enhancedResults: [RetrievalResult] = []
        for (index, result) in results.enumerated() {
            if index < enhanced.count {
                let graphResult = enhanced[index]
                enhancedResults.append(RetrievalResult(
                    id: result.id,
                    text: result.text,
                    source: result.source,
                    category: result.category,
                    score: result.score,
                    matchType: result.matchType,
                    entityContext: graphResult.entityContext.isEmpty ? nil : graphResult.entityContext,
                    communitySummary: graphResult.communitySummary
                ))
            } else {
                enhancedResults.append(result)
            }
        }

        return enhancedResults
    }

    // MARK: - Direct Search (bypasses routing)

    /// Direct hybrid search without query routing - useful for testing
    public func searchDirect(
        query: String,
        maxResults: Int = 10
    ) async -> [RetrievalResult] {
        guard isInitialized, let vectorIndex = vectorIndex else {
            return []
        }

        let hybridResults = await hybridRetriever.search(
            query: query,
            vectorIndex: vectorIndex,
            bm25Index: bm25Index,
            topK: maxResults
        )

        return hybridResults.map { hybrid in
            let metadata = chunkMetadata[hybrid.id]
            let matchType: RetrievalResult.MatchType
            if hybrid.hasKeywordMatch && hybrid.hasSemanticMatch {
                matchType = .hybrid
            } else if hybrid.hasKeywordMatch {
                matchType = .keyword
            } else {
                matchType = .semantic
            }

            return RetrievalResult(
                id: hybrid.id,
                text: hybrid.text,
                source: hybrid.source,
                category: metadata?.category,
                score: hybrid.fusedScore,
                matchType: matchType,
                entityContext: nil,
                communitySummary: nil
            )
        }
    }

    // MARK: - Statistics

    /// Get statistics about the brain
    public func getStats() -> BrainStats {
        return BrainStats(
            totalChunks: indexedChunkCount,
            totalTerms: bm25Index.termCount,
            entityCount: knowledgeGraph?.entityCount ?? 0,
            isInitialized: isInitialized
        )
    }

    public struct BrainStats {
        public let totalChunks: Int
        public let totalTerms: Int
        public let entityCount: Int
        public let isInitialized: Bool
    }

    // MARK: - Clear

    /// Clear all data from the brain
    public func clear() async {
        bm25Index.clear()
        vectorIndex = await SimilarityIndex(
            model: DistilbertEmbeddings(),
            metric: CosineSimilarity()
        )
        chunkMetadata.removeAll()
        knowledgeGraph = nil
        indexedChunkCount = 0

        // Delete files
        try? FileManager.default.removeItem(at: Self.bm25IndexUrl)
        try? FileManager.default.removeItem(at: Self.metadataUrl)
        try? FileManager.default.removeItem(at: Self.graphDatabaseUrl)

        Self.logger.notice("Brain cleared")
    }
}
