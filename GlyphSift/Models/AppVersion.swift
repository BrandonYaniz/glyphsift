import Foundation

enum AppVersion {
    static var display: String {
        Bundle.main.object(forInfoDictionaryKey: "GlyphSiftReleaseVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
    }
}
