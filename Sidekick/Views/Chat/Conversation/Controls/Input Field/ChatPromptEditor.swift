//
//  ChatPromptEditor.swift
//  Sidekick
//
//  Created by John Bean on 4/20/25.
//

import SwiftUI

struct ChatPromptEditor: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var promptController: PromptController
    
    @AppStorage("useCommandReturn") private var useCommandReturn: Bool = Settings.useCommandReturn
    var sendDescription: String {
        return String(localized: "Enter a message. Press ") + Settings.SendShortcut(self.useCommandReturn).rawValue + String(localized: " to send.")
    }
    
    @FocusState var isFocused: Bool
    @Binding var isRecording: Bool
    
    /// Store a debouncing work item that we can cancel
    @State private var debouncedTask: DispatchWorkItem?
    
    var useAttachments: Bool = true
    var useDictation: Bool = true
    
    /// A `Bool` controlling whether space is reserved for options below the text field
    var bottomOptions: Bool = false
    
    var cornerRadius = 24.0
    var rect: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var outlineColor: Color {
        if isRecording {
            return .red
        } else if isFocused {
            return Color("borderMedium")
        }
        return Color("borderLight")
    }
    
    var body: some View {
        MultilineTextField(
            text: self.$promptController.prompt.animation(.linear),
            insertionPoint: self.$promptController.insertionPoint,
            prompt: sendDescription,
            onImageDrop: { url in
                Task {
                    await self.promptController.addFile(url)
                }
            }
        )
        .textFieldStyle(.plain)
        .frame(maxWidth: .infinity)
        .if(self.useAttachments) { view in
            view
                .padding(.leading, 32)
        }
        .if(self.useDictation) { view in
            view
                .padding(.trailing, 20)
        }
        .if(!self.useAttachments) { view in
            view
                .padding(.leading, 16)
        }
        .if(!self.useDictation) { view in
            view
                .padding(.trailing, 16)
        }
        .if(self.bottomOptions) { view in
            view
                .padding(.bottom, 30)
        }
        .padding(.vertical, 10)
        .padding(.top, 2)
        .cornerRadius(cornerRadius)
        .background(
            Color("surface-chat")
        )
        .mask(rect)
        .overlay(
            rect
                .stroke(style: StrokeStyle(lineWidth: 1))
                .foregroundStyle(outlineColor)
        )
        .shadow(
            color: .black.opacity(isFocused ? 0.08 : 0.05),
            radius: isFocused ? 4 : 2,
            x: 0,
            y: isFocused ? 2 : 1
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
    
}
