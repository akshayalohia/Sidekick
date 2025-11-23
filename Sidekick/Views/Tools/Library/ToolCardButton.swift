//
//  ToolCardButton.swift
//  Sidekick
//
//  Created by John Bean on 2/20/25.
//

import SwiftUI

struct ToolCardButton: View {
	
	@Environment(\.colorScheme) var colorScheme
	@State private var isHovering: Bool = false
	
	var name: String
	var description: String
	var isSvg: Bool = false
	var image: () -> Image
	
	var action: () -> Void
	
	var isDarkMode: Bool {
		return self.colorScheme == .dark
	}
	
	var backgroundOpacity: Double {
		return isHovering ? 0.3 : 0.15
	}
	
    var body: some View {
		Button {
			self.action()
		} label: {
			self.label
		}
		.buttonStyle(.plain)
		.onHover { hover in
			self.isHovering = hover
		}
        .listRowSeparator(.hidden)
    }
	
	var label: some View {
		HStack(spacing: 16) {
			image()
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
				.foregroundColor(Color("text-primary"))
				.if(isSvg && isDarkMode) { view in
					view
						.colorInvert()
				}
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text-primary"))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color("text-secondary"))
                    .multilineTextAlignment(.leading)
            }
            Spacer()
		}
		.padding(20)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			isHovering ? Color("surface-hover") : Color("surface-chat")
		)
		.cornerRadius(12)
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color("borderLight"), lineWidth: 1)
		)
		.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
		.animation(.libreChatDefault, value: isHovering)
	}
	
}
