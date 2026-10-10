import Foundation
import Testing
@testable import ChromeProfileRouter

struct LocalizationTests {
    @Test func translationsPreserveKeysAndFormatArguments() throws {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func table(_ language: String) throws -> [String: String] {
            let data = try Data(contentsOf: project.appendingPathComponent("Resources/\(language).lproj/Localizable.strings"))
            return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let english = try table("en")
        let placeholder = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:@|lld|ld|d)"#)
        func placeholders(_ value: String) -> [String] {
            placeholder.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }.sorted()
        }
        let resources = try FileManager.default.contentsOfDirectory(at: project.appendingPathComponent("Resources"),
                                                                   includingPropertiesForKeys: nil)
        for directory in resources where directory.pathExtension == "lproj" {
            let language = directory.deletingPathExtension().lastPathComponent
            let translations = try table(language)
            #expect(Set(english.keys) == Set(translations.keys), "\(language)")
            for (key, value) in english {
                let translation = try #require(translations[key])
                #expect(!translation.isEmpty, "\(language): \(key)")
                #expect(placeholders(value) == placeholders(translation), "\(language): \(key)")
            }
        }
    }

    @Test func standardLanguageOverridesDoNotBecomeRoutingArguments() throws {
        let options = try CommandLineOptions(arguments: ["-AppleLanguages", "(ja, en)", "--resolve",
            "https://example.com/", "-AppleLocale", "en_US"])
        #expect(options.mode == .resolve)
        #expect(options.urls.map(\.absoluteString) == ["https://example.com/"])
        #expect(throws: (any Error).self) { try CommandLineOptions(arguments: ["-AppleLanguages"]) }
        #expect(throws: (any Error).self) { try CommandLineOptions(arguments: ["-AppleLocale"]) }
        #expect(throws: (any Error).self) { try CommandLineOptions(arguments: ["--unknown-option"]) }
    }
}
