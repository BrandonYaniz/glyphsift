import Foundation

enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case raw
    case plainText
    case markdown
    case html
    case richText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw:
            return "Raw"
        case .plainText:
            return "Plain Text"
        case .markdown:
            return "Markdown"
        case .html:
            return "HTML"
        case .richText:
            return "Rich Text"
        }
    }

    static func available(for sourceFormat: SourceFormat) -> [OutputFormat] {
        switch sourceFormat {
        case .plainText:
            return [.plainText]
        case .markdown, .html:
            return [.raw, .plainText, .markdown, .html, .richText]
        case .richText:
            return [.plainText, .markdown, .html, .richText]
        }
    }
}
