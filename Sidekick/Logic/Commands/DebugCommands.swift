//
//  DebugCommands.swift
//  Sidekick
//
//  Created by Bean John on 10/5/24.
//

import Foundation
import SwiftUI
import TipKit

@MainActor
public class DebugCommands {
	
	static var commands: some Commands {
        CommandGroup(after: .help) {
			Menu("Debug") {
				Self.debugSettings
				Self.debugConversations
				Self.debugBrain
				Button(
					action: ExpertManager.shared.resetDatastore
				) {
					Text("Delete All Experts")
				}
				Button {
					FileManager.showItemInFinder(
						url: Settings.containerUrl
					)
				} label: {
					Text("Show Container in Finder")
				}
			}
		}
	}
	
	private static var debugSettings: some View {
		Menu("Settings") {
			Button(
				action: Settings.clearUserDefaults
			) {
				Text("Clear All Settings")
			}
			Button(
				action: InferenceSettings.setDefaults
			) {
				Text("Set Inference Settings to Defaults")
			}
		}
	}
	
	private static var debugConversations: some View {
		Menu("Conversations") {
			Button(
				action: ConversationManager.shared.createBackup
			) {
				Text("Backup Conversations")
			}
			if ConversationManager.shared.backupExists {
				Button(
					action: ConversationManager.shared.retoreFromBackup
				) {
					Text("Restore Conversations from Backup")
				}
			}
			Button(
				action: ConversationManager.shared.resetDatastore
			) {
				Text("Delete All Conversations")
			}
		}
	}

	private static var debugBrain: some View {
		Menu("Brain (RAG System)") {
			Button {
				Task {
					print("\n" + String(repeating: "=", count: 60))
					print("RUNNING ALL BRAIN TESTS")
					print(String(repeating: "=", count: 60) + "\n")
					await BrainTester.runAllTests()
				}
			} label: {
				Text("Run All Tests")
			}

			Divider()

			Button {
				BrainTester.testQueryRouter()
			} label: {
				Text("Test Query Router")
			}

			Button {
				BrainTester.testBM25Index()
			} label: {
				Text("Test BM25 Index")
			}

			Button {
				Task {
					await BrainTester.testHybridRetrieval()
				}
			} label: {
				Text("Test Hybrid Retrieval")
			}

			Divider()

			Button {
				let stats = KnowledgeBrain.shared.getStats()
				print("\n=== Knowledge Brain Stats ===")
				print("Initialized: \(stats.isInitialized)")
				print("Total chunks: \(stats.totalChunks)")
				print("Total terms: \(stats.totalTerms)")
				print("Entity count: \(stats.entityCount)")
				print("=============================\n")
			} label: {
				Text("Print Brain Stats")
			}

			Button {
				let stats = UnifiedMemory.shared.stats
				print("\n=== Unified Memory Stats ===")
				print("Semantic memories: \(stats.semantic)")
				print("Episodic memories: \(stats.episodic)")
				print("Procedural memories: \(stats.procedural)")
				print("============================\n")
			} label: {
				Text("Print Memory Stats")
			}

			Divider()

			Button {
				Task {
					await KnowledgeBrain.shared.clear()
					print("Brain cleared.")
				}
			} label: {
				Text("Clear Brain")
			}

			Button {
				UnifiedMemory.shared.clearAll()
				print("Unified memory cleared.")
			} label: {
				Text("Clear Memory")
			}

			Divider()

			Toggle("Use Unified Brain", isOn: Binding(
				get: { RetrievalSettings.useUnifiedBrain },
				set: { RetrievalSettings.useUnifiedBrain = $0 }
			))

			Toggle("Use Query Routing", isOn: Binding(
				get: { RetrievalSettings.useQueryRouting },
				set: { RetrievalSettings.useQueryRouting = $0 }
			))

			Toggle("Use Hybrid Search", isOn: Binding(
				get: { RetrievalSettings.useHybridSearch },
				set: { RetrievalSettings.useHybridSearch = $0 }
			))

			Toggle("Use Memory", isOn: Binding(
				get: { RetrievalSettings.useMemory },
				set: { RetrievalSettings.useMemory = $0 }
			))
		}
	}

}
