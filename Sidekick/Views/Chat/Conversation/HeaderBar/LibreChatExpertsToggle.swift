//
//  LibreChatExpertsToggle.swift
//  Sidekick
//
//  Created for LibreChat UI transformation
//

import SwiftUI

struct LibreChatExpertsToggle: View {

    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject private var expertManager: ExpertManager
    @EnvironmentObject private var conversationState: ConversationState

    @State private var isHovered: Bool = false
    @State private var showingMenu: Bool = false

    var selectedExpert: Expert? {
        guard let selectedExpertId = conversationState.selectedExpertId else {
            return nil
        }
        return expertManager.getExpert(id: selectedExpertId)
    }

    var displayText: String {
        if let expert = selectedExpert {
            return expert.name
        } else {
            return "Select Expert"
        }
    }

    var inactiveExperts: [Expert] {
        return expertManager.experts.filter({ expert in
            expert != selectedExpert
        })
    }

    var createExpertsTip: CreateExpertsTip = .init()

    var body: some View {
        Menu {
            Group {
                selectOptions
                if !inactiveExperts.isEmpty {
                    Divider()
                }
                manageExpertsButton
            }
        } label: {
            HStack(spacing: 8) {
                if let expert = selectedExpert {
                    Image(systemName: expert.symbolName)
                        .font(.system(size: 14))
                        .foregroundColor(Color("text-primary"))
                }
                Text(displayText)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(Color("text-primary"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(Color("text-primary"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color("surface-tertiary") : Color("surface-secondary"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("borderLight"), lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .popoverTip(
            createExpertsTip,
            arrowEdge: .top
        ) { action in
            // Open expert editor
            conversationState.isManagingExperts.toggle()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    var selectOptions: some View {
        ForEach(
            inactiveExperts
        ) { expert in
            Button {
                withAnimation(.linear) {
                    conversationState.selectedExpertId = expert.id
                }
            } label: {
                expert.label
            }
        }
    }

    var manageExpertsButton: some View {
        Button {
            conversationState.isManagingExperts.toggle()
        } label: {
            Text("Manage Experts")
        }
        .onChange(of: conversationState.isManagingExperts) {
            // Show tip if needed
            if !conversationState.isManagingExperts &&
                LengthyTasksController.shared.hasTasks {
                LengthyTasksProgressTip.hasLengthyTask = true
            }
        }
    }
}
