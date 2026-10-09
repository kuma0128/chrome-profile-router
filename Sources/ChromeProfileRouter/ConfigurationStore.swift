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
                    "設定ファイルがありません。--config で指定するか、ビルドした .app を使用してください。")
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
            throw RoutingError.invalidConfiguration("設定ファイルを読み取れません: \(url.path)")
        }
        return try RoutingConfiguration.decode(data)
    }
}
