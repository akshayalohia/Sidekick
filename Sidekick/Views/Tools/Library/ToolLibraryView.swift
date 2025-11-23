//
//  ToolboxLibraryView.swift
//  Sidekick
//
//  Created by John Bean on 2/20/25.
//

import SwiftUI

struct ToolboxLibraryView: View {
    
	@Environment(\.openWindow) var openWindow
	
	@Binding var isPresented: Bool
	@State private var showAssistantInstructionSheet: Bool = false
	
    var body: some View {
		VStack(spacing: 0) {
			// Header
			HStack {
				ExitButton {
					self.isPresented.toggle()
				}
				Spacer()
				Text("Tools")
					.font(.system(size: 17, weight: .semibold))
					.foregroundColor(Color("text-primary"))
				Spacer()
				// Invisible spacer for centering
				ExitButton {
					self.isPresented.toggle()
				}
				.opacity(0)
				.disabled(true)
			}
			.padding(.horizontal, 32)
			.padding(.top, 20)
			.padding(.bottom, 16)
			
			Divider()
			
			// Tools List
			tools
		}
		.background(Color("surface-primary"))
    }
	
    var tools: some View {
        ScrollView {
			VStack(spacing: 16) {
				self.dashboardCard
				self.detectorCard
				self.diagrammerCard
				self.inlineAssistantCard
				self.slideStudioCard
			}
			.padding(.horizontal, 32)
			.padding(.vertical, 24)
		}
    }
    
    var dashboardCard: some View {
        ToolCardButton(
            name: String(localized: "Dashboard"),
            description: String(localized: "View usage statistics and trends")
        ) {
            Image(systemName: "chart.line.uptrend.xyaxis")
        } action: {
            self.openToolWindow(id: "dashboard")
        }
    }
    
    var diagrammerCard: some View {
		ToolCardButton(
			name: String(localized: "Diagrammer"),
			description: String(localized: "Generate diagrams with AI"),
			isSvg: true
		) {
            Image("mindmap")
		} action: {
			self.openToolWindow(id: "diagrammer")
		}
	}
	
	var slideStudioCard: some View {
		ToolCardButton(
			name: String(localized: "Slide Studio"),
			description: String(localized: "Create 10 minute presentations in 5 minutes")
		) {
			Image(systemName: "rectangle.on.rectangle.angled")
		} action: {
			self.openToolWindow(id: "slideStudio")
		}
	}
	
	var inlineAssistantCard: some View {
		ToolCardButton(
			name: String(localized: "Inline Writing Assistant"),
			description: String(localized: "Edit text with AI without leaving your editor"),
			isSvg: false
		) {
			Image(systemName: "pencil.and.list.clipboard")
		} action: {
			self.showAssistantInstructionSheet.toggle()
		}
		.sheet(isPresented: $showAssistantInstructionSheet) {
			AssistantInstructionView(
				showAssistantInstructionSheet: $showAssistantInstructionSheet
			)
			.frame(
				maxWidth: 450,
				maxHeight: 250
			)
		}
	}
    
	var detectorCard: some View {
		ToolCardButton(
			name: String(localized: "Detector"),
			description: String(localized: "Stay one step ahead of Turnitin")
		) {
			Image(systemName: "checkmark.seal.text.page")
		} action: {
			self.openToolWindow(id: "detector")
		}
	}
	
	/// Function to open an tool's associated window
	private func openToolWindow(
		id: String
	) {
		// Open window & close sheet
		self.openWindow(id: id)
		self.isPresented.toggle()
	}
	
}
