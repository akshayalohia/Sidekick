//
//  SwiftUIView.swift
//  Sidekick
//
//  Created by John Bean on 2/12/25.
//

import SwiftUI

struct LengthyTasksNavigationButton: View {

	@State private var isHovering: Bool = false

	var body: some View {
		LengthyTasksButton()
			.onHover { hovering in
				withAnimation(.easeInOut(duration: 0.2)) {
					self.isHovering = hovering
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, 10)
			.padding(.top, 7)
			.padding(.bottom, 9)
			.background(
				self.isHovering ? Color("surface-hover") : Color.clear
			)
			.clipShape(
				RoundedRectangle(cornerRadius: 8)
			)
	}

}
