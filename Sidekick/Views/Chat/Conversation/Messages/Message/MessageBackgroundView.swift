//
//  MessageBackgroundView.swift
//  Sidekick
//
//  Created by Bean John on 10/23/24.
//

import SwiftUI

struct MessageBackgroundView: View {
	
	private let cornerRadius: CGFloat = 8
	private let borderWidth: CGFloat = 0.5
	
	var body: some View {
		unevenRoundedRectangle(cornerRadius)
			.fill(
				Color.textBackground
			)
			.padding(borderWidth)
			.background {
				unevenRoundedRectangle(cornerRadius + borderWidth)
					.fill(Color.borderLight)
			}
	}
	
	private func unevenRoundedRectangle(
		_ cornerRadius: CGFloat
	) -> some Shape {
		UnevenRoundedRectangle(
			cornerRadii: .init(
				topLeading: 0,
				bottomLeading: cornerRadius,
				bottomTrailing: cornerRadius,
				topTrailing: cornerRadius
			),
			style: .circular
		)
	}
	
}

#Preview {
    MessageBackgroundView()
}
