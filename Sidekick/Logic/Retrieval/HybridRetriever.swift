//
//  HybridRetriever.swift
//  Sidekick
//
//  Combines BM25 keyword search with vector semantic search using Reciprocal Rank Fusion
//

import Foundation
import OSLog
import SimilaritySearchKit
import SimilaritySearchKitDistilbert

/// Hybrid retriever combining keyword (BM25) and semantic (vector) search
public class HybridRetriever {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: HybridRetriever.self)
    )

    // MARK: - Types

    public struct HybridResult: Identifiable {
        public let id: UUID
        public let text: String
        public let source: String
        public let chunkIndex: Int?
        public let vectorRank: Int?
        public let bm25Rank: Int?
        public let vectorScore: Float?
        public let bm25Score: Double?
        public let fusedScore: Double

        public var hasKeywordMatch: Bool { bm25Rank != nil }
        public var hasSemanticMatch: Bool { vectorRank != nil }
    }

    // MARK: - Properties

    /// RRF constant (standard value of 60)
    private let rrfK: Double = 60

    /// Minimum vector similarity threshold
    private let vectorThreshold: Float = 0.4

    // MARK: - Search

    /// Perform hybrid search combining BM25 and vector results
    /// - Parameters:
    ///   - query: The search query
    ///   - vectorIndex: The similarity index for semantic search
    ///   - bm25Index: The BM25 index for keyword search
    ///   - topK: Maximum number of results to return
    /// - Returns: Array of hybrid results sorted by fused score
    public func search(
        query: String,
        vectorIndex: SimilarityIndex,
        bm25Index: BM25Index,
        topK: Int = 20
    ) async -> [HybridResult] {
        // Run both searches (vector search is async)
        let vectorResults = await vectorIndex.search(
            query: query,
            maxResults: topK * 2,
            threshold: vectorThreshold
        )

        let bm25Results = bm25Index.search(query: query, topK: topK * 2)

        Self.logger.debug("Vector search returned \(vectorResults.count), BM25 returned \(bm25Results.count) results")

        return fuseResults(
            vectorResults: vectorResults,
            bm25Results: bm25Results,
            topK: topK
        )
    }

    /// Fuse vector and BM25 results using Reciprocal Rank Fusion
    private func fuseResults(
        vectorResults: [SearchResult],
        bm25Results: [BM25Index.SearchResult],
        topK: Int
    ) -> [HybridResult] {
        // Build maps from document identifier to rank and score
        // For vector results, we use the source URL + chunk index as identifier
        var vectorRanks: [String: (rank: Int, score: Float, result: SearchResult)] = [:]
        for (index, result) in vectorResults.enumerated() {
            let key = makeKey(source: result.sourceUrlText ?? "", chunkIndex: result.itemIndex)
            vectorRanks[key] = (index + 1, result.score, result)  // 1-indexed rank
        }

        var bm25Ranks: [String: (rank: Int, score: Double, result: BM25Index.SearchResult)] = [:]
        for (index, result) in bm25Results.enumerated() {
            let key = makeKey(source: result.document.source, chunkIndex: result.document.chunkIndex)
            bm25Ranks[key] = (index + 1, result.score, result)
        }

        // Collect all unique document keys
        var allKeys = Set(vectorRanks.keys)
        allKeys.formUnion(bm25Ranks.keys)

        // Calculate RRF scores and build results
        var hybridResults: [HybridResult] = []

        for key in allKeys {
            let vectorData = vectorRanks[key]
            let bm25Data = bm25Ranks[key]

            // RRF score = sum of 1/(k + rank) for each ranking
            var rrfScore: Double = 0

            if let vr = vectorData {
                rrfScore += 1.0 / (rrfK + Double(vr.rank))
            }
            if let br = bm25Data {
                rrfScore += 1.0 / (rrfK + Double(br.rank))
            }

            // Get document info from whichever source has it
            let text: String
            let source: String
            let chunkIndex: Int?
            let id: UUID

            if let vr = vectorData {
                text = vr.result.text
                source = vr.result.sourceUrlText ?? ""
                chunkIndex = vr.result.itemIndex
                id = UUID(uuidString: vr.result.id) ?? UUID()
            } else if let br = bm25Data {
                text = br.result.document.text
                source = br.result.document.source
                chunkIndex = br.result.document.chunkIndex
                id = br.result.document.id
            } else {
                continue
            }

            hybridResults.append(HybridResult(
                id: id,
                text: text,
                source: source,
                chunkIndex: chunkIndex,
                vectorRank: vectorData?.rank,
                bm25Rank: bm25Data?.rank,
                vectorScore: vectorData?.score,
                bm25Score: bm25Data?.score,
                fusedScore: rrfScore
            ))
        }

        // Sort by fused score (highest first) and return top K
        let sorted = hybridResults.sorted { $0.fusedScore > $1.fusedScore }

        Self.logger.debug("RRF fusion produced \(sorted.count) unique results, returning top \(min(topK, sorted.count))")

        return Array(sorted.prefix(topK))
    }

    /// Create a unique key for a document chunk
    private func makeKey(source: String, chunkIndex: Int?) -> String {
        if let idx = chunkIndex {
            return "\(source)_\(idx)"
        }
        return source
    }

    // MARK: - Weighted Hybrid Search

    /// Perform weighted hybrid search with configurable blend
    /// - Parameters:
    ///   - query: The search query
    ///   - vectorIndex: The similarity index
    ///   - bm25Index: The BM25 index
    ///   - vectorWeight: Weight for vector search (0-1), BM25 gets 1-vectorWeight
    ///   - topK: Maximum results
    public func searchWeighted(
        query: String,
        vectorIndex: SimilarityIndex,
        bm25Index: BM25Index,
        vectorWeight: Double = 0.5,
        topK: Int = 20
    ) async -> [HybridResult] {
        let vectorResults = await vectorIndex.search(
            query: query,
            maxResults: topK * 2,
            threshold: vectorThreshold
        )

        let bm25Results = bm25Index.search(query: query, topK: topK * 2)

        return fuseResultsWeighted(
            vectorResults: vectorResults,
            bm25Results: bm25Results,
            vectorWeight: vectorWeight,
            topK: topK
        )
    }

    /// Fuse results using weighted scoring instead of RRF
    private func fuseResultsWeighted(
        vectorResults: [SearchResult],
        bm25Results: [BM25Index.SearchResult],
        vectorWeight: Double,
        topK: Int
    ) -> [HybridResult] {
        let bm25Weight = 1.0 - vectorWeight

        // Normalize scores to 0-1 range
        let maxVectorScore = vectorResults.map { $0.score }.max() ?? 1.0
        let maxBm25Score = bm25Results.map { $0.score }.max() ?? 1.0

        // Build lookup maps
        var vectorScores: [String: (score: Float, result: SearchResult)] = [:]
        for result in vectorResults {
            let key = makeKey(source: result.sourceUrlText ?? "", chunkIndex: result.itemIndex)
            let normalizedScore = maxVectorScore > 0 ? result.score / maxVectorScore : 0
            vectorScores[key] = (normalizedScore, result)
        }

        var bm25Scores: [String: (score: Double, result: BM25Index.SearchResult)] = [:]
        for result in bm25Results {
            let key = makeKey(source: result.document.source, chunkIndex: result.document.chunkIndex)
            let normalizedScore = maxBm25Score > 0 ? result.score / maxBm25Score : 0
            bm25Scores[key] = (normalizedScore, result)
        }

        // Combine scores
        var allKeys = Set(vectorScores.keys)
        allKeys.formUnion(bm25Scores.keys)

        var hybridResults: [HybridResult] = []

        for key in allKeys {
            let vectorData = vectorScores[key]
            let bm25Data = bm25Scores[key]

            let vScore = Double(vectorData?.score ?? 0) * vectorWeight
            let bScore = (bm25Data?.score ?? 0) * bm25Weight
            let combinedScore = vScore + bScore

            let text: String
            let source: String
            let chunkIndex: Int?
            let id: UUID

            if let vr = vectorData {
                text = vr.result.text
                source = vr.result.sourceUrlText ?? ""
                chunkIndex = vr.result.itemIndex
                id = UUID(uuidString: vr.result.id) ?? UUID()
            } else if let br = bm25Data {
                text = br.result.document.text
                source = br.result.document.source
                chunkIndex = br.result.document.chunkIndex
                id = br.result.document.id
            } else {
                continue
            }

            hybridResults.append(HybridResult(
                id: id,
                text: text,
                source: source,
                chunkIndex: chunkIndex,
                vectorRank: vectorData != nil ? vectorResults.firstIndex(where: { makeKey(source: $0.sourceUrlText ?? "", chunkIndex: $0.itemIndex) == key }).map { $0 + 1 } : nil,
                bm25Rank: bm25Data != nil ? bm25Results.firstIndex(where: { makeKey(source: $0.document.source, chunkIndex: $0.document.chunkIndex) == key }).map { $0 + 1 } : nil,
                vectorScore: vectorData?.score,
                bm25Score: bm25Data?.score,
                fusedScore: combinedScore
            ))
        }

        return Array(hybridResults.sorted { $0.fusedScore > $1.fusedScore }.prefix(topK))
    }
}
