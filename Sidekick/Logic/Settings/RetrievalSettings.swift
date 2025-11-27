//
//  RetrievalSettings.swift
//  Sidekick
//
//  Created by Bean John on 10/16/24.
//

import Foundation
import SecureDefaults

public class RetrievalSettings {
    
    /// A `Bool` representing whether the memory feature is used
    static var useMemory: Bool {
        get {
            // Set default
            if !UserDefaults.standard.exists(key: "useMemory") {
                // Default to false
                Self.useMemory = false
            }
            return UserDefaults.standard.bool(
                forKey: "useMemory"
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useMemory")
        }
    }
    
    /// Computed property for Tavily API key
    public static var tavilyApiKey: String {
        set {
            let defaults: SecureDefaults = SecureDefaults.defaults()
            defaults.set(newValue, forKey: "apiKey")
        }
        get {
            let defaults: SecureDefaults = SecureDefaults.defaults()
            return defaults.string(forKey: "apiKey") ?? ""
        }
    }
    
    /// Computed property for backup Tavily API key
    public static var tavilyBackupApiKey: String {
        set {
            let defaults: SecureDefaults = SecureDefaults.defaults()
            defaults.set(newValue, forKey: "backupApiKey")
        }
        get {
            let defaults: SecureDefaults = SecureDefaults.defaults()
            return defaults.string(forKey: "backupApiKey") ?? ""
        }
    }
    
    /// A `Bool` representing whether web search can be used
    static var canUseWebSearch: Bool {
        // Get provider
        let provider: SearchProvider = SearchProvider(
            rawValue: Self.defaultSearchProvider
        ) ?? .duckDuckGo
        // Check for each provider
        switch provider {
            case .duckDuckGo, .google:
                return true
            case .tavily:
                return !Self.tavilyApiKey.isEmpty
        }
    }
    
    /// Computed property for whether the context of a search result is used
    static var useWebSearchResultContext: Bool {
        get {
            // Set default
            if !UserDefaults.standard.exists(key: "useWebSearchResultContext") {
                // Default to true for more content
                Self.useWebSearchResultContext = true
            }
            return UserDefaults.standard.bool(
                forKey: "useWebSearchResultContext"
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useWebSearchResultContext")
        }
    }
    
    /// Computed property for how many search results are returned
    static var searchResultsMultiplier: Int {
        get {
            // Set default
            if !UserDefaults.standard.exists(key: "searchResultsMultiplier") {
                Self.searchResultsMultiplier = 3
            }
            return UserDefaults.standard.integer(
                forKey: "searchResultsMultiplier"
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "searchResultsMultiplier")
        }
    }
    
    /// The default search provider, where 0 = DuckDuckGo, 1 = Tavily, 2 = Google
    static var defaultSearchProvider: Int {
        get {
            // Default to DuckDuckGo
            if !UserDefaults.standard.exists(key: "defaultSearchProvider") {
                Self.defaultSearchProvider = 0
            }
            return UserDefaults.standard.integer(
                forKey: "defaultSearchProvider"
            )
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "defaultSearchProvider")
        }
    }
    /// Search providers supported by Sidekick
    public enum SearchProvider: Int, CaseIterable {
        
        case duckDuckGo = 0
        case tavily = 1
        case google = 2
        
    }
    
    // MARK: - Graph RAG Settings
    
    /// Whether Graph RAG feature is enabled globally
    static var graphRAGEnabled: Bool {
        get {
            if !UserDefaults.standard.exists(key: "graphRAGEnabled") {
                Self.graphRAGEnabled = true  // Default to enabled
            }
            return UserDefaults.standard.bool(forKey: "graphRAGEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "graphRAGEnabled")
        }
    }
    
    /// Maximum number of entities to extract per expert
    static var graphRAGMaxEntities: Int {
        get {
            if !UserDefaults.standard.exists(key: "graphRAGMaxEntities") {
                Self.graphRAGMaxEntities = 500  // Default
            }
            return UserDefaults.standard.integer(forKey: "graphRAGMaxEntities")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "graphRAGMaxEntities")
        }
    }
    
    /// Number of hierarchical community levels
    static var graphRAGCommunityLevels: Int {
        get {
            if !UserDefaults.standard.exists(key: "graphRAGCommunityLevels") {
                Self.graphRAGCommunityLevels = 3  // Default: 0, 1, 2
            }
            return UserDefaults.standard.integer(forKey: "graphRAGCommunityLevels")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "graphRAGCommunityLevels")
        }
    }

    // MARK: - Unified Brain Settings

    /// Whether to use the unified brain instead of separate experts
    static var useUnifiedBrain: Bool {
        get {
            if !UserDefaults.standard.exists(key: "useUnifiedBrain") {
                Self.useUnifiedBrain = false  // Default to false (opt-in)
            }
            return UserDefaults.standard.bool(forKey: "useUnifiedBrain")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useUnifiedBrain")
        }
    }

    /// Whether to use query routing to decide when RAG is needed
    static var useQueryRouting: Bool {
        get {
            if !UserDefaults.standard.exists(key: "useQueryRouting") {
                Self.useQueryRouting = true  // Default to enabled
            }
            return UserDefaults.standard.bool(forKey: "useQueryRouting")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useQueryRouting")
        }
    }

    /// Whether to use hybrid search (BM25 + vector)
    static var useHybridSearch: Bool {
        get {
            if !UserDefaults.standard.exists(key: "useHybridSearch") {
                Self.useHybridSearch = true  // Default to enabled
            }
            return UserDefaults.standard.bool(forKey: "useHybridSearch")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useHybridSearch")
        }
    }

    /// Weight for vector search in hybrid mode (0-1, BM25 gets 1-this)
    static var hybridVectorWeight: Double {
        get {
            if !UserDefaults.standard.exists(key: "hybridVectorWeight") {
                Self.hybridVectorWeight = 0.5  // Equal weighting by default
            }
            return UserDefaults.standard.double(forKey: "hybridVectorWeight")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hybridVectorWeight")
        }
    }

    /// Whether to use cross-encoder reranking
    static var useReranking: Bool {
        get {
            if !UserDefaults.standard.exists(key: "useReranking") {
                Self.useReranking = false  // Default to disabled until model is bundled
            }
            return UserDefaults.standard.bool(forKey: "useReranking")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useReranking")
        }
    }

    /// Default chunk size for indexing (in characters)
    static var chunkSize: Int {
        get {
            if !UserDefaults.standard.exists(key: "chunkSize") {
                Self.chunkSize = 400  // Optimal for most use cases
            }
            return UserDefaults.standard.integer(forKey: "chunkSize")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "chunkSize")
        }
    }

}
