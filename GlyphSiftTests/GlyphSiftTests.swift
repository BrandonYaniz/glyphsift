import AppKit
import XCTest
@testable import GlyphSift

final class GlyphSiftTests: XCTestCase {
    private let engine = CleaningEngine()
    private let detector = SourceFormatDetector()

    func testPrivacyCleanRemovesHiddenUnicode() {
        let result = engine.analyze("Hello\u{200B}World\u{FEFF}", preset: .privacyClean, settings: .default)

        XCTAssertEqual(result.cleaned, "HelloWorld")
        XCTAssertEqual(result.findings.filter { $0.category == .hiddenUnicode }.count, 2)
    }

    func testPrivacyCleanRemovesDirectionalOverride() {
        let result = engine.analyze("abc\u{202E}def", preset: .privacyClean, settings: .default)

        XCTAssertEqual(result.cleaned, "abcdef")
        XCTAssertEqual(result.findings.filter { $0.category == .hiddenUnicode }.count, 1)
    }

    func testPrivacyCleanRemovesUnicodeTagCharacters() {
        let result = engine.analyze("a\u{E0061}b", preset: .privacyClean, settings: .default)

        XCTAssertEqual(result.cleaned, "ab")
        XCTAssertEqual(result.findings.filter { $0.category == .hiddenUnicode }.count, 1)
    }

    func testPrivacyCleanRemovesVariationSelectors() {
        let result = engine.analyze("text\u{FE0F}", preset: .privacyClean, settings: .default)

        XCTAssertEqual(result.cleaned, "text")
        XCTAssertEqual(result.findings.filter { $0.category == .hiddenUnicode }.count, 1)
    }

    func testPrivacyCleanRemovesSoftHyphen() {
        let result = engine.analyze("soft\u{00AD}hyphen", preset: .privacyClean, settings: .default)

        XCTAssertEqual(result.cleaned, "softhyphen")
        XCTAssertEqual(result.findings.filter { $0.category == .hiddenUnicode }.count, 1)
    }

    func testPlainTextNormalizesNonbreakingSpace() {
        let result = engine.analyze("Hello\u{00A0}World", preset: .plainText, settings: .default)

        XCTAssertEqual(result.cleaned, "Hello World")
        XCTAssertEqual(result.findings.filter { $0.category == .whitespace }.count, 1)
    }

    func testPlainTextNormalizesLineBreaks() {
        let result = engine.analyze("A\r\nB\rC", preset: .plainText, settings: .default)

        XCTAssertEqual(result.cleaned, "A\nB\nC")
        XCTAssertGreaterThanOrEqual(result.findings.filter { $0.category == .whitespace }.count, 1)
    }

    func testPublishingCleanNormalizesSmartQuotes() {
        let result = engine.analyze("“Hello,” she said. ‘Yes.’", preset: .publishingClean, settings: .default)

        XCTAssertEqual(result.cleaned, "\"Hello,\" she said. 'Yes.'")
        XCTAssertEqual(result.findings.filter { $0.category == .punctuation }.count, 4)
    }

    func testPublishingCleanNormalizesEllipses() {
        let result = engine.analyze("Wait…", preset: .publishingClean, settings: .default)

        XCTAssertEqual(result.cleaned, "Wait...")
        XCTAssertEqual(result.findings.filter { $0.category == .punctuation }.count, 1)
    }

    func testPublishingCleanNormalizesDashes() {
        let result = engine.analyze("A—B–C", preset: .publishingClean, settings: .default)

        XCTAssertEqual(result.cleaned, "A-B-C")
        XCTAssertEqual(result.findings.filter { $0.category == .punctuation }.count, 2)
    }

    func testCodeSafePreservesTabsAndRepeatedSpaces() {
        let input = "func test() {\n\tlet x  =  1\n}"
        let result = engine.analyze(input, preset: .codeSafe, settings: .default)

        XCTAssertEqual(result.cleaned, input)
    }

    func testRegexBlankReplacementRemovesMatches() {
        var settings = AppSettings.default
        settings.regexRules = [RegexRule(name: "Remove foo", findPattern: "foo", replacement: "", order: 0)]

        let result = engine.analyze("foo bar foo", preset: .plainText, settings: settings)

        XCTAssertEqual(result.cleaned, " bar ")
        XCTAssertEqual(result.findings.filter { $0.category == .regex }.count, 2)
    }

    func testRegexReplacementWorks() {
        var settings = AppSettings.default
        settings.regexRules = [RegexRule(name: "Replace foo", findPattern: "(foo)", replacement: "bar", order: 0)]

        let result = engine.analyze("foo foo", preset: .plainText, settings: settings)

        XCTAssertEqual(result.cleaned, "bar bar")
        XCTAssertEqual(result.findings.filter { $0.category == .regex }.count, 2)
    }

    func testInvalidRegexDoesNotCrash() {
        var settings = AppSettings.default
        settings.regexRules = [RegexRule(name: "Invalid", findPattern: "[", replacement: "", order: 0)]

        let result = engine.analyze("foo", preset: .plainText, settings: settings)

        XCTAssertEqual(result.cleaned, "foo")
        XCTAssertTrue(result.findings.isEmpty)
    }

    func testAggressiveCleanRemovesTrackingParametersFromURLs() {
        var settings = AppSettings.default
        settings.urlCleaning.removeTrackingParameters = true

        let result = engine.analyze("Visit https://example.com/page?utm_source=newsletter&id=42&fbclid=abc.", preset: .aggressiveClean, settings: settings)

        XCTAssertEqual(result.cleaned, "Visit https://example.com/page?id=42.")
        XCTAssertEqual(result.findings.filter { $0.category == .urlTracking }.count, 1)
    }

    func testURLTrackingCleanupLeavesLinksAloneWhenDisabled() {
        let result = engine.analyze("https://example.com/?utm_source=newsletter&id=42", preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(result.cleaned, "https://example.com/?utm_source=newsletter&id=42")
        XCTAssertTrue(result.findings.filter { $0.category == .urlTracking }.isEmpty)
    }

    func testURLTrackingCleanupMatchesParameterNamesCaseInsensitively() {
        var settings = AppSettings.default
        settings.urlCleaning.removeTrackingParameters = true

        let result = engine.analyze("https://example.com/?UTM_Source=newsletter&id=42", preset: .aggressiveClean, settings: settings)

        XCTAssertEqual(result.cleaned, "https://example.com/?id=42")
        XCTAssertEqual(result.findings.filter { $0.category == .urlTracking }.count, 1)
    }

    func testURLTrackingCleanupRemovesEmptyQueryWhenOnlyTrackingRemains() {
        var settings = AppSettings.default
        settings.urlCleaning.removeTrackingParameters = true

        let result = engine.analyze("https://example.com/?utm_source=newsletter.", preset: .aggressiveClean, settings: settings)

        XCTAssertEqual(result.cleaned, "https://example.com/.")
        XCTAssertEqual(result.findings.filter { $0.category == .urlTracking }.count, 1)
    }

    func testURLTrackingCleanupHandlesMultipleLinks() {
        var settings = AppSettings.default
        settings.urlCleaning.removeTrackingParameters = true

        let result = engine.analyze("A https://a.com/?utm_source=x&id=1 B https://b.com/?fbclid=y&page=2", preset: .aggressiveClean, settings: settings)

        XCTAssertEqual(result.cleaned, "A https://a.com/?id=1 B https://b.com/?page=2")
        XCTAssertEqual(result.findings.filter { $0.category == .urlTracking }.count, 2)
    }

    func testPresetCountsCanBeComputedFromFindings() {
        let result = engine.analyze("Hello\u{200B} “World”", preset: .aggressiveClean, settings: .default)

        XCTAssertGreaterThan(result.findings.count, 0)
    }

    func testSourceFormatDetectsHTML() {
        XCTAssertEqual(detector.detect("<p>Hello</p>"), .html)
    }

    func testSourceFormatDetectsHTMLDocument() {
        XCTAssertEqual(detector.detect("<!doctype html><html><body>Hello</body></html>"), .html)
    }

    func testSourceFormatDetectsHTMLTable() {
        XCTAssertEqual(detector.detect("<table><tr><td>Total</td></tr></table>"), .html)
    }

    func testSourceFormatDetectsMarkdown() {
        XCTAssertEqual(detector.detect("## Heading\n\n[Link](https://example.com)"), .markdown)
    }

    func testSourceFormatDetectsMarkdownLists() {
        XCTAssertEqual(detector.detect("- One\n- Two"), .markdown)
    }

    func testSourceFormatDetectsMarkdownFences() {
        XCTAssertEqual(detector.detect("```swift\nlet value = 1\n```"), .markdown)
    }

    func testSourceFormatKeepsPlainTextWithComparisonSymbols() {
        XCTAssertEqual(detector.detect("Use 1 < 2 and 3 > 2 in examples."), .plainText)
    }

    func testPlainTextOnlyOffersPlainTextOutput() {
        XCTAssertEqual(OutputFormat.available(for: .plainText), [.plainText])
    }

    func testMarkdownOffersFormattedOutputs() {
        XCTAssertEqual(OutputFormat.available(for: .markdown), [.raw, .plainText, .markdown, .html, .richText])
    }

    func testRichTextOffersFormattedOutputsWithoutRaw() {
        XCTAssertEqual(OutputFormat.available(for: .richText), [.plainText, .markdown, .html, .richText])
    }

    func testPasteboardFormatDetectsRichText() {
        let detector = PasteboardSourceFormatDetector()

        XCTAssertEqual(detector.detect(types: ["public.utf8-plain-text", "public.rtf"]), .richText)
    }

    func testPasteboardFormatDetectsHTML() {
        let detector = PasteboardSourceFormatDetector()

        XCTAssertEqual(detector.detect(types: ["public.html", "public.utf8-plain-text"]), .html)
    }

    func testRawMarkdownPreservesMarkupWhileCleaningText() throws {
        let cleaner = SourcePreservingCleaner()
        let raw = cleaner.clean("## “Title”\n\nThis\u{00A0}has\u{200B}spaces.", sourceFormat: .markdown, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "## \"Title\"\n\nThis hasspaces.")
    }

    func testRawMarkdownCleansFencedCodeConservatively() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "```js\nconst value = “keep”;\u{200B}\n```\n\n“Clean”"
        let raw = cleaner.clean(input, sourceFormat: .markdown, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "```js\nconst value = “keep”;\n```\n\n\"Clean\"")
    }

    func testRawMarkdownCleansFrontMatterConservatively() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "---\ntitle: “Keep”\u{200B}\n---\n\n“Clean”"
        let raw = cleaner.clean(input, sourceFormat: .markdown, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "---\ntitle: “Keep”\n---\n\n\"Clean\"")
    }

    func testRawMarkdownCleansReferenceLinksConservatively() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "[ref]: https://example.com/“keep”\u{200B}\n\n“Clean”"
        let raw = cleaner.clean(input, sourceFormat: .markdown, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "[ref]: https://example.com/“keep”\n\n\"Clean\"")
    }

    func testRawMarkdownPreservesEscapedMarkup() throws {
        let cleaner = SourcePreservingCleaner()
        let raw = cleaner.clean(#"Use \*literal\* markup and “clean” text."#, sourceFormat: .markdown, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, #"Use \*literal\* markup and "clean" text."#)
    }

    func testRawHTMLPreservesTagsAndScriptWhileCleaningVisibleText() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "<p>“Hello”\u{00A0}there\u{200B}</p><script>const x = “keep”;\u{200B}  </script>"
        let raw = cleaner.clean(input, sourceFormat: .html, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "<p>\"Hello\" there</p><script>const x = “keep”;  </script>")
    }

    func testRawHTMLCleansStyleContentConservatively() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "<style>.title::before { content: “keep”;\u{200B} }</style><p>“Clean”</p>"
        let raw = cleaner.clean(input, sourceFormat: .html, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "<style>.title::before { content: “keep”; }</style><p>\"Clean\"</p>")
    }

    func testRawHTMLPreservesTagsWithGreaterThanInAttributes() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "<p data-label=\"1 > 0\u{200B}\">“Clean”</p>"
        let raw = cleaner.clean(input, sourceFormat: .html, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "<p data-label=\"1 > 0\">\"Clean\"</p>")
    }

    func testRawHTMLCleansCommentsConservatively() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "<!-- “keep” > marker\u{200B} -->\n<p>“Clean”</p>"
        let raw = cleaner.clean(input, sourceFormat: .html, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "<!-- “keep” > marker -->\n<p>\"Clean\"</p>")
    }

    func testRendererConvertsMarkdownToPlainText() throws {
        let result = engine.analyze("## Heading\n\nA [link](https://example.com)", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .plainText, sourceFormat: .markdown, rawText: result.cleaned)

        XCTAssertEqual(output.plainText, "Heading\n\nA link")
    }

    func testRendererConvertsHTMLToPlainText() throws {
        let result = engine.analyze("<h1>Heading</h1><p>A&nbsp;line</p>", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .plainText, sourceFormat: .html, rawText: result.cleaned)

        XCTAssertEqual(output.plainText, "Heading\nA line")
        XCTAssertEqual(output.warnings, ["Formatting is removed for Plain Text output."])
    }

    func testAttributedCleanerPreservesFormattingWhenTextIsCleaned() throws {
        let input = NSMutableAttributedString(string: "“Bold”\u{00A0}text")
        input.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 1, length: 4))
        let result = engine.analyze(input.string, preset: .publishingClean, settings: .default)

        let output = AttributedTextCleaner().clean(input, result: result)
        let font = try XCTUnwrap(output.attribute(.font, at: 1, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(output.string, "\"Bold\" text")
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    func testRendererUsesCleanedRichTextWhenAvailable() throws {
        let input = NSMutableAttributedString(string: "Bold")
        input.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSRange(location: 0, length: 4))
        let result = engine.analyze(input.string, preset: .plainText, settings: .default)

        let output = try OutputRenderer().render(result, format: .richText, sourceFormat: .richText, rawText: result.cleaned, richText: input)
        let font = try XCTUnwrap(output.attributedString?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(output.plainText, "Bold")
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    func testRendererConvertsMarkdownHeadingsToRichText() throws {
        let result = engine.analyze("# Heading", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .richText, sourceFormat: .markdown, rawText: result.cleaned)
        let font = try XCTUnwrap(output.attributedString?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(output.plainText, "Heading")
        XCTAssertEqual(font.pointSize, 24)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    func testRendererConvertsMarkdownListsToRichText() throws {
        let result = engine.analyze("- First\n1. Second", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .richText, sourceFormat: .markdown, rawText: result.cleaned)

        XCTAssertEqual(output.plainText, "• First\n1. Second")
    }

    func testRendererConvertsInlineMarkdownToRichText() throws {
        let result = engine.analyze("Use **bold**, *italic*, and `code`.", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .richText, sourceFormat: .markdown, rawText: result.cleaned)
        let attributed = try XCTUnwrap(output.attributedString)
        let text = attributed.string as NSString
        let boldFont = try XCTUnwrap(attributed.attribute(.font, at: text.range(of: "bold").location, effectiveRange: nil) as? NSFont)
        let italicFont = try XCTUnwrap(attributed.attribute(.font, at: text.range(of: "italic").location, effectiveRange: nil) as? NSFont)
        let codeFont = try XCTUnwrap(attributed.attribute(.font, at: text.range(of: "code").location, effectiveRange: nil) as? NSFont)

        XCTAssertEqual(attributed.string, "Use bold, italic, and code.")
        XCTAssertTrue(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
        XCTAssertTrue(NSFontManager.shared.traits(of: italicFont).contains(.italicFontMask))
        XCTAssertTrue(codeFont.fontName.lowercased().contains("mono"))
    }

    func testRendererConvertsMarkdownLinksToRichText() throws {
        let result = engine.analyze("[OpenAI](https://openai.com)", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .richText, sourceFormat: .markdown, rawText: result.cleaned)
        let attributed = try XCTUnwrap(output.attributedString)
        let link = try XCTUnwrap(attributed.attribute(.link, at: 0, effectiveRange: nil) as? URL)

        XCTAssertEqual(attributed.string, "OpenAI")
        XCTAssertEqual(link.absoluteString, "https://openai.com")
    }

    func testSettingsStoreExportsAndImportsSettings() throws {
        var settings = AppSettings.default
        settings.selectedPreset = .aggressiveClean
        settings.selectedOutputFormat = .html
        settings.regexRules = [
            RegexRule(name: "Trim SKU prefix", findPattern: #"SKU-(\d+)"#, replacement: "$1", order: 0)
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GlyphSiftSettings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try SettingsStore().export(settings, to: url)
        let imported = try SettingsStore().import(from: url)

        XCTAssertEqual(imported.selectedPreset, .aggressiveClean)
        XCTAssertEqual(imported.selectedOutputFormat, .html)
        XCTAssertEqual(imported.regexRules, settings.regexRules)
    }

    func testSettingsStoreRejectsMalformedImport() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GlyphSiftBadSettings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"selectedPreset":"plainText"}"#.utf8).write(to: url)

        XCTAssertThrowsError(try SettingsStore().import(from: url))
    }

    @MainActor
    func testViewModelFallsBackToPlainTextOutputForPlainTextInput() {
        let store = temporarySettingsStore()
        defer { try? FileManager.default.removeItem(at: store.settingsURL) }
        let viewModel = GlyphSiftViewModel(store: store)

        viewModel.originalText = "<p>Hello</p>"
        viewModel.selectedOutputFormat = .html
        viewModel.originalText = "Hello"

        XCTAssertEqual(viewModel.sourceFormat, .plainText)
        XCTAssertEqual(viewModel.availableOutputFormats, [.plainText])
        XCTAssertEqual(viewModel.selectedOutputFormat, .plainText)
    }

    @MainActor
    func testViewModelPersistsSettingsToInjectedStore() {
        let store = temporarySettingsStore()
        defer { try? FileManager.default.removeItem(at: store.settingsURL) }
        let viewModel = GlyphSiftViewModel(store: store)

        viewModel.selectedPreset = .aggressiveClean

        XCTAssertEqual(store.load().selectedPreset, .aggressiveClean)
    }

    func testClipboardWriterCopiesHTMLWithPlainTextFallback() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("GlyphSiftHTML.\(UUID().uuidString)"))
        let output = RenderedOutput(displayText: "<p>Hello</p>", plainText: "<p>Hello</p>", attributedString: nil, rtfData: nil)

        let message = ClipboardWriter().write(output, format: .html, sourceFormat: .markdown, to: pasteboard)

        XCTAssertEqual(message, "Copied")
        XCTAssertEqual(pasteboard.string(forType: .html), "<p>Hello</p>")
        XCTAssertEqual(pasteboard.string(forType: .string), "<p>Hello</p>")
    }

    func testClipboardWriterCopiesRichTextWithPlainTextFallback() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("GlyphSiftRTF.\(UUID().uuidString)"))
        let attributed = NSAttributedString(string: "Hello", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        let rtf = try XCTUnwrap(try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]))
        let output = RenderedOutput(displayText: "Hello", plainText: "Hello", attributedString: attributed, rtfData: rtf)

        let message = ClipboardWriter().write(output, format: .richText, sourceFormat: .richText, to: pasteboard)

        XCTAssertEqual(message, "Copied")
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
        XCTAssertEqual(pasteboard.string(forType: .string), "Hello")
    }

    func testRendererWarnsForBestEffortConversion() throws {
        let result = engine.analyze("## Heading", preset: .plainText, settings: .default)
        let output = try OutputRenderer().render(result, format: .html, sourceFormat: .markdown, rawText: result.cleaned)

        XCTAssertEqual(output.warnings, ["Conversion is best effort. Raw keeps the most complete source when available."])
    }

    private func temporarySettingsStore() -> SettingsStore {
        SettingsStore(customSettingsURL: FileManager.default.temporaryDirectory.appendingPathComponent("GlyphSiftSettings-\(UUID().uuidString).json"))
    }
}
