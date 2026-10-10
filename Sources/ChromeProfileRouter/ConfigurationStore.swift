import Foundation
import RouterCore

struct ConfigurationStore {
    let overrideURL: URL?
    let userURL: URL
    let bundledURL: URL?

    init(overrideURL: URL? = nil,
         userURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/chrome-profile-router/config.json"),
         bundledURL: URL? = Bundle.main.url(forResource: "config", withExtension: "json")) {
        self.overrideURL = overrideURL
        self.userURL = userURL
        self.bundledURL = bundledURL
    }

    var fileURL: URL {
        get throws {
            if let overrideURL { return overrideURL }
            if FileManager.default.fileExists(atPath: userURL.path) { return userURL }
            guard let bundledURL else {
                throw RoutingError.invalidConfiguration(
                    String(localized: "No settings file was found. Specify one with --config or use the built .app."))
            }
            try FileManager.default.createDirectory(at: userURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            do {
                // copyItem refuses to overwrite a file created by another launch.
                try FileManager.default.copyItem(at: bundledURL, to: userURL)
            } catch CocoaError.fileWriteFileExists {
                // Another launch created the user's settings first. Preserve them.
            }
            return userURL
        }
    }

    func load() throws -> RoutingConfiguration {
        let url = try fileURL
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw RoutingError.invalidConfiguration(String(localized: "Could not read settings: \(url.path)"))
        }
        return try RoutingConfiguration.decode(data)
    }
}
