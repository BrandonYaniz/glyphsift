import Foundation

enum OutputFormat: String, CaseIterable, Identifiable, Codable {
    case plainText
    case richText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .richText:
            return "Rich Text"
        }
    }
}
