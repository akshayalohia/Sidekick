# Knowledge Graph Viewer Documentation

## Overview

The Knowledge Graph Viewer is a SwiftUI-based visualization component that displays entities, relationships, and communities extracted from expert resources. It's integrated into the expert settings UI and provides an interactive graph visualization.

## Architecture

### Main Components

1. **KnowledgeGraphVisualizationView.swift** (`Sidekick/Views/Expert/Resource/`)
   - Main view controller
   - Handles loading, error states, and UI layout
   - Contains sidebar with statistics and entity details

2. **GraphCanvasView** (private struct in same file)
   - SwiftUI Canvas-based rendering engine
   - Handles layout calculation and drawing
   - Manages user interactions (click to select entities)

3. **GraphDatabase.swift** (`Sidekick/Logic/Utilities/GraphRAG/`)
   - SQLite database interface
   - `loadGraph(resourceId:)` - loads entities filtered by resource ID
   - `loadAllGraphs()` - loads ALL entities regardless of resource ID (fallback)
   - Stores entities, relationships, communities, and community members

4. **Resources.swift** (`Sidekick/Types/Expert/`)
   - `loadGraphIndex()` - main entry point for loading graphs
   - Merges graphs from multiple resources
   - Falls back to `loadAllGraphs()` if resource IDs don't match

## Data Flow

1. **Loading Process:**
   ```
   User clicks "View Graph" 
   → KnowledgeGraphVisualizationView.loadGraph()
   → expert.resources.loadGraphIndex()
   → For each resource: database.loadGraph(resourceId)
   → If no entities found: database.loadAllGraphs() (fallback)
   → Merge all graphs into one KnowledgeGraph
   → Display in GraphCanvasView
   ```

2. **Data Structure:**
   - `KnowledgeGraph`: Contains entities (dict), relationships (array), communities (array)
   - `GraphEntity`: id, name, type, description, sourceChunks, embedding
   - `GraphRelationship`: sourceEntityId, targetEntityId, type, description, strength
   - `Community`: id, level, memberEntityIds, subCommunityIds, title, summary

## Visualization Approach

### Layout Algorithm

**Current Implementation:**
1. **Initial Layout:** Circular arrangement
   - Entities placed in a circle around center
   - Radius = 35% of canvas size
   - Angle step = 2π / entity count

2. **Force-Directed Adjustment:** 20 iterations
   - **Repulsion:** Nodes repel each other (force = 1000 / distance²)
   - **Attraction:** Connected nodes attract (force = distance * 0.01)
   - **Damping:** Forces applied with 0.1 multiplier
   - **Result:** Nodes spread out but connected entities stay closer

**Performance Limits:**
- Only displays top 100 entities (by relationship count)
- Entities sorted by number of connections before limiting

### Rendering

**Drawing Order (back to front):**
1. **Communities:** Semi-transparent colored rectangles around entity groups
   - Colors cycle: blue, green, orange, purple, pink (by level)
   - Opacity: 0.1
   - Only shown if community has entities in display set

2. **Relationships:** Lines connecting entities
   - Color: Gray with opacity based on strength (0.3-0.8)
   - Width: 1-3px based on strength
   - Only drawn if both entities are in display set

3. **Entities:** Colored circles with labels
   - **Size:** 20-50px based on connection count
   - **Color:** Based on entity type:
     - Blue: Person
     - Green: Organization/Company
     - Orange: Location/Place
     - Purple: Concept/Idea
     - Gray: Other
   - **Label:** Entity name (truncated to 15 chars)
   - **Selection:** Blue border when clicked

### Interaction

- **Click:** Select entity (shows details in sidebar)
- **Zoom:** Toolbar buttons (50%-200%, currently not fully implemented)
- **Pan:** Not implemented (would need ScrollView or manual offset)

## Current Limitations & Issues

### Major Issues

1. **Scalability Problem:**
   - With 100+ entities, graph becomes unreadable
   - Even at 50% zoom, too crowded to understand relationships
   - No way to filter or focus on specific entities/communities
   - No clustering or hierarchical view options

2. **Layout Issues:**
   - Force-directed algorithm is too simple (only 20 iterations)
   - No consideration for community structure in layout
   - Entities can overlap or cluster poorly
   - No adaptive sizing based on zoom level

3. **Interaction Limitations:**
   - No pan/scroll (fixed viewport)
   - Zoom controls exist but don't affect Canvas rendering
   - No search/filter functionality
   - No way to hide/show specific entity types or communities
   - No way to focus on a subgraph (e.g., show only entities connected to selected one)

4. **Visual Clarity:**
   - Too many relationships create visual noise
   - Community regions can overlap confusingly
   - Entity labels can overlap
   - No way to highlight important entities or paths

### Technical Debt

1. **Resource ID Mismatch:**
   - Entities stored with old resource IDs
   - Fallback to `loadAllGraphs()` works but isn't ideal
   - Should probably migrate or update resource IDs

2. **Performance:**
   - Layout calculation happens synchronously on main thread
   - No caching of layouts
   - Canvas redraws everything on every frame

3. **Code Organization:**
   - GraphCanvasView is a large private struct (500+ lines)
   - Layout, rendering, and interaction all mixed together
   - Could be split into separate components

## File Locations

- **Main View:** `Sidekick/Views/Expert/Resource/KnowledgeGraphVisualizationView.swift`
- **Database:** `Sidekick/Logic/Utilities/GraphRAG/GraphDatabase.swift`
- **Data Models:** 
  - `Sidekick/Types/Expert/KnowledgeGraph.swift`
  - `Sidekick/Types/Expert/GraphEntity.swift`
  - `Sidekick/Types/Expert/GraphRelationship.swift`
  - `Sidekick/Types/Expert/Community.swift`
- **Integration:** `Sidekick/Views/Expert/Resource/ResourceSectionView.swift` (line ~190)

## Suggested Improvements

1. **Better Layout:**
   - Use proper graph layout library (e.g., GraphViz algorithms)
   - Consider hierarchical/force-directed hybrid
   - Group entities by community in layout
   - Adaptive node sizing based on zoom

2. **Filtering & Focus:**
   - Search bar to find entities
   - Filter by entity type
   - Filter by community
   - "Focus mode" - show only selected entity and its connections
   - Hide/show relationships by strength threshold

3. **Interaction:**
   - Proper pan/zoom with ScrollView or custom gesture handling
   - Double-click to expand/focus on entity
   - Right-click context menu
   - Keyboard shortcuts

4. **Visual Improvements:**
   - Better community visualization (maybe as clusters)
   - Relationship labels on hover
   - Entity details tooltip
   - Path highlighting between entities
   - Minimap overview

5. **Performance:**
   - Async layout calculation
   - Level-of-detail rendering (simplify at low zoom)
   - Virtualization for large graphs
   - Layout caching

6. **Alternative Views:**
   - List view of entities with relationship counts
   - Matrix view showing entity connections
   - Tree view for hierarchical communities
   - Timeline view if temporal data exists

## Key Functions to Modify

- `calculateLayout(size:)` - Improve layout algorithm
- `drawEntities()`, `drawRelationships()`, `drawCommunities()` - Enhance rendering
- `handleTap(at:)` - Add more interaction modes
- `displayEntities` computed property - Add filtering logic
- Add new computed properties for filtered relationships, communities

## Database Schema

- **entities:** id, name, type, description, embedding, resource_id
- **relationships:** id, source_entity_id, target_entity_id, type, description, strength
- **communities:** id, level, title, summary, embedding
- **community_members:** community_id, entity_id, sub_community_id
- **chunk_entities:** chunk_index, entity_id (mapping)

## Notes

- Communities are stored globally (not per-resource), which is why they show up even when entities don't match resource IDs
- The fallback `loadAllGraphs()` loads everything, which works but isn't resource-specific
- Canvas rendering is efficient but doesn't scale well to 100+ nodes
- Current implementation prioritizes simplicity over scalability

