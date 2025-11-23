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
		HStack {
			image()
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 60, height: 60)
				.foregroundColor(.primary)
				.if(isSvg && isDarkMode) { view in
					view
						.colorInvert()
				}
                .padding(.trailing)
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(name)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
		}
		.multilineTextAlignment(.center)
		.padding()
		.background {
			RoundedRectangle(
				cornerRadius: 8
			)
			.fill(Color.secondary.opacity(backgroundOpacity))
		}
	}
	
}
