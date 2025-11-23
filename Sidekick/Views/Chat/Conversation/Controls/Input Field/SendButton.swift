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
        return isEnabled ? Color.green : Color.gray
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

                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
