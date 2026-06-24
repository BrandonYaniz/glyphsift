import AppKit
import Foundation

struct AttributedTextCleaner {
    func clean(_ attributed: NSAttributedString, result: CleaningResult) -> NSAttributedString {
        guard attributed.string == result.original else {
            return NSAttributedString(string: result.cleaned)
        }

        let output = NSMutableAttributedString(attributedString: attributed)
        let replacements = result.findings
            .filter { supportedCategories.contains($0.category) && $0.matchedText != $0.replacementText }
            .sorted { $0.range.location > $1.range.location }

        for finding in replacements where NSMaxRange(finding.range) <= output.length {
            output.replaceCharacters(in: finding.range, with: finding.replacementText)
        }

        guard output.string == result.cleaned else {
            return NSAttributedString(string: result.cleaned)
        }

        return output
    }
}

private extension AttributedTextCleaner {
    var supportedCategories: Set<FindingCategory> {
        [.hiddenUnicode, .whitespace, .punctuation, .regex]
    }
}
