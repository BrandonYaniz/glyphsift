import XCTest
@testable import GlyphSift

final class GlyphSiftTests: XCTestCase {
    private let engine = CleaningEngine()

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
}
