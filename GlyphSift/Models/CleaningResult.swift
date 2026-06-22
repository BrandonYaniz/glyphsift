import Foundation

struct CleaningResult: Equatable {
    var original: String
    var cleaned: String
    var findings: [CleaningFinding]
    var report: CleaningReport

    static let empty = CleaningResult(
        original: "",
        cleaned: "",
        findings: [],
        report: CleaningReport.empty(presetName: CleaningPreset.plainText.displayName)
    )
}

struct CleaningReport: Equatable {
    var presetName: String
    var totalFindings: Int
    var totalChanges: Int
    var charactersBefore: Int
    var charactersAfter: Int
    var wordsBefore: Int
    var wordsAfter: Int
    var categoryCounts: [FindingCategory: Int]
    var ruleCounts: [UUID: Int]

    static func empty(presetName: String) -> CleaningReport {
        CleaningReport(
            presetName: presetName,
            totalFindings: 0,
            totalChanges: 0,
            charactersBefore: 0,
            charactersAfter: 0,
            wordsBefore: 0,
            wordsAfter: 0,
            categoryCounts: [:],
            ruleCounts: [:]
        )
    }
}
