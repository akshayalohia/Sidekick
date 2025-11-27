//
//  BM25Index.swift
//  Sidekick
//
//  BM25 (Okapi BM25) keyword search implementation for hybrid retrieval
//

import Foundation
import OSLog

/// BM25 keyword search index for catching exact matches that vector search misses
public class BM25Index {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: BM25Index.self)
    )

    // MARK: - Types

    public struct Document: Codable, Identifiable {
        public let id: UUID
        public let text: String
        public let source: String
        public let chunkIndex: Int
        public var tokenFrequencies: [String: Int]

        public init(id: UUID, text: String, source: String, chunkIndex: Int) {
            self.id = id
            self.text = text
            self.source = source
            self.chunkIndex = chunkIndex
            self.tokenFrequencies = [:]
        }
    }

    public struct SearchResult {
        public let document: Document
        public let score: Double
    }

    // MARK: - Properties

    private var documents: [Document] = []
    private var invertedIndex: [String: [(docIndex: Int, frequency: Int)]] = [:]
    private var documentLengths: [Int] = []
    private var averageDocLength: Double = 0
    private var totalDocuments: Int { documents.count }

    // BM25 parameters (standard values)
    private let k1: Double = 1.5   // Term frequency saturation parameter
    private let b: Double = 0.75   // Length normalization parameter

    // Stopwords to filter out
    private let stopwords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "must", "shall", "can", "need", "dare",
        "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
        "from", "as", "into", "through", "during", "before", "after",
        "above", "below", "between", "under", "again", "further", "then",
        "once", "here", "there", "when", "where", "why", "how", "all",
        "each", "few", "more", "most", "other", "some", "such", "no", "nor",
        "not", "only", "own", "same", "so", "than", "too", "very", "just",
        "and", "but", "if", "or", "because", "until", "while", "this", "that"
    ]

    // MARK: - Initialization

    public init() {}

    // MARK: - Indexing

    /// Add a document to the index
    public func addDocument(id: UUID, text: String, source: String, chunkIndex: Int) {
        let tokens = tokenize(text)
        var tokenFreqs: [String: Int] = [:]

        for token in tokens {
            tokenFreqs[token, default: 0] += 1
        }

        var doc = Document(id: id, text: text, source: source, chunkIndex: chunkIndex)
        doc.tokenFrequencies = tokenFreqs

        let docIndex = documents.count
        documents.append(doc)
        documentLengths.append(tokens.count)

        // Update inverted index
        for (token, freq) in tokenFreqs {
            invertedIndex[token, default: []].append((docIndex, freq))
        }

        // Update average document length
        let totalLength = documentLengths.reduce(0, +)
        averageDocLength = documentLengths.isEmpty ? 0 : Double(totalLength) / Double(documentLengths.count)
    }

    /// Add multiple documents efficiently
    public func addDocuments(_ docs: [(id: UUID, text: String, source: String, chunkIndex: Int)]) {
        for doc in docs {
            addDocument(id: doc.id, text: doc.text, source: doc.source, chunkIndex: doc.chunkIndex)
        }
    }

    /// Clear all documents from the index
    public func clear() {
        documents.removeAll()
        invertedIndex.removeAll()
        documentLengths.removeAll()
        averageDocLength = 0
    }

    // MARK: - Search

    /// Search the index using BM25 scoring
    public func search(query: String, topK: Int = 20) -> [SearchResult] {
        guard !documents.isEmpty else {
            Self.logger.debug("BM25 search called on empty index")
            return []
        }

        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else {
            Self.logger.debug("BM25 search with empty query tokens")
            return []
        }

        var scores: [Int: Double] = [:]
        let N = Double(totalDocuments)

        for token in queryTokens {
            guard let postings = invertedIndex[token] else { continue }

            // IDF calculation: log((N - df + 0.5) / (df + 0.5) + 1)
            let df = Double(postings.count)
            let idf = log((N - df + 0.5) / (df + 0.5) + 1)

            for (docIndex, termFreq) in postings {
                let docLength = Double(documentLengths[docIndex])
                let tf = Double(termFreq)

                // BM25 term score
                let numerator = tf * (k1 + 1)
                let denominator = tf + k1 * (1 - b + b * (docLength / max(averageDocLength, 1)))
                let termScore = idf * (numerator / denominator)

                scores[docIndex, default: 0] += termScore
            }
        }

        // Sort by score and return top K
        let sortedResults = scores.sorted { $0.value > $1.value }
            .prefix(topK)
            .map { SearchResult(document: documents[$0.key], score: $0.value) }

        Self.logger.debug("BM25 search returned \(sortedResults.count) results for query: \(query.prefix(50))")

        return Array(sortedResults)
    }

    // MARK: - Tokenization

    /// Tokenize text into searchable terms
    private func tokenize(_ text: String) -> [String] {
        let cleaned = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }

        // Filter stopwords but keep important terms
        return cleaned.filter { !stopwords.contains($0) }
    }

    // MARK: - Persistence

    /// Codable wrapper for saving/loading
    private struct IndexData: Codable {
        let documents: [Document]
    }

    /// Save the index to a file
    public func save(to url: URL) throws {
        let data = IndexData(documents: documents)
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url, options: .atomic)
        Self.logger.info("Saved BM25 index with \(documents.count) documents to \(url.path)")
    }

    /// Load the index from a file
    public func load(from url: URL) throws {
        let rawData = try Data(contentsOf: url)
        let data = try JSONDecoder().decode(IndexData.self, from: rawData)

        // Clear and rebuild
        clear()
        for doc in data.documents {
            addDocument(id: doc.id, text: doc.text, source: doc.source, chunkIndex: doc.chunkIndex)
        }
        Self.logger.info("Loaded BM25 index with \(documents.count) documents from \(url.path)")
    }

    // MARK: - Stats

    /// Number of documents in the index
    public var documentCount: Int { documents.count }

    /// Number of unique terms in the index
    public var termCount: Int { invertedIndex.count }
}
