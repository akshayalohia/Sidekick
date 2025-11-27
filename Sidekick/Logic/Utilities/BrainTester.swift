//
//  BrainTester.swift
//  Sidekick
//
//  Test utility for verifying the unified brain RAG system
//

import Foundation
import OSLog

/// Test utility for the unified brain system
@MainActor
public class BrainTester {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: BrainTester.self)
    )

    // MARK: - Test Query Router

    /// Test the query router classification
    public static func testQueryRouter() {
        print("\n=== Testing Query Router ===\n")

        let testQueries: [(query: String, expectedIntent: QueryRouter.QueryIntent)] = [
            // Personal queries - should trigger full RAG
            ("What did John email me about the project?", .personal),
            ("Find my notes from yesterday's meeting", .personal),
            ("What documents do I have about the budget?", .personal),

            // Memory queries - should use memory recall only
            ("What's my favorite restaurant?", .memory),
            ("Do I prefer dark mode or light mode?", .memory),
            ("What are my usual preferences for coffee?", .memory),

            // General queries - should NOT trigger RAG
            ("Explain how photosynthesis works", .general),
            ("What is the capital of France?", .general),
            ("How do I write a for loop in Python?", .general),

            // Hybrid queries - light RAG + creativity
            ("Help me write an email to my boss about the project", .hybrid),
            ("Draft a response to the client", .hybrid),
            ("What should I say in my presentation?", .hybrid)
        ]

        let router = QueryRouter.shared
        var correct = 0
        var total = testQueries.count

        for (query, expected) in testQueries {
            let result = router.classify(query: query)
            let passed = result.intent == expected
            if passed { correct += 1 }

            let status = passed ? "✓" : "✗"
            print("\(status) Query: \"\(query.prefix(50))...\"")
            print("  Expected: \(expected.rawValue), Got: \(result.intent.rawValue) (confidence: \(String(format: "%.2f", result.confidence)))")
            print("  Reason: \(result.reasoning)\n")
        }

        print("Query Router Test: \(correct)/\(total) correct (\(Int(Double(correct)/Double(total)*100))%)\n")
    }

    // MARK: - Test BM25 Index

    /// Test the BM25 keyword search
    public static func testBM25Index() {
        print("\n=== Testing BM25 Index ===\n")

        let bm25 = BM25Index()

        // Add test documents
        let testDocs = [
            (text: "Meeting with John about the Q4 budget review scheduled for Monday", source: "calendar"),
            (text: "Email from Sarah regarding the marketing campaign results", source: "email"),
            (text: "Invoice #INV-2024-0847 from ACME Corp for $5,000", source: "documents"),
            (text: "Notes from team standup: discussed sprint priorities and blockers", source: "notes"),
            (text: "John mentioned we need to finalize the budget proposal by Friday", source: "email")
        ]

        for (index, doc) in testDocs.enumerated() {
            bm25.addDocument(
                id: UUID(),
                text: doc.text,
                source: doc.source,
                chunkIndex: index
            )
        }

        print("Indexed \(bm25.documentCount) documents with \(bm25.termCount) unique terms\n")

        // Test queries
        let testSearches = [
            "budget",           // Should find budget-related docs
            "John",             // Should find John-related docs
            "INV-2024-0847",    // Exact invoice number
            "marketing",        // Should find Sarah's email
            "quantum physics"   // Should find nothing
        ]

        for query in testSearches {
            let results = bm25.search(query: query, topK: 3)
            print("Query: \"\(query)\"")
            if results.isEmpty {
                print("  No results found")
            } else {
                for (index, result) in results.enumerated() {
                    print("  [\(index + 1)] Score: \(String(format: "%.3f", result.score)) - \(result.document.text.prefix(60))...")
                }
            }
            print("")
        }
    }

    // MARK: - Test Hybrid Retrieval

    /// Test hybrid retrieval (requires initialized KnowledgeBrain)
    public static func testHybridRetrieval() async {
        print("\n=== Testing Hybrid Retrieval ===\n")

        let brain = KnowledgeBrain.shared

        // Wait for initialization
        if !brain.isInitialized {
            print("Waiting for brain initialization...")
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        }

        guard brain.isInitialized else {
            print("Brain not initialized, skipping hybrid test")
            return
        }

        // If brain is empty, add some test data
        let stats = brain.getStats()
        if stats.totalChunks == 0 {
            print("Brain is empty, adding test data...")

            await brain.ingest(
                content: """
                Meeting with John Smith on Monday to discuss the Q4 budget review.
                We need to finalize the budget proposal by Friday.
                The marketing team has completed their campaign analysis.
                Invoice INV-2024-0847 from ACME Corporation totaling $5,000 is pending approval.
                Sarah mentioned the client presentation is scheduled for next week.
                Team standup notes: Sprint priorities include the new dashboard feature.
                """,
                source: "test_data",
                category: .notes
            ) { progress, stage in
                print("  \(String(format: "%.0f%%", progress * 100)) - \(stage)")
            }

            print("Ingestion complete\n")
        }

        // Test queries
        let testQueries = [
            "budget review with John",
            "invoice ACME",
            "marketing campaign",
            "what is the meaning of life"  // Should return low-relevance or nothing
        ]

        for query in testQueries {
            print("Query: \"\(query)\"")
            let results = await brain.searchDirect(query: query, maxResults: 3)

            if results.isEmpty {
                print("  No results found")
            } else {
                for (index, result) in results.enumerated() {
                    let matchIcon: String
                    switch result.matchType {
                    case .hybrid: matchIcon = "🔄"
                    case .keyword: matchIcon = "🔤"
                    case .semantic: matchIcon = "🧠"
                    case .graphExpanded: matchIcon = "🕸️"
                    }
                    print("  [\(index + 1)] \(matchIcon) Score: \(String(format: "%.3f", result.score))")
                    print("      \(result.text.prefix(80))...")
                }
            }
            print("")
        }
    }

    // MARK: - Run All Tests

    /// Run all tests
    public static func runAllTests() async {
        print("\n" + String(repeating: "=", count: 60))
        print("UNIFIED BRAIN RAG SYSTEM - TEST SUITE")
        print(String(repeating: "=", count: 60))

        testQueryRouter()
        testBM25Index()
        await testHybridRetrieval()

        print(String(repeating: "=", count: 60))
        print("TEST SUITE COMPLETE")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
