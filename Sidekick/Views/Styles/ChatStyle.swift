//
//  ChatStyle.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import SwiftUI

struct ChatFieldStyle: TextFieldStyle {
    
	@Environment(\.colorScheme) var colorScheme
	
    @FocusState var isFocused: Bool
	@Binding var isRecording: Bool
	
	var useAttachments: Bool = true
	var useDictation: Bool = true
	
	/// A `Bool` controlling whether space is reserved for options below the text field
	var bottomOptions: Bool = false
	
	var cornerRadius = 8.0
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
	
	func _body(configuration: TextField<Self._Label>) -> some View {
		configuration
			.textFieldStyle(.plain)
			.frame(maxWidth: .infinity)
			.if(self.useAttachments) { view in
				view
					.padding(.leading, 24)
			}
			.if(self.useDictation) { view in
				view
					.padding(.trailing, 21)
			}
			.if(!self.useAttachments) { view in
				view
					.padding(.leading, 4)
			}
			.if(!self.useDictation) { view in
				view
					.padding(.trailing, 4)
			}
			.if(self.bottomOptions) { view in
				view
					.padding(.bottom, 30)
			}
			.padding(8)
			.cornerRadius(cornerRadius)
			.background(
				LinearGradient(
					colors: [
						Color.textBackground,
						Color.textBackground.opacity(0.9),
						Color.textBackground.opacity(0.75),
						Color.textBackground.opacity(0.5)
					],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.mask(rect)
			.overlay(
				rect
					.stroke(style: StrokeStyle(lineWidth: 1))
					.foregroundStyle(outlineColor)
			)
			.animation(.easeInOut(duration: 0.2), value: isFocused)
	}
	
}

struct ChatButtonStyle: ButtonStyle {
    
    let cornerRadius = 30.0
    var rect: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .bold()
            .cornerRadius(cornerRadius)
            .background(
                LinearGradient(
                    colors: [
                        Color.textBackground,
                        Color.textBackground.opacity(0.5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(rect)
            .overlay(
                rect
                    .stroke(style: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.primary)
            )
    }
    
}
