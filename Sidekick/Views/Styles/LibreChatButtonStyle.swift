//
//  LibreChatButtonStyle.swift
//  Sidekick
//
//  Created for UI Modernization
//

import SwiftUI

/// Button style matching LibreChat's clean, modern aesthetic
/// Supports pill-shaped buttons with smooth animations and clear active states
struct LibreChatButtonStyle: ButtonStyle {
    
    enum Variant {
        case `default`
        case primary
        case destructive
        case ghost
    }
    
    var isActive: Bool = false
    var variant: Variant = .default
    var size: ButtonSize = .medium
    
    enum ButtonSize {
        case small
        case medium
        case large
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 12
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .system(size: 13, weight: .medium)
            case .medium: return .system(size: 14, weight: .medium)
            case .large: return .system(size: 16, weight: .medium)
            }
        }
    }
    
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.fontSize)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(9999) // Pill shape
            .overlay(
                RoundedRectangle(cornerRadius: 9999)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    private var backgroundColor: Color {
        if isActive {
            switch variant {
            case .primary, .default:
                return Color("submitButtonGreen") // Green for active primary
            case .destructive:
                return Color.red // Use system red for destructive
            case .ghost:
                return Color("surface-active-alt")
            }
        }
        
        if isHovering {
            switch variant {
            case .ghost:
                return Color("surface-hover")
            default:
                return Color("surface-chat")
            }
        }
        
        switch variant {
        case .primary, .default:
            return Color("surface-chat")
        case .destructive:
            return Color("surface-chat")
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        if isActive {
            return .white
        }
        
        switch variant {
        case .primary, .default:
            return Color("text-primary")
        case .destructive:
            return isActive ? .white : Color.red
        case .ghost:
            return Color("text-primary")
        }
    }
    
    private var borderColor: Color {
        if isActive {
            return Color.clear
        }
        
        if isHovering && variant == .ghost {
            return Color("border-medium")
        }
        
        return Color("borderMedium")
    }
    
    private var borderWidth: CGFloat {
        if isActive {
            return 0
        }
        return 1
    }
    
    private var shadowColor: Color {
        if isActive {
            return .black.opacity(0.3)
        }
        return .black.opacity(0.1)
    }
    
    private var shadowRadius: CGFloat {
        if isActive {
            return 8
        }
        return 2
    }
    
    private var shadowY: CGFloat {
        if isActive {
            return 4
        }
        return 1
    }
}

/// Convenience extension for easy button styling
extension View {
    func libreChatButtonStyle(
        isActive: Bool = false,
        variant: LibreChatButtonStyle.Variant = .default,
        size: LibreChatButtonStyle.ButtonSize = .medium
    ) -> some View {
        self.buttonStyle(
            LibreChatButtonStyle(
                isActive: isActive,
                variant: variant,
                size: size
            )
        )
    }
}

