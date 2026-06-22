import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GlyphSiftViewModel()
    @State private var isShowingSettings = false

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            presetRow
            HSplitView {
                originalPane
                    .frame(minWidth: 360)
                cleanPane
                    .frame(minWidth: 360)
            }
            ReportView(result: viewModel.selectedResult, rules: viewModel.settings.regexRules)
                .frame(maxHeight: 190)
        }
        .padding(14)
        .frame(minWidth: 980, minHeight: 720)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("GlyphSift")
                .font(.title2.weight(.semibold))
            Spacer()
            Picker("Output Type", selection: $viewModel.selectedOutputFormat) {
                ForEach(OutputFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Button("Copy Cleaned") {
                viewModel.copyCleanedOutput()
            }
            .disabled(viewModel.cleanedText.isEmpty)
            Button("Clear") {
                viewModel.clear()
            }
            Button("Settings") {
                isShowingSettings = true
            }
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(CleaningPreset.allCases) { preset in
                Button {
                    viewModel.selectedPreset = preset
                } label: {
                    HStack {
                        Text(preset.displayName)
                        Text("\(viewModel.presetCounts[preset] ?? 0)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(viewModel.selectedPreset == preset ? .white.opacity(0.2) : .secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.selectedPreset == preset ? .accentColor : .gray.opacity(0.45))
            }
        }
    }

    private var originalPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            paneHeader(title: "Original", text: viewModel.originalText)
            HighlightedTextView(
                text: $viewModel.originalText,
                findings: viewModel.selectedResult.findings,
                isEditable: true,
                placeholder: "Paste text here."
            )
            if markerPreview != viewModel.originalText, !viewModel.originalText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hidden Character Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(markerPreview)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 70)
                }
            }
        }
    }

    private var cleanPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                paneHeader(title: "Clean", text: viewModel.renderedOutput.plainText)
                Spacer()
                Button("Copy") {
                    viewModel.copyCleanedOutput()
                }
                .disabled(viewModel.cleanedText.isEmpty)
            }
            if viewModel.selectedOutputFormat == .richText {
                RichTextPreview(attributedString: viewModel.renderedOutput.attributedString, fallbackText: viewModel.renderedOutput.displayText)
            } else {
                HighlightedTextView(
                    text: .constant(viewModel.cleanedText),
                    findings: [],
                    isEditable: false,
                    placeholder: "Cleaned text will appear here."
                )
            }
        }
    }

    private func paneHeader(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text("\(text.count) characters · \(text.split { $0.isWhitespace }.count) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var markerPreview: String {
        var output = viewModel.originalText
        let hidden = viewModel.selectedResult.findings
            .filter { $0.category == .hiddenUnicode }
            .sorted { $0.range.location > $1.range.location }
        for finding in hidden {
            guard let range = Range(finding.range, in: output) else { continue }
            output.replaceSubrange(range, with: marker(for: finding))
        }
        return output
    }

    private func marker(for finding: CleaningFinding) -> String {
        switch finding.label {
        case "Zero width space":
            return "⟦ZWSP⟧"
        case "Zero width non joiner":
            return "⟦ZWNJ⟧"
        case "Zero width joiner":
            return "⟦ZWJ⟧"
        case "Byte order mark":
            return "⟦BOM⟧"
        case "Soft hyphen":
            return "⟦SHY⟧"
        case "Word joiner":
            return "⟦WJ⟧"
        case "Unicode tag character":
            return "⟦TAG⟧"
        case "Variation selector":
            return "⟦VS⟧"
        case "Directional control":
            return "⟦BIDI⟧"
        default:
            return "⟦HIDDEN⟧"
        }
    }
}
