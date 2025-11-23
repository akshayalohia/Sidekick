//
//  LibreChatCardStyle.swift
//  Sidekick
//
//  Created for UI Modernization
//

import SwiftUI

/// Card/panel style matching LibreChat's clean aesthetic
struct LibreChatCardStyle: ViewModifier {
    
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color("surface-primary"))
            .cornerRadius(cornerRadius)
            .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color("borderLight"), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func libreChatCard(padding: CGFloat = 16, cornerRadius: CGFloat = 8) -> some View {
        self.modifier(LibreChatCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}

/// Section header style matching LibreChat
struct LibreChatSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color("text-secondary"))
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func libreChatSectionHeader() -> some View {
        self.modifier(LibreChatSectionHeader())
    }
}

