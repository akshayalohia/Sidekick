//
//  SearchMenuToggleButton.swift
//  Sidekick
//
//  Created by John Bean on 5/7/25.
//

import SwiftUI

struct SearchMenuToggleButton: View {

    @EnvironmentObject private var promptController: PromptController
    @State private var isHovering = false

    var activatedFillColor: Color

    @Binding var useWebSearch: Bool
    @Binding var selectedSearchState: SearchState

    var selectedModel: KnownModel? {
        return Model.shared.selectedModel
    }

    var backgroundColor: Color {
        // Always shown as active since one option is always selected
        if isHovering {
            return Color("surface-hover")
        }
        return Color("surface-chat")
    }

    var iconColor: Color {
        return .secondary
    }

    var textColor: Color {
        return .secondary
    }

    var borderColor: Color {
        return Color("borderMedium")
    }

    var borderWidth: CGFloat {
        return 1
    }

    var labelText: String {
        return selectedSearchState.description
    }

    var body: some View {
        Menu {
            ForEach(SearchState.allCases) { option in
                Button {
                    self.changeSelection(newSelection: option)
                } label: {
                    Text(option.description)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)

                Text(labelText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(textColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(height: 36)
            .background(backgroundColor)
            .cornerRadius(9999)
            .overlay(
                RoundedRectangle(cornerRadius: 9999)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .animation(.easeOut(duration: 0.2), value: isHovering)
        } primaryAction: {
            self.toggle()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
    
    private func toggle() {
        withAnimation(.linear(duration: 0.15)) {
            self.useWebSearch.toggle()
        }
        self.onToggle(newValue: self.useWebSearch)
    }

    private func changeSelection(newSelection: SearchState) {
        withAnimation(.linear(duration: 0.15)) {
            let didChange: Bool = self.selectedSearchState != newSelection
            self.selectedSearchState = newSelection
            if didChange {
                self.useWebSearch = true
            } else {
                self.useWebSearch.toggle()
            }
        }
        self.checkDeepResearchAvailability()
    }

    private func onToggle(
        newValue: Bool
    ) {
        // Check if search is configured
        if !RetrievalSettings.canUseWebSearch {
            // If not, show error and return
            Dialogs.showAlert(
                title: String(localized: "Search not configured"),
                message: String(localized: "Search is not configured properly. Please configure it in \"Settings\" -> \"Retrieval\".")
            )
            // Set back to false
            self.useWebSearch = false
            return
        }
        // Check Deep Research
        self.checkDeepResearchAvailability()
    }
    
    private func checkDeepResearchAvailability() {
        // If not using Deep Research, return
        if !self.promptController.isUsingDeepResearch {
            return
        }
        // Check if function calling is activated
        if !Settings.useFunctions {
            // If not, show error and return
            Dialogs.showAlert(
                title: String(localized: "Not Available"),
                message: String(localized: "Functions must be turned on to use Deep Research.")
            )
            self.resetSearchState()
            return
        } else {
            // If functions can be used, force on
            self.promptController.useFunctions = true
        }
    }
    
    /// Function to reset search state
    private func resetSearchState() {
        self.useWebSearch = false // Set back to false
        self.selectedSearchState = .search
    }
    
}
