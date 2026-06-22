import Foundation

struct AppSettings: Codable, Equatable {
    var selectedPreset: CleaningPreset
    var selectedOutputFormat: OutputFormat
    var unicode: UnicodeSettings
    var whitespace: WhitespaceSettings
    var punctuation: PunctuationSettings
    var markdown: MarkdownSettings
    var html: HTMLSettings
    var urlCleaning: URLCleaningSettings
    var regexRules: [RegexRule]
    var runCustomRegexInCodeSafe: Bool

    static let `default` = AppSettings(
        selectedPreset: .plainText,
        selectedOutputFormat: .plainText,
        unicode: .default,
        whitespace: .default,
        punctuation: .default,
        markdown: .default,
        html: .default,
        urlCleaning: .default,
        regexRules: [],
        runCustomRegexInCodeSafe: true
    )
}

struct UnicodeSettings: Codable, Equatable {
    var removeZeroWidthCharacters: Bool
    var removeBidiControls: Bool
    var removeVariationSelectors: Bool
    var removeTagCharacters: Bool
    var removeSoftHyphen: Bool
    var removeCombiningMarksAggressive: Bool
    var normalizeConfusablesAggressive: Bool

    static let `default` = UnicodeSettings(
        removeZeroWidthCharacters: true,
        removeBidiControls: true,
        removeVariationSelectors: true,
        removeTagCharacters: true,
        removeSoftHyphen: true,
        removeCombiningMarksAggressive: false,
        normalizeConfusablesAggressive: false
    )
}

struct WhitespaceSettings: Codable, Equatable {
    var normalizeLineBreaks: Bool
    var normalizeNoBreakSpaces: Bool
    var trimTrailingWhitespace: Bool
    var collapseMultipleSpaces: Bool
    var collapseExcessiveBlankLines: Bool
    var convertTabsToSpaces: Bool
    var tabWidth: Int

    static let `default` = WhitespaceSettings(
        normalizeLineBreaks: true,
        normalizeNoBreakSpaces: true,
        trimTrailingWhitespace: true,
        collapseMultipleSpaces: false,
        collapseExcessiveBlankLines: true,
        convertTabsToSpaces: false,
        tabWidth: 4
    )
}

struct PunctuationSettings: Codable, Equatable {
    var normalizeSmartQuotes: Bool
    var normalizeEllipses: Bool
    var normalizeDashes: Bool
    var dashReplacement: DashReplacement

    static let `default` = PunctuationSettings(
        normalizeSmartQuotes: true,
        normalizeEllipses: true,
        normalizeDashes: true,
        dashReplacement: .hyphen
    )
}

enum DashReplacement: String, Codable, CaseIterable, Identifiable {
    case hyphen
    case spacedHyphen
    case comma
    case space
    case remove

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hyphen:
            return "Hyphen"
        case .spacedHyphen:
            return "Space hyphen space"
        case .comma:
            return "Comma"
        case .space:
            return "Space"
        case .remove:
            return "Remove"
        }
    }

    var replacement: String {
        switch self {
        case .hyphen:
            return "-"
        case .spacedHyphen:
            return " - "
        case .comma:
            return ","
        case .space:
            return " "
        case .remove:
            return ""
        }
    }
}

struct MarkdownSettings: Codable, Equatable {
    var convertLinksToText: Bool
    var removeImagesKeepAltText: Bool
    var stripCodeFences: Bool
    var stripBlockquoteMarkers: Bool

    static let `default` = MarkdownSettings(
        convertLinksToText: false,
        removeImagesKeepAltText: false,
        stripCodeFences: false,
        stripBlockquoteMarkers: false
    )
}

struct HTMLSettings: Codable, Equatable {
    var decodeEntities: Bool
    var stripTags: Bool

    static let `default` = HTMLSettings(decodeEntities: false, stripTags: false)
}

struct URLCleaningSettings: Codable, Equatable {
    var removeTrackingParameters: Bool
    var trackingParameters: [String]

    static let `default` = URLCleaningSettings(
        removeTrackingParameters: false,
        trackingParameters: [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
            "fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid", "vero_id",
            "_hsenc", "_hsmi"
        ]
    )
}
