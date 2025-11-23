//
//  Resources.swift
//  Sidekick
//
//  Created by Bean John on 10/6/24.
//

import Foundation
import FSKit_macOS
import OSLog
import SimilaritySearchKit
import SimilaritySearchKitDistilbert
import SwiftUI

/// An object that manages a expert's resources
public struct Resources: Identifiable, Codable, Hashable, Sendable {
    
    /// A `Logger` object for ``Resources`` objects
    private static let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Resources.self)
    )
    
    /// Stored property for `Identifiable` conformance
    public var id: UUID = UUID()
    
    /// An array of all resources associated with this expert of type  ``Resource``
    public var resources: [Resource] = []
    
    /// A URL of the expert's index directory of type `URL`
    public var indexUrl: URL {
        return Settings
            .containerUrl
            .appendingPathComponent("Resources")
            .appendingPathComponent(self.id.uuidString)
    }
    
    /// The ``Status`` of the resource
    public var status: Status? = nil
    
    public enum Status: CaseIterable, Codable, Sendable {
        case indexing
        case ready
    }
    
    /// Whether Graph RAG is enabled for this expert's resources
    public var useGraphRAG: Bool = false
    
    /// The status of graph indexing
    public var graphStatus: GraphStatus? = nil
    
    /// Progress information for graph indexing
    public var graphProgress: GraphProgress? = nil
    
    public enum GraphStatus: CaseIterable, Codable, Sendable {
        case building
        case ready
        case error
    }
    
    /// Represents progress when building graph indexes
    public struct GraphProgress: Codable, Hashable, Sendable {
        public var percentComplete: Double
        public var stagePercentComplete: Double?
        public var stage: String?
        public var stageIdentifier: String?
        
        public init(
            percentComplete: Double,
            stagePercentComplete: Double? = nil,
            stage: String? = nil,
            stageIdentifier: String? = nil
        ) {
            self.percentComplete = percentComplete
            self.stagePercentComplete = stagePercentComplete
            self.stage = stage
            self.stageIdentifier = stageIdentifier
        }
        
        enum CodingKeys: String, CodingKey {
            case percentComplete
            case stagePercentComplete
            case stage
            case stageIdentifier
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.percentComplete = try container.decode(Double.self, forKey: .percentComplete)
            self.stagePercentComplete = try container.decodeIfPresent(Double.self, forKey: .stagePercentComplete)
            self.stage = try container.decodeIfPresent(String.self, forKey: .stage)
            self.stageIdentifier = try container.decodeIfPresent(String.self, forKey: .stageIdentifier)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(percentComplete, forKey: .percentComplete)
            try container.encodeIfPresent(stagePercentComplete, forKey: .stagePercentComplete)
            try container.encodeIfPresent(stage, forKey: .stage)
            try container.encodeIfPresent(stageIdentifier, forKey: .stageIdentifier)
        }
    }
    
    // MARK: - Initialization
    
    /// Default initializer
    public init() {}
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id
        case resources
        case status
        case useGraphRAG
        case graphStatus
        case graphProgress
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        resources = try container.decode([Resource].self, forKey: .resources)
        status = try container.decodeIfPresent(Status.self, forKey: .status)
        
        // Provide default values for new properties to support existing saved data
        useGraphRAG = try container.decodeIfPresent(Bool.self, forKey: .useGraphRAG) ?? false
        graphStatus = try container.decodeIfPresent(GraphStatus.self, forKey: .graphStatus)
        graphProgress = try container.decodeIfPresent(GraphProgress.self, forKey: .graphProgress)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(resources, forKey: .resources)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encode(useGraphRAG, forKey: .useGraphRAG)
        try container.encodeIfPresent(graphStatus, forKey: .graphStatus)
        try container.encodeIfPresent(graphProgress, forKey: .graphProgress)
    }
    
    /// Function to load a similarity index of type `SimilarityIndex`, must cache after initial load to improve performance
    /// - Returns: Returns a similarity index of type `SimilarityIndex`
    public func loadIndex() async -> SimilarityIndex {
        let startTime: Date = .now
        // Init index
        let similarityIndex: SimilarityIndex = await SimilarityIndex(
            model: DistilbertEmbeddings(),
            metric: CosineSimilarity()
        )
        // Load items
        for resource in self.resources {
            let indexItems: [IndexItem] = await resource.getIndexItems(
                resourcesDirUrl: self.indexUrl
            )
            similarityIndex.indexItems += indexItems
        }
        print("Loaded index in \(Date.now.timeIntervalSince(startTime)) seconds.")
        // Return similarity index
        return similarityIndex
    }
    
    /// Function to update resources index
    /// - Parameters:
    ///   - expertName: The name of the expert whose resources is being updated
    ///   - progressUpdate: Optional closure to receive progress updates
    @MainActor
    public mutating func updateResourcesIndex(
        expertName: String,
        progressUpdate: (@Sendable (GraphProgress) -> Void)? = nil
    ) async {
        // Add to task list
        let taskId: UUID = UUID()
        let taskName: String = String(localized: "Updating resource index for expert \"\(expertName)\"")
        withAnimation(.linear(duration: 0.3)) {
            LengthyTasksController.shared.addTask(
                id: taskId,
                task: taskName
            )
        }
        // Log
        self.status = .indexing
        if self.useGraphRAG {
            let initialProgress = GraphProgress(
                percentComplete: 0.0,
                stagePercentComplete: 0.0,
                stage: String(localized: "Preparing resources"),
                stageIdentifier: String(localized: "Preparing resources")
            )
            self.graphStatus = .building
            self.graphProgress = initialProgress
            progressUpdate?(initialProgress)
        } else {
            self.graphProgress = nil
        }
        let useGraphRAG: Bool = self.useGraphRAG
        Self.logger.notice("Updating resource index for expert \"\(expertName, privacy: .public)\" (Graph RAG: \(useGraphRAG ? "Enabled" : "Disabled"))")
        // Update for each file
        var resources: [Resource] = self.resources
        let indexUrl: URL = self.indexUrl
        var totalEntities: Int = 0
        var allGraphsSucceeded = true
        
        let totalResourceCount = max(resources.count, 1)
        var resourceWorkUnits: [Int] = []
        for index in resources.indices {
            var resource = resources[index]
            let units = resource.workloadEstimate(useGraphRAG: useGraphRAG)
            resourceWorkUnits.append(units)
            resources[index] = resource
        }
        let totalWorkUnits = max(resourceWorkUnits.reduce(0, +), 1)
        var completedWorkUnits: Double = 0
        
        var latestProgress: GraphProgress? = self.graphProgress
        
        for index in resources.indices {
            let resourceUnits = Double(resourceWorkUnits[index])
            // Update progress at start of each resource
            if useGraphRAG {
                let stageDescription = String(
                    localized: "Processing resource \(index + 1) of \(totalResourceCount)"
                )
                let stageIdentifier = String(localized: "Preparing resource")
                    .graphStageIdentifier(fallback: "preparing resource")
                let overallProgress = completedWorkUnits / Double(totalWorkUnits)
                let progress = GraphProgress(
                    percentComplete: overallProgress,
                    stagePercentComplete: 0.0,
                    stage: stageDescription,
                    stageIdentifier: stageIdentifier
                )
                self.graphStatus = .building
                self.graphProgress = progress
                progressUpdate?(progress)
                latestProgress = progress
            }
            
            let success = await resources[index].updateIndex(
                resourcesDirUrl: indexUrl,
                useGraphRAG: useGraphRAG,
                progressCallback: { update in
                    totalEntities = update.entities
                    guard useGraphRAG else { return }
                    
                    let resourceFraction = max(0.0, min(update.fractionComplete, 1.0))
                    let overallProgress = (
                        completedWorkUnits + (resourceUnits * resourceFraction)
                    ) / Double(totalWorkUnits)
                    let clampedOverall = max(0.0, min(overallProgress, 1.0))
                    
                    let stageDescription = update.stage.isEmpty ? String(
                        localized: "Processing resource \(index + 1) of \(totalResourceCount)"
                    ) : update.stage
                    let stageIdentifier = stageDescription.graphStageIdentifier(
                        fallback: String(localized: "Processing resource")
                    )
                    
                    let stageProgressRaw = update.total > 0 ? Double(update.current) / Double(update.total) : resourceFraction
                    let stageProgress = max(0.0, min(stageProgressRaw, 1.0))
                    let progressValue = GraphProgress(
                        percentComplete: clampedOverall,
                        stagePercentComplete: stageProgress,
                        stage: stageDescription,
                        stageIdentifier: stageIdentifier
                    )
                    latestProgress = progressValue
                    progressUpdate?(progressValue)
                }
            )
            
            if useGraphRAG && !success {
                allGraphsSucceeded = false
                Self.logger.error("Graph building failed for resource at index \(index)")
            }
            
            if useGraphRAG {
                completedWorkUnits += resourceUnits
            }
            
            if useGraphRAG, let latest = latestProgress {
                self.graphProgress = latest
            }
        }
        
        await MainActor.run {
            self.resources = resources
            
            // Update graph status based on results
            if self.useGraphRAG {
                self.graphStatus = allGraphsSucceeded ? .ready : .error
                if allGraphsSucceeded {
                    completedWorkUnits = Double(totalWorkUnits)
                    let finalProgress = GraphProgress(
                        percentComplete: 1.0,
                        stagePercentComplete: 1.0,
                        stage: String(localized: "Completed"),
                        stageIdentifier: String(localized: "Completed")
                    )
                    self.graphProgress = finalProgress
                    progressUpdate?(finalProgress)
                }
            } else {
                self.graphStatus = .ready
                self.graphProgress = nil
            }
        }
        
        // Log
        Self.logger.notice("Updated index for resources in expert \"\(expertName, privacy: .public)\"")
        if self.useGraphRAG {
            if allGraphsSucceeded {
                Self.logger.notice("Built knowledge graph with \(totalEntities) entities")
            } else {
                Self.logger.error("Some knowledge graphs failed to build")
            }
            
            // Clear progress now that indexing is complete
            self.graphProgress = nil
        }
        // Record removed resources
        let removedResources: [Resource] = self.resources.filter({
            !(!$0.wasMoved || $0.isWebResource)
        })
        let removedResourcesDescription: String = removedResources.map({
            return "\"\($0.name)\""
        }).joined(separator: ", ")
        if !removedResources.isEmpty {
            Task { @MainActor in
                Dialogs.showAlert(
                    title: String(localized: "Remove Resources"),
                    message: String(localized: "The resources \(removedResourcesDescription) were removed because they could not be located.")
                )
            }
        }
        // Remove resources
        await MainActor.run {
            self.resources = self.resources.filter({ !$0.wasMoved || $0.isWebResource })
        }
        // Remove from task list
        await MainActor.run {
            withAnimation(.linear(duration: 0.3)) {
                LengthyTasksController.shared.finishTask(
                    taskId: taskId
                )
            }
        }
        // Log
        Self.logger.notice("Finished updating resource index for expert \"\(expertName, privacy: .public)\"")
        self.status = .ready
        if self.useGraphRAG {
            self.graphStatus = .ready
        }
    }
    
    /// Function to load knowledge graph index
    /// - Returns: The merged knowledge graph for all resources
    public func loadGraphIndex() async -> KnowledgeGraph? {
        guard self.useGraphRAG else {
            return nil
        }
        
        let startTime: Date = .now
        let dbPath = self.indexUrl.appendingPathComponent("graph.sqlite").path
        
        Self.logger.info("Loading graph from: \(dbPath)")
        Self.logger.info("Number of resources to load: \(self.resources.count)")
        
        do {
            let database = try GraphDatabase(dbPath: dbPath)
            
            // Create a merged graph
            let mergedGraph = KnowledgeGraph(resourceId: self.id)
            
            // Load graphs for each resource
            for (index, resource) in self.resources.enumerated() {
                Self.logger.info("Loading graph for resource \(index + 1)/\(self.resources.count): \(resource.name) (ID: \(resource.id))")
                do {
                    let graph = try database.loadGraph(resourceId: resource.id)
                    Self.logger.info("Loaded graph for resource \(resource.name): \(graph.entityCount) entities, \(graph.relationshipCount) relationships, \(graph.communityCount) communities")
                    mergedGraph.merge(graph)
                } catch {
                    Self.logger.warning("Failed to load graph for resource \(resource.id): \(error.localizedDescription)")
                }
            }
            
            // If we didn't load any entities, try loading all entities from the database
            // This handles the case where resource IDs have changed but entities still exist
            if mergedGraph.entityCount == 0 {
                Self.logger.info("No entities loaded with resource IDs, attempting to load all entities from database")
                do {
                    let allEntitiesGraph = try database.loadAllGraphs()
                    Self.logger.info("Loaded all entities graph: \(allEntitiesGraph.entityCount) entities, \(allEntitiesGraph.relationshipCount) relationships, \(allEntitiesGraph.communityCount) communities")
                    mergedGraph.merge(allEntitiesGraph)
                } catch {
                    Self.logger.warning("Failed to load all entities: \(error.localizedDescription)")
                }
            }
            
            Self.logger.info("Loaded merged knowledge graph in \(Date.now.timeIntervalSince(startTime)) seconds")
            Self.logger.info("Final merged graph: \(mergedGraph.entityCount) entities, \(mergedGraph.relationshipCount) relationships, \(mergedGraph.communityCount) communities")
            return mergedGraph
            
        } catch {
            Self.logger.error("Failed to load knowledge graph: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Function to migrate to Graph RAG
    /// - Parameters:
    ///   - expertName: The name of the expert
    ///   - progressUpdate: Optional closure to receive progress updates
    @MainActor
    public mutating func migrateToGraphRAG(
        expertName: String,
        progressUpdate: (@Sendable (GraphProgress) -> Void)? = nil
    ) async {
        // Enable Graph RAG
        self.useGraphRAG = true
        self.graphStatus = .building
        
        Self.logger.notice("Migrating expert \"\(expertName)\" to Graph RAG")
        
        // Trigger full re-index
        await self.updateResourcesIndex(expertName: expertName, progressUpdate: progressUpdate)
        
        Self.logger.notice("Completed migration to Graph RAG for expert \"\(expertName)\"")
    }
    
    /// Function to initialize directory for the resources's index
    public mutating func setup() async {
        // Make directory
        do {
            try FileManager.default.createDirectory(
                at: self.indexUrl,
                withIntermediateDirectories: true
            )
        } catch {
            Self.logger.error("Failed to create directory for resources index: \(error, privacy: .public)")
        }
    }
    
    
    /// Function to add a resource without reindexing
    @MainActor
    public mutating func addResource(_ resource: Resource) {
        if self.resources.map(\.url).contains(resource.url) { return }
        Self.logger.notice("Adding resource \(resource.url, privacy: .public)")
        self.resources.append(resource)
    }
    
    /// Function to add multiple resources without reindexing
    @MainActor
    public mutating func addResources(_ resources: [Resource]) {
        for resource in resources {
            if self.resources.map(\.url).contains(resource.url) {
                continue
            }
            Self.logger.notice("Adding resource \(resource.url, privacy: .public)")
            self.resources.append(resource)
        }
    }
    
    /// Function to remove a resource without reindexing
    @MainActor
    public mutating func removeResource(_ resource: Resource) {
        for index in self.resources.indices  {
            if self.resources[index].id == resource.id {
                self.resources[index].deleteDirectory(
                    resourcesDirUrl: self.indexUrl
                )
                self.resources.remove(at: index)
                Self.logger.notice("Removing resource \(resource.url, privacy: .public)")
                break
            }
        }
    }
    
    /// Function to show the resources's index directory in Finder
    public func showIndexDirectory() async {
        await MainActor.run {
            FileManager.showItemInFinder(url: self.indexUrl)
        }
    }
    
}

// MARK: - Graph Progress Helpers

private extension String {
    
    func graphStageIdentifier(fallback: String) -> String {
        let sanitized = self.sanitizedStageIdentifier()
        if sanitized.isEmpty {
            let fallbackSanitized = fallback.sanitizedStageIdentifier()
            return fallbackSanitized.isEmpty ? fallback.lowercased() : fallbackSanitized
        }
        return sanitized
    }
    
    private func sanitizedStageIdentifier() -> String {
        var base = self
        let patterns = [
            "\\([^)]*\\)",
            "\\b\\d+\\/\\d+\\b",
            "\\b\\d+%\\b",
            "\\b\\d+\\b"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(base.startIndex..., in: base)
                base = regex.stringByReplacingMatches(in: base, options: [], range: range, withTemplate: "")
            }
        }
        if let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            let range = NSRange(base.startIndex..., in: base)
            base = whitespaceRegex.stringByReplacingMatches(in: base, options: [], range: range, withTemplate: " ")
        }
        base = base.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return base
    }
    
}
