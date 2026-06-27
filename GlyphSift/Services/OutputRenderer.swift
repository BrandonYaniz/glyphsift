import AppKit
import Foundation

protocol OutputRendering {
    func render(_ result: CleaningResult, format: OutputFormat, sourceFormat: SourceFormat, rawText: String, richText: NSAttributedString?) throws -> RenderedOutput
}

struct OutputRenderer: OutputRendering {
    func render(_ result: CleaningResult, format: OutputFormat, sourceFormat: SourceFormat, rawText: String, richText: NSAttributedString? = nil) throws -> RenderedOutput {
        switch format {
        case .raw:
            return RenderedOutput(displayText: rawText, plainText: rawText, attributedString: nil, rtfData: nil)
        case .plainText:
            let plainText = renderPlainText(result.cleaned, sourceFormat: sourceFormat, rawText: rawText)
            return RenderedOutput(displayText: plainText, plainText: plainText, attributedString: nil, rtfData: nil, warnings: warnings(for: format, sourceFormat: sourceFormat))
        case .markdown:
            let markdown = renderMarkdown(result.cleaned, sourceFormat: sourceFormat, rawText: rawText)
            return RenderedOutput(displayText: markdown, plainText: markdown, attributedString: nil, rtfData: nil, warnings: warnings(for: format, sourceFormat: sourceFormat))
        case .html:
            let html = renderHTML(result.cleaned, sourceFormat: sourceFormat, rawText: rawText)
            return RenderedOutput(displayText: html, plainText: html, attributedString: nil, rtfData: nil, warnings: warnings(for: format, sourceFormat: sourceFormat))
        case .richText:
            let attributed = renderRichText(result.cleaned, sourceFormat: sourceFormat, rawText: rawText, richText: richText)
            let rtf = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            return RenderedOutput(displayText: attributed.string, plainText: attributed.string, attributedString: attributed, rtfData: rtf, warnings: warnings(for: format, sourceFormat: sourceFormat))
        }
    }
}

private extension OutputRenderer {
    func warnings(for format: OutputFormat, sourceFormat: SourceFormat) -> [String] {
        guard sourceFormat != .plainText, format != .raw else {
            return []
        }

        switch (sourceFormat, format) {
        case (.html, .plainText), (.markdown, .plainText), (.richText, .plainText):
            return ["Formatting is removed for Text output."]
        case (.html, .markdown), (.markdown, .html), (.html, .richText), (.markdown, .richText), (.richText, .html), (.richText, .markdown):
            return ["Conversion is best effort. Raw keeps the most complete source when available."]
        default:
            return []
        }
    }

    func renderPlainText(_ cleaned: String, sourceFormat: SourceFormat, rawText: String) -> String {
        switch sourceFormat {
        case .html:
            return htmlToPlainText(rawText)
        case .markdown:
            return markdownToPlainText(rawText)
        case .plainText, .richText:
            return cleaned
        }
    }

    func renderMarkdown(_ cleaned: String, sourceFormat: SourceFormat, rawText: String) -> String {
        switch sourceFormat {
        case .markdown:
            return rawText
        case .html:
            return htmlToMarkdown(rawText)
        case .plainText, .richText:
            return cleaned
        }
    }

    func renderHTML(_ cleaned: String, sourceFormat: SourceFormat, rawText: String) -> String {
        switch sourceFormat {
        case .html:
            return rawText
        case .markdown:
            return markdownToHTML(rawText)
        case .plainText, .richText:
            return htmlEscaped(cleaned)
        }
    }

    func renderRichText(_ cleaned: String, sourceFormat: SourceFormat, rawText: String, richText: NSAttributedString?) -> NSAttributedString {
        switch sourceFormat {
        case .html:
            return attributedHTML(rawText) ?? NSAttributedString(string: htmlToPlainText(rawText))
        case .markdown:
            return renderMarkdownAsRichText(rawText)
        case .richText:
            return richText ?? NSAttributedString(string: cleaned)
        case .plainText:
            return NSAttributedString(string: cleaned)
        }
    }

    func renderMarkdownAsRichText(_ markdown: String) -> NSAttributedString {
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

    func htmlToPlainText(_ html: String) -> String {
        let withBreaks = replacing(html, pattern: #"(?i)<\s*br\s*/?\s*>|</\s*(p|div|section|article|li|h[1-6]|tr)\s*>"#, template: "\n")
        let withoutScripts = replacing(withBreaks, pattern: #"(?is)<script\b[^>]*>.*?</script\s*>"#, template: "")
        let withoutStyles = replacing(withoutScripts, pattern: #"(?is)<style\b[^>]*>.*?</style\s*>"#, template: "")
        let withoutTags = replacing(withoutStyles, pattern: #"(?s)<[^>]+>"#, template: "")
        return decodeHTMLEntities(withoutTags)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markdownToPlainText(_ markdown: String) -> String {
        var output = markdown
        output = replacing(output, pattern: #"(?ms)^```.*?^```"#, template: "")
        output = replacing(output, pattern: #"!\[([^\]]*)\]\([^\)]*\)"#, template: "$1")
        output = replacing(output, pattern: #"\[([^\]]+)\]\([^\)]*\)"#, template: "$1")
        output = replacing(output, pattern: #"(?m)^\s{0,3}#{1,6}\s+"#, template: "")
        output = replacing(output, pattern: #"(?m)^\s{0,3}>\s?"#, template: "")
        output = replacing(output, pattern: #"(?m)^\s*[-*+]\s+"#, template: "")
        output = replacing(output, pattern: #"(?m)^\s*\d+\.\s+"#, template: "")
        output = replacing(output, pattern: #"\*\*([^*]+)\*\*|__([^_]+)__"#, template: "$1$2")
        output = replacing(output, pattern: #"\*([^*]+)\*|_([^_]+)_"#, template: "$1$2")
        output = replacing(output, pattern: #"`([^`]+)`"#, template: "$1")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func htmlToMarkdown(_ html: String) -> String {
        var output = html
        output = replacing(output, pattern: #"(?is)<script\b[^>]*>.*?</script\s*>"#, template: "")
        output = replacing(output, pattern: #"(?is)<style\b[^>]*>.*?</style\s*>"#, template: "")
        output = replacing(output, pattern: #"(?i)<\s*h1\b[^>]*>(.*?)</\s*h1\s*>"#, template: "# $1\n")
        output = replacing(output, pattern: #"(?i)<\s*h2\b[^>]*>(.*?)</\s*h2\s*>"#, template: "## $1\n")
        output = replacing(output, pattern: #"(?i)<\s*h3\b[^>]*>(.*?)</\s*h3\s*>"#, template: "### $1\n")
        output = replacing(output, pattern: #"(?i)<\s*h4\b[^>]*>(.*?)</\s*h4\s*>"#, template: "#### $1\n")
        output = replacing(output, pattern: #"(?i)<\s*h5\b[^>]*>(.*?)</\s*h5\s*>"#, template: "##### $1\n")
        output = replacing(output, pattern: #"(?i)<\s*h6\b[^>]*>(.*?)</\s*h6\s*>"#, template: "###### $1\n")
        output = replacing(output, pattern: #"(?i)<\s*(strong|b)\b[^>]*>(.*?)</\s*\1\s*>"#, template: "**$2**")
        output = replacing(output, pattern: #"(?i)<\s*(em|i)\b[^>]*>(.*?)</\s*\1\s*>"#, template: "*$2*")
        output = replacing(output, pattern: #"(?i)<\s*code\b[^>]*>(.*?)</\s*code\s*>"#, template: "`$1`")
        output = replacing(output, pattern: #"(?i)<\s*a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</\s*a\s*>"#, template: "[$2]($1)")
        output = replacing(output, pattern: #"(?i)<\s*a\b[^>]*href\s*=\s*([^\s>"']+)[^>]*>(.*?)</\s*a\s*>"#, template: "[$2]($1)")
        output = replacingHTMLBlockquotes(in: output)
        output = replacingOrderedHTMLLists(in: output)
        output = replacing(output, pattern: #"(?i)<\s*li\b[^>]*>(.*?)</\s*li\s*>"#, template: "- $1\n")
        output = replacing(output, pattern: #"(?i)<\s*br\s*/?\s*>"#, template: "\n")
        output = replacing(output, pattern: #"(?i)</\s*(p|div|section|article|ul|ol)\s*>"#, template: "\n")
        output = replacing(output, pattern: #"(?s)<[^>]+>"#, template: "")
        return decodeHTMLEntities(output).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func replacingHTMLBlockquotes(in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<\s*blockquote\b[^>]*>(.*?)</\s*blockquote\s*>"#) else {
            return input
        }

        let nsInput = input as NSString
        var output = ""
        var currentLocation = 0

        for match in regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length)) {
            output += nsInput.substring(with: NSRange(location: currentLocation, length: match.range.location - currentLocation))
            output += markdownBlockquote(from: nsInput.substring(with: match.range(at: 1)))
            currentLocation = match.range.location + match.range.length
        }

        output += nsInput.substring(from: currentLocation)
        return output
    }

    func markdownBlockquote(from html: String) -> String {
        let plainText = replacing(html, pattern: #"(?i)<\s*br\s*/?\s*>|</\s*(p|div)\s*>"#, template: "\n")
        let withoutTags = replacing(plainText, pattern: #"(?s)<[^>]+>"#, template: "")
        let lines = decodeHTMLEntities(withoutTags)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.map { "> \($0)" }.joined(separator: "\n") + "\n"
    }

    func replacingOrderedHTMLLists(in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<\s*ol\b[^>]*>(.*?)</\s*ol\s*>"#) else {
            return input
        }

        let nsInput = input as NSString
        var output = ""
        var currentLocation = 0

        for match in regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length)) {
            output += nsInput.substring(with: NSRange(location: currentLocation, length: match.range.location - currentLocation))
            output += orderedMarkdownItems(in: nsInput.substring(with: match.range(at: 1)))
            currentLocation = match.range.location + match.range.length
        }

        output += nsInput.substring(from: currentLocation)
        return output
    }

    func orderedMarkdownItems(in html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<\s*li\b[^>]*>(.*?)</\s*li\s*>"#) else {
            return html
        }

        let nsHTML = html as NSString
        let lines = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)).enumerated().map { index, match in
            let item = nsHTML.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(index + 1). \(item)"
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var htmlLines: [String] = []
        var openListTag: String?
        var isBlockquoteOpen = false

        func closeOpenList() {
            if let tag = openListTag {
                htmlLines.append("</\(tag)>")
                openListTag = nil
            }
        }

        func closeOpenBlockquote() {
            if isBlockquoteOpen {
                htmlLines.append("</blockquote>")
                isBlockquoteOpen = false
            }
        }

        for line in lines {
            if line.hasPrefix("# ") {
                closeOpenBlockquote()
                closeOpenList()
                htmlLines.append("<h1>\(inlineMarkdownToHTML(String(line.dropFirst(2))))</h1>")
            } else if line.hasPrefix("## ") {
                closeOpenBlockquote()
                closeOpenList()
                htmlLines.append("<h2>\(inlineMarkdownToHTML(String(line.dropFirst(3))))</h2>")
            } else if let heading = markdownHeading(in: line) {
                closeOpenBlockquote()
                closeOpenList()
                htmlLines.append("<h\(heading.level)>\(inlineMarkdownToHTML(heading.text))</h\(heading.level)>")
            } else if let match = line.range(of: #"^\s*[-*+]\s+"#, options: .regularExpression) {
                closeOpenBlockquote()
                if openListTag != "ul" {
                    closeOpenList()
                    htmlLines.append("<ul>")
                    openListTag = "ul"
                }
                htmlLines.append("<li>\(inlineMarkdownToHTML(String(line[match.upperBound...])))</li>")
            } else if let match = line.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) {
                closeOpenBlockquote()
                if openListTag != "ol" {
                    closeOpenList()
                    htmlLines.append("<ol>")
                    openListTag = "ol"
                }
                htmlLines.append("<li>\(inlineMarkdownToHTML(String(line[match.upperBound...])))</li>")
            } else if let match = line.range(of: #"^\s{0,3}>\s?"#, options: .regularExpression) {
                closeOpenList()
                if !isBlockquoteOpen {
                    htmlLines.append("<blockquote>")
                    isBlockquoteOpen = true
                }
                htmlLines.append("<p>\(inlineMarkdownToHTML(String(line[match.upperBound...])))</p>")
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                closeOpenBlockquote()
                closeOpenList()
                htmlLines.append("")
            } else {
                closeOpenBlockquote()
                closeOpenList()
                htmlLines.append("<p>\(inlineMarkdownToHTML(line))</p>")
            }
        }

        closeOpenBlockquote()
        closeOpenList()
        return htmlLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markdownHeading(in line: String) -> (level: Int, text: String)? {
        guard let match = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) else {
            return nil
        }
        return (line[line.startIndex..<match.upperBound].filter { $0 == "#" }.count, String(line[match.upperBound...]))
    }

    func inlineMarkdownToHTML(_ text: String) -> String {
        var output = htmlEscaped(text)
        output = replacing(output, pattern: #"\*\*([^*]+)\*\*"#, template: "<strong>$1</strong>")
        output = replacing(output, pattern: #"\*([^*]+)\*"#, template: "<em>$1</em>")
        output = replacing(output, pattern: #"`([^`]+)`"#, template: "<code>$1</code>")
        output = replacing(output, pattern: #"\[([^\]]+)\]\(([^\)]+)\)"#, template: #"<a href="$2">$1</a>"#)
        return output
    }

    func attributedHTML(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    func decodeHTMLEntities(_ input: String) -> String {
        let named = input
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        return replacingNumericHTMLEntities(in: named)
    }

    func replacingNumericHTMLEntities(in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x[0-9A-Fa-f]+|\d+);"#) else {
            return input
        }

        let nsInput = input as NSString
        var output = ""
        var currentLocation = 0

        for match in regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length)) {
            output += nsInput.substring(with: NSRange(location: currentLocation, length: match.range.location - currentLocation))
            let value = nsInput.substring(with: match.range(at: 1))
            output += character(forNumericEntityValue: value) ?? nsInput.substring(with: match.range)
            currentLocation = match.range.location + match.range.length
        }

        output += nsInput.substring(from: currentLocation)
        return output
    }

    func character(forNumericEntityValue value: String) -> String? {
        let scalarValue: UInt32?
        if value.lowercased().hasPrefix("x") {
            scalarValue = UInt32(value.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(value, radix: 10)
        }
        guard let scalarValue, let scalar = UnicodeScalar(scalarValue) else {
            return nil
        }
        return String(scalar)
    }

    func htmlEscaped(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func replacing(_ input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        return regex.stringByReplacingMatches(in: input, range: NSRange(location: 0, length: (input as NSString).length), withTemplate: template)
    }

    func renderLine(_ line: String) -> NSAttributedString {
        if let heading = markdownHeading(in: line) {
            return styledLine(heading.text, font: headingFont(for: heading.level), spacing: headingSpacing(for: heading.level))
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

    func headingFont(for level: Int) -> NSFont {
        switch level {
        case 1:
            return .boldSystemFont(ofSize: 24)
        case 2:
            return .boldSystemFont(ofSize: 20)
        case 3:
            return .systemFont(ofSize: 17, weight: .semibold)
        case 4:
            return .systemFont(ofSize: 15, weight: .semibold)
        case 5:
            return .systemFont(ofSize: 14, weight: .semibold)
        default:
            return .systemFont(ofSize: 13, weight: .semibold)
        }
    }

    func headingSpacing(for level: Int) -> CGFloat {
        switch level {
        case 1:
            return 8
        case 2:
            return 6
        default:
            return 4
        }
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
