//
//  SidebarButtonView.swift
//  Sidekick
//
//  Created by John Bean on 2/20/25.
//

import SwiftUI

struct SidebarButtonView: View {

	@State private var isHovering: Bool = false

	var title: String
	var systemImage: String

	var action: () -> Void

	var body: some View {
		Button {
			self.action()
		} label: {
			Label(
				title,
				systemImage: systemImage
			)
			.foregroundStyle(.secondary)
			.font(.headline)
			.fontWeight(.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.background(
				self.isHovering ? Color("surface-hover") : Color.clear
			)
			.clipShape(
				RoundedRectangle(cornerRadius: 8)
			)
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			withAnimation(
				.easeInOut(duration: 0.2)
			) {
				self.isHovering = hovering
			}
		}
	}

}
