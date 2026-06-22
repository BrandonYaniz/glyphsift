import AppKit
import SwiftUI

struct HighlightedTextView: NSViewRepresentable {
    @Binding var text: String
    var findings: [CleaningFinding]
    var isEditable: Bool
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.isEditable = isEditable

        let displayText = isEditable ? text : (text.isEmpty ? placeholder : text)
        let attributed = NSMutableAttributedString(
            string: displayText,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: !isEditable && text.isEmpty ? NSColor.placeholderTextColor : NSColor.textColor
            ]
        )

        if !text.isEmpty {
            for finding in findings where NSMaxRange(finding.range) <= attributed.length {
                attributed.addAttribute(.backgroundColor, value: replacementCandidateColor, range: finding.range)
                attributed.addAttribute(.toolTip, value: finding.label, range: finding.range)
            }
        }

        let contentChanged = textView.string != attributed.string || textView.textStorage?.string != attributed.string
        let findingsChanged = context.coordinator.lastFindingsSignature != findingsSignature

        if contentChanged {
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributed)
            if !text.isEmpty, selectedRange.location <= attributed.length {
                textView.setSelectedRange(NSRange(location: selectedRange.location, length: min(selectedRange.length, attributed.length - selectedRange.location)))
            }
        } else if findingsChanged || context.coordinator.lastRenderedText != displayText {
            textView.textStorage?.setAttributedString(attributed)
        }

        context.coordinator.lastRenderedText = displayText
        context.coordinator.lastFindingsSignature = findingsSignature

        if contentChanged, !isEditable {
            scrollToTop(textView)
        } else if context.coordinator.shouldScrollToTop {
            scrollToTop(textView)
            context.coordinator.shouldScrollToTop = false
        }
    }

    private var replacementCandidateColor: NSColor {
        NSColor.systemRed.withAlphaComponent(0.28)
    }

    private var findingsSignature: String {
        findings.map { "\($0.range.location):\($0.range.length):\($0.category.rawValue):\($0.label):\($0.replacementText)" }.joined(separator: "|")
    }

    private func scrollToTop(_ textView: NSTextView) {
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        textView.enclosingScrollView?.contentView.scroll(to: .zero)
        textView.enclosingScrollView?.reflectScrolledClipView(textView.enclosingScrollView?.contentView ?? NSClipView())
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextView
        var previousTextLength: Int = 0
        var shouldScrollToTop = false
        var lastRenderedText = ""
        var lastFindingsSignature = ""

        init(parent: HighlightedTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard parent.isEditable, let textView = notification.object as? NSTextView else { return }
            let nextText = textView.string
            if abs(nextText.count - previousTextLength) > 1 {
                shouldScrollToTop = true
                parent.scrollToTop(textView)
            }
            previousTextLength = nextText.count
            parent.text = nextText
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard parent.isEditable, parent.text.isEmpty, let textView = notification.object as? NSTextView else { return }
            textView.string = ""
            previousTextLength = 0
        }
    }
}
