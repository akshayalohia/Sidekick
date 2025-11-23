//
//  CapsuleButtonStyle.swift
//  Sidekick
//
//  Created by Bean John on 10/10/24.
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
	
	@State private var hovered: Bool = false
	
	@Environment(\.colorScheme) var colorScheme
	
	var background: some View {
		Group {
			if !hovered {
				Color.buttonBackground
			} else {
				Color.buttonBackground
					.brightness(
						colorScheme == .dark ? 0.1 : -0.1
					)
			}
		}
	}
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(hovered ? .body.bold() : .body)
			.background(
				RoundedRectangle(
					cornerSize: CGSize(width: 8, height: 8),
					style: .continuous
				)
				.strokeBorder(
					hovered ? Color.primary.opacity(0) : Color.primary.opacity(0.2),
					lineWidth: 0.5
				)
				.foregroundColor(Color.primary)
				.background(
					background
				)
			)
			.multilineTextAlignment(.leading) // Center-align multiline text
			.lineLimit(nil) // Allow unlimited lines
			.onHover(perform: { hovering in
				hovered = hovering
			})
			.animation(
				.easeInOut(duration: 0.2),
				value: hovered
			)
			.clipShape(
				RoundedRectangle(
					cornerSize: CGSize(width: 8, height: 8),
					style: .continuous
				)
			)
	}
	
}
