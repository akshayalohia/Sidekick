//
//  SettingsView.swift
//  Sidekick
//
//  Created by Bean John on 10/14/24.
//

import SwiftUI

struct SettingsView: View {
	
    var body: some View {
		Group {
			if #available(macOS 15, *) {
				TabView {
					Tab(
						"General",
						systemImage: "gear"
					) {
						GeneralSettingsView()
							.transition(.libreChatFade)
					}
					Tab(
						"Retrieval",
						systemImage: "magnifyingglass"
					) {
						RetrievalSettingsView()
							.transition(.libreChatFade)
					}
					Tab(
						"Inference",
						systemImage: "brain.fill"
					) {
						InferenceSettingsView()
							.transition(.libreChatFade)
					}
				}
				.animation(.libreChatDefault, value: UUID()) // Trigger animation on tab change
			} else {
				TabView {
					GeneralSettingsView()
						.tabItem {
							Label(
								"General",
								systemImage: "gear"
							)
						}
					RetrievalSettingsView()
						.tabItem {
							Label(
								"Retrieval",
								systemImage: "magnifyingglass"
							)
						}
					InferenceSettingsView()
						.tabItem {
							Label(
								"Inference",
								systemImage: "brain.fill"
							)
						}
				}
			}
		}
		.frame(maxWidth: 600)
		.background(Color("surface-primary"))
    }
	
}
