import AppKit
import Foundation

struct ClipboardWriter {
    func write(_ output: RenderedOutput, format: OutputFormat, sourceFormat: SourceFormat, to pasteboard: NSPasteboard = .general) -> String {
        pasteboard.clearContents()

        switch format {
        case .raw:
            pasteboard.setString(output.plainText, forType: .string)
            if sourceFormat == .html {
                pasteboard.setString(output.plainText, forType: .html)
            }
            return "Copied"
        case .plainText, .markdown:
            pasteboard.setString(output.plainText, forType: .string)
            return "Copied"
        case .html:
            pasteboard.setString(output.plainText, forType: .html)
            pasteboard.setString(output.plainText, forType: .string)
            return "Copied"
        case .richText:
            if let rtfData = output.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
                pasteboard.setString(output.plainText, forType: .string)
                return "Copied"
            }

            pasteboard.setString(output.plainText, forType: .string)
            return "Rich Text rendering failed, copied plain text instead."
        }
    }
}
