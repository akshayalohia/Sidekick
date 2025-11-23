//
//  UseFunctionsButton.swift
//  Sidekick
//
//  Created by John Bean on 4/14/25.
//

import SwiftUI

struct UseFunctionsButton: View {

    @EnvironmentObject private var promptController: PromptController
    @ObservedObject var functionSelectionManager = FunctionSelectionManager.shared

    var activatedFillColor: Color

    @Binding var useFunctions: Bool

    var useFunctionsTip: UseFunctionsTip = .init()

    @State private var isHovering = false

    var backgroundColor: Color {
        if useFunctions {
            // Active: Solid blue background for maximum visibility
            return Color.blue
        }
        if isHovering {
            return Color("surface-hover")
        }
        return Color("surface-chat")
    }

    var iconColor: Color {
        return self.useFunctions ? Color.white : .secondary
    }

    var textColor: Color {
        return self.useFunctions ? Color.white : .secondary
    }

    var borderColor: Color {
        return self.useFunctions ? Color.blue : Color("borderMedium")
    }

    var borderWidth: CGFloat {
        return self.useFunctions ? 0 : 1
    }

    var body: some View {
        Menu {
            // Function category menu items with checkmarks
            ForEach(FunctionCategory.allCases) { category in
                Button {
                    functionSelectionManager.toggleCategory(category)
                } label: {
                    HStack {
                        Text(category.description)
                        Spacer()
                        if functionSelectionManager.isEnabled(category) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Separator
            Divider()

            // Select All option
            Button(String(localized: "Select All")) {
                functionSelectionManager.enableAll()
            }

            // Deselect All option
            Button(String(localized: "Deselect All")) {
                functionSelectionManager.disableAll()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)

                Text("Functions")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(textColor)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(iconColor)
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
            .shadow(color: .black.opacity(useFunctions ? 0.3 : 0.1), radius: useFunctions ? 8 : 2, x: 0, y: useFunctions ? 4 : 1)
            .animation(.easeOut(duration: 0.2), value: useFunctions)
            .animation(.easeOut(duration: 0.2), value: isHovering)
        } primaryAction: {
            self.toggle()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in
            self.isHovering = hovering
        }
        .popoverTip(self.useFunctionsTip)
    }

    private func toggle() {
        withAnimation(.linear(duration: 0.05)) {
            self.useFunctions.toggle()
        }
        self.onToggle(newValue: self.useFunctions)
    }

    private func onToggle(
        newValue: Bool
    ) {
        // Check if functions is configured
        if !Settings.useFunctions {
            // If not, show error and return
            self.useFunctions = false // Set back to false
            Dialogs.showAlert(
                title: String(localized: "Functions Disabled"),
                message: String(localized: "Functions are disabled in Settings. Please configure it in \"Settings\" -> \"General\" -> \"Functions\".")
            )
            return
        }
        // Check if deep research is activated
        if self.promptController.isUsingDeepResearch {
            // If true, force functions
            self.useFunctions = true
            Dialogs.showAlert(
                title: String(localized: "Not Available"),
                message: String(localized: "Functions must be turned on to use Deep Research.")
            )
            return
        }
    }

}
