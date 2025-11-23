//
//  SidekickApp.swift
//  Sidekick
//
//  Created by Bean John on 10/4/24.
//

import AppKit
import Foundation
import FSKit_macOS
import Sparkle
import SwiftUI
import TipKit

@main
struct SidekickApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState: AppState = .shared
    @StateObject private var downloadManager: DownloadManager = .shared
    @StateObject private var conversationManager: ConversationManager = .shared
    @StateObject private var expertManager: ExpertManager = .shared
    @StateObject private var commandManager: CommandManager = .shared
    @StateObject private var memories: Memories = .shared
    
    @StateObject private var lengthyTasksController: LengthyTasksController = .shared
    
    /// Updater object for Sparkle
    private let updaterController: SPUStandardUpdaterController = .init(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    
    init() {
        // Hide all tips for now
        Tips.hideAllTipsForTesting()
        // Initialize model cache
        Task {
            let signpost = StartupMetrics.begin("KnownModel.initializeModelCache")
            await KnownModel.initializeModelCache()
            StartupMetrics.end("KnownModel.initializeModelCache", signpost)
        }
    }
    
    var body: some Scene {
        
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(downloadManager)
                .environmentObject(conversationManager)
                .environmentObject(expertManager)
                .environmentObject(lengthyTasksController)
                .environmentObject(memories)
                .background(Color("surface-primary"))
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // Commands for operations in conversations (e.g. Creating a new conversation)
            ConversationCommands.commands
            // Commands to use and manage experts
            ConversationCommands.expertCommands
            // Commands to change the window state / appearance
            WindowCommands.commands
            // Command replacing the help button
            HelpCommands.helpCommand
            // Commands useful for debugging
            DebugCommands.commands
            // Commands to obtain help and report problems
            HelpCommands.commands
            // Command to check for update
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        
        // Window for managing memories
        SwiftUI.Window("Memory", id: "memory") {
            MemoriesManagerView()
                .environmentObject(memories)
                .frame(minWidth: 500, maxWidth: 600, maxHeight: 550)
        }
        .windowResizability(.contentSize)
        .windowIdealSize(.fitToContent)
        
        // Window for Tool: Models
        SwiftUI.Window("Models", id: "models") {
            ModelExplorerView()
        }
        
        // Window for Tool: Dashboard
        SwiftUI.Window("Dashboard", id: "dashboard") {
            DashboardView()
        }
        
        // Window for Tool: Detector
        SwiftUI.Window("Detector", id: "detector") {
            DetectorView()
        }
        
        // Window for Tool: Diagrammer
        SwiftUI.Window("Diagrammer", id: "diagrammer") {
            DiagrammerView()
        }
        
        // Window for Tool: Slide Studio
        SwiftUI.Window("Slide Studio", id: "slideStudio") {
            SlideStudioView()
        }
        
        // Settings window
        SwiftUI.Settings {
            SettingsView()
                .environmentObject(commandManager)
        }
        
    }
    
}
