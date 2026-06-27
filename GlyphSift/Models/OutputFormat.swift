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
            return "Text"
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
            return [.plainText, .raw]
        case .markdown, .html:
            return [.plainText, .raw, .markdown, .html, .richText]
        case .richText:
            return [.plainText, .raw, .markdown, .html, .richText]
        }
    }
}
