import Foundation
import Testing
@testable import RouterCore

struct RoutingTests {
    private func configuration() throws -> RoutingConfiguration {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try RoutingConfiguration.decode(Data(contentsOf: project.appendingPathComponent("config.json")))
    }

    private func configuration(host: String, includeSubdomains: Bool = true) throws -> RoutingConfiguration {
        let data = try JSONSerialization.data(withJSONObject: [
            "defaultProfile": "personal",
            "profiles": ["personal": "Default", "work": "Profile 1"],
            "rules": [["host": host, "profile": "work", "includeSubdomains": includeSubdomains]],
        ])
        return try RoutingConfiguration.decode(data)
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

    @Test func encodedInternationalHostsMatchPunycodeRules() throws {
        let config = try configuration(host: "xn--bcher-kva.example")
        let inputs = [
            "https://bücher.example/path?q=a%20b#section",
            "https://xn--bcher-kva.example/path?q=a%20b#section",
            "https://%62%C3%BCcher.example/path?q=a%20b#section",
            "https://team.b%C3%BCcher.example./path",
        ]
        for input in inputs {
            let url = try #require(URL(string: input))
            let plan = try config.plan(for: url)
            #expect(plan.profileDirectory == "Profile 1", "\(input)")
            #expect(plan.host == (input.contains("team.") ? "team.xn--bcher-kva.example" : "xn--bcher-kva.example"))
            #expect(plan.arguments == ["--profile-directory=Profile 1", url.absoluteString])
        }
    }

    @Test(arguments: [
        ("bücher.example", "xn--bcher-kva.example"),
        ("BÜCHER.example.", "xn--bcher-kva.example"),
        ("例え.テスト", "xn--r8jz45g.xn--zckzah"),
        ("e\u{301}.example", "xn--9ca.example"),
        ("ＷＯＲＫ。ＥＸＡＭＰＬＥ．ＣＯＭ．", "work.example.com"),
    ])
    func internationalizedRulesMatchEquivalentHostnames(ruleHost: String, asciiHost: String) throws {
        let config = try configuration(host: ruleHost)
        let encodedHost = ruleHost.utf8.map { String(format: "%%%02X", $0) }.joined()
        for host in [ruleHost, asciiHost, encodedHost] {
            for prefix in ["", "team."] {
                let url = try #require(URL(string: "https://\(prefix)\(host)/path?q=value#section"))
                let plan = try config.plan(for: url)
                #expect(plan.profileDirectory == "Profile 1", "\(url)")
                #expect(plan.host == prefix + asciiHost)
                #expect(plan.arguments == ["--profile-directory=Profile 1", url.absoluteString])
            }
        }
    }

    @Test func internationalizedRulesKeepExactMatchesAndHostBoundaries() throws {
        let exact = try configuration(host: "bücher.example", includeSubdomains: false)
        let subdomains = try configuration(host: "bücher.example")
        for input in ["https://team.bücher.example/", "https://team.xn--bcher-kva.example/",
                      "https://team.b%C3%BCcher.example/"] {
            let url = try #require(URL(string: input))
            #expect(try exact.plan(for: url).profileDirectory == "Default")
            #expect(try subdomains.plan(for: url).profileDirectory == "Profile 1")
        }
        for input in ["https://evilbücher.example/", "https://bücher.example.evil.example/",
                      "https://bücher.example@evil.example/", "https://evil.example/?next=https://bücher.example/",
                      "https://b%25C3%25BCcher.example/"] {
            let url = try #require(URL(string: input))
            #expect(try subdomains.plan(for: url).profileDirectory == "Default", "\(input)")
        }
    }

    @Test(arguments: [
        "", ".", "bücher..example", "bücher.example..", "-bücher.example", "bücher-.example",
        "https://bücher.example", "bücher.example/path", "bücher.example:443", "user@bücher.example",
        "bücher.example?query", "bücher.example#fragment", "bücher.example\\path",
        " bücher.example", "bücher.example ", "bücher.example\n", "*.bücher.example",
        "b%C3%BCcher.example", "bücher%2Eexample", "a_b.example", "\u{200D}.example",
        String(repeating: "é", count: 58) + ".example",
        String(repeating: "a", count: 64) + ".example",
        Array(repeating: String(repeating: "a", count: 63), count: 4).joined(separator: "."),
    ])
    func invalidRuleHostsAreRejected(host: String) {
        #expect(throws: (any Error).self) { try configuration(host: host) }
    }

    @Test func equivalentInternationalizedRulesUseFirstMatch() throws {
        let config = try RoutingConfiguration.decode(Data(#"""
        {"defaultProfile":"personal","profiles":{"personal":"Default","work":"Profile 1"},
         "rules":[{"host":"BÜCHER.example.","profile":"work","includeSubdomains":true},
                  {"host":"xn--bcher-kva.example","profile":"personal","includeSubdomains":true}]}
        """#.utf8))
        let plan = try config.plan(for: #require(URL(string: "https://team.b%C3%BCcher.example/")))
        #expect(plan.profileDirectory == "Profile 1")
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

    @Test func localHTMLHostIsCaseInsensitive() throws {
        let config = try configuration()
        for host in ["localhost", "LOCALHOST", "LocalHost"] {
            let url = try #require(URL(string: "file://\(host)/tmp/router%20check.HTML"))
            let plan = try config.plan(for: url)
            #expect(plan.arguments == ["--profile-directory=Default", url.absoluteString])
            #expect(plan.host.isEmpty)
        }
        for host in ["localhost.example", "example.localhost", "remote.example"] {
            let url = try #require(URL(string: "file://\(host)/tmp/check.html"))
            #expect(throws: (any Error).self) { try config.plan(for: url) }
        }
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
