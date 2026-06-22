import Foundation

enum FindingCategory: String, Codable, CaseIterable, Identifiable {
    case hiddenUnicode
    case whitespace
    case punctuation
    case regex
    case markdown
    case html
    case urlTracking
    case destructive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hiddenUnicode:
            return "Hidden Unicode"
        case .whitespace:
            return "Whitespace"
        case .punctuation:
            return "Punctuation"
        case .regex:
            return "Regex"
        case .markdown:
            return "Markdown"
        case .html:
            return "HTML"
        case .urlTracking:
            return "URL Tracking"
        case .destructive:
            return "Destructive"
        }
    }
}

struct CleaningFinding: Identifiable, Equatable {
    var id: UUID
    var range: NSRange
    var category: FindingCategory
    var label: String
    var matchedText: String
    var replacementText: String
    var ruleID: UUID?

    init(
        id: UUID = UUID(),
        range: NSRange,
        category: FindingCategory,
        label: String,
        matchedText: String,
        replacementText: String,
        ruleID: UUID? = nil
    ) {
        self.id = id
        self.range = range
        self.category = category
        self.label = label
        self.matchedText = matchedText
        self.replacementText = replacementText
        self.ruleID = ruleID
    }
}
