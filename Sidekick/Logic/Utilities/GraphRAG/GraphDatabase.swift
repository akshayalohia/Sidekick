//
//  GraphDatabase.swift
//  Sidekick
//
//  Created by John Bean on 11/10/25.
//

import Foundation
import SQLite
import OSLog

/// Manages persistence of knowledge graphs using SQLite
public class GraphDatabase {
	
	/// A `Logger` object for ``GraphDatabase``
	private static let logger: Logger = .init(
		subsystem: Bundle.main.bundleIdentifier!,
		category: String(describing: GraphDatabase.self)
	)
	
	private let db: Connection
	
	// Table definitions
	private let entities = Table("entities")
	private let relationships = Table("relationships")
	private let communities = Table("communities")
	private let communityMembers = Table("community_members")
	private let chunkEntities = Table("chunk_entities")
	
	// Entity columns
	private let entityId = SQLite.Expression<String>("id")
	private let entityName = SQLite.Expression<String>("name")
	private let entityType = SQLite.Expression<String>("type")
	private let entityDescription = SQLite.Expression<String>("description")
	private let entityEmbedding = SQLite.Expression<Data?>("embedding")
	private let entityResourceId = SQLite.Expression<String>("resource_id")
	
	// Relationship columns
	private let relationshipId = SQLite.Expression<String>("id")
	private let relationshipSource = SQLite.Expression<String>("source_entity_id")
	private let relationshipTarget = SQLite.Expression<String>("target_entity_id")
	private let relationshipType = SQLite.Expression<String>("type")
	private let relationshipDescription = SQLite.Expression<String>("description")
	private let relationshipStrength = SQLite.Expression<Double>("strength")
	
	// Community columns
	private let communityId = SQLite.Expression<String>("id")
	private let communityLevel = SQLite.Expression<Int64>("level")
	private let communityTitle = SQLite.Expression<String>("title")
	private let communitySummary = SQLite.Expression<String>("summary")
	private let communityEmbedding = SQLite.Expression<Data?>("embedding")
	
	// Member columns
	private let memberId = SQLite.Expression<Int64>("id")
	private let memberCommunityId = SQLite.Expression<String>("community_id")
	private let memberEntityId = SQLite.Expression<String?>("entity_id")
	private let memberSubCommunityId = SQLite.Expression<String?>("sub_community_id")
	
	// Chunk entity columns
	private let chunkEntityId = SQLite.Expression<Int64>("id")
	private let chunkIndex = SQLite.Expression<Int64>("chunk_index")
	private let chunkEntityEntityId = SQLite.Expression<String>("entity_id")
	
	/// Initialize database at given path
	/// - Parameter dbPath: Path to SQLite database file
	public init(dbPath: String) throws {
		do {
			db = try Connection(dbPath)
			try createTables()
		} catch {
			Self.logger.error("Failed to initialize database: \(error.localizedDescription)")
			throw DatabaseError.initializationFailed(error.localizedDescription)
		}
	}
	
	/// Create database tables if they don't exist
	private func createTables() throws {
		// Entities table
		try db.run(entities.create(ifNotExists: true) { t in
			t.column(entityId, primaryKey: true)
			t.column(entityName)
			t.column(entityType)
			t.column(entityDescription)
			t.column(entityEmbedding)
			t.column(entityResourceId)
		})
		
		// Create index on entity name for faster lookups
		try db.run(entities.createIndex(entityName, ifNotExists: true))
		
		// Relationships table
		try db.run(relationships.create(ifNotExists: true) { t in
			t.column(relationshipId, primaryKey: true)
			t.column(relationshipSource)
			t.column(relationshipTarget)
			t.column(relationshipType)
			t.column(relationshipDescription)
			t.column(relationshipStrength)
		})
		
		// Create indices for relationship queries
		try db.run(relationships.createIndex(relationshipSource, ifNotExists: true))
		try db.run(relationships.createIndex(relationshipTarget, ifNotExists: true))
		
		// Communities table
		try db.run(communities.create(ifNotExists: true) { t in
			t.column(communityId, primaryKey: true)
			t.column(communityLevel)
			t.column(communityTitle)
			t.column(communitySummary)
			t.column(communityEmbedding)
		})
		
		// Community members table (for many-to-many relationships)
		try db.run(communityMembers.create(ifNotExists: true) { t in
			t.column(memberId, primaryKey: .autoincrement)
			t.column(memberCommunityId)
			t.column(memberEntityId)
			t.column(memberSubCommunityId)
		})
		
		// Create index on community_id for faster lookups
		try db.run(communityMembers.createIndex(memberCommunityId, ifNotExists: true))
		
		// Chunk entities table (for chunk-to-entity mapping)
		try db.run(chunkEntities.create(ifNotExists: true) { t in
			t.column(chunkEntityId, primaryKey: .autoincrement)
			t.column(chunkIndex)
			t.column(chunkEntityEntityId)
		})
		
		// Create index on chunk_index for faster lookups
		try db.run(chunkEntities.createIndex(chunkIndex, ifNotExists: true))
	}
	
	/// Save a knowledge graph to the database
	/// - Parameter graph: The knowledge graph to save
	public func saveGraph(_ graph: KnowledgeGraph) throws {
		do {
			try db.transaction {
				// Clear existing data for this resource
				try clearResourceData(resourceId: graph.resourceId.uuidString)
				
				// Save entities
				for entity in graph.entities {
					let embeddingData: Data? = if let embedding = entity.embedding {
						try? JSONEncoder().encode(embedding)
					} else {
						nil
					}
					
					try db.run(entities.insert(
						entityId <- entity.id.uuidString,
						entityName <- entity.name,
						entityType <- entity.type,
						entityDescription <- entity.description,
						entityEmbedding <- embeddingData,
						entityResourceId <- graph.resourceId.uuidString
					))
					
					// Save chunk mappings
					for chunk in entity.sourceChunks {
						try db.run(chunkEntities.insert(
							chunkIndex <- Int64(chunk),
							chunkEntityEntityId <- entity.id.uuidString
						))
					}
				}
				
				// Save relationships
				for relationship in graph.relationships {
					try db.run(relationships.insert(
						relationshipId <- relationship.id.uuidString,
						relationshipSource <- relationship.sourceEntityId.uuidString,
						relationshipTarget <- relationship.targetEntityId.uuidString,
						relationshipType <- relationship.relationshipType,
						relationshipDescription <- relationship.description,
						relationshipStrength <- Double(relationship.strength)
					))
				}
				
				// Save communities
				for community in graph.communities {
					let embeddingData: Data? = if let embedding = community.embedding {
						try? JSONEncoder().encode(embedding)
					} else {
						nil
					}
					
					try db.run(communities.insert(
						communityId <- community.id.uuidString,
						communityLevel <- Int64(community.level),
						communityTitle <- community.title,
						communitySummary <- community.summary,
						communityEmbedding <- embeddingData
					))
					
					// Save community members
					for entityId in community.memberEntityIds {
						try db.run(communityMembers.insert(
							memberCommunityId <- community.id.uuidString,
							memberEntityId <- entityId.uuidString,
							memberSubCommunityId <- nil
						))
					}
					
					// Save sub-communities
					for subCommId in community.subCommunityIds {
						try db.run(communityMembers.insert(
							memberCommunityId <- community.id.uuidString,
							memberEntityId <- nil,
							memberSubCommunityId <- subCommId.uuidString
						))
					}
				}
			}
			
			Self.logger.notice("Saved graph with \(graph.entityCount) entities, \(graph.relationshipCount) relationships, \(graph.communityCount) communities")
			
		} catch {
			Self.logger.error("Failed to save graph: \(error.localizedDescription)")
			throw DatabaseError.saveFailed(error.localizedDescription)
		}
	}
	
	/// Load a knowledge graph for a resource
	/// - Parameter resourceId: The resource ID
	/// - Returns: The loaded knowledge graph
	public func loadGraph(resourceId: UUID) throws -> KnowledgeGraph {
		let graph = KnowledgeGraph(resourceId: resourceId)
		
		do {
			// Load entities
			let entityRows = try db.prepare(entities.filter(entityResourceId == resourceId.uuidString))
			var loadedEntities: [GraphEntity] = []
			
			for row in entityRows {
				let id = UUID(uuidString: row[entityId])!
				let embedding: [Float]? = if let data = row[entityEmbedding] {
					try? JSONDecoder().decode([Float].self, from: data)
				} else {
					nil
				}
				
				// Get source chunks for this entity
				let chunkRows = try db.prepare(chunkEntities.filter(chunkEntityEntityId == row[entityId]))
				let sourceChunks = chunkRows.map { Int($0[chunkIndex]) }
				
				let entity = GraphEntity(
					id: id,
					name: row[entityName],
					type: row[entityType],
					description: row[entityDescription],
					sourceChunks: sourceChunks,
					embedding: embedding
				)
				
				loadedEntities.append(entity)
			}
			
			graph.addEntities(loadedEntities)
			
			// Load relationships
			let relationshipRows = try db.prepare(relationships)
			var loadedRelationships: [GraphRelationship] = []
			
			for row in relationshipRows {
				// Check if both entities exist in the graph
				let sourceId = UUID(uuidString: row[relationshipSource])!
				let targetId = UUID(uuidString: row[relationshipTarget])!
				
				guard graph.findEntity(id: sourceId) != nil,
				      graph.findEntity(id: targetId) != nil else {
					continue  // Skip relationships with missing entities
				}
				
				let relationship = GraphRelationship(
					id: UUID(uuidString: row[relationshipId])!,
					sourceEntityId: sourceId,
					targetEntityId: targetId,
					relationshipType: row[relationshipType],
					description: row[relationshipDescription],
					strength: Float(row[relationshipStrength])
				)
				
				loadedRelationships.append(relationship)
			}
			
			graph.addRelationships(loadedRelationships)
			
			// Load communities
			let communityRows = try db.prepare(communities)
			var loadedCommunities: [Community] = []
			
			for row in communityRows {
				let commId = row[communityId]
				let embedding: [Float]? = if let data = row[communityEmbedding] {
					try? JSONDecoder().decode([Float].self, from: data)
				} else {
					nil
				}
				
				// Get members
				let memberRows = try db.prepare(communityMembers.filter(memberCommunityId == commId))
				var entityIds: [UUID] = []
				var subCommIds: [UUID] = []
				
				for memberRow in memberRows {
					if let entityIdStr = memberRow[memberEntityId],
					   let entityId = UUID(uuidString: entityIdStr) {
						entityIds.append(entityId)
					}
					if let subCommIdStr = memberRow[memberSubCommunityId],
					   let subCommId = UUID(uuidString: subCommIdStr) {
						subCommIds.append(subCommId)
					}
				}
				
				let community = Community(
					id: UUID(uuidString: commId)!,
					level: Int(row[communityLevel]),
					memberEntityIds: entityIds,
					subCommunityIds: subCommIds,
					summary: row[communitySummary],
					embedding: embedding,
					title: row[communityTitle]
				)
				
				loadedCommunities.append(community)
			}
			
			graph.addCommunities(loadedCommunities)
			
		Self.logger.notice("Loaded graph with \(graph.entityCount) entities, \(graph.relationshipCount) relationships, \(graph.communityCount) communities")
		
		// Debug: Check what's actually in the database
		do {
			let allEntityRows = try db.prepare(entities)
			var allEntityCount = 0
			var entityCountByResource: [String: Int] = [:]
			for row in allEntityRows {
				allEntityCount += 1
				let resourceId = row[entityResourceId]
				entityCountByResource[resourceId, default: 0] += 1
			}
			Self.logger.info("Database contains \(allEntityCount) total entities")
			for (resourceId, count) in entityCountByResource {
				Self.logger.info("  Resource \(resourceId): \(count) entities")
			}
			Self.logger.info("Looking for resourceId: \(resourceId.uuidString)")
		} catch {
			Self.logger.warning("Could not query all entities: \(error.localizedDescription)")
		}
		
		return graph
		
	} catch {
		Self.logger.error("Failed to load graph: \(error.localizedDescription)")
		throw DatabaseError.loadFailed(error.localizedDescription)
	}
}
	
	/// Load all entities, relationships, and communities from the database regardless of resource ID
	/// This is useful when resource IDs have changed but entities still exist
	/// - Returns: A knowledge graph with all data
	public func loadAllGraphs() throws -> KnowledgeGraph {
		let graph = KnowledgeGraph(resourceId: UUID()) // Use a temporary ID
		
		do {
			// Load ALL entities regardless of resource ID
			let entityRows = try db.prepare(entities)
			var loadedEntities: [GraphEntity] = []
			
			for row in entityRows {
				let id = UUID(uuidString: row[entityId])!
				let embedding: [Float]? = if let data = row[entityEmbedding] {
					try? JSONDecoder().decode([Float].self, from: data)
				} else {
					nil
				}
				
				// Get source chunks for this entity
				let chunkRows = try db.prepare(chunkEntities.filter(chunkEntityEntityId == row[entityId]))
				let sourceChunks = chunkRows.map { Int($0[chunkIndex]) }
				
				let entity = GraphEntity(
					id: id,
					name: row[entityName],
					type: row[entityType],
					description: row[entityDescription],
					sourceChunks: sourceChunks,
					embedding: embedding
				)
				
				loadedEntities.append(entity)
			}
			
			graph.addEntities(loadedEntities)
			Self.logger.info("Loaded \(loadedEntities.count) entities from database")
			
			// Load ALL relationships
			let relationshipRows = try db.prepare(relationships)
			var loadedRelationships: [GraphRelationship] = []
			
			for row in relationshipRows {
				let sourceId = UUID(uuidString: row[relationshipSource])!
				let targetId = UUID(uuidString: row[relationshipTarget])!
				
				// Only add if both entities exist in the graph
				guard graph.findEntity(id: sourceId) != nil,
				      graph.findEntity(id: targetId) != nil else {
					continue
				}
				
				let relationship = GraphRelationship(
					id: UUID(uuidString: row[relationshipId])!,
					sourceEntityId: sourceId,
					targetEntityId: targetId,
					relationshipType: row[relationshipType],
					description: row[relationshipDescription],
					strength: Float(row[relationshipStrength])
				)
				
				loadedRelationships.append(relationship)
			}
			
			graph.addRelationships(loadedRelationships)
			Self.logger.info("Loaded \(loadedRelationships.count) relationships from database")
			
			// Load ALL communities
			let communityRows = try db.prepare(communities)
			var loadedCommunities: [Community] = []
			
			for row in communityRows {
				let commId = row[communityId]
				let embedding: [Float]? = if let data = row[communityEmbedding] {
					try? JSONDecoder().decode([Float].self, from: data)
				} else {
					nil
				}
				
				// Get members
				let memberRows = try db.prepare(communityMembers.filter(memberCommunityId == commId))
				var entityIds: [UUID] = []
				var subCommIds: [UUID] = []
				
				for memberRow in memberRows {
					if let entityIdStr = memberRow[memberEntityId],
					   let entityId = UUID(uuidString: entityIdStr) {
						// Only include if entity exists in graph
						if graph.findEntity(id: entityId) != nil {
							entityIds.append(entityId)
						}
					}
					if let subCommIdStr = memberRow[memberSubCommunityId],
					   let subCommId = UUID(uuidString: subCommIdStr) {
						subCommIds.append(subCommId)
					}
				}
				
				let community = Community(
					id: UUID(uuidString: commId)!,
					level: Int(row[communityLevel]),
					memberEntityIds: entityIds,
					subCommunityIds: subCommIds,
					summary: row[communitySummary],
					embedding: embedding,
					title: row[communityTitle]
				)
				
				loadedCommunities.append(community)
			}
			
			graph.addCommunities(loadedCommunities)
			Self.logger.info("Loaded \(loadedCommunities.count) communities from database")
			
			Self.logger.notice("Loaded all graphs: \(graph.entityCount) entities, \(graph.relationshipCount) relationships, \(graph.communityCount) communities")
			
			return graph
			
		} catch {
			Self.logger.error("Failed to load all graphs: \(error.localizedDescription)")
			throw DatabaseError.loadFailed(error.localizedDescription)
		}
	}
	
	/// Clear all data for a resource
	private func clearResourceData(resourceId: String) throws {
		// Get all entity IDs for this resource
		let entityRows = try db.prepare(entities.filter(entityResourceId == resourceId))
		let entityIds = entityRows.map { $0[entityId] }
		
		// Delete chunk mappings
		for entityIdStr in entityIds {
			try db.run(chunkEntities.filter(chunkEntityEntityId == entityIdStr).delete())
		}
		
		// Delete relationships
		for entityIdStr in entityIds {
			try db.run(relationships.filter(
				relationshipSource == entityIdStr || relationshipTarget == entityIdStr
			).delete())
		}
		
		// Delete community members (no need to filter by resource, will be cleaned up with entities)
		
		// Delete entities
		try db.run(entities.filter(entityResourceId == resourceId).delete())
	}
	
	/// Get database statistics
	/// - Returns: Dictionary with statistics
	public func getStatistics() throws -> [String: Int] {
		return [
			"entities": try db.scalar(entities.count),
			"relationships": try db.scalar(relationships.count),
			"communities": try db.scalar(communities.count)
		]
	}
	
	/// Error types
	public enum DatabaseError: Error {
		case initializationFailed(String)
		case saveFailed(String)
		case loadFailed(String)
	}
}

