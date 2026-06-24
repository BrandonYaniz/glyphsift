import AppKit

struct RenderedOutput {
    var displayText: String
    var plainText: String
    var attributedString: NSAttributedString?
    var rtfData: Data?
    var warnings: [String]

    init(displayText: String, plainText: String, attributedString: NSAttributedString?, rtfData: Data?, warnings: [String] = []) {
        self.displayText = displayText
        self.plainText = plainText
        self.attributedString = attributedString
        self.rtfData = rtfData
        self.warnings = warnings
    }

    static let empty = RenderedOutput(displayText: "", plainText: "", attributedString: nil, rtfData: nil)
}
