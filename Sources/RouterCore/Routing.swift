import Foundation

public enum RoutingError: Error, LocalizedError {
    case invalidConfiguration(String)
    case unsupportedURL

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason): return String(localized: "Check your settings.\n\(reason)")
        case .unsupportedURL: return String(localized: "Only http/https URLs and local HTML files can be opened.")
        }
    }
}

public struct RoutingConfiguration: Decodable, Sendable {
    public struct Rule: Decodable, Sendable {
        public let host: String
        public let profile: String
        public let includeSubdomains: Bool
    }

    public let defaultProfile: String
    public let profiles: [String: String]
    public let rules: [Rule]

    public static func decode(_ data: Data) throws -> Self {
        let configuration: Self
        do {
            configuration = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw RoutingError.invalidConfiguration(String(localized: "The JSON format or required fields are invalid."))
        }
        try configuration.validate()
        return configuration
    }

    private func validate() throws {
        guard profiles[defaultProfile] != nil else {
            throw RoutingError.invalidConfiguration(String(localized: "defaultProfile must refer to an entry in profiles."))
        }
        for (name, directory) in profiles {
            guard !name.isEmpty,
                  directory.range(of: #"\A(?:Default|Profile [1-9][0-9]*)\z"#,
                                  options: .regularExpression) != nil else {
                throw RoutingError.invalidConfiguration(
                    String(localized: "Each profile must have a nonempty name and a directory of Default or Profile followed by a number."))
            }
        }
        for rule in rules {
            let host = Self.normalizedHost(rule.host)
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            guard !host.isEmpty, host.utf8.count <= 253,
                  labels.allSatisfy({ label in
                      !label.isEmpty && label.utf8.count <= 63 &&
                      label.first != "-" && label.last != "-" &&
                      label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
                  }) else {
                throw RoutingError.invalidConfiguration(String(localized: "Use only domain names for host in rules."))
            }
            guard profiles[rule.profile] != nil else {
                throw RoutingError.invalidConfiguration(String(localized: "A rule refers to an undefined profile."))
            }
        }
    }

    public func plan(for url: URL) throws -> LaunchPlan {
        let scheme = url.scheme?.lowercased()
        let isWebURL = ["http", "https"].contains(scheme ?? "") && !(url.host ?? "").isEmpty
        let isLocalHTML = url.isFileURL && [nil, "", "localhost"].contains(url.host) &&
            ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased())
        guard isWebURL || isLocalHTML else {
            throw RoutingError.unsupportedURL
        }
        let host = isWebURL ? Self.normalizedHost(url.host!) : ""
        let rule = rules.first {
            let expected = Self.normalizedHost($0.host)
            return isWebURL && (host == expected || ($0.includeSubdomains && host.hasSuffix("." + expected)))
        }
        let profile = rule?.profile ?? defaultProfile
        guard let directory = profiles[profile] else {
            throw RoutingError.invalidConfiguration(String(localized: "The destination profile is missing from profiles."))
        }
        return LaunchPlan(host: host, profile: profile, profileDirectory: directory,
                          arguments: ["--profile-directory=\(directory)", url.absoluteString])
    }

    private static func normalizedHost(_ host: String) -> String {
        let value = host.lowercased()
        return value.hasSuffix(".") ? String(value.dropLast()) : value
    }
}

public struct LaunchPlan: Encodable, Sendable {
    public let host: String
    public let profile: String
    public let profileDirectory: String
    public let arguments: [String]
}

public struct LaunchBatch: Sendable {
    public let profileDirectory: String
    public private(set) var plans: [LaunchPlan]

    public var arguments: [String] {
        ["--profile-directory=\(profileDirectory)"] + plans.flatMap { $0.arguments.dropFirst() }
    }

    // Preserve first-seen profile order and URL order within each profile.
    // Group by directory so aliases for the same Chrome profile share a launch.
    public static func grouping(_ plans: [LaunchPlan]) -> [Self] {
        var batches: [Self] = []
        var indices: [String: Int] = [:]
        for plan in plans {
            if let index = indices[plan.profileDirectory] {
                batches[index].plans.append(plan)
            } else {
                indices[plan.profileDirectory] = batches.count
                batches.append(Self(profileDirectory: plan.profileDirectory, plans: [plan]))
            }
        }
        return batches
    }
}
