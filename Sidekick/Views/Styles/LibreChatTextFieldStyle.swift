//
//  LibreChatTextFieldStyle.swift
//  Sidekick
//
//  Created for UI Modernization
//

import SwiftUI

/// Text field style matching LibreChat's clean form inputs
struct LibreChatTextFieldStyle: TextFieldStyle {
    
    var isFocused: Bool = false
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("surface-chat"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? Color("borderMedium") : Color("borderLight"),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// Secure field style matching LibreChat's clean form inputs
struct LibreChatSecureFieldStyle: TextFieldStyle {
    
    var isFocused: Bool = false
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("surface-chat"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? Color("borderMedium") : Color("borderLight"),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

