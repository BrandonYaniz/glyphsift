import Foundation

struct SourcePreservingCleaner {
    func clean(_ input: String, sourceFormat: SourceFormat, preset: CleaningPreset, settings: AppSettings) -> String {
        guard sourceFormat == .markdown || sourceFormat == .html else {
            return input
        }

        let protectedRanges = protectedRanges(in: input, sourceFormat: sourceFormat)
        return rewrite(input, protectedRanges: protectedRanges) { segment in
            cleanSegment(segment, preset: preset, settings: settings)
        }
    }
}

private extension SourcePreservingCleaner {
    func protectedRanges(in input: String, sourceFormat: SourceFormat) -> [NSRange] {
        switch sourceFormat {
        case .html:
            return ranges(
                in: input,
                patterns: [
                    #"(?is)<script\b[^>]*>.*?</script\s*>"#,
                    #"(?is)<style\b[^>]*>.*?</style\s*>"#,
                    #"(?s)<[^>]+>"#
                ]
            )
        case .markdown:
            return ranges(
                in: input,
                patterns: [
                    #"(?ms)^```.*?^```"#,
                    #"`[^`\n]+`"#,
                    #"!\[[^\]]*\]\([^\)]*\)"#,
                    #"\[[^\]]+\]\([^\)]+\)"#,
                    #"(?m)^\s{0,3}#{1,6}\s+"#,
                    #"(?m)^\s{0,3}>\s?"#,
                    #"(?m)^\s*[-*+]\s+"#,
                    #"(?m)^\s*\d+\.\s+"#,
                    #"\*\*|__|\*|_"#
                ]
            )
        default:
            return []
        }
    }

    func ranges(in input: String, patterns: [String]) -> [NSRange] {
        let fullRange = NSRange(location: 0, length: (input as NSString).length)
        let collected = patterns.flatMap { pattern -> [NSRange] in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            return regex.matches(in: input, range: fullRange).map(\.range)
        }
        return merged(collected)
    }

    func merged(_ ranges: [NSRange]) -> [NSRange] {
        let sorted = ranges
            .filter { $0.location != NSNotFound && $0.length > 0 }
            .sorted { $0.location < $1.location }
        var result: [NSRange] = []

        for range in sorted {
            guard let last = result.last else {
                result.append(range)
                continue
            }

            let lastEnd = NSMaxRange(last)
            let rangeEnd = NSMaxRange(range)
            if range.location <= lastEnd {
                result[result.count - 1] = NSRange(location: last.location, length: max(lastEnd, rangeEnd) - last.location)
            } else {
                result.append(range)
            }
        }

        return result
    }

    func rewrite(_ input: String, protectedRanges: [NSRange], transform: (String) -> String) -> String {
        let nsInput = input as NSString
        var output = ""
        var location = 0

        for protectedRange in protectedRanges {
            if protectedRange.location > location {
                let segmentRange = NSRange(location: location, length: protectedRange.location - location)
                output += transform(nsInput.substring(with: segmentRange))
            }
            output += nsInput.substring(with: protectedRange)
            location = NSMaxRange(protectedRange)
        }

        if location < nsInput.length {
            output += transform(nsInput.substring(from: location))
        }

        return output
    }

    func cleanSegment(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        var output = input
        output = removeHiddenUnicode(output, preset: preset, settings: settings)
        output = normalizeWhitespace(output, preset: preset, settings: settings)
        output = normalizePunctuation(output, preset: preset, settings: settings)
        return output
    }

    func removeHiddenUnicode(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset == .privacyClean || preset == .codeSafe || preset == .aggressiveClean else {
            return input
        }
        return String(input.unicodeScalars.filter { !shouldRemoveHiddenScalar($0, settings: settings) })
    }

    func normalizeWhitespace(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        var output = input
        if settings.whitespace.normalizeLineBreaks {
            output = output.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        if settings.whitespace.normalizeNoBreakSpaces {
            let scalars = output.unicodeScalars.map { Self.spaceScalars.contains($0.value) ? UnicodeScalar(32)! : $0 }
            output = String(String.UnicodeScalarView(scalars))
        }
        if preset != .codeSafe, settings.whitespace.convertTabsToSpaces || preset == .publishingClean || preset == .aggressiveClean {
            output = output.replacingOccurrences(of: "\t", with: String(repeating: " ", count: max(settings.whitespace.tabWidth, 1)))
        }
        if preset != .privacyClean, settings.whitespace.trimTrailingWhitespace {
            output = replacing(output, pattern: "[ \\t]+$", options: [.anchorsMatchLines], template: "")
        }
        if settings.whitespace.collapseMultipleSpaces || preset == .publishingClean || preset == .aggressiveClean {
            output = replacing(output, pattern: " {2,}", template: " ")
        }
        if preset != .codeSafe, preset != .privacyClean, settings.whitespace.collapseExcessiveBlankLines {
            output = replacing(output, pattern: "\\n{3,}", template: "\n\n")
        }
        return output
    }

    func normalizePunctuation(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset == .publishingClean || preset == .aggressiveClean else {
            return input
        }

        var output = input
        if settings.punctuation.normalizeSmartQuotes {
            for (character, replacement) in [("“", "\""), ("”", "\""), ("„", "\""), ("‟", "\""), ("‘", "'"), ("’", "'"), ("‚", "'"), ("‛", "'")] {
                output = output.replacingOccurrences(of: character, with: replacement)
            }
        }
        if settings.punctuation.normalizeEllipses {
            output = output.replacingOccurrences(of: "…", with: "...")
        }
        if settings.punctuation.normalizeDashes {
            for character in ["‐", "‑", "‒", "–", "—", "―"] {
                output = output.replacingOccurrences(of: character, with: settings.punctuation.dashReplacement.replacement)
            }
        }
        return output
    }

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

    func replacing(_ input: String, pattern: String, options: NSRegularExpression.Options = [], template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return input }
        return regex.stringByReplacingMatches(in: input, range: NSRange(location: 0, length: (input as NSString).length), withTemplate: template)
    }

    static let spaceScalars = Set<UInt32>([0x00A0, 0x1680, 0x202F, 0x205F, 0x3000] + Array(0x2000...0x200A))
}
