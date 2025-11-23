//
//  CollapsibleUserMessageView.swift
//  Sidekick
//
//  Created by Assistant on 11/6/25.
//

import SwiftUI

struct CollapsibleUserMessageView: View {
    
    var text: String
    
    @State private var isExpanded: Bool?
    
    private let collapsedLineCount: Int = 15
    
    private var effectiveIsExpanded: Bool {
        // If isExpanded is nil (first load), determine based on line count
        // Short messages (15 lines or less) start expanded
        return isExpanded ?? (totalLineCount <= collapsedLineCount)
    }
    
    var totalLineCount: Int {
        return text.components(separatedBy: .newlines).count
    }
    
    var shouldShowExpandButton: Bool {
        return totalLineCount > collapsedLineCount
    }
    
    var displayedContent: String {
        if effectiveIsExpanded || !shouldShowExpandButton {
            return text
        }
        let lines = text.components(separatedBy: .newlines)
        return lines.prefix(collapsedLineCount).joined(separator: "\n")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !self.effectiveIsExpanded && self.shouldShowExpandButton {
                // Collapsed state with overlay
                VStack(alignment: .leading, spacing: 0) {
                    Text(self.displayedContent)
                        .font(.system(size: NSFont.systemFontSize + 1.0))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: self.calculateCollapsedHeight(), alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    // Gradient and button overlay
                    VStack(spacing: 0) {
                        // Gradient fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.textBackground.opacity(0), location: 0),
                                .init(color: Color.textBackground.opacity(0.95), location: 0.5),
                                .init(color: Color.textBackground, location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                        
                        // Button area
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.isExpanded = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Show all \(self.totalLineCount) lines")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }
                }
            } else {
                // Expanded state or short message
                Text(displayedContent)
                    .font(.system(size: NSFont.systemFontSize + 1.0))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Collapse button at bottom when expanded
            if self.effectiveIsExpanded && self.shouldShowExpandButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isExpanded = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                        Text("Show less")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
                .frame(maxWidth: .infinity)
            }
        }
        .textSelection(.enabled)
    }
    
    private func calculateCollapsedHeight() -> CGFloat {
        let fontSize = NSFont.systemFontSize + 1.0
        let lineSpacing: CGFloat = 4
        let lineHeight = fontSize + lineSpacing
        return CGFloat(self.collapsedLineCount) * lineHeight
    }
}


