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

    func testPresetCountsCanBeComputedFromFindings() {
        let result = engine.analyze("Hello\u{200B} “World”", preset: .aggressiveClean, settings: .default)

        XCTAssertGreaterThan(result.findings.count, 0)
    }

    func testSourceFormatDetectsHTML() {
        XCTAssertEqual(detector.detect("<p>Hello</p>"), .html)
    }

    func testSourceFormatDetectsMarkdown() {
        XCTAssertEqual(detector.detect("## Heading\n\n[Link](https://example.com)"), .markdown)
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

    func testRawHTMLPreservesTagsAndScriptWhileCleaningVisibleText() throws {
        let cleaner = SourcePreservingCleaner()
        let input = "<p>“Hello”\u{00A0}there\u{200B}</p><script>const x = “keep”;  </script>"
        let raw = cleaner.clean(input, sourceFormat: .html, preset: .aggressiveClean, settings: .default)

        XCTAssertEqual(raw, "<p>\"Hello\" there</p><script>const x = “keep”;  </script>")
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
}
