import AppKit
import SwiftUI

struct RichTextPreview: NSViewRepresentable {
    var attributedString: NSAttributedString?
    var fallbackText: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.backgroundColor = NSColor.textBackgroundColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let previousText = context.coordinator.previousText
        if let attributedString {
            textView.textStorage?.setAttributedString(attributedString)
        } else {
            textView.string = fallbackText.isEmpty ? "Cleaned text will appear here." : fallbackText
        }
        if textView.string != previousText {
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            context.coordinator.previousText = textView.string
        }
    }

    final class Coordinator {
        var previousText = ""
    }
}
