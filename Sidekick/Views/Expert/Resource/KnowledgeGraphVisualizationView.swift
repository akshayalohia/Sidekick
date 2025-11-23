//
//  KnowledgeGraphVisualizationView.swift
//  Sidekick
//
//  Created on 1/27/25.
//

import SwiftUI

struct KnowledgeGraphVisualizationView: View {
    
    let expert: Expert
    @State private var knowledgeGraph: KnowledgeGraph?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedEntityId: UUID?
    @State private var zoomLevel: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var showRelationshipLabels: Bool = false
    @State private var selectedCommunityLevel: Int? = nil // nil = all levels, 0 = level 0, etc.
    @State private var isLegendExpanded: Bool = true

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading knowledge graph...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error loading graph")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if let graph = knowledgeGraph {
                    if graph.entityCount == 0 && graph.relationshipCount == 0 {
                        // Empty graph - show helpful message
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Empty Knowledge Graph")
                                .font(.headline)
                            Text("This expert's knowledge graph has no entities or relationships yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            if graph.communityCount > 0 {
                                Text("Note: \(graph.communityCount) communities exist in the database but have no associated entities.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        graphView(graph: graph)
                    }
                } else {
                    Text("No graph data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Knowledge Graph: \(expert.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if let graph = knowledgeGraph {
                    // Community level picker - separate item for better layout
                    ToolbarItem(placement: .automatic) {
                        Picker("Community Level", selection: $selectedCommunityLevel) {
                            Text("All Levels").tag(nil as Int?)
                            ForEach(communityLevels(graph: graph), id: \.self) { level in
                                Text("Level \(level)").tag(level as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 120)
                        .help("Select community level to display")
                    }

                    // Zoom controls - grouped together
                    ToolbarItem(placement: .automatic) {
                        HStack(spacing: 8) {
                            Button {
                                zoomLevel = max(0.1, zoomLevel - 0.2)
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            Text("\(Int(zoomLevel * 100))%")
                                .frame(width: 50)
                            Button {
                                zoomLevel = min(5.0, zoomLevel + 0.2)
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            Button {
                                resetView(for: graph)
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                        }
                    }

                    // Relationship labels toggle - separate item with visible label
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showRelationshipLabels.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showRelationshipLabels ? "tag.fill" : "tag")
                                Text("Labels")
                            }
                        }
                        .help("Toggle relationship labels")
                    }
                }
            }
        }
        .frame(minWidth: 1400, minHeight: 900)
        .task {
            await loadGraph()
        }
    }
    
    @ViewBuilder
    private func graphView(graph: KnowledgeGraph) -> some View {
        HStack(spacing: 0) {
            // Main graph visualization
            GraphCanvasView(
                graph: graph,
                zoomLevel: $zoomLevel,
                panOffset: $panOffset,
                showRelationshipLabels: showRelationshipLabels,
                selectedCommunityLevel: selectedCommunityLevel,
                selectedEntityId: $selectedEntityId
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Sidebar with statistics and details
            VStack(alignment: .leading, spacing: 16) {
                // Statistics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.headline)
                    Divider()
                    StatRow(label: "Entities", value: "\(graph.entityCount)")
                    StatRow(label: "Relationships", value: "\(graph.relationshipCount)")
                    // Filter communities to only count those with entities in the graph
                    let relevantCommunities = graph.communities.filter { community in
                        !community.memberEntityIds.filter { graph.findEntity(id: $0) != nil }.isEmpty
                    }
                    StatRow(label: "Communities", value: "\(relevantCommunities.count)")
                    if graph.communityCount != relevantCommunities.count {
                        Text("(\(graph.communityCount) total in database)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Legend
                DisclosureGroup(isExpanded: $isLegendExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Entity Types Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Entity Types")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            LegendItemView(color: .blue, label: "Person")
                            LegendItemView(color: .green, label: "Organization/Company")
                            LegendItemView(color: .orange, label: "Location/Place")
                            LegendItemView(color: .purple, label: "Concept/Idea")
                            LegendItemView(color: .gray, label: "Other/Unknown")

                            Text("Note: Node size = number of connections")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.top, 2)
                        }

                        Divider()

                        // Relationships Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Relationships")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 30, height: 3)
                                    .cornerRadius(1.5)
                                Text("Gray curved lines")
                                    .font(.caption2)
                            }

                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 30, height: 4)
                                    .cornerRadius(2)
                                Text("Thicker/opaque = stronger")
                                    .font(.caption2)
                            }

                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 2)
                                    .cornerRadius(1)
                                Text("Thinner/transparent = weaker")
                                    .font(.caption2)
                            }
                        }

                        Divider()

                        // Communities Section
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Communities (Background)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            LegendItemView(color: Color(red: 0.2, green: 0.6, blue: 0.9), label: "Level 0", shape: .roundedRect)
                            LegendItemView(color: Color(red: 0.3, green: 0.8, blue: 0.5), label: "Level 1", shape: .roundedRect)
                            LegendItemView(color: Color(red: 0.9, green: 0.6, blue: 0.2), label: "Level 2", shape: .roundedRect)
                            LegendItemView(color: Color(red: 0.7, green: 0.3, blue: 0.9), label: "Level 3", shape: .roundedRect)
                            LegendItemView(color: Color(red: 0.9, green: 0.4, blue: 0.6), label: "Level 4+", shape: .roundedRect)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Legend")
                        .font(.headline)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Selected entity details
                if let selectedId = selectedEntityId,
                   let entity = graph.findEntity(id: selectedId) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entity Details")
                            .font(.headline)
                        Divider()
                        Text(entity.name)
                            .font(.title3)
                            .bold()
                        Text("Type: \(entity.type)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !entity.description.isEmpty {
                            Text(entity.description)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                        
                        // Related entities
                        let related = graph.getRelatedEntities(for: selectedId)
                        if !related.isEmpty {
                            Divider()
                            Text("Related Entities (\(related.count))")
                                .font(.subheadline)
                                .bold()
                            ForEach(related.prefix(5)) { entity in
                                Text("• \(entity.name)")
                                    .font(.caption)
                            }
                            if related.count > 5 {
                                Text("... and \(related.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .frame(width: 250)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func resetView(for graph: KnowledgeGraph) {
        // Reset zoom to 1.0 and center pan to show the graph
        zoomLevel = 1.0
        panOffset = .zero
    }

    private func communityLevels(graph: KnowledgeGraph) -> [Int] {
        // Get unique community levels available in the graph
        let levels = Set(graph.communities.map { $0.level })
        return levels.sorted()
    }

    private func loadGraph() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Debug: Check resources
            print("Loading graph for expert: \(expert.name)")
            print("Number of resources: \(expert.resources.resources.count)")
            for (index, resource) in expert.resources.resources.enumerated() {
                print("Resource \(index): \(resource.name) (ID: \(resource.id))")
            }
            
            let graph = await expert.resources.loadGraphIndex()
            await MainActor.run {
                self.knowledgeGraph = graph
                self.isLoading = false
                if graph == nil {
                    self.errorMessage = "No knowledge graph found. Make sure Graph RAG is enabled and indexing is complete."
                } else {
                    // Debug logging
                    print("Loaded graph: \(graph!.entityCount) entities, \(graph!.relationshipCount) relationships, \(graph!.communityCount) communities")
                    print("Graph resource ID: \(graph!.resourceId)")
                    if graph!.entityCount == 0 {
                        print("Warning: Graph has 0 entities.")
                        print("Entities in graph: \(graph!.entities.count)")
                        print("Relationships in graph: \(graph!.relationships.count)")
                        print("Communities in graph: \(graph!.communities.count)")
                        
                        // Check if we can query the database directly
                        Task {
                            await self.diagnoseDatabase()
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("Error loading graph: \(error)")
            }
        }
    }
    
    private func diagnoseDatabase() async {
        let dbPath = expert.resources.indexUrl.appendingPathComponent("graph.sqlite").path
        print("Database path: \(dbPath)")
        
        // Check if database exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dbPath) {
            print("Database file exists")
            
            // Try to query directly
            do {
                let database = try GraphDatabase(dbPath: dbPath)
                // We can't easily query without exposing internals, but we can check file size
                if let attributes = try? fileManager.attributesOfItem(atPath: dbPath),
                   let fileSize = attributes[.size] as? Int64 {
                    print("Database file size: \(fileSize) bytes")
                }
            } catch {
                print("Could not open database: \(error)")
            }
        } else {
            print("Database file does NOT exist at: \(dbPath)")
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .font(.caption)
    }
}

private struct LegendItemView: View {
    enum Shape {
        case circle
        case roundedRect
    }

    let color: Color
    let label: String
    var shape: Shape = .circle

    var body: some View {
        HStack(spacing: 8) {
            Group {
                switch shape {
                case .circle:
                    Circle()
                        .fill(color.opacity(0.7))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(color, lineWidth: 1)
                        )
                case .roundedRect:
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(width: 20, height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            Text(label)
                .font(.caption2)
        }
    }
}

private struct GraphCanvasView: View {
    let graph: KnowledgeGraph
    @Binding var zoomLevel: CGFloat
    @Binding var panOffset: CGSize
    let showRelationshipLabels: Bool
    let selectedCommunityLevel: Int? // nil = all levels, specific level = filter to that level
    @Binding var selectedEntityId: UUID?

    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var canvasSize: CGSize = CGSize(width: 1200, height: 1200)
    @State private var layoutCalculated: Bool = false
    @State private var layoutProgress: Double = 0.0
    @State private var isCalculatingLayout: Bool = false
    @State private var viewportRect: CGRect = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @GestureState private var gestureMagnification: CGFloat = 1.0
    
    // All entities - no hard limit, viewport culling happens during rendering
    private var displayEntities: [GraphEntity] {
        return graph.entities
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Background
                Color(NSColor.textBackgroundColor)

                if displayEntities.isEmpty {
                    // Show message when no entities
                    VStack(spacing: 16) {
                        Image(systemName: "network")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No entities to display")
                            .font(.headline)
                        Text("The knowledge graph has \(graph.entityCount) entities, but none are available for visualization.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    Canvas { context, size in
                        guard !displayEntities.isEmpty else { return }

                        // Apply zoom and pan transformations
                        // Order: translate first (pan), then scale (zoom)
                        // This centers zoom on viewport center
                        var transformedContext = context

                        // Center point for zoom
                        let centerX = size.width / 2
                        let centerY = size.height / 2

                        // Combine actual pan offset with gesture offset
                        let totalPanOffset = CGSize(
                            width: panOffset.width + gestureOffset.width,
                            height: panOffset.height + gestureOffset.height
                        )

                        // Apply pan offset
                        transformedContext.translateBy(x: totalPanOffset.width, y: totalPanOffset.height)

                        // Apply zoom around the center point
                        transformedContext.translateBy(x: centerX, y: centerY)
                        transformedContext.scaleBy(x: zoomLevel, y: zoomLevel)
                        transformedContext.translateBy(x: -centerX, y: -centerY)

                        // Calculate visible bounds for viewport culling
                        let visibleBounds = calculateVisibleBounds(size: size)

                        // Draw communities as background regions
                        drawCommunities(context: transformedContext, size: size, visibleBounds: visibleBounds)

                        // Draw relationships (edges)
                        drawRelationships(context: transformedContext, visibleBounds: visibleBounds)

                        // Draw entities (nodes)
                        drawEntities(context: transformedContext, size: size, visibleBounds: visibleBounds)
                    }
                    .onAppear {
                        if !layoutCalculated {
                            calculateLayout(size: geometry.size)
                        }
                        viewportRect = CGRect(origin: .zero, size: geometry.size)
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        canvasSize = newSize
                        viewportRect = CGRect(origin: .zero, size: newSize)
                        calculateLayout(size: newSize)
                    }
                    .onChange(of: displayEntities.count) { oldCount, newCount in
                        // Recalculate layout if entities change
                        if newCount > 0 {
                            calculateLayout(size: geometry.size)
                        } else {
                            nodePositions = [:]
                            layoutCalculated = false
                        }
                    }
                    .gesture(
                        // Pan gesture with DragGesture
                        DragGesture(minimumDistance: 5)
                            .updating($gestureOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                // Only update pan offset if it was a drag, not a tap
                                if abs(value.translation.width) > 5 || abs(value.translation.height) > 5 {
                                    panOffset.width += value.translation.width
                                    panOffset.height += value.translation.height
                                } else {
                                    // Handle as tap for selection
                                    handleTap(at: value.location, size: canvasSize)
                                }
                            }
                    )
                    .gesture(
                        // Magnification gesture for zoom with 80% reduced sensitivity
                        MagnificationGesture()
                            .onChanged { value in
                                // Reduce sensitivity by 80%: dampened zoom
                                let dampenedValue = 1.0 + (value - 1.0) * 0.2
                                let newZoom = zoomLevel * dampenedValue
                                zoomLevel = max(0.1, min(5.0, newZoom))
                            }
                    )

                    // Progress indicator overlay
                    if isCalculatingLayout {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Calculating layout...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: layoutProgress)
                                .frame(width: 200)
                            Text("\(Int(layoutProgress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }

                    // Mini-map overlay
                    MiniMapView(
                        nodePositions: nodePositions,
                        displayEntities: displayEntities,
                        canvasSize: canvasSize,
                        viewportRect: viewportRect,
                        graph: graph
                    )
                    .frame(width: 150, height: 150)
                    .padding(16)
                }
            }
        }
    }
    
    private func calculateVisibleBounds(size: CGSize) -> CGRect {
        // Calculate the viewport bounds in world coordinates
        // Account for zoom and pan to determine what's actually visible

        let centerX = size.width / 2
        let centerY = size.height / 2

        // Combine actual pan offset with gesture offset
        let totalPanOffset = CGSize(
            width: panOffset.width + gestureOffset.width,
            height: panOffset.height + gestureOffset.height
        )

        // Inverse of the transformations we apply in the canvas
        // Start with viewport rect
        var left = -totalPanOffset.width
        var right = size.width - totalPanOffset.width
        var top = -totalPanOffset.height
        var bottom = size.height - totalPanOffset.height

        // Apply inverse zoom transformation
        let invZoom = 1.0 / zoomLevel
        left = (left - centerX) * invZoom + centerX
        right = (right - centerX) * invZoom + centerX
        top = (top - centerY) * invZoom + centerY
        bottom = (bottom - centerY) * invZoom + centerY

        // Add margin for smooth culling (entities just outside viewport)
        let margin: CGFloat = 200

        return CGRect(
            x: left - margin,
            y: top - margin,
            width: right - left + 2 * margin,
            height: bottom - top + 2 * margin
        )
    }

    private func isEntityVisible(position: CGPoint, bounds: CGRect, nodeSize: CGFloat) -> Bool {
        // Check if entity is within visible bounds (with nodeSize padding)
        return bounds.insetBy(dx: -nodeSize, dy: -nodeSize).contains(position)
    }

    private func calculateLayout(size: CGSize) {
        let entities = displayEntities
        guard !entities.isEmpty else {
            nodePositions = [:]
            layoutCalculated = false
            return
        }

        // Run layout calculation asynchronously
        Task { @MainActor in
            isCalculatingLayout = true
            layoutProgress = 0.0

            // Clear existing positions
            var newPositions: [UUID: CGPoint] = [:]

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let canvasRadius = min(size.width, size.height) * 0.4

            // IMPROVED INITIAL POSITIONING: Community-aware layout
            // Build entity to community mapping (only for level 0 communities - most specific)
            let displayEntityIds = Set(entities.map { $0.id })
            let leafCommunities = graph.communities.filter { $0.level == 0 }
            var entityToCommunity: [UUID: UUID] = [:]

            for community in leafCommunities {
                for entityId in community.memberEntityIds {
                    if displayEntityIds.contains(entityId) {
                        entityToCommunity[entityId] = community.id
                    }
                }
            }

            // Group entities by community
            let relevantCommunities = leafCommunities.filter { community in
                !community.memberEntityIds.filter { displayEntityIds.contains($0) }.isEmpty
            }

            var communityGroups: [UUID: [GraphEntity]] = [:]
            var entitiesWithoutCommunity: [GraphEntity] = []

            for entity in entities {
                if let communityId = entityToCommunity[entity.id] {
                    if communityGroups[communityId] == nil {
                        communityGroups[communityId] = []
                    }
                    communityGroups[communityId]?.append(entity)
                } else {
                    entitiesWithoutCommunity.append(entity)
                }
            }

            // Position communities in a circle
            let communityCount = communityGroups.count + (entitiesWithoutCommunity.isEmpty ? 0 : 1)
            let communityAngleStep = (2 * .pi) / CGFloat(max(communityCount, 1))

            var currentCommunityIndex = 0

            // Place each community's entities in their region
            for (communityId, communityEntities) in communityGroups {
                let communityAngle = CGFloat(currentCommunityIndex) * communityAngleStep
                let communityCenterX = center.x + canvasRadius * 0.8 * cos(communityAngle)
                let communityCenterY = center.y + canvasRadius * 0.8 * sin(communityAngle)
                let communityCenter = CGPoint(x: communityCenterX, y: communityCenterY)

                // Place entities within this community in a smaller circle
                let communityRadius = min(100.0, canvasRadius * 0.2)
                let entityAngleStep = (2 * .pi) / CGFloat(max(communityEntities.count, 1))

                for (index, entity) in communityEntities.enumerated() {
                    let angle = CGFloat(index) * entityAngleStep
                    let x = communityCenter.x + communityRadius * cos(angle)
                    let y = communityCenter.y + communityRadius * sin(angle)
                    newPositions[entity.id] = CGPoint(x: x, y: y)
                }

                currentCommunityIndex += 1
            }

            // Place entities without community in their own region
            if !entitiesWithoutCommunity.isEmpty {
                let communityAngle = CGFloat(currentCommunityIndex) * communityAngleStep
                let communityCenterX = center.x + canvasRadius * 0.8 * cos(communityAngle)
                let communityCenterY = center.y + canvasRadius * 0.8 * sin(communityAngle)
                let communityCenter = CGPoint(x: communityCenterX, y: communityCenterY)

                let communityRadius = min(100.0, canvasRadius * 0.2)
                let entityAngleStep = (2 * .pi) / CGFloat(entitiesWithoutCommunity.count)

                for (index, entity) in entitiesWithoutCommunity.enumerated() {
                    let angle = CGFloat(index) * entityAngleStep
                    let x = communityCenter.x + communityRadius * cos(angle)
                    let y = communityCenter.y + communityRadius * sin(angle)
                    newPositions[entity.id] = CGPoint(x: x, y: y)
                }
            }

            nodePositions = newPositions
            layoutProgress = 0.1

            // IMPROVED FORCE-DIRECTED ADJUSTMENT: 100 iterations with early stopping
            let maxIterations = 100
            let stabilityThreshold: CGFloat = 1.0 // Total movement threshold for early stopping

            for iteration in 0..<maxIterations {
                var forces: [UUID: CGPoint] = [:]

                // ADAPTIVE DAMPING: Higher damping early, lower later
                let dampingFactor = 0.4 * (1.0 - CGFloat(iteration) / CGFloat(maxIterations) * 0.5)

                for entity in entities {
                    guard let pos = nodePositions[entity.id] else { continue }
                    var force = CGPoint.zero

                    // IMPROVED REPULSION: Stronger base repulsion for better separation
                    for otherEntity in entities where otherEntity.id != entity.id {
                        guard let otherPos = nodePositions[otherEntity.id] else { continue }
                        let dx = pos.x - otherPos.x
                        let dy = pos.y - otherPos.y
                        let distanceSquared = dx * dx + dy * dy
                        let distance = sqrt(distanceSquared)

                        if distance > 0 && distance < canvasRadius * 2 {
                            // Stronger repulsion: increased from 1000 to 3000
                            let repulsion = 3000.0 / max(distanceSquared, 400)
                            force.x += (dx / distance) * repulsion
                            force.y += (dy / distance) * repulsion
                        }
                    }

                    // IMPROVED ATTRACTION: Stronger attraction to connected nodes
                    let relationships = graph.getRelationships(for: entity.id)
                    for rel in relationships {
                        let connectedId = rel.sourceEntityId == entity.id ? rel.targetEntityId : rel.sourceEntityId
                        guard let connectedPos = nodePositions[connectedId],
                              displayEntityIds.contains(connectedId),
                              connectedId != entity.id else { continue }

                        let dx = connectedPos.x - pos.x
                        let dy = connectedPos.y - pos.y
                        let distance = sqrt(dx * dx + dy * dy)

                        if distance > 0 {
                            // Increased attraction strength from 0.01 to 0.03
                            var attractionStrength = distance * 0.03

                            // COMMUNITY-AWARE FORCES: 2x stronger attraction for same-community entities
                            let entityCommunity = entityToCommunity[entity.id]
                            let connectedCommunity = entityToCommunity[connectedId]
                            if entityCommunity != nil && entityCommunity == connectedCommunity {
                                attractionStrength *= 2.0
                            }

                            // Apply relationship strength multiplier
                            attractionStrength *= CGFloat(rel.strength)

                            force.x += (dx / distance) * attractionStrength
                            force.y += (dy / distance) * attractionStrength
                        }
                    }

                    // COMMUNITY COHESION: Additional attraction to community center
                    if let communityId = entityToCommunity[entity.id],
                       let communityEntities = communityGroups[communityId] {
                        // Calculate community centroid
                        var centroidX: CGFloat = 0
                        var centroidY: CGFloat = 0
                        var count = 0

                        for communityEntity in communityEntities {
                            if let communityEntityPos = nodePositions[communityEntity.id] {
                                centroidX += communityEntityPos.x
                                centroidY += communityEntityPos.y
                                count += 1
                            }
                        }

                        if count > 0 {
                            centroidX /= CGFloat(count)
                            centroidY /= CGFloat(count)

                            let dx = centroidX - pos.x
                            let dy = centroidY - pos.y
                            let distance = sqrt(dx * dx + dy * dy)

                            if distance > 0 {
                                // Gentle pull towards community center
                                let cohesionStrength = distance * 0.005
                                force.x += (dx / distance) * cohesionStrength
                                force.y += (dy / distance) * cohesionStrength
                            }
                        }
                    }

                    forces[entity.id] = force
                }

                // INTER-COMMUNITY REPULSION: Push overlapping communities apart
                // Calculate centroids for each community
                var communityCentroids: [UUID: CGPoint] = [:]
                for (communityId, communityEntities) in communityGroups {
                    var centroidX: CGFloat = 0
                    var centroidY: CGFloat = 0
                    var count = 0

                    for communityEntity in communityEntities {
                        if let pos = nodePositions[communityEntity.id] {
                            centroidX += pos.x
                            centroidY += pos.y
                            count += 1
                        }
                    }

                    if count > 0 {
                        communityCentroids[communityId] = CGPoint(
                            x: centroidX / CGFloat(count),
                            y: centroidY / CGFloat(count)
                        )
                    }
                }

                // Apply repulsion between community centroids
                let communityIds = Array(communityCentroids.keys)
                for i in 0..<communityIds.count {
                    for j in (i+1)..<communityIds.count {
                        let communityId1 = communityIds[i]
                        let communityId2 = communityIds[j]

                        guard let centroid1 = communityCentroids[communityId1],
                              let centroid2 = communityCentroids[communityId2],
                              let entities1 = communityGroups[communityId1],
                              let entities2 = communityGroups[communityId2] else { continue }

                        let dx = centroid1.x - centroid2.x
                        let dy = centroid1.y - centroid2.y
                        let distanceSquared = dx * dx + dy * dy
                        let distance = sqrt(distanceSquared)

                        if distance > 0 {
                            // Strong repulsion between community centroids
                            let repulsionForce = 7500.0 / max(distanceSquared, 100)
                            let forceX = (dx / distance) * repulsionForce
                            let forceY = (dy / distance) * repulsionForce

                            // Distribute force to all entities in community 1
                            for entity in entities1 {
                                if let currentForce = forces[entity.id] {
                                    forces[entity.id] = CGPoint(
                                        x: currentForce.x + forceX / CGFloat(entities1.count),
                                        y: currentForce.y + forceY / CGFloat(entities1.count)
                                    )
                                }
                            }

                            // Distribute opposite force to all entities in community 2
                            for entity in entities2 {
                                if let currentForce = forces[entity.id] {
                                    forces[entity.id] = CGPoint(
                                        x: currentForce.x - forceX / CGFloat(entities2.count),
                                        y: currentForce.y - forceY / CGFloat(entities2.count)
                                    )
                                }
                            }
                        }
                    }
                }

                // Apply forces and track total movement
                var totalMovement: CGFloat = 0
                for entity in entities {
                    guard let pos = nodePositions[entity.id],
                          let force = forces[entity.id] else { continue }

                    let newX = pos.x + force.x * dampingFactor
                    let newY = pos.y + force.y * dampingFactor

                    // Calculate movement
                    let movement = sqrt(pow(newX - pos.x, 2) + pow(newY - pos.y, 2))
                    totalMovement += movement

                    nodePositions[entity.id] = CGPoint(x: newX, y: newY)
                }

                // Update progress
                layoutProgress = 0.1 + (0.9 * Double(iteration + 1) / Double(maxIterations))

                // EARLY STOPPING: If layout has stabilized, stop iterating
                if totalMovement < stabilityThreshold {
                    print("Layout stabilized after \(iteration + 1) iterations (movement: \(totalMovement))")
                    break
                }
            }

            layoutCalculated = true
            isCalculatingLayout = false
            layoutProgress = 1.0
        }
    }

    
    private func drawCommunities(context: GraphicsContext, size: CGSize, visibleBounds: CGRect) {
        // Filter communities to only those with entities in the display set
        let displayEntityIds = Set(displayEntities.map { $0.id })
        let relevantCommunities = graph.communities.filter { community in
            // Only show communities that have at least one entity in the display set
            let hasRelevantEntities = !community.memberEntityIds.filter { displayEntityIds.contains($0) }.isEmpty

            // Filter by selected level if specified
            if let selectedLevel = selectedCommunityLevel {
                return hasRelevantEntities && community.level == selectedLevel
            } else {
                return hasRelevantEntities
            }
        }.sorted { $0.level < $1.level }

        for community in relevantCommunities {
            // Filter member entities to only those in display set
            let relevantMemberIds = community.memberEntityIds.filter { displayEntityIds.contains($0) }
            guard !relevantMemberIds.isEmpty else { continue }

            // Get positions of entities in this community
            let memberPositions = relevantMemberIds.compactMap { nodePositions[$0] }
            guard !memberPositions.isEmpty else { continue }

            // Calculate bounding box with better padding
            let minX = memberPositions.map { $0.x }.min() ?? 0
            let maxX = memberPositions.map { $0.x }.max() ?? 0
            let minY = memberPositions.map { $0.y }.min() ?? 0
            let maxY = memberPositions.map { $0.y }.max() ?? 0

            // Improved color scheme with higher contrast
            let colors: [Color] = [
                Color(red: 0.2, green: 0.6, blue: 0.9),  // Bright blue
                Color(red: 0.3, green: 0.8, blue: 0.5),  // Bright green
                Color(red: 0.9, green: 0.6, blue: 0.2),  // Bright orange
                Color(red: 0.7, green: 0.3, blue: 0.9),  // Bright purple
                Color(red: 0.9, green: 0.4, blue: 0.6)   // Bright pink
            ]
            let baseColor = colors[community.level % colors.count]

            // Add more padding for better visual separation
            let padding: CGFloat = 100
            let rect = CGRect(
                x: minX - padding,
                y: minY - padding,
                width: maxX - minX + (padding * 2),
                height: maxY - minY + (padding * 2)
            )

            // Viewport culling for communities - skip if not visible
            guard visibleBounds.intersects(rect) else { continue }

            // Use rounded rectangle with more opacity for better visibility
            context.fill(
                Path(roundedRect: rect, cornerRadius: 20),
                with: .color(baseColor.opacity(0.15))
            )

            // Add border for better definition
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 20),
                with: .color(baseColor.opacity(0.4)),
                lineWidth: 2
            )

            // Draw community label with better contrast
            if !memberPositions.isEmpty {
                let labelBg = Path(roundedRect: CGRect(
                    x: minX - padding + 8,
                    y: minY - padding + 8,
                    width: min(CGFloat(community.title.count) * 6 + 12, rect.width - 16),
                    height: 18
                ), cornerRadius: 4)

                context.fill(labelBg, with: .color(baseColor.opacity(0.3)))

                let resolvedText = Text(community.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(baseColor.opacity(0.9))
                context.draw(resolvedText, at: CGPoint(x: minX - padding + 14, y: minY - padding + 17), anchor: .leading)
            }
        }
    }
    
    private func drawRelationships(context: GraphicsContext, visibleBounds: CGRect) {
        let displayEntityIds = Set(displayEntities.map { $0.id })

        for relationship in graph.relationships {
            // Only draw if both entities are in display set
            guard displayEntityIds.contains(relationship.sourceEntityId),
                  displayEntityIds.contains(relationship.targetEntityId),
                  let sourcePos = nodePositions[relationship.sourceEntityId],
                  let targetPos = nodePositions[relationship.targetEntityId] else {
                continue
            }

            // Viewport culling for relationships - skip if both endpoints are outside viewport
            let sourceVisible = visibleBounds.contains(sourcePos)
            let targetVisible = visibleBounds.contains(targetPos)
            guard sourceVisible || targetVisible else { continue }

            // Calculate midpoint and control point for curved edge
            let midX = (sourcePos.x + targetPos.x) / 2
            let midY = (sourcePos.y + targetPos.y) / 2

            // Vector perpendicular to the line for control point offset
            let dx = targetPos.x - sourcePos.x
            let dy = targetPos.y - sourcePos.y
            let distance = sqrt(dx * dx + dy * dy)

            // Perpendicular vector (rotated 90 degrees)
            let perpX = -dy / distance
            let perpY = dx / distance

            // Offset for curve (proportional to distance for natural curves)
            let curveOffset = min(distance * 0.2, 50.0)
            let controlPoint = CGPoint(
                x: midX + perpX * curveOffset,
                y: midY + perpY * curveOffset
            )

            // Draw curved line using quadratic curve
            var path = Path()
            path.move(to: sourcePos)
            path.addQuadCurve(to: targetPos, control: controlPoint)

            // Color and width based on relationship strength
            let opacity = Double(relationship.strength) * 0.5 + 0.3
            let baseLineWidth = CGFloat(relationship.strength) * 2 + 1
            let scaledLineWidth = baseLineWidth

            context.stroke(
                path,
                with: .color(.gray.opacity(opacity)),
                lineWidth: scaledLineWidth
            )

            // Draw relationship label if enabled, zoom level is high enough, and label is visible
            if showRelationshipLabels {
                let midPoint = CGPoint(
                    x: (sourcePos.x + targetPos.x) / 2,
                    y: (sourcePos.y + targetPos.y) / 2
                )

                // Only draw label if midpoint is visible
                guard visibleBounds.contains(midPoint) else { continue }

                let labelText = relationship.description.isEmpty ? relationship.relationshipType : relationship.description
                let truncatedLabel = labelText.count > 20 ? String(labelText.prefix(17)) + "..." : labelText

                // Position label at the control point (curve apex)
                let resolvedText = Text(truncatedLabel)
                    .font(.system(size: max(8, 9)))
                    .foregroundColor(.primary)

                // Draw background for better readability
                let labelWidth = CGFloat(truncatedLabel.count) * 6
                let labelHeight: CGFloat = 14
                let labelBg = Path(roundedRect: CGRect(
                    x: controlPoint.x - labelWidth / 2,
                    y: controlPoint.y - labelHeight / 2,
                    width: labelWidth,
                    height: labelHeight
                ), cornerRadius: 3)

                context.fill(labelBg, with: .color(Color(NSColor.textBackgroundColor).opacity(0.9)))
                context.stroke(labelBg, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)

                context.draw(resolvedText, at: controlPoint, anchor: .center)
            }
        }
    }
    
    private func drawEntities(context: GraphicsContext, size: CGSize, visibleBounds: CGRect) {
        for entity in displayEntities {
            guard let pos = nodePositions[entity.id] else { continue }

            // Node size based on number of connections
            let relationships = graph.getRelationships(for: entity.id)
            let baseNodeSize: CGFloat = min(max(CGFloat(relationships.count) * 2 + 20, 20), 50)
            let nodeSize = baseNodeSize

            // Viewport culling - skip entities not in view
            guard isEntityVisible(position: pos, bounds: visibleBounds, nodeSize: baseNodeSize) else {
                continue
            }

            let isSelected = selectedEntityId == entity.id

            // Node color based on entity type
            let nodeColor = colorForEntityType(entity.type)

            // Draw node circle
            let circle = Path(ellipseIn: CGRect(
                x: pos.x - nodeSize / 2,
                y: pos.y - nodeSize / 2,
                width: nodeSize,
                height: nodeSize
            ))

            context.fill(circle, with: .color(nodeColor.opacity(0.7)))

            let strokeWidth: CGFloat = isSelected ? 3 : 2
            if isSelected {
                context.stroke(circle, with: .color(.blue), lineWidth: strokeWidth)
            } else {
                context.stroke(circle, with: .color(nodeColor), lineWidth: strokeWidth)
            }

            // Draw entity name
            let maxChars = 15
            let displayName = entity.name.count > maxChars ? String(entity.name.prefix(maxChars - 3)) + "..." : entity.name

            let baseFontSize: CGFloat = 9
            let fontSize = baseFontSize

            let resolvedText = Text(displayName)
                .font(.system(size: max(7, fontSize)))
                .foregroundColor(.primary)

            context.draw(resolvedText, at: CGPoint(x: pos.x, y: pos.y + nodeSize / 2 + 8), anchor: .center)
        }
    }
    
    private func colorForEntityType(_ type: String) -> Color {
        let typeLower = type.lowercased()
        if typeLower.contains("person") {
            return .blue
        } else if typeLower.contains("organization") || typeLower.contains("company") {
            return .green
        } else if typeLower.contains("location") || typeLower.contains("place") {
            return .orange
        } else if typeLower.contains("concept") || typeLower.contains("idea") {
            return .purple
        } else {
            return .gray
        }
    }
    
    private func handleTap(at location: CGPoint, size: CGSize) {
        // Transform tap location to account for current zoom and pan
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Inverse transformation to get world coordinates from screen coordinates
        var worldX = location.x - panOffset.width
        var worldY = location.y - panOffset.height

        // Apply inverse zoom
        let invZoom = 1.0 / zoomLevel
        worldX = (worldX - centerX) * invZoom + centerX
        worldY = (worldY - centerY) * invZoom + centerY

        let worldLocation = CGPoint(x: worldX, y: worldY)

        // Find entity at tap location
        for entity in displayEntities {
            guard let pos = nodePositions[entity.id] else { continue }
            let relationships = graph.getRelationships(for: entity.id)
            let nodeSize: CGFloat = min(max(CGFloat(relationships.count) * 2 + 20, 20), 50)

            let distance = sqrt(
                pow(worldLocation.x - pos.x, 2) + pow(worldLocation.y - pos.y, 2)
            )

            if distance <= nodeSize / 2 + 10 {
                selectedEntityId = entity.id
                return
            }
        }

        // Deselect if tapping empty space
        selectedEntityId = nil
    }
}

// MARK: - Mini-Map Component
private struct MiniMapView: View {
    let nodePositions: [UUID: CGPoint]
    let displayEntities: [GraphEntity]
    let canvasSize: CGSize
    let viewportRect: CGRect
    let graph: KnowledgeGraph

    var body: some View {
        Canvas { context, size in
            // Background
            context.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                with: .color(Color(NSColor.controlBackgroundColor).opacity(0.95))
            )

            // Border
            context.stroke(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                with: .color(.gray.opacity(0.5)),
                lineWidth: 1
            )

            guard !nodePositions.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return }

            // Calculate bounds of all nodes
            let positions = nodePositions.values
            guard !positions.isEmpty else { return }

            let minX = positions.map { $0.x }.min() ?? 0
            let maxX = positions.map { $0.x }.max() ?? 0
            let minY = positions.map { $0.y }.min() ?? 0
            let maxY = positions.map { $0.y }.max() ?? 0

            let graphWidth = maxX - minX
            let graphHeight = maxY - minY

            guard graphWidth > 0, graphHeight > 0 else { return }

            // Scale factor to fit graph in mini-map with padding
            let padding: CGFloat = 10
            let availableWidth = size.width - (padding * 2)
            let availableHeight = size.height - (padding * 2)

            let scaleX = availableWidth / graphWidth
            let scaleY = availableHeight / graphHeight
            let scale = min(scaleX, scaleY)

            // Center the graph in mini-map
            let scaledGraphWidth = graphWidth * scale
            let scaledGraphHeight = graphHeight * scale
            let offsetX = padding + (availableWidth - scaledGraphWidth) / 2
            let offsetY = padding + (availableHeight - scaledGraphHeight) / 2

            // Helper function to transform coordinates
            func transformPoint(_ point: CGPoint) -> CGPoint {
                return CGPoint(
                    x: offsetX + (point.x - minX) * scale,
                    y: offsetY + (point.y - minY) * scale
                )
            }

            // Draw relationships as simple lines
            let displayEntityIds = Set(displayEntities.map { $0.id })
            for relationship in graph.relationships {
                guard displayEntityIds.contains(relationship.sourceEntityId),
                      displayEntityIds.contains(relationship.targetEntityId),
                      let sourcePos = nodePositions[relationship.sourceEntityId],
                      let targetPos = nodePositions[relationship.targetEntityId] else {
                    continue
                }

                let transformedSource = transformPoint(sourcePos)
                let transformedTarget = transformPoint(targetPos)

                var path = Path()
                path.move(to: transformedSource)
                path.addLine(to: transformedTarget)

                context.stroke(
                    path,
                    with: .color(.gray.opacity(0.3)),
                    lineWidth: 0.5
                )
            }

            // Draw nodes
            for entity in displayEntities {
                guard let pos = nodePositions[entity.id] else { continue }

                let transformedPos = transformPoint(pos)
                let nodeSize: CGFloat = 3

                let circle = Path(ellipseIn: CGRect(
                    x: transformedPos.x - nodeSize / 2,
                    y: transformedPos.y - nodeSize / 2,
                    width: nodeSize,
                    height: nodeSize
                ))

                context.fill(circle, with: .color(.blue.opacity(0.6)))
            }

            // Draw viewport indicator
            if viewportRect.width > 0, viewportRect.height > 0 {
                let viewportTopLeft = transformPoint(CGPoint(x: minX, y: minY))
                let viewportBottomRight = transformPoint(CGPoint(x: maxX, y: maxY))

                let viewportWidth = viewportBottomRight.x - viewportTopLeft.x
                let viewportHeight = viewportBottomRight.y - viewportTopLeft.y

                let viewportPath = Path(roundedRect: CGRect(
                    x: viewportTopLeft.x,
                    y: viewportTopLeft.y,
                    width: viewportWidth,
                    height: viewportHeight
                ), cornerRadius: 2)

                context.stroke(
                    viewportPath,
                    with: .color(.blue.opacity(0.8)),
                    lineWidth: 2
                )

                context.fill(
                    viewportPath,
                    with: .color(.blue.opacity(0.1))
                )
            }
        }
        .background(Color.clear)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

