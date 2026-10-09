import Foundation
import Testing
@testable import ChromeProfileRouter

struct ConfigurationStoreTests {
    private let sample = Data(#"{"defaultProfile":"personal","profiles":{"personal":"Default"},"rules":[]}"#.utf8)

    private func withStore(_ body: (ConfigurationStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundledURL = directory.appendingPathComponent("sample.json")
        try sample.write(to: bundledURL)
        let userURL = directory.appendingPathComponent("settings/config.json")
        try body(ConfigurationStore(userURL: userURL, bundledURL: bundledURL), directory)
    }

    @Test func firstLaunchCreatesEditableUserSettings() throws {
        try withStore { store, _ in
            #expect(try store.load().defaultProfile == "personal")
            #expect(try store.fileURL == store.userURL)
            #expect(try Data(contentsOf: store.userURL) == sample)
            // Subsequent launches read the user's changes instead of the bundled sample.
            let edited = Data(#"{"defaultProfile":"work","profiles":{"work":"Profile 3"},"rules":[]}"#.utf8)
            try edited.write(to: store.userURL)
            #expect(try store.load().defaultProfile == "work")
            #expect(try Data(contentsOf: store.userURL) == edited)
        }
    }

    @Test func invalidExistingSettingsArePreserved() throws {
        try withStore { store, _ in
            try FileManager.default.createDirectory(at: store.userURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let invalid = Data("invalid JSON".utf8)
            try invalid.write(to: store.userURL)
            #expect(throws: (any Error).self) { try store.load() }
            #expect(try Data(contentsOf: store.userURL) == invalid)
        }
    }

    @Test func explicitConfigDoesNotCreateUserSettings() throws {
        try withStore { store, directory in
            let overrideURL = directory.appendingPathComponent("override.json")
            try sample.write(to: overrideURL)
            let explicit = ConfigurationStore(overrideURL: overrideURL, userURL: store.userURL,
                                              bundledURL: store.bundledURL)
            #expect(try explicit.load().defaultProfile == "personal")
            #expect(try explicit.fileURL == overrideURL)
            #expect(!FileManager.default.fileExists(atPath: store.userURL.path))
            try FileManager.default.removeItem(at: overrideURL)
            #expect(throws: (any Error).self) { try explicit.load() }
            #expect(!FileManager.default.fileExists(atPath: store.userURL.path))
        }
    }

    @Test func missingSampleAndUnwritableDestinationFail() throws {
        try withStore { store, directory in
            let missing = ConfigurationStore(userURL: store.userURL, bundledURL: nil)
            #expect(throws: (any Error).self) { try missing.load() }
            let blockedDirectory = directory.appendingPathComponent("settings")
            try Data().write(to: blockedDirectory)
            #expect(throws: (any Error).self) { try store.load() }
            #expect(!FileManager.default.fileExists(atPath: store.userURL.path))
        }
    }
}
