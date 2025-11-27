//
//  SearchResult.swift
//  Sidekick
//
//  Created by Bean John on 10/12/24.
//

import Foundation
import SimilaritySearchKit

public struct SearchResult: Identifiable, Codable {

	init(
		searchResult: SimilaritySearchKit.SearchResult
	) {
		self.text = searchResult.text
		self.score = searchResult.score
		self.metadata = searchResult.metadata
	}

	/// Direct initializer for creating SearchResult without SimilaritySearchKit dependency
	init(
		text: String,
		score: Float,
		source: String,
		itemIndex: Int? = nil
	) {
		self.text = text
		self.score = score
		var meta: [String: String] = ["source": source]
		if let idx = itemIndex {
			meta["itemIndex"] = "\(idx)"
		}
		self.metadata = meta
	}

	/// Stored property for `Identifiable` conformance
	public var id: UUID = UUID()
	
	/// Property for the searched text
	public var text: String
	
	/// Property for the match score
	public var score: Float
	
	/// Property for the metadata
	private var metadata: [String: String]
	
	/// Computed property returning the result's source's index
	public var itemIndex: Int? {
		guard let itemIndex: String = self.metadata["itemIndex"] else { return nil }
		return Int(itemIndex)
	}
	
	/// Computed property returning the result's source's URL
	public var sourceUrl: URL? {
		guard let source: String = self.metadata["source"] else { return nil }
		return URL(string: source)
	}
	
	/// Computed property returning the result's source's URL text
	public var sourceUrlText: String? {
		if sourceUrl?.isWebURL ?? false {
			return sourceUrl?.absoluteString
		}
		return sourceUrl?.posixPath
	}
	
}
