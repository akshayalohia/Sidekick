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
                if knowledgeGraph != nil {
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            Button {
                                zoomLevel = max(0.5, zoomLevel - 0.2)
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            Text("\(Int(zoomLevel * 100))%")
                                .frame(width: 50)
                            Button {
                                zoomLevel = min(2.0, zoomLevel + 0.2)
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            Button {
                                zoomLevel = 1.0
                                panOffset = .zero
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
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
                zoomLevel: zoomLevel,
                panOffset: panOffset,
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

private struct GraphCanvasView: View {
    let graph: KnowledgeGraph
    let zoomLevel: CGFloat
    let panOffset: CGSize
    @Binding var selectedEntityId: UUID?
    
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var canvasSize: CGSize = CGSize(width: 1200, height: 1200)
    @State private var layoutCalculated: Bool = false
    
    // Limit entities for performance
    private var displayEntities: [GraphEntity] {
        let entities = graph.entities
        // Show top entities by number of relationships
        let entityConnections = Dictionary(grouping: graph.relationships) { $0.sourceEntityId }
            .merging(Dictionary(grouping: graph.relationships) { $0.targetEntityId }) { $0 + $1 }
        
        let sorted = entities.sorted { entity1, entity2 in
            let count1 = entityConnections[entity1.id]?.count ?? 0
            let count2 = entityConnections[entity2.id]?.count ?? 0
            return count1 > count2
        }
        
        // Limit to top 100 for performance
        return Array(sorted.prefix(100))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                        
                        // Draw communities as background regions
                        drawCommunities(context: context, size: size)
                        
                        // Draw relationships (edges)
                        drawRelationships(context: context)
                        
                        // Draw entities (nodes)
                        drawEntities(context: context, size: size)
                    }
                    .onAppear {
                        if !layoutCalculated {
                            calculateLayout(size: geometry.size)
                        }
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        canvasSize = newSize
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
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTap(at: value.location)
                            }
                    )
                }
            }
        }
    }
    
    private func calculateLayout(size: CGSize) {
        let entities = displayEntities
        guard !entities.isEmpty else {
            nodePositions = [:]
            layoutCalculated = false
            return
        }
        
        // Clear existing positions
        var newPositions: [UUID: CGPoint] = [:]
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        let angleStep = (2 * .pi) / CGFloat(entities.count)
        
        // Circular layout
        for (index, entity) in entities.enumerated() {
            let angle = CGFloat(index) * angleStep
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            newPositions[entity.id] = CGPoint(x: x, y: y)
        }
        
        nodePositions = newPositions
        layoutCalculated = true
        
        // Simple force-directed adjustment (just a few iterations)
        for _ in 0..<20 {
            var forces: [UUID: CGPoint] = [:]
            
            for entity in entities {
                guard let pos = nodePositions[entity.id] else { continue }
                var force = CGPoint.zero
                
                // Repulsion from other nodes
                for otherEntity in entities where otherEntity.id != entity.id {
                    guard let otherPos = nodePositions[otherEntity.id] else { continue }
                    let dx = pos.x - otherPos.x
                    let dy = pos.y - otherPos.y
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > 0 {
                        let repulsion = 1000.0 / (distance * distance)
                        force.x += (dx / distance) * repulsion
                        force.y += (dy / distance) * repulsion
                    }
                }
                
                // Attraction to connected nodes
                let relationships = graph.getRelationships(for: entity.id)
                for rel in relationships {
                    let connectedId = rel.sourceEntityId == entity.id ? rel.targetEntityId : rel.sourceEntityId
                    guard let connectedPos = nodePositions[connectedId],
                          connectedId != entity.id else { continue }
                    let dx = connectedPos.x - pos.x
                    let dy = connectedPos.y - pos.y
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > 0 {
                        let attraction = distance * 0.01
                        force.x += (dx / distance) * attraction
                        force.y += (dy / distance) * attraction
                    }
                }
                
                forces[entity.id] = force
            }
            
            // Apply forces
            for entity in entities {
                guard let pos = nodePositions[entity.id],
                      let force = forces[entity.id] else { continue }
                let newX = pos.x + force.x * 0.1
                let newY = pos.y + force.y * 0.1
                nodePositions[entity.id] = CGPoint(x: newX, y: newY)
            }
        }
    }
    
    private func drawCommunities(context: GraphicsContext, size: CGSize) {
        // Filter communities to only those with entities in the display set
        let displayEntityIds = Set(displayEntities.map { $0.id })
        let relevantCommunities = graph.communities.filter { community in
            // Only show communities that have at least one entity in the display set
            !community.memberEntityIds.filter { displayEntityIds.contains($0) }.isEmpty
        }.sorted { $0.level < $1.level }
        
        for community in relevantCommunities {
            // Filter member entities to only those in display set
            let relevantMemberIds = community.memberEntityIds.filter { displayEntityIds.contains($0) }
            guard !relevantMemberIds.isEmpty else { continue }
            
            // Get positions of entities in this community
            let memberPositions = relevantMemberIds.compactMap { nodePositions[$0] }
            guard !memberPositions.isEmpty else { continue }
            
            // Calculate bounding box
            let minX = memberPositions.map { $0.x }.min() ?? 0
            let maxX = memberPositions.map { $0.x }.max() ?? 0
            let minY = memberPositions.map { $0.y }.min() ?? 0
            let maxY = memberPositions.map { $0.y }.max() ?? 0
            
            // Draw community region with color based on level
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
            let color = colors[community.level % colors.count].opacity(0.1)
            
            let rect = CGRect(
                x: minX - 30,
                y: minY - 30,
                width: maxX - minX + 60,
                height: maxY - minY + 60
            )
            
            context.fill(
                Path(roundedRect: rect, cornerRadius: 15),
                with: .color(color)
            )
            
            // Draw community label
            if !memberPositions.isEmpty {
                let resolvedText = Text(community.title)
                    .font(.caption2)
                    .foregroundColor(color.opacity(0.7))
                context.draw(resolvedText, at: CGPoint(x: minX + 10, y: minY - 15), anchor: .leading)
            }
        }
    }
    
    private func drawRelationships(context: GraphicsContext) {
        let displayEntityIds = Set(displayEntities.map { $0.id })
        
        for relationship in graph.relationships {
            // Only draw if both entities are in display set
            guard displayEntityIds.contains(relationship.sourceEntityId),
                  displayEntityIds.contains(relationship.targetEntityId),
                  let sourcePos = nodePositions[relationship.sourceEntityId],
                  let targetPos = nodePositions[relationship.targetEntityId] else {
                continue
            }
            
            // Draw line
            var path = Path()
            path.move(to: sourcePos)
            path.addLine(to: targetPos)
            
            // Color and width based on relationship strength
            let opacity = Double(relationship.strength) * 0.5 + 0.3
            let lineWidth = CGFloat(relationship.strength) * 2 + 1
            
            context.stroke(
                path,
                with: .color(.gray.opacity(opacity)),
                lineWidth: lineWidth
            )
        }
    }
    
    private func drawEntities(context: GraphicsContext, size: CGSize) {
        for entity in displayEntities {
            guard let pos = nodePositions[entity.id] else { continue }
            
            let isSelected = selectedEntityId == entity.id
            
            // Node size based on number of connections
            let relationships = graph.getRelationships(for: entity.id)
            let nodeSize: CGFloat = min(max(CGFloat(relationships.count) * 2 + 20, 20), 50)
            
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
            
            if isSelected {
                context.stroke(circle, with: .color(.blue), lineWidth: 3)
            } else {
                context.stroke(circle, with: .color(nodeColor), lineWidth: 2)
            }
            
            // Draw entity name (truncated)
            let displayName = entity.name.count > 15 ? String(entity.name.prefix(12)) + "..." : entity.name
            let resolvedText = Text(displayName)
                .font(.system(size: 9))
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
    
    private func handleTap(at location: CGPoint) {
        // Find entity at tap location
        for entity in displayEntities {
            guard let pos = nodePositions[entity.id] else { continue }
            let relationships = graph.getRelationships(for: entity.id)
            let nodeSize: CGFloat = min(max(CGFloat(relationships.count) * 2 + 20, 20), 50)
            
            let distance = sqrt(
                pow(location.x - pos.x, 2) + pow(location.y - pos.y, 2)
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

