import Foundation
import RouterCore

struct ConfigurationStore {
    let overrideURL: URL?

    var fileURL: URL {
        get throws {
            if let overrideURL { return overrideURL }
            let userURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/chrome-profile-router/config.json")
            if FileManager.default.fileExists(atPath: userURL.path) { return userURL }
            if let bundledURL = Bundle.main.url(forResource: "config", withExtension: "json") {
                return bundledURL
            }
            throw RoutingError.invalidConfiguration(
                "設定ファイルがありません。--config で指定するか、ビルドした .app を使用してください。")
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
