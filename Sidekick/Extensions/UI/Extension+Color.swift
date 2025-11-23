//
//  Extension+Color.swift
//  Sidekick
//
//  Created by Bean John on 10/4/24.
//

import Foundation
import SwiftUI

extension Color: @retroactive Decodable {}
extension Color: @retroactive Encodable {}

extension Color {
	
	init(hex: String) {
		
		let rgba = hex.toRGBA()
		
		self.init(
			.sRGB,
			red: Double(rgba.r),
			green: Double(rgba.g),
			blue: Double(rgba.b),
			opacity: Double(rgba.alpha)
		)
		
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let hex = try container.decode(String.self)
		self.init(hex: hex)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(toHex)
	}
	
	var toHex: String? {
		return toHex()
	}
	
	func toHex(alpha: Bool = false) -> String? {
		
		let environment = EnvironmentValues()
		let r: Float = self.resolve(in: environment).red
		let g: Float = self.resolve(in: environment).green
		let b: Float = self.resolve(in: environment).blue
		let a: Float = self.resolve(in: environment).opacity
		
		return String(format: "%02lX%02lX%02lX%02lX",
					  lroundf(r * 255),
					  lroundf(g * 255),
					  lroundf(b * 255),
					  lroundf(a * 255))
		
	}
	
	// Luminance computed property
	public var luminance: Double {
		
		// Convert SwiftUI Color to NSColor to CIColor
		let osColor: NSColor = NSColor(self)
		let ciColor: CIColor = CIColor(color: osColor)!
		
		// Extract RGB values
		let red: CGFloat = ciColor.red
		let green: CGFloat = ciColor.green
		let blue: CGFloat = ciColor.blue
		
		// Compute luminance.
		return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
	}
	
	// Computed property that returns most appropriate text color
	public var adaptedTextColor: Color {
		return (self.luminance > 0.5) ? Color.black : Color.white
	}


}

