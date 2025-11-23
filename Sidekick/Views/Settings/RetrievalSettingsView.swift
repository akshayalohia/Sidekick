//
//  RetrievalSettingsView.swift
//  Sidekick
//
//  Created by Bean John on 10/16/24.
//

import SwiftUI

struct RetrievalSettingsView: View {
    
    @Environment(\.openWindow) var openWindow
    
    @AppStorage("useMemory") private var useMemory: Bool = RetrievalSettings.useMemory
    
    @AppStorage("defaultSearchProvider") private var defaultSearchProvider: Int = RetrievalSettings.defaultSearchProvider
    
    @State private var tavilyApiKey: String = RetrievalSettings.tavilyApiKey
    @State private var tavilyBackupApiKey: String = RetrievalSettings.tavilyBackupApiKey
    
    @AppStorage("searchResultsMultiplier") private var searchResultsMultiplier: Int = RetrievalSettings.searchResultsMultiplier
    @State private var useWebSearchResultContext: Bool = RetrievalSettings.useWebSearchResultContext
    
    // Graph RAG settings
    @AppStorage("graphRAGEnabled") private var graphRAGEnabled: Bool = RetrievalSettings.graphRAGEnabled
    @AppStorage("graphRAGMaxEntities") private var graphRAGMaxEntities: Int = RetrievalSettings.graphRAGMaxEntities
    @AppStorage("graphRAGCommunityLevels") private var graphRAGCommunityLevels: Int = RetrievalSettings.graphRAGCommunityLevels
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Memory Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Memory")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        useMemoryToggle
                        manageMemories
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                
                // Resources Search Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Resources Search")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        resourcesSearch
                        graphRAGToggle
                        if graphRAGEnabled {
                            graphRAGMaxEntitiesSlider
                            graphRAGCommunityLevelsSlider
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                // Search Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Search")
                        .libreChatSectionHeader()
                        .padding(.horizontal, 32)
                    
                    VStack(spacing: 20) {
                        searchProviderPicker
                        // If Tavily is selected
                        if defaultSearchProvider == 1 {
                            tavilySearch
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color("surface-primary"))
    }
    
    var useMemoryToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Use Memory")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color("text-primary"))
                    StatusLabelView.experimental
                }
                Text("Controls whether Sidekick remembers information about you to provide more customized, personal responses in the future.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Toggle("", isOn: $useMemory)
                .toggleStyle(.libreChat)
        }
        .padding(.vertical, 8)
    }
    
    var manageMemories: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Memories")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Manage Sidekick's memories.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Button {
                self.openWindow(id: "memory")
            } label: {
                Text("Manage")
            }
            .libreChatButtonStyle()
        }
        .padding(.vertical, 8)
    }
    
    var searchProviderPicker: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search Provider")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Select the search provider used for web search.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            Picker(
                selection: $defaultSearchProvider.animation(.libreChatDefault)
            ) {
                Text("DuckDuckGo")
                    .tag(0)
                Text("Tavily")
                    .tag(1)
                Text("Google")
                    .tag(2)
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 8)
    }
    
    var tavilySearch: some View {
        Group {
            tavilyApiKeyEditor
            tavilyBackupApiKeyEditor
        }
        .onAppear {
            self.tavilyApiKey = RetrievalSettings.tavilyApiKey
            self.tavilyBackupApiKey = RetrievalSettings.tavilyBackupApiKey
        }
    }
    
    var tavilyApiKeyEditor: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("API Key")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(tavilyApiKey.isEmpty ? .red : Color("text-primary"))
                Text("Needed to access the Tavily API")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
                Button {
                    let url: URL = URL(string: "https://app.tavily.com/home")!
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Get an API Key")
                }
                .buttonStyle(.plain)
                .foregroundColor(Color("text-secondary"))
                .font(.system(size: 12))
            }
            Spacer()
            SecureField("", text: $tavilyApiKey)
                .textContentType(.password)
                .textFieldStyle(LibreChatSecureFieldStyle())
                .frame(width: 300)
                .onChange(of: tavilyApiKey) { oldValue, newValue in
                    RetrievalSettings.tavilyApiKey = newValue
                }
        }
        .padding(.vertical, 8)
    }
    
    var tavilyBackupApiKeyEditor: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Backup API Key (Optional)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Used to access the Tavily API if the main API key fails.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            Spacer()
            SecureField("", text: $tavilyBackupApiKey)
                .textFieldStyle(LibreChatSecureFieldStyle())
                .frame(width: 300)
                .onChange(
                    of: tavilyBackupApiKey
                ) { oldValue, newValue in
                    RetrievalSettings.tavilyBackupApiKey = newValue
                }
        }
        .padding(.vertical, 8)
    }
    
    var resourcesSearch: some View {
        Group {
            searchResultCount
            searchResultContext
        }
    }
    
    var searchResultCount: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("Search Results")
                    .font(.title3)
                    .bold()
                Text("Controls the number of search results from expert resources fed to the chatbot. The more results, the slower the chatbot will respond.")
                    .font(.caption)
            }
            .frame(minWidth: 250)
            Spacer()
            Picker(selection: $searchResultsMultiplier) {
                Text("Less")
                    .tag(2)
                Text("Default")
                    .tag(3)
                Text("More")
                    .tag(4)
                Text("Most")
                    .tag(6)
            }
            .pickerStyle(.segmented)
        }
    }
    
    var searchResultContext: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search Result Context")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color("text-primary"))
                Text("Controls whether context of a search result is given to the chatbot. Turning this on will decrease generation speed, but will increase the length of each search result.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            .frame(minWidth: 250)
            Spacer()
            Toggle("", isOn: $useWebSearchResultContext)
                .toggleStyle(.libreChat)
        }
        .onChange(of: useWebSearchResultContext) {
            RetrievalSettings.useWebSearchResultContext = self.useWebSearchResultContext
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Graph RAG Settings
    
    var graphRAGToggle: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Enable Knowledge Graphs")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color("text-primary"))
                    StatusLabelView.experimental
                }
                Text("Use knowledge graphs to enhance retrieval with entity relationships and hierarchical communities. This provides better context but requires re-indexing.")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
            }
            .frame(minWidth: 275)
            Spacer()
            Toggle("", isOn: $graphRAGEnabled)
                .toggleStyle(.libreChat)
        }
        .padding(.vertical, 8)
    }
    
    var graphRAGMaxEntitiesSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Maximum Entities")
                    .font(.title3)
                    .bold()
                Spacer()
                Text("\(graphRAGMaxEntities)")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Maximum number of entities to extract per expert. Higher values provide more detail but slower indexing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                    .frame(maxWidth: 25)
                Slider(value: Binding(
                    get: { Double(graphRAGMaxEntities) },
                    set: { graphRAGMaxEntities = Int($0) }
                ), in: 100...1000, step: 50)
            }
        }
    }
    
    var graphRAGCommunityLevelsSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Community Levels")
                    .font(.title3)
                    .bold()
                Spacer()
                Text("\(graphRAGCommunityLevels)")
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Number of hierarchical levels for community detection. More levels capture broader themes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                    .frame(maxWidth: 15)
                Slider(value: Binding(
                    get: { Double(graphRAGCommunityLevels) },
                    set: { graphRAGCommunityLevels = Int($0) }
                ), in: 2...5, step: 1)
            }
        }
    }
    
}
