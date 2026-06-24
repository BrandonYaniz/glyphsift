import Foundation

struct SourcePreservingCleaner {
    func clean(_ input: String, sourceFormat: SourceFormat, preset: CleaningPreset, settings: AppSettings) -> String {
        guard sourceFormat == .markdown || sourceFormat == .html else {
            return input
        }

        return rewrite(input, segments: segments(in: input, sourceFormat: sourceFormat), preset: preset, settings: settings)
    }
}

private extension SourcePreservingCleaner {
    enum SegmentPolicy {
        case protected
        case conservative
    }

    struct SourceSegment {
        var range: NSRange
        var policy: SegmentPolicy
    }

    func segments(in input: String, sourceFormat: SourceFormat) -> [SourceSegment] {
        switch sourceFormat {
        case .html:
            let sourceMarkupSegments = htmlSourceMarkupRanges(in: input)
                .map { SourceSegment(range: $0, policy: .conservative) }
            let sourceSegments = htmlSourceContentRanges(in: input)
                .map { SourceSegment(range: $0, policy: .conservative) }
            return mergedSegments(sourceMarkupSegments + sourceSegments)
        case .markdown:
            return markdownSegments(in: input)
        default:
            return []
        }
    }

    func markdownSegments(in input: String) -> [SourceSegment] {
        let conservativePatterns = [
            #"(?ms)\A---\s*$.*?^---\s*$"#,
            #"(?ms)^```.*?^```"#,
            #"(?ms)^~~~.*?^~~~"#,
            #"(?m)^(?: {4}|\t).*$"#,
            #"(?m)^\s{0,3}\[[^\]]+\]:\s+\S.*$"#
        ]
        let protectedPatterns = [
            #"`[^`\n]+`"#,
            #"!\[[^\]]*\]\([^\)]*\)"#,
            #"\[[^\]]+\]\([^\)]+\)"#,
            #"<[A-Za-z][^>\n]*>"#,
            #"(?m)^\s{0,3}#{1,6}\s+"#,
            #"(?m)^\s{0,3}>\s?"#,
            #"(?m)^\s*[-*+]\s+"#,
            #"(?m)^\s*\d+\.\s+"#,
            #"\*\*|__|\*|_"#
        ]

        let conservative = ranges(in: input, patterns: conservativePatterns)
            .map { SourceSegment(range: $0, policy: .conservative) }
        let escaped = escapedMarkdownRanges(in: input)
            .map { SourceSegment(range: $0, policy: .protected) }
        let protected = ranges(in: input, patterns: protectedPatterns)
            .map { SourceSegment(range: $0, policy: .protected) }
        return mergedSegments(conservative + escaped + protected)
    }

    func escapedMarkdownRanges(in input: String) -> [NSRange] {
        var ranges: [NSRange] = []
        var index = input.startIndex

        while index < input.endIndex {
            guard input[index] == "\\" else {
                index = input.index(after: index)
                continue
            }

            let next = input.index(after: index)
            guard next < input.endIndex, input[next] != "\n" else {
                index = next
                continue
            }

            let end = input.index(after: next)
            ranges.append(NSRange(index..<end, in: input))
            index = end
        }

        return ranges
    }

    func htmlSourceContentRanges(in input: String) -> [NSRange] {
        ranges(in: input, patterns: [#"(?is)<script\b[^>]*>(.*?)</script\s*>"#, #"(?is)<style\b[^>]*>(.*?)</style\s*>"#], captureIndex: 1)
    }

    func htmlSourceMarkupRanges(in input: String) -> [NSRange] {
        ranges(in: input, patterns: [
            #"(?s)<!--.*?-->"#,
            #"(?s)<!\[CDATA\[.*?\]\]>"#,
            #"<(?:"[^"]*"|'[^']*'|[^'"<>])*>"#
        ])
    }

    func ranges(in input: String, patterns: [String]) -> [NSRange] {
        ranges(in: input, patterns: patterns, captureIndex: 0)
    }

    func ranges(in input: String, patterns: [String], captureIndex: Int) -> [NSRange] {
        let fullRange = NSRange(location: 0, length: (input as NSString).length)
        let collected = patterns.flatMap { pattern -> [NSRange] in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            return regex.matches(in: input, range: fullRange).compactMap { match in
                guard match.numberOfRanges > captureIndex else { return nil }
                let range = match.range(at: captureIndex)
                return range.location == NSNotFound ? nil : range
            }
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

    func mergedSegments(_ segments: [SourceSegment]) -> [SourceSegment] {
        segments
            .filter { $0.range.location != NSNotFound && $0.range.length > 0 }
            .sorted {
                if $0.range.location == $1.range.location {
                    return $0.range.length > $1.range.length
                }
                return $0.range.location < $1.range.location
            }
            .reduce(into: [SourceSegment]()) { result, segment in
                guard let last = result.last else {
                    result.append(segment)
                    return
                }

                if segment.range.location < NSMaxRange(last.range) {
                    return
                }
                result.append(segment)
            }
    }

    func rewrite(_ input: String, segments: [SourceSegment], preset: CleaningPreset, settings: AppSettings) -> String {
        let nsInput = input as NSString
        var output = ""
        var location = 0

        for segment in segments {
            if segment.range.location > location {
                let segmentRange = NSRange(location: location, length: segment.range.location - location)
                output += cleanSegment(nsInput.substring(with: segmentRange), preset: preset, settings: settings, trimFinalBoundary: false)
            }

            let segmentText = nsInput.substring(with: segment.range)
            switch segment.policy {
            case .protected:
                output += segmentText
            case .conservative:
                output += cleanConservativeSource(segmentText, preset: preset, settings: settings)
            }
            location = NSMaxRange(segment.range)
        }

        if location < nsInput.length {
            output += cleanSegment(nsInput.substring(from: location), preset: preset, settings: settings)
        }

        return output
    }

    func cleanSegment(_ input: String, preset: CleaningPreset, settings: AppSettings, trimFinalBoundary: Bool = true) -> String {
        var output = input
        output = removeHiddenUnicode(output, preset: preset, settings: settings)
        output = normalizeWhitespace(output, preset: preset, settings: settings, trimFinalBoundary: trimFinalBoundary)
        output = normalizePunctuation(output, preset: preset, settings: settings)
        return output
    }

    func cleanConservativeSource(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        var output = removeHiddenUnicode(input, preset: preset, settings: settings)
        if settings.whitespace.normalizeLineBreaks {
            output = output.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        if settings.whitespace.normalizeNoBreakSpaces {
            let scalars = output.unicodeScalars.map { Self.spaceScalars.contains($0.value) ? UnicodeScalar(32)! : $0 }
            output = String(String.UnicodeScalarView(scalars))
        }
        return output
    }

    func removeHiddenUnicode(_ input: String, preset: CleaningPreset, settings: AppSettings) -> String {
        guard preset == .privacyClean || preset == .codeSafe || preset == .aggressiveClean else {
            return input
        }
        return String(input.unicodeScalars.filter { !shouldRemoveHiddenScalar($0, settings: settings) })
    }

    func normalizeWhitespace(_ input: String, preset: CleaningPreset, settings: AppSettings, trimFinalBoundary: Bool = true) -> String {
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
            output = replacing(output, pattern: "[ \\t]+(?=\\n)", template: "")
            if trimFinalBoundary {
                output = replacing(output, pattern: "[ \\t]+\\z", template: "")
            }
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
