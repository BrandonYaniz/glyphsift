import Foundation

struct SettingsStore {
    var fileManager: FileManager = .default
    var customSettingsURL: URL?

    init(fileManager: FileManager = .default, customSettingsURL: URL? = nil) {
        self.fileManager = fileManager
        self.customSettingsURL = customSettingsURL
    }

    var settingsURL: URL {
        if let customSettingsURL {
            return customSettingsURL
        }
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("GlyphSift", isDirectory: true).appendingPathComponent("settings.json")
    }

    func load() -> AppSettings {
        do {
            let data = try Data(contentsOf: settingsURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    func save(_ settings: AppSettings) throws {
        let folder = settingsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
    }

    func export(_ settings: AppSettings, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: [.atomic])
    }

    func `import`(from url: URL) throws -> AppSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}
