import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: GlyphSiftViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                presetSection
                unicodeSection
                whitespaceSection
                punctuationSection
                markdownSection
                htmlSection
                urlSection
                regexSection
                importExportSection
            }
            .formStyle(.grouped)

            HStack {
                Text("Version \(AppVersion.display)")
                    .foregroundStyle(.secondary)
                if let status = viewModel.statusMessage {
                    Text(status)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 680, minHeight: 620)
    }

    private var presetSection: some View {
        Section("Presets") {
            Picker("Selected preset", selection: $viewModel.selectedPreset) {
                ForEach(CleaningPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            Picker("Output type", selection: $viewModel.selectedOutputFormat) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
        }
    }

    private var unicodeSection: some View {
        Section("Unicode Cleaning") {
            Toggle("Remove zero width characters", isOn: binding(\.unicode.removeZeroWidthCharacters))
            Toggle("Remove directional controls", isOn: binding(\.unicode.removeBidiControls))
            Toggle("Remove variation selectors", isOn: binding(\.unicode.removeVariationSelectors))
            Toggle("Remove Unicode tag characters", isOn: binding(\.unicode.removeTagCharacters))
            Toggle("Remove soft hyphen", isOn: binding(\.unicode.removeSoftHyphen))
            Toggle("Remove combining marks in Aggressive Clean", isOn: binding(\.unicode.removeCombiningMarksAggressive))
            Toggle("Normalize confusables in Aggressive Clean", isOn: binding(\.unicode.normalizeConfusablesAggressive))
        }
    }

    private var whitespaceSection: some View {
        Section("Whitespace and Line Breaks") {
            Toggle("Normalize line breaks", isOn: binding(\.whitespace.normalizeLineBreaks))
            Toggle("Normalize no-break spaces", isOn: binding(\.whitespace.normalizeNoBreakSpaces))
            Toggle("Trim trailing whitespace", isOn: binding(\.whitespace.trimTrailingWhitespace))
            Toggle("Collapse multiple spaces", isOn: binding(\.whitespace.collapseMultipleSpaces))
            Toggle("Collapse excessive blank lines", isOn: binding(\.whitespace.collapseExcessiveBlankLines))
            Toggle("Convert tabs to spaces", isOn: binding(\.whitespace.convertTabsToSpaces))
            Stepper("Tab width: \(viewModel.settings.whitespace.tabWidth)", value: intBinding(\.whitespace.tabWidth, range: 1...12))
        }
    }

    private var punctuationSection: some View {
        Section("Punctuation") {
            Toggle("Normalize smart quotes", isOn: binding(\.punctuation.normalizeSmartQuotes))
            Toggle("Normalize ellipses", isOn: binding(\.punctuation.normalizeEllipses))
            Toggle("Normalize dashes", isOn: binding(\.punctuation.normalizeDashes))
            Picker("Dash replacement", selection: dashBinding) {
                ForEach(DashReplacement.allCases) { replacement in
                    Text(replacement.displayName).tag(replacement)
                }
            }
        }
    }

    private var markdownSection: some View {
        Section("Markdown") {
            Toggle("Convert links to text", isOn: binding(\.markdown.convertLinksToText))
            Toggle("Remove images and keep alt text", isOn: binding(\.markdown.removeImagesKeepAltText))
            Toggle("Strip code fences", isOn: binding(\.markdown.stripCodeFences))
            Toggle("Strip blockquote markers", isOn: binding(\.markdown.stripBlockquoteMarkers))
        }
    }

    private var htmlSection: some View {
        Section("HTML") {
            Toggle("Decode common HTML entities", isOn: binding(\.html.decodeEntities))
            Toggle("Strip HTML tags", isOn: binding(\.html.stripTags))
        }
    }

    private var urlSection: some View {
        Section("URL Cleaning") {
            Toggle("Remove tracking parameters", isOn: binding(\.urlCleaning.removeTrackingParameters))
            Text("Removes known marketing parameters while keeping the rest of the link intact.")
                .foregroundStyle(.secondary)
        }
    }

    private var regexSection: some View {
        Section("Custom Regex Rules") {
            Toggle("Run custom regex rules in Code Safe", isOn: binding(\.runCustomRegexInCodeSafe))
            ForEach(viewModel.settings.regexRules.sorted { $0.order < $1.order }) { rule in
                RegexRuleEditor(
                    rule: regexBinding(for: rule),
                    error: viewModel.regexError(for: rule),
                    moveUp: { viewModel.moveRegexRule(rule, direction: -1) },
                    moveDown: { viewModel.moveRegexRule(rule, direction: 1) },
                    delete: { viewModel.deleteRegexRule(rule) }
                )
            }
            Button("Add Rule") {
                viewModel.addRegexRule()
            }
        }
    }

    private var importExportSection: some View {
        Section("Import and Export") {
            HStack {
                Button("Import JSON…") {
                    importSettings()
                }
                Button("Export JSON…") {
                    exportSettings()
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding {
            viewModel.settings[keyPath: keyPath]
        } set: { value in
            viewModel.updateSettings { $0[keyPath: keyPath] = value }
        }
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppSettings, Int>, range: ClosedRange<Int>) -> Binding<Int> {
        Binding {
            viewModel.settings[keyPath: keyPath]
        } set: { value in
            viewModel.updateSettings { $0[keyPath: keyPath] = min(max(value, range.lowerBound), range.upperBound) }
        }
    }

    private var dashBinding: Binding<DashReplacement> {
        Binding {
            viewModel.settings.punctuation.dashReplacement
        } set: { value in
            viewModel.updateSettings { $0.punctuation.dashReplacement = value }
        }
    }

    private func regexBinding(for rule: RegexRule) -> Binding<RegexRule> {
        Binding {
            viewModel.settings.regexRules.first(where: { $0.id == rule.id }) ?? rule
        } set: { updated in
            viewModel.updateSettings { settings in
                guard let index = settings.regexRules.firstIndex(where: { $0.id == updated.id }) else { return }
                settings.regexRules[index] = updated
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importSettings(from: url)
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "GlyphSift Settings.json"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.exportSettings(to: url)
        }
    }
}

private struct RegexRuleEditor: View {
    @Binding var rule: RegexRule
    let error: String?
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enabled", isOn: $rule.enabled)
                TextField("Name", text: $rule.name)
                Button("Up", action: moveUp)
                Button("Down", action: moveDown)
                Button("Delete", role: .destructive, action: delete)
            }
            TextField("Find regex", text: $rule.findPattern)
            TextField("Replace with blank to remove", text: $rule.replacement)
            HStack {
                Toggle("Case sensitive", isOn: $rule.caseSensitive)
                Toggle("Multiline", isOn: $rule.multiline)
                Toggle("Dot matches newline", isOn: $rule.dotMatchesNewline)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }
}
