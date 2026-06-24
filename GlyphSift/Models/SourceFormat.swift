import Foundation

enum SourceFormat: String, Identifiable {
    case plainText
    case markdown
    case html
    case richText

    var id: String { rawValue }

    var displayName: String {
        switch self {
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
}

struct SourceFormatDetector {
    func detect(_ text: String) -> SourceFormat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }

        if looksLikeHTML(trimmed) {
            return .html
        }

        if looksLikeMarkdown(trimmed) {
            return .markdown
        }

        return .plainText
    }
}

private extension SourceFormatDetector {
    func looksLikeHTML(_ text: String) -> Bool {
        if text.range(of: #"(?is)^\s*<!doctype\s+html\b"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"(?is)<\s*(html|head|body|main|article|section|div|p|span|h[1-6]|ul|ol|li|a|strong|em|b|i|br|table|tr|td|th|script|style)\b[^>]*>"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"(?s)<[^>]+>.*</[^>]+>"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    func looksLikeMarkdown(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^#{1,6}\s+\S"#,
            #"(?m)^\s*[-*+]\s+\S"#,
            #"(?m)^\s*\d+\.\s+\S"#,
            #"(?m)^>\s+\S"#,
            #"(?m)^```"#,
            #"\[[^\]]+\]\([^\)]+\)"#,
            #"\*\*[^*]+\*\*|__[^_]+__"#,
            #"`[^`]+`"#
        ]

        var score = 0
        for pattern in patterns where text.range(of: pattern, options: .regularExpression) != nil {
            score += 1
        }
        return score > 0
    }
}
