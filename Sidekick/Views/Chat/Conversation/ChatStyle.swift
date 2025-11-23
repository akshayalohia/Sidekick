//
//  ChatStyle.swift
//  Sidekick
//
//  Created by Bean John on 10/8/24.
//

import SwiftUI

struct ChatStyle: TextFieldStyle {
	
	@Environment(\.colorScheme) var colorScheme
	
	@FocusState var isFocused: Bool
	
	let cornerRadius = 8.0
	var rect: RoundedRectangle {
		RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
	}
	
	func _body(configuration: TextField<Self._Label>) -> some View {
		configuration
			.textFieldStyle(.plain)
			.frame(maxWidth: .infinity)
			.padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
			.padding(8)
			.cornerRadius(cornerRadius)
			.background(
				LinearGradient(colors: [Color.textBackground, Color.textBackground.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
			)
			.mask(rect)
			.overlay(
				rect
					.stroke(style: StrokeStyle(lineWidth: 1))
					.foregroundStyle(isFocused ? Color("borderMedium") : Color("borderLight"))
			)
			.animation(.easeInOut(duration: 0.2), value: isFocused)
	}
	
}
