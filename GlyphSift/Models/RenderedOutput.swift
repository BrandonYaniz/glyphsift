import AppKit

struct RenderedOutput {
    var displayText: String
    var plainText: String
    var attributedString: NSAttributedString?
    var rtfData: Data?

    static let empty = RenderedOutput(displayText: "", plainText: "", attributedString: nil, rtfData: nil)
}
