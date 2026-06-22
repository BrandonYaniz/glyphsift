import Foundation

enum CleaningPreset: String, CaseIterable, Identifiable, Codable {
    case plainText
    case privacyClean
    case publishingClean
    case codeSafe
    case aggressiveClean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .privacyClean:
            return "Privacy Clean"
        case .publishingClean:
            return "Publishing Clean"
        case .codeSafe:
            return "Code Safe"
        case .aggressiveClean:
            return "Aggressive Clean"
        }
    }
}

enum CleaningOption: String, Codable, CaseIterable, Identifiable {
    case hiddenUnicode
    case whitespace
    case punctuation
    case markdown
    case html
    case urlTracking
    case customRegex

    var id: String { rawValue }
}

struct CleaningRule: Identifiable, Codable, Equatable {
    var id: UUID
    var option: CleaningOption
    var label: String
    var enabled: Bool
}
