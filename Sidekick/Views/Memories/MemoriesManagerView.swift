//
//  MemoriesManagerView.swift
//  Sidekick
//
//  Created by John Bean on 4/22/25.
//

import SwiftUI

struct MemoriesManagerView: View {
    
    @EnvironmentObject private var memories: Memories
    
    @State private var query: String = ""
    
    var filteredMemories: [Memory] {
        if query.isEmpty {
            return memories.memories
        } else {
            return memories.memories.filter { memory in
                return memory.text.lowercased().contains(query.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Memories")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color("text-primary"))
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        self.memories.resetDatastore()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color("text-secondary"))
                    
                    PopoverButton(
                        arrowEdge: .bottom
                    ) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                    } content: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Memories")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color("text-primary"))
                            Text("Sidekick remembers useful details about you and your preferences so it can be more helpful.")
                                .font(.system(size: 13))
                                .foregroundColor(Color("text-secondary"))
                        }
                        .padding(16)
                        .frame(maxWidth: 300)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color("text-secondary"))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("text-secondary"))
                    .font(.system(size: 13))
                TextField("Search Memories", text: $query.animation(.libreChatDefault))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color("surface-chat"))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // List
            List(
                filteredMemories
            ) { memory in
                MemoryRowView(memory: memory)
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 32))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Color("surface-primary"))
    }
    
    struct MemoryRowView: View {
        
        @EnvironmentObject private var memories: Memories
        @State private var isHovering = false
    
        var memory: Memory
        
        var body: some View {
            HStack(spacing: 12) {
                Text(memory.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color("text-primary"))
                    .lineLimit(nil)
                Spacer()
                Button {
                    withAnimation(.libreChatDefault) {
                        self.memories.forget(memory)
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isHovering ? Color.red : Color("text-secondary"))
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1.0 : 0.6)
            }
            .padding(.vertical, 4)
            .background(isHovering ? Color("surface-hover") : Color.clear)
            .cornerRadius(6)
            .onHover { hovering in
                withAnimation(.libreChatDefault) {
                    isHovering = hovering
                }
            }
        }
        
    }
    
}
