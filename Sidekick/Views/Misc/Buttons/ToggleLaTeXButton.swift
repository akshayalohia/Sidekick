//
//  ToggleLaTeXButton.swift
//  Sidekick
//
//  Created by Bean John on 11/28/24.
//

import SwiftUI

struct ToggleLaTeXButton: View {
	
	@Binding var renderLatex: Bool
	
	@State private var isHovering: Bool = false
	
    var body: some View {
		Toggle(
			isOn: $renderLatex.animation(.linear),
			label: {
				label
					.onHover { isHovering in
						withAnimation(.linear) {
							self.isHovering = isHovering
						}
					}
			}
		)
		.toggleStyle(.button)
		.buttonStyle(.plain)
    }
	
	var label: some View {
		HStack {
			if self.isHovering {
				Text("Toggle LaTeX")
					.padding(.leading, 9)
					.offset(x: 4)
					.transition {
						.scale
						.combined(
							with: .opacity
						)
					}
			}
			operators
				.rotationEffect(isHovering ? .degrees(45) : .degrees(0))
				.scaleEffect(0.5)
				.fontWeight(.heavy)
				.padding(.vertical, 1.25)
		}
		.foregroundStyle(Color.secondary)
		.background {
			Capsule()
				.stroke(
					Color.secondary,
					lineWidth: 1.0
				)
				.fill(
					Color.textBackground
				)
		}
		.scaleEffect(0.85)
	}
	
	var operators: some View {
		VStack(
			spacing: 0
		) {
			HStack(
				spacing: 0
			) {
				Group {
					Image(systemName: "plus")
					Image(systemName: "minus")
				}
				.rotationEffect(isHovering ? .degrees(-45) : .degrees(0))
			}
			HStack(
				spacing: 0
			) {
				Group {
					Image(systemName: "multiply")
					Image(systemName: "divide")
				}
				.rotationEffect(isHovering ? .degrees(-45) : .degrees(0))
			}
		}
	}
	
}
