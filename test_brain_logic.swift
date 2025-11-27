// Standalone test for QueryRouter logic (paste into Swift Playground or Xcode)
// This tests the core classification without dependencies

import Foundation

// Simplified QueryRouter for testing
class TestQueryRouter {
    enum QueryIntent: String {
        case personal, memory, general, hybrid
    }
    
    let personalSignals: Set<String> = [
        "my", "i", "me", "mine", "our", "we",
        "email", "emails", "meeting", "meetings", "notes", "note",
        "calendar", "document", "documents", "file", "files",
        "yesterday", "last week", "last month", "told me", "said to me",
        "sent me", "wrote", "scheduled", "appointment",
        "project", "task", "todo", "reminder"
    ]
    
    let memorySignals: Set<String> = [
        "favorite", "favourite", "prefer", "preference", "like", "dislike",
        "usually", "always", "never", "habit", "routine"
    ]
    
    let generalSignals: Set<String> = [
        "explain", "define", "what is", "who is", "how does",
        "in general", "typically", "generally speaking",
        "history of", "science", "math", "calculate",
        "code", "programming", "algorithm", "function"
    ]
    
    let hybridSignals: Set<String> = [
        "help me write", "draft", "compose", "prepare",
        "suggest", "recommend", "advice", "should i"
    ]
    
    func classify(query: String) -> (intent: QueryIntent, confidence: Float) {
        let lowercased = query.lowercased()
        let words = Set(lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        
        let personalCount = words.intersection(personalSignals).count + countPhrases(lowercased, ["told me", "sent me", "last week"])
        let memoryCount = words.intersection(memorySignals).count
        let generalCount = words.intersection(generalSignals).count + countPhrases(lowercased, ["what is", "who is", "how does"])
        let hybridCount = words.intersection(hybridSignals).count + countPhrases(lowercased, ["help me write", "should i"])
        
        let scores: [(QueryIntent, Int)] = [
            (.personal, personalCount),
            (.memory, memoryCount),
            (.general, generalCount),
            (.hybrid, hybridCount)
        ]
        
        let maxScore = scores.max(by: { $0.1 < $1.1 })!
        let totalSignals = max(personalCount + memoryCount + generalCount + hybridCount, 1)
        
        if maxScore.1 == 0 {
            return (.hybrid, 0.5)
        } else if maxScore.1 >= 2 {
            return (maxScore.0, min(Float(maxScore.1) / Float(totalSignals) + 0.3, 0.95))
        } else {
            return (maxScore.0, Float(maxScore.1) / Float(totalSignals) + 0.2)
        }
    }
    
    func countPhrases(_ text: String, _ phrases: [String]) -> Int {
        phrases.filter { text.contains($0) }.count
    }
}

// Test cases
let router = TestQueryRouter()

let testCases: [(query: String, expected: TestQueryRouter.QueryIntent)] = [
    ("What did John email me about the project?", .personal),
    ("Find my notes from yesterday's meeting", .personal),
    ("What's my favorite restaurant?", .memory),
    ("Do I prefer dark mode?", .memory),
    ("Explain how photosynthesis works", .general),
    ("What is the capital of France?", .general),
    ("Help me write an email to my boss", .hybrid),
    ("What should I say in my presentation?", .hybrid),
]

print("=== QueryRouter Test Results ===\n")
var passed = 0
for (query, expected) in testCases {
    let result = router.classify(query: query)
    let success = result.intent == expected
    if success { passed += 1 }
    let icon = success ? "✓" : "✗"
    print("\(icon) \"\(query.prefix(45))...\"")
    print("  Expected: \(expected.rawValue), Got: \(result.intent.rawValue) (conf: \(String(format: "%.2f", result.confidence)))\n")
}

print("Results: \(passed)/\(testCases.count) passed")
