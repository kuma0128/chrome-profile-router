import Foundation
import Testing
@testable import RouterCore

struct RoutingTests {
    private func configuration() throws -> RoutingConfiguration {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try RoutingConfiguration.decode(Data(contentsOf: project.appendingPathComponent("config.json")))
    }

    @Test func currentRulesAndDefault() throws {
        let config = try configuration()
        let cases = [
            ("https://portal.example.com/wiki/pages/123", "Default"),
            ("https://login.example.com/", "Default"),
            ("https://work.example.com/data/project", "Profile 1"),
            ("https://docs.example.org/page", "Profile 2"),
            ("https://team.docs.example.org/page", "Profile 2"),
            ("http://deep.team.docs.example.org:8080/page", "Profile 2"),
            ("https://example.com/", "Default"),
        ]
        for (input, expected) in cases {
            let plan = try config.plan(for: #require(URL(string: input)))
            #expect(plan.profileDirectory == expected, "\(input)")
        }
    }

    @Test func hostnameBoundariesAndNormalization() throws {
        let config = try configuration()
        let cases = [
            ("https://DOCS.EXAMPLE.ORG./page", "Profile 2"),
            ("https://WORK.EXAMPLE.COM./page", "Profile 1"),
            ("https://evildocs.example.org/", "Default"),
            ("https://docs.example.org.example.com/", "Default"),
            ("https://docs.example.org@example.com/", "Default"),
            ("https://example.com/?next=https://docs.example.org", "Default"),
            ("https://sub.work.example.com/", "Default"),
        ]
        for (input, expected) in cases {
            let plan = try config.plan(for: #require(URL(string: input)))
            #expect(plan.profileDirectory == expected, "\(input)")
        }
    }

    @Test func urlRemainsOneUnmodifiedArgument() throws {
        let url = try #require(URL(string:
            "https://docs.example.org/path?q=a%20b&literal=%24%28touch%20bad%29&quote=%27#section"))
        let plan = try configuration().plan(for: url)
        #expect(plan.arguments == ["--profile-directory=Profile 2", url.absoluteString])
    }

    @Test func unsupportedURLsAreRejected() throws {
        let config = try configuration()
        for input in ["file:///tmp/test.txt", "file://remote.example/test.html", "javascript:alert(1)",
                      "chrome://version", "relative/path", "https://"] {
            if let url = URL(string: input) {
                #expect(throws: (any Error).self) { try config.plan(for: url) }
            }
        }
    }

    @Test func localHTMLUsesDefaultProfile() throws {
        let url = URL(fileURLWithPath: "/tmp/router check.html")
        let plan = try configuration().plan(for: url)
        #expect(plan.profileDirectory == "Default")
        #expect(plan.arguments == ["--profile-directory=Default", url.absoluteString])
        #expect(plan.host.isEmpty)
    }

    @Test func invalidConfigurationDoesNotFallback() throws {
        let inputs = [
            #"{"defaultProfile":"missing","profiles":{"work":"Default"},"rules":[]}"#,
            #"{"defaultProfile":"work","profiles":{"work":"../Default"},"rules":[]}"#,
            #"{"defaultProfile":"work","profiles":{"work":"Default\n"},"rules":[]}"#,
            #"{"defaultProfile":"work","profiles":{"work":"Default"},"rules":[{"host":"docs.example.org","profile":"missing","includeSubdomains":true}]}"#,
            #"{"defaultProfile":"work","profiles":{"work":"Default"},"rules":[{"host":"https://docs.example.org","profile":"work","includeSubdomains":true}]}"#,
            #"{"defaultProfile":"work","profiles":{"work":"Default"},"rules":[{"host":"docs.example.org","profile":"work"}]}"#,
            "not JSON",
        ]
        for input in inputs {
            #expect(throws: (any Error).self) { try RoutingConfiguration.decode(Data(input.utf8)) }
        }
    }

    @Test func sameProfileURLsShareOneLaunchWithoutChangingURLs() throws {
        let config = try configuration()
        let inputs = [
            "https://docs.example.org/path?q=a%20b&literal=%24%28touch%20bad%29#section",
            "https://team.docs.example.org/second",
            "https://docs.example.org/path?q=a%20b&literal=%24%28touch%20bad%29#section",
        ]
        let plans = try inputs.map { try config.plan(for: #require(URL(string: $0))) }
        let batches = LaunchBatch.grouping(plans)
        #expect(batches.count == 1)
        let batch = try #require(batches.first)
        #expect(batch.profileDirectory == "Profile 2")
        #expect(batch.plans.count == inputs.count)
        #expect(batch.arguments == ["--profile-directory=Profile 2"] + inputs)
    }

    @Test func mixedProfilesPreserveFirstSeenOrderAndPerProfileURLOrder() throws {
        let config = try configuration()
        let inputs = ["https://docs.example.org/first", "https://work.example.com/first",
                      "https://docs.example.org/second", "https://example.com/", "file:///tmp/check.html",
                      "https://work.example.com/second"]
        let plans = try inputs.map { try config.plan(for: #require(URL(string: $0))) }
        let batches = LaunchBatch.grouping(plans)
        #expect(batches.map(\.profileDirectory) == ["Profile 2", "Profile 1", "Default"])
        #expect(batches.map(\.arguments) == [
            ["--profile-directory=Profile 2", inputs[0], inputs[2]],
            ["--profile-directory=Profile 1", inputs[1], inputs[5]],
            ["--profile-directory=Default", inputs[3], inputs[4]],
        ])
    }

    @Test func profileAliasesShareOneLaunch() throws {
        let config = try RoutingConfiguration.decode(Data(#"""
        {"defaultProfile":"work","profiles":{"work":"Default","alias":"Default"},
         "rules":[{"host":"example.com","profile":"alias","includeSubdomains":false}]}
        """#.utf8))
        let plans = try ["https://example.com/", "https://other.example/"].map {
            try config.plan(for: #require(URL(string: $0)))
        }
        let batches = LaunchBatch.grouping(plans)
        #expect(batches.count == 1)
        #expect(batches.first?.plans.map(\.profile) == ["alias", "work"])
        #expect(batches.first?.arguments == ["--profile-directory=Default",
                                             "https://example.com/", "https://other.example/"])
    }

    @Test func emptyBatchDoesNotLaunchChrome() {
        #expect(LaunchBatch.grouping([]).isEmpty)
    }

    @Test func overlappingRulesUseFirstMatch() throws {
        let config = try RoutingConfiguration.decode(Data(#"""
        {"defaultProfile":"work","profiles":{"work":"Default","other":"Profile 1"},
         "rules":[{"host":"EXAMPLE.COM.","profile":"other","includeSubdomains":true},
                  {"host":"team.example.com","profile":"work","includeSubdomains":false}]}
        """#.utf8))
        let plan = try config.plan(for: #require(URL(string: "https://TEAM.EXAMPLE.COM./")))
        #expect(plan.profileDirectory == "Profile 1")
    }
}
