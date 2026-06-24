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
    private let sourcePreservingCleaner = SourcePreservingCleaner()
    private let store = SettingsStore()
    private var isUpdatingSettings = false

    init() {
        let loaded = store.load()
        self.settings = loaded
        self.selectedPreset = loaded.selectedPreset
        self.selectedOutputFormat = loaded.selectedOutputFormat
        recompute()
    }

    func recompute() {
        sourceFormat = formatDetector.detect(originalText)
        availableOutputFormats = OutputFormat.available(for: sourceFormat)
        if !availableOutputFormats.contains(selectedOutputFormat) {
            selectedOutputFormat = availableOutputFormats.first ?? .plainText
            return
        }

        selectedResult = engine.analyze(originalText, preset: selectedPreset, settings: settings)
        cleanedText = selectedResult.cleaned
        let rawText = sourcePreservingCleaner.clean(originalText, sourceFormat: sourceFormat, preset: selectedPreset, settings: settings)
        renderedOutput = (try? renderer.render(selectedResult, format: selectedOutputFormat, sourceFormat: sourceFormat, rawText: rawText)) ?? RenderedOutput(displayText: cleanedText, plainText: cleanedText, attributedString: nil, rtfData: nil)

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
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch selectedOutputFormat {
        case .raw, .markdown, .html:
            pasteboard.setString(renderedOutput.plainText, forType: .string)
            statusMessage = "Copied"
        case .plainText:
            pasteboard.setString(renderedOutput.plainText, forType: .string)
            statusMessage = "Copied"
        case .richText:
            if let rtfData = renderedOutput.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
                pasteboard.setString(renderedOutput.plainText, forType: .string)
                statusMessage = "Copied"
            } else {
                pasteboard.setString(renderedOutput.plainText, forType: .string)
                statusMessage = "Rich Text rendering failed, copied plain text instead."
            }
        }
    }

    func clear() {
        originalText = ""
        statusMessage = nil
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
}

private func normalizeRuleOrder(_ rules: inout [RegexRule]) {
    for index in rules.indices {
        rules[index].order = index
    }
}
