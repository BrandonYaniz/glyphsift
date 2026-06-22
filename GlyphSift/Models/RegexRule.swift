import Foundation

struct RegexRule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var enabled: Bool
    var findPattern: String
    var replacement: String
    var caseSensitive: Bool
    var multiline: Bool
    var dotMatchesNewline: Bool
    var order: Int

    init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        findPattern: String,
        replacement: String = "",
        caseSensitive: Bool = true,
        multiline: Bool = false,
        dotMatchesNewline: Bool = false,
        order: Int
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.findPattern = findPattern
        self.replacement = replacement
        self.caseSensitive = caseSensitive
        self.multiline = multiline
        self.dotMatchesNewline = dotMatchesNewline
        self.order = order
    }
}
