import AppKit
import Foundation

protocol OutputRendering {
    func render(_ result: CleaningResult, format: OutputFormat) throws -> RenderedOutput
}

struct OutputRenderer: OutputRendering {
    func render(_ result: CleaningResult, format: OutputFormat) throws -> RenderedOutput {
        switch format {
        case .plainText:
            return RenderedOutput(displayText: result.cleaned, plainText: result.cleaned, attributedString: nil, rtfData: nil)
        case .richText:
            let attributed = renderRichText(result.cleaned)
            let rtf = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            return RenderedOutput(displayText: attributed.string, plainText: attributed.string, attributedString: attributed, rtfData: rtf)
        }
    }
}

private extension OutputRenderer {
    func renderRichText(_ markdown: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let renderedLine = renderLine(line)
            output.append(renderedLine)
            if index < lines.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }

        return output
    }

    func renderLine(_ line: String) -> NSAttributedString {
        if line.hasPrefix("# ") {
            return styledLine(String(line.dropFirst(2)), font: .boldSystemFont(ofSize: 24), spacing: 8)
        }
        if line.hasPrefix("## ") {
            return styledLine(String(line.dropFirst(3)), font: .boldSystemFont(ofSize: 20), spacing: 6)
        }
        if line.hasPrefix("### ") {
            return styledLine(String(line.dropFirst(4)), font: .systemFont(ofSize: 17, weight: .semibold), spacing: 4)
        }

        let unorderedPrefixes = ["- ", "* ", "+ "]
        if let prefix = unorderedPrefixes.first(where: { line.hasPrefix($0) }) {
            return styledLine("• " + line.dropFirst(prefix.count), font: .systemFont(ofSize: 13), spacing: 2, parseInline: true)
        }

        if let orderedMatch = try? NSRegularExpression(pattern: #"^\d+\.\s+"#),
           let match = orderedMatch.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
           match.range.location == 0 {
            let prefix = (line as NSString).substring(with: match.range)
            let body = String(line.dropFirst(match.range.length))
            return styledLine(prefix + body, font: .systemFont(ofSize: 13), spacing: 2, parseInline: true)
        }

        return styledLine(line, font: .systemFont(ofSize: 13), spacing: 6, parseInline: true)
    }

    func styledLine(_ text: String, font: NSFont, spacing: CGFloat, parseInline: Bool = false) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacing
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        if parseInline {
            applyInlineMarkdown(to: attributed, baseFont: font)
        }
        return attributed
    }

    func applyInlineMarkdown(to attributed: NSMutableAttributedString, baseFont: NSFont) {
        replaceInline(in: attributed, pattern: #"\*\*([^*]+)\*\*"#, font: NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask))
        replaceInline(in: attributed, pattern: #"`([^`]+)`"#, font: .monospacedSystemFont(ofSize: 12, weight: .regular))
        replaceInline(in: attributed, pattern: #"\*([^*]+)\*"#, font: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask))
        replaceLinks(in: attributed, baseFont: baseFont)
    }

    func replaceInline(in attributed: NSMutableAttributedString, pattern: String, font: NSFont) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        while let match = regex.firstMatch(in: attributed.string, range: NSRange(location: 0, length: attributed.length)), match.numberOfRanges > 1 {
            let inner = (attributed.string as NSString).substring(with: match.range(at: 1))
            attributed.replaceCharacters(in: match.range, with: inner)
            attributed.addAttribute(.font, value: font, range: NSRange(location: match.range.location, length: (inner as NSString).length))
        }
    }

    func replaceLinks(in attributed: NSMutableAttributedString, baseFont: NSFont) {
        guard let regex = try? NSRegularExpression(pattern: #"(\[([^\]]+)\]\(([^\)]+)\))"#) else { return }
        while let match = regex.firstMatch(in: attributed.string, range: NSRange(location: 0, length: attributed.length)), match.numberOfRanges > 3 {
            let text = (attributed.string as NSString).substring(with: match.range(at: 2))
            let urlString = (attributed.string as NSString).substring(with: match.range(at: 3))
            attributed.replaceCharacters(in: match.range(at: 1), with: text)
            let linkRange = NSRange(location: match.range.location, length: (text as NSString).length)
            attributed.addAttribute(.font, value: baseFont, range: linkRange)
            attributed.addAttribute(.foregroundColor, value: NSColor.linkColor, range: linkRange)
            if let url = URL(string: urlString) {
                attributed.addAttribute(.link, value: url, range: linkRange)
            }
        }
    }
}
