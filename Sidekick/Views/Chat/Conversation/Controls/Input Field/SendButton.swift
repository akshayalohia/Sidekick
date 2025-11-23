//
//  SendButton.swift
//  Sidekick
//
//  Created by John Bean on 11/23/25.
//

import SwiftUI

struct SendButton: View {

    var prompt: String
    var onSubmit: () -> Void

    private var isEnabled: Bool {
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var buttonColor: Color {
        if isEnabled {
            return Color("surface-active-alt")
        }
        return Color("surface-chat")
    }
    
    private var iconColor: Color {
        return isEnabled ? Color("text-primary") : Color("text-secondary")
    }

    var body: some View {
        Button {
            if isEnabled {
                onSubmit()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color("borderMedium"), lineWidth: isEnabled ? 0 : 1)
                    )

                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
