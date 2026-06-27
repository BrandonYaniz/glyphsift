import AppKit
import Combine
import Foundation

@MainActor
final class GlyphSiftViewModel: ObservableObject {
    @Published var originalText: String = "" {
        didSet { recompute() }
    }

    @Published var cleanedText: String = ""
    @Published var renderedOutput: RenderedOutput = .empty
    @Published var sourceFormat: SourceFormat = .plainText
    @Published var availableOutputFormats: [OutputFormat] = OutputFormat.available(for: .plainText)

    @Published var selectedPreset: CleaningPreset {
        didSet {
            settings.selectedPreset = selectedPreset
            recomputeAndSave()
        }
    }

    @Published var selectedOutputFormat: OutputFormat {
        didSet {
            settings.selectedOutputFormat = selectedOutputFormat
            recomputeAndSave()
        }
    }

    @Published var settings: AppSettings {
        didSet {
            if settings.selectedPreset != selectedPreset {
                selectedPreset = settings.selectedPreset
            }
            if settings.selectedOutputFormat != selectedOutputFormat {
                selectedOutputFormat = settings.selectedOutputFormat
            }
            recomputeAndSave()
        }
    }

    @Published var selectedResult: CleaningResult = .empty
    @Published var presetCounts: [CleaningPreset: Int] = [:]
    @Published var statusMessage: String?

    private let engine = CleaningEngine()
    private let renderer = OutputRenderer()
    private let formatDetector = SourceFormatDetector()
    private let pasteboardFormatDetector = PasteboardSourceFormatDetector()
    private let sourcePreservingCleaner = SourcePreservingCleaner()
    private let attributedTextCleaner = AttributedTextCleaner()
    private let clipboardWriter = ClipboardWriter()
    private let store: SettingsStore
    private var isUpdatingSettings = false
    private var pastedSourceFormat: SourceFormat?
    private var pastedAttributedText: NSAttributedString?

    convenience init() {
        self.init(store: SettingsStore())
    }

    init(store: SettingsStore) {
        self.store = store
        let loaded = store.load()
        self.settings = loaded
        self.selectedPreset = loaded.selectedPreset
        self.selectedOutputFormat = loaded.selectedOutputFormat
        recompute()
    }

    func recompute() {
        if originalText.isEmpty {
            pastedSourceFormat = nil
            pastedAttributedText = nil
        }

        sourceFormat = pastedSourceFormat ?? formatDetector.detect(originalText)
        availableOutputFormats = OutputFormat.available(for: sourceFormat)
        if !availableOutputFormats.contains(selectedOutputFormat) {
            selectedOutputFormat = availableOutputFormats.first ?? .plainText
            return
        }

        selectedResult = engine.analyze(originalText, preset: selectedPreset, settings: settings)
        cleanedText = selectedResult.cleaned
        let rawText = cleanedRawText(for: selectedResult)
        let richText = cleanedRichText(for: selectedResult)
        renderedOutput = (try? renderer.render(selectedResult, format: selectedOutputFormat, sourceFormat: sourceFormat, rawText: rawText, richText: richText)) ?? RenderedOutput(displayText: cleanedText, plainText: cleanedText, attributedString: nil, rtfData: nil)

        var counts: [CleaningPreset: Int] = [:]
        for preset in CleaningPreset.allCases {
            counts[preset] = engine.analyze(originalText, preset: preset, settings: settings).findings.count
        }
        presetCounts = counts
    }

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        var next = settings
        update(&next)
        settings = next
    }

    func copyCleanedOutput() {
        statusMessage = clipboardWriter.write(renderedOutput, format: selectedOutputFormat, sourceFormat: sourceFormat)
    }

    func clear() {
        originalText = ""
        pastedSourceFormat = nil
        pastedAttributedText = nil
        statusMessage = nil
    }

    func capturePasteboard(_ pasteboard: NSPasteboard) {
        let typeNames = pasteboard.types?.map(\.rawValue) ?? []
        pastedSourceFormat = pasteboardFormatDetector.detect(types: typeNames)
        pastedAttributedText = richText(from: pasteboard)
    }

    func addRegexRule() {
        let order = (settings.regexRules.map(\.order).max() ?? -1) + 1
        updateSettings {
            $0.regexRules.append(RegexRule(name: "New Rule", findPattern: "", order: order))
        }
    }

    func deleteRegexRule(_ rule: RegexRule) {
        updateSettings {
            $0.regexRules.removeAll { $0.id == rule.id }
            normalizeRuleOrder(&$0.regexRules)
        }
    }

    func moveRegexRule(_ rule: RegexRule, direction: Int) {
        updateSettings {
            let sorted = $0.regexRules.sorted { $0.order < $1.order }
            guard let index = sorted.firstIndex(where: { $0.id == rule.id }) else { return }
            let target = index + direction
            guard sorted.indices.contains(target) else { return }
            var moved = sorted
            moved.swapAt(index, target)
            normalizeRuleOrder(&moved)
            $0.regexRules = moved
        }
    }

    func regexError(for rule: RegexRule) -> String? {
        guard !rule.findPattern.isEmpty else { return nil }
        do {
            _ = try NSRegularExpression(pattern: rule.findPattern, options: regexOptions(for: rule))
            return nil
        } catch {
            return "That regex pattern is invalid."
        }
    }

    func exportSettings(to url: URL) {
        do {
            try store.export(settings, to: url)
            statusMessage = "Settings exported"
        } catch {
            statusMessage = "Settings could not be exported."
        }
    }

    func importSettings(from url: URL) {
        do {
            settings = try store.import(from: url)
            statusMessage = "Settings imported"
        } catch {
            statusMessage = "Settings could not be imported."
        }
    }
}

private extension GlyphSiftViewModel {
    func recomputeAndSave() {
        guard !isUpdatingSettings else { return }
        recompute()
        do {
            try store.save(settings)
        } catch {
            statusMessage = "Settings could not be saved."
        }
    }

    func regexOptions(for rule: RegexRule) -> NSRegularExpression.Options {
        var options: NSRegularExpression.Options = []
        if !rule.caseSensitive { options.insert(.caseInsensitive) }
        if rule.multiline { options.insert(.anchorsMatchLines) }
        if rule.dotMatchesNewline { options.insert(.dotMatchesLineSeparators) }
        return options
    }

    func cleanedRichText(for result: CleaningResult) -> NSAttributedString? {
        guard sourceFormat == .richText, let pastedAttributedText else {
            return nil
        }
        return attributedTextCleaner.clean(pastedAttributedText, result: result)
    }

    func cleanedRawText(for result: CleaningResult) -> String {
        switch sourceFormat {
        case .markdown, .html:
            return sourcePreservingCleaner.clean(originalText, sourceFormat: sourceFormat, preset: selectedPreset, settings: settings)
        case .plainText, .richText:
            return result.cleaned
        }
    }

    func richText(from pasteboard: NSPasteboard) -> NSAttributedString? {
        if let data = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            return attributed
        }
        return nil
    }
}

private func normalizeRuleOrder(_ rules: inout [RegexRule]) {
    for index in rules.indices {
        rules[index].order = index
    }
}
