//
//  AnimationConstants.swift
//  Sidekick
//
//  Created for UI Modernization
//

import SwiftUI

/// Animation constants matching LibreChat's timing and easing
extension Animation {
    
    /// Default animation for most UI interactions (200ms)
    static let libreChatDefault = Animation.easeInOut(duration: 0.2)
    
    /// Fast animation for instant feedback (50ms)
    static let libreChatFast = Animation.easeInOut(duration: 0.05)
    
    /// Slide animation for panels and sidebars (300ms with custom easing)
    static let libreChatSlide = Animation.timingCurve(
        0.25, 0.1, 0.25, 1,
        duration: 0.3
    )
    
    /// Fade animation for modals and overlays (500ms)
    static let libreChatFade = Animation.easeOut(duration: 0.5)
    
    /// Spring animation for bouncy interactions
    static let libreChatSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7
    )
}

/// Transition constants for consistent view transitions
extension AnyTransition {
    
    /// Slide in from right (for side panels)
    static var libreChatSlideFromRight: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
        .animation(.libreChatSlide)
    }
    
    /// Slide in from left (for side panels)
    static var libreChatSlideFromLeft: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
        .animation(.libreChatSlide)
    }
    
    /// Fade transition (for modals)
    static var libreChatFade: AnyTransition {
        .opacity
            .animation(.libreChatFade)
    }
    
    /// Scale and fade (for popovers)
    static var libreChatScaleFade: AnyTransition {
        .scale(scale: 0.95)
            .combined(with: .opacity)
            .animation(.libreChatDefault)
    }
}

