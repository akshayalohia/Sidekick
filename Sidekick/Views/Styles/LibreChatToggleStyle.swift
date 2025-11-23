//
//  LibreChatToggleStyle.swift
//  Sidekick
//
//  Created for UI Modernization
//

import SwiftUI

/// Toggle style matching LibreChat's clean switches
struct LibreChatToggleStyle: ToggleStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Track
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isOn ? Color("submitButtonGreen") : Color("borderMedium"))
                    .frame(width: 44, height: 24)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .padding(2)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        }
    }
}

extension ToggleStyle where Self == LibreChatToggleStyle {
    static var libreChat: LibreChatToggleStyle {
        LibreChatToggleStyle()
    }
}

