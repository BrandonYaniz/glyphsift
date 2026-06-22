import Foundation

struct CleaningEngine {
    func analyze(_ input: String, preset: CleaningPreset, settings: AppSettings) -> CleaningResult {
        guard !input.isEmpty else {
            return CleaningResult(
                original: input,
                cleaned: input,
                findings: [],
                report: CleaningReport.empty(presetName: preset.displayName)
            )
        }

        var findings: [CleaningFinding] = []
        findings.append(contentsOf: analyzeHiddenUnicode(input, preset: preset, settings: settings))
        findings.append(contentsOf: analyzeWhitespace(input, preset: preset, settings: settings))
        findings.append(contentsOf: analyzePunctuation(input, preset: preset, settings: settings))
        findings.append(contentsOf: analyzeMarkdown(input, preset: preset, settings: settings))
        findings.append(contentsOf: analyzeHTML(input, preset: preset, settings: settings))
        findings.append(contentsOf: analyzeRegexRules(input, preset: preset, settings: settings))

        var cleaned = input
        cleaned = applyHiddenUnicodeRemoval(cleaned, preset: preset, settings: settings)
        cleaned = applyWhitespaceNormalization(cleaned, preset: preset, settings: settings)
        cleaned = applyPunctuationNormalization(cleaned, preset: preset, settings: settings)
        cleaned = applyMarkdownCleanup(cleaned, preset: preset, settings: settings)
        cleaned = applyHTMLCleanup(cleaned, preset: preset, settings: settings)
        cleaned = applyRegexRules(cleaned, preset: preset, settings: settings)

        return CleaningResult(
            original: input,
            cleaned: cleaned,
            findings: findings.sorted { $0.range.location < $1.range.location },
            report: makeReport(original: input, cleaned: cleaned, preset: preset, findings: findings)
        )
    }

    func analyzeHiddenUnicode(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        guard preset.removesHiddenUnicode else { return [] }

        var findings: [CleaningFinding] = []
        let nsInput = input as NSString
        for scalar in input.unicodeScalars where shouldRemoveHiddenScalar(scalar, settings: settings) {
            let scalarString = String(scalar)
            let searchRange = NSRange(location: 0, length: nsInput.length)
            var location = 0
            while location < nsInput.length {
                let remaining = NSRange(location: location, length: nsInput.length - location)
                let found = nsInput.range(of: scalarString, options: [], range: remaining)
                if found.location == NSNotFound { break }
                findings.append(CleaningFinding(
                    range: found,
                    category: .hiddenUnicode,
                    label: hiddenUnicodeLabel(for: scalar),
                    matchedText: scalarString,
                    replacementText: ""
                ))
                location = found.location + max(found.length, 1)
            }
            _ = searchRange
        }
        return deduplicated(findings)
    }

    func applyHiddenUnicodeRemoval(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset.removesHiddenUnicode else { return input }
        return String(input.unicodeScalars.filter { !shouldRemoveHiddenScalar($0, settings: settings) })
    }

    func analyzeWhitespace(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        var findings: [CleaningFinding] = []
        let nsInput = input as NSString

        if preset.normalizesLineBreaks(settings), input.contains("\r") {
            findings.append(contentsOf: matches(in: input, pattern: "\\r\\n|\\r", category: .whitespace, label: "Line break", replacement: "\n"))
        }

        if preset.normalizesNoBreakSpaces(settings) {
            for scalar in input.unicodeScalars where Self.spaceScalars.contains(scalar.value) {
                let value = String(scalar)
                var location = 0
                while location < nsInput.length {
                    let found = nsInput.range(of: value, options: [], range: NSRange(location: location, length: nsInput.length - location))
                    if found.location == NSNotFound { break }
                    findings.append(CleaningFinding(range: found, category: .whitespace, label: "Nonbreaking or typographic space", matchedText: value, replacementText: " "))
                    location = found.location + max(found.length, 1)
                }
            }
        }

        if preset.convertsTabsToSpaces(settings), input.contains("\t") {
            findings.append(contentsOf: matches(in: input, pattern: "\\t", category: .whitespace, label: "Tab", replacement: String(repeating: " ", count: max(settings.whitespace.tabWidth, 1))))
        }

        if preset.trimsTrailingWhitespace(settings) {
            findings.append(contentsOf: matches(in: input, pattern: "[ \\t]+$", options: [.anchorsMatchLines], category: .whitespace, label: "Trailing whitespace", replacement: ""))
        }

        if preset.collapsesMultipleSpaces(settings) {
            findings.append(contentsOf: matches(in: input, pattern: " {2,}", category: .whitespace, label: "Repeated spaces", replacement: " "))
        }

        if preset.collapsesBlankLines(settings) {
            findings.append(contentsOf: matches(in: input, pattern: "\\n{3,}", category: .whitespace, label: "Excessive blank lines", replacement: "\n\n"))
        }

        return findings
    }

    func applyWhitespaceNormalization(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        var output = input
        if preset.normalizesLineBreaks(settings) {
            output = output.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        if preset.normalizesNoBreakSpaces(settings) {
            let scalars = output.unicodeScalars.map { Self.spaceScalars.contains($0.value) ? UnicodeScalar(32)! : $0 }
            output = String(String.UnicodeScalarView(scalars))
        }
        if preset.convertsTabsToSpaces(settings) {
            output = output.replacingOccurrences(of: "\t", with: String(repeating: " ", count: max(settings.whitespace.tabWidth, 1)))
        }
        if preset.trimsTrailingWhitespace(settings) {
            output = replacing(output, pattern: "[ \\t]+$", options: [.anchorsMatchLines], template: "")
        }
        if preset.collapsesMultipleSpaces(settings) {
            output = replacing(output, pattern: " {2,}", template: " ")
        }
        if preset.collapsesBlankLines(settings) {
            output = replacing(output, pattern: "\\n{3,}", template: "\n\n")
        }
        return output
    }

    func analyzePunctuation(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        guard preset.normalizesPunctuation(settings) else { return [] }
        var findings: [CleaningFinding] = []
        for (character, replacement) in punctuationMap(settings: settings) {
            findings.append(contentsOf: literalMatches(in: input, value: character, category: .punctuation, label: "Normalize punctuation", replacement: replacement))
        }
        return findings
    }

    func applyPunctuationNormalization(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset.normalizesPunctuation(settings) else { return input }
        var output = input
        for (character, replacement) in punctuationMap(settings: settings) {
            output = output.replacingOccurrences(of: character, with: replacement)
        }
        return output
    }

    func analyzeRegexRules(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        guard preset.runsCustomRegex(settings) else { return [] }
        var findings: [CleaningFinding] = []
        for rule in settings.regexRules.filter(\.enabled).sorted(by: { $0.order < $1.order }) where !rule.findPattern.isEmpty {
            guard let regex = makeRegex(rule) else { continue }
            let nsInput = input as NSString
            let range = NSRange(location: 0, length: nsInput.length)
            for match in regex.matches(in: input, range: range) {
                let matchedText = nsInput.substring(with: match.range)
                let replacement = regex.replacementString(for: match, in: input, offset: 0, template: rule.replacement)
                findings.append(CleaningFinding(range: match.range, category: .regex, label: rule.name, matchedText: matchedText, replacementText: replacement, ruleID: rule.id))
            }
        }
        return findings
    }

    func applyRegexRules(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset.runsCustomRegex(settings) else { return input }
        var output = input
        for rule in settings.regexRules.filter(\.enabled).sorted(by: { $0.order < $1.order }) where !rule.findPattern.isEmpty {
            guard let regex = makeRegex(rule) else { continue }
            output = regex.stringByReplacingMatches(in: output, range: NSRange(location: 0, length: (output as NSString).length), withTemplate: rule.replacement)
        }
        return output
    }

    func makeReport(original: String, cleaned: String, preset: CleaningPreset, findings: [CleaningFinding]) -> CleaningReport {
        var categoryCounts: [FindingCategory: Int] = [:]
        var ruleCounts: [UUID: Int] = [:]
        for finding in findings {
            categoryCounts[finding.category, default: 0] += 1
            if let ruleID = finding.ruleID {
                ruleCounts[ruleID, default: 0] += 1
            }
        }

        return CleaningReport(
            presetName: preset.displayName,
            totalFindings: findings.count,
            totalChanges: findings.filter { $0.matchedText != $0.replacementText }.count,
            charactersBefore: original.count,
            charactersAfter: cleaned.count,
            wordsBefore: wordCount(original),
            wordsAfter: wordCount(cleaned),
            categoryCounts: categoryCounts,
            ruleCounts: ruleCounts
        )
    }
}

private extension CleaningEngine {
    static let spaceScalars = Set<UInt32>([0x00A0, 0x1680, 0x202F, 0x205F, 0x3000] + Array(0x2000...0x200A))

    func shouldRemoveHiddenScalar(_ scalar: UnicodeScalar, settings: AppSettings) -> Bool {
        let value = scalar.value
        if settings.unicode.removeSoftHyphen, value == 0x00AD { return true }
        if settings.unicode.removeZeroWidthCharacters, [0x034F, 0x180E, 0x200B, 0x200C, 0x200D, 0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0xFEFF].contains(value) { return true }
        if settings.unicode.removeBidiControls, value == 0x061C || value == 0x200E || value == 0x200F || (0x202A...0x202E).contains(value) || (0x2066...0x206F).contains(value) { return true }
        if settings.unicode.removeTagCharacters, (0xE0000...0xE007F).contains(value) { return true }
        if settings.unicode.removeVariationSelectors, (0xFE00...0xFE0F).contains(value) || (0xE0100...0xE01EF).contains(value) { return true }
        if settings.unicode.removeCombiningMarksAggressive, (0x0300...0x036F).contains(value) { return true }
        return false
    }

    func hiddenUnicodeLabel(for scalar: UnicodeScalar) -> String {
        switch scalar.value {
        case 0x200B:
            return "Zero width space"
        case 0x200C:
            return "Zero width non joiner"
        case 0x200D:
            return "Zero width joiner"
        case 0xFEFF:
            return "Byte order mark"
        case 0x00AD:
            return "Soft hyphen"
        case 0x2060:
            return "Word joiner"
        case 0xE0000...0xE007F:
            return "Unicode tag character"
        case 0xFE00...0xFE0F, 0xE0100...0xE01EF:
            return "Variation selector"
        case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x206F:
            return "Directional control"
        default:
            return "Hidden Unicode"
        }
    }

    func punctuationMap(settings: AppSettings) -> [(String, String)] {
        var map: [(String, String)] = []
        if settings.punctuation.normalizeSmartQuotes {
            map.append(contentsOf: [("“", "\""), ("”", "\""), ("„", "\""), ("‟", "\""), ("‘", "'"), ("’", "'"), ("‚", "'"), ("‛", "'")])
        }
        if settings.punctuation.normalizeEllipses {
            map.append(("…", "..."))
        }
        if settings.punctuation.normalizeDashes {
            let replacement = settings.punctuation.dashReplacement.replacement
            map.append(contentsOf: ["‐", "‑", "‒", "–", "—", "―"].map { ($0, replacement) })
        }
        return map
    }

    func analyzeMarkdown(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        guard preset == .aggressiveClean else { return [] }
        var findings: [CleaningFinding] = []
        if settings.markdown.removeImagesKeepAltText {
            findings.append(contentsOf: matches(in: input, pattern: "!\\[([^\\]]*)\\]\\([^\\)]*\\)", category: .markdown, label: "Markdown image", replacement: "$1"))
        }
        if settings.markdown.convertLinksToText {
            findings.append(contentsOf: matches(in: input, pattern: "\\[([^\\]]+)\\]\\([^\\)]*\\)", category: .markdown, label: "Markdown link", replacement: "$1"))
        }
        if settings.markdown.stripBlockquoteMarkers {
            findings.append(contentsOf: matches(in: input, pattern: "^>\\s?", options: [.anchorsMatchLines], category: .markdown, label: "Blockquote marker", replacement: ""))
        }
        if settings.markdown.stripCodeFences {
            findings.append(contentsOf: matches(in: input, pattern: "^```.*$|^```$", options: [.anchorsMatchLines], category: .markdown, label: "Code fence", replacement: ""))
        }
        return findings
    }

    func applyMarkdownCleanup(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset == .aggressiveClean else { return input }
        var output = input
        if settings.markdown.removeImagesKeepAltText {
            output = replacing(output, pattern: "!\\[([^\\]]*)\\]\\([^\\)]*\\)", template: "$1")
        }
        if settings.markdown.convertLinksToText {
            output = replacing(output, pattern: "\\[([^\\]]+)\\]\\([^\\)]*\\)", template: "$1")
        }
        if settings.markdown.stripBlockquoteMarkers {
            output = replacing(output, pattern: "^>\\s?", options: [.anchorsMatchLines], template: "")
        }
        if settings.markdown.stripCodeFences {
            output = replacing(output, pattern: "^```.*$|^```$", options: [.anchorsMatchLines], template: "")
        }
        return output
    }

    func analyzeHTML(_ input: String, preset: CleaningPreset, settings: AppSettings) -> [CleaningFinding] {
        guard preset == .aggressiveClean else { return [] }
        var findings: [CleaningFinding] = []
        if settings.html.decodeEntities {
            for (entity, replacement) in htmlEntities {
                findings.append(contentsOf: literalMatches(in: input, value: entity, category: .html, label: "HTML entity", replacement: replacement))
            }
        }
        if settings.html.stripTags {
            findings.append(contentsOf: matches(in: input, pattern: "<[^>]+>", category: .html, label: "HTML tag", replacement: ""))
        }
        return findings
    }

    func applyHTMLCleanup(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset == .aggressiveClean else { return input }
        var output = input
        if settings.html.decodeEntities {
            for (entity, replacement) in htmlEntities {
                output = output.replacingOccurrences(of: entity, with: replacement)
            }
        }
        if settings.html.stripTags {
            output = replacing(output, pattern: "<[^>]+>", template: "")
        }
        return output
    }

    var htmlEntities: [(String, String)] {
        [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")]
    }

    func literalMatches(in input: String, value: String, category: FindingCategory, label: String, replacement: String) -> [CleaningFinding] {
        let nsInput = input as NSString
        var results: [CleaningFinding] = []
        var location = 0
        while location < nsInput.length {
            let found = nsInput.range(of: value, options: [], range: NSRange(location: location, length: nsInput.length - location))
            if found.location == NSNotFound { break }
            results.append(CleaningFinding(range: found, category: category, label: label, matchedText: nsInput.substring(with: found), replacementText: replacement))
            location = found.location + max(found.length, 1)
        }
        return results
    }

    func matches(in input: String, pattern: String, options: NSRegularExpression.Options = [], category: FindingCategory, label: String, replacement: String) -> [CleaningFinding] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsInput = input as NSString
        return regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length)).map { match in
            CleaningFinding(
                range: match.range,
                category: category,
                label: label,
                matchedText: nsInput.substring(with: match.range),
                replacementText: regex.replacementString(for: match, in: input, offset: 0, template: replacement)
            )
        }
    }

    func replacing(_ input: String, pattern: String, options: NSRegularExpression.Options = [], template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return input }
        return regex.stringByReplacingMatches(in: input, range: NSRange(location: 0, length: (input as NSString).length), withTemplate: template)
    }

    func makeRegex(_ rule: RegexRule) -> NSRegularExpression? {
        var options: NSRegularExpression.Options = []
        if !rule.caseSensitive { options.insert(.caseInsensitive) }
        if rule.multiline { options.insert(.anchorsMatchLines) }
        if rule.dotMatchesNewline { options.insert(.dotMatchesLineSeparators) }
        return try? NSRegularExpression(pattern: rule.findPattern, options: options)
    }

    func deduplicated(_ findings: [CleaningFinding]) -> [CleaningFinding] {
        var seen = Set<String>()
        return findings.filter {
            let key = "\($0.range.location):\($0.range.length):\($0.label)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace }.count
    }
}

private extension CleaningPreset {
    var removesHiddenUnicode: Bool {
        switch self {
        case .plainText, .publishingClean:
            return false
        case .privacyClean, .codeSafe, .aggressiveClean:
            return true
        }
    }

    func normalizesLineBreaks(_ settings: AppSettings) -> Bool {
        settings.whitespace.normalizeLineBreaks
    }

    func normalizesNoBreakSpaces(_ settings: AppSettings) -> Bool {
        settings.whitespace.normalizeNoBreakSpaces
    }

    func trimsTrailingWhitespace(_ settings: AppSettings) -> Bool {
        self != .privacyClean && settings.whitespace.trimTrailingWhitespace
    }

    func collapsesMultipleSpaces(_ settings: AppSettings) -> Bool {
        switch self {
        case .publishingClean, .aggressiveClean:
            return settings.whitespace.collapseMultipleSpaces || true
        default:
            return settings.whitespace.collapseMultipleSpaces
        }
    }

    func collapsesBlankLines(_ settings: AppSettings) -> Bool {
        switch self {
        case .codeSafe, .privacyClean:
            return false
        default:
            return settings.whitespace.collapseExcessiveBlankLines
        }
    }

    func convertsTabsToSpaces(_ settings: AppSettings) -> Bool {
        switch self {
        case .publishingClean, .aggressiveClean:
            return true
        case .codeSafe:
            return false
        default:
            return settings.whitespace.convertTabsToSpaces
        }
    }

    func normalizesPunctuation(_ settings: AppSettings) -> Bool {
        switch self {
        case .publishingClean, .aggressiveClean:
            return settings.punctuation.normalizeSmartQuotes || settings.punctuation.normalizeEllipses || settings.punctuation.normalizeDashes
        default:
            return false
        }
    }

    func runsCustomRegex(_ settings: AppSettings) -> Bool {
        if self == .codeSafe && !settings.runCustomRegexInCodeSafe {
            return false
        }
        return !settings.regexRules.isEmpty
    }
}
