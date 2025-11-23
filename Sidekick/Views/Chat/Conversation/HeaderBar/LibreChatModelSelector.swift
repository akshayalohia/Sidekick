//
//  LibreChatModelSelector.swift
//  Sidekick
//
//  Created for LibreChat UI transformation
//

import SwiftUI

struct LibreChatModelSelector: View {

    @AppStorage("remoteModelName") private var serverModelName: String = InferenceSettings.serverModelName

    @EnvironmentObject private var model: Model
    @State private var showingDropdown: Bool = false
    @State private var isHovered: Bool = false

    // Get the current model name for display
    var currentModelName: String {
        if let selectedModelName = model.selectedModelName {
            return formatModelName(selectedModelName)
        } else if InferenceSettings.useServer {
            return serverModelName.isEmpty ? "Select Model" : formatModelName(serverModelName)
        } else {
            return "Select Model"
        }
    }

    // Format model name for compact display (truncate long names)
    private func formatModelName(_ name: String) -> String {
        let components = parseModelIdentifier(name)

        if let knownModel = KnownModel.findModel(byIdentifier: name, in: KnownModel.availableModels) {
            var displayName: String
            if let explicitName = knownModel.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !explicitName.isEmpty {
                displayName = explicitName
            } else {
                let providerSource: String
                if knownModel.organization == .other, let orgId = knownModel.organizationIdentifier {
                    providerSource = orgId
                } else {
                    providerSource = components.provider ?? knownModel.organization.rawValue
                }
                let matchedComponents = parseModelIdentifier(knownModel.primaryName)
                let baseName = String(knownModel.primaryName.split(separator: ":").first ?? Substring(knownModel.primaryName))
                displayName = buildDisplayName(provider: providerSource, model: baseName, variant: matchedComponents.variant)
            }
            let providerForPrefix: String
            if knownModel.organization == .other, let orgId = knownModel.organizationIdentifier {
                providerForPrefix = orgId
            } else {
                providerForPrefix = components.provider ?? knownModel.organization.rawValue
            }
            displayName = applyProviderPrefixIfNeeded(displayName, provider: providerForPrefix)
            let matchedComponents = parseModelIdentifier(knownModel.primaryName)
            displayName = harmonizeVariantDisplay(displayName, expectedVariant: matchedComponents.variant)
            return displayName
        }

        return buildDisplayName(provider: components.provider, model: components.model, variant: components.variant)
    }

    private func parseModelIdentifier(_ name: String) -> (provider: String?, model: String, variant: String?) {
        var remainder = name
        var provider: String? = nil
        if let slashIndex = remainder.firstIndex(of: "/") {
            provider = String(remainder[..<slashIndex])
            remainder = String(remainder[remainder.index(after: slashIndex)...])
        }
        var variant: String? = nil
        if let colonIndex = remainder.firstIndex(of: ":") {
            variant = String(remainder[remainder.index(after: colonIndex)...])
            remainder = String(remainder[..<colonIndex])
        }
        return (provider, remainder, variant)
    }

    private func buildDisplayName(provider: String?, model: String, variant: String?) -> String {
        let formattedModel = formatModelComponent(model)
        var result = ""
        if let provider {
            result = "\(formatProviderName(provider)): "
        }
        result += formattedModel
        if let variant = variant?.trimmingCharacters(in: .whitespacesAndNewlines), !variant.isEmpty {
            let lowerVariant = variant.lowercased()
            if Self.variantSuffixTokens.contains(lowerVariant) {
                result += " (\(lowerVariant))"
            } else {
                result += " \(variant)"
            }
        }
        return result
    }

    private func formatProviderName(_ provider: String) -> String {
        return (provider.prefix(1).uppercased() + provider.dropFirst().lowercased())
            .replacingOccurrences(of: "Bytedance", with: "ByteDance")
            .replacingOccurrences(of: "Openrouter", with: "OpenRouter")
            .replacingOccurrences(of: "Deepseek", with: "DeepSeek")
            .replacingOccurrences(of: "Deepcogito", with: "DeepCogito")
            .replacingOccurrences(of: "X-ai", with: "xAI")
            .replacingOccurrences(of: "Meta-llama", with: "Meta-Llama")
            .replacingOccurrences(of: "Minimax", with: "MiniMax")
            .replacingOccurrences(of: "Z-ai", with: "Zhipu AI")
            .replacingOccurrences(of: "Nousresearch", with: "NousResearch")
            .replacingSuffix("ai", with: "AI")
            .replacingSuffix("org", with: "Org")
            .replacingSuffix("labs", with: "Labs")
    }

    private func formatModelComponent(_ model: String) -> String {
        var spacedResult = ""
        for (index, char) in model.enumerated() {
            if char.isUppercase && index > 0 {
                let previousIndex = model.index(model.startIndex, offsetBy: index - 1)
                if model[previousIndex].isLowercase {
                    spacedResult += " "
                }
            }
            spacedResult.append(char)
        }
        let condensed = spacedResult.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return condensed.lowercased()
    }

    private func applyProviderPrefixIfNeeded(_ displayName: String, provider: String?) -> String {
        guard let provider else { return displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            return trimmed
        }
        return "\(formatProviderName(provider)): \(trimmed)"
    }

    private func harmonizeVariantDisplay(_ displayName: String, expectedVariant rawVariant: String?) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawVariant = rawVariant?.trimmingCharacters(in: .whitespacesAndNewlines), !rawVariant.isEmpty else {
            return removeRecognizedVariantSuffix(from: trimmed)
        }
        let lowerVariant = rawVariant.lowercased()
        if Self.variantSuffixTokens.contains(lowerVariant) {
            if trimmed.range(of: "(\(lowerVariant))", options: .caseInsensitive) != nil {
                return trimmed
            }
            let base = removeRecognizedVariantSuffix(from: trimmed)
            return base + " (\(lowerVariant))"
        } else {
            if trimmed.range(of: rawVariant, options: .caseInsensitive) != nil {
                return trimmed
            }
            return trimmed + " \(rawVariant)"
        }
    }

    private func removeRecognizedVariantSuffix(from displayName: String) -> String {
        var result = displayName
        for token in Self.variantSuffixTokens {
            let suffix = " (\(token))"
            if result.lowercased().hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return result
    }

    private static let variantSuffixTokens: Set<String> = ["free", "exacto"]

    var body: some View {
        Button {
            showingDropdown.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(currentModelName)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(Color("text-primary"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(Color("text-primary"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDropdown) {
            ModelSelectorDropdownContent(
                serverModelName: self.$serverModelName
            )
            .frame(width: 360, height: 480)
        }
    }
}
