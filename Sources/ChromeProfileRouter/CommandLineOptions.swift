import Foundation

struct CommandLineOptions {
    enum Mode { case receive, resolve, open, check, help }
    var mode: Mode = .receive
    var configURL: URL?
    var urls: [URL] = []

    static let help = String(localized: "cli.help", defaultValue: """
    Chrome Profile Router
      --resolve URL [URL ...]   Show routing as JSON without launching Chrome
      --open URL [URL ...]      Open in the configured Chrome profile
      --check-config           Validate settings
      --config PATH            Use this settings file for this launch
      --help                   Show this help
    Open the .app directly to manage settings and updates. URL launches forward links to Chrome.
    The app exits after forwarding, unless an update check or update window is active.
    Specify local HTML files as file:///... URLs.
    """, comment: "Command-line help. Keep option names and URL schemes unchanged.")

    init(arguments: [String]) throws {
        var index = 0
        var selectedMode = false
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-AppleLanguages", "-AppleLocale":
                // Foundation reads these standard launch overrides from the original arguments.
                index += 1
                guard index < arguments.count else { throw UsageError() }
            case "--config":
                index += 1
                guard index < arguments.count else { throw UsageError() }
                configURL = URL(fileURLWithPath: (arguments[index] as NSString).expandingTildeInPath)
            case "--resolve", "--open", "--check-config", "--help":
                guard !selectedMode else { throw UsageError() }
                selectedMode = true
                mode = ["--resolve": .resolve, "--open": .open,
                        "--check-config": .check, "--help": .help][argument]!
            default:
                guard !argument.hasPrefix("-"), let url = URL(string: argument) else { throw UsageError() }
                urls.append(url)
            }
            index += 1
        }
        switch mode {
        case .resolve, .open: guard !urls.isEmpty else { throw UsageError() }
        default: guard urls.isEmpty else { throw UsageError() }
        }
    }

    struct UsageError: Error, LocalizedError {
        var errorDescription: String? {
            String(localized: "Check the command-line arguments.") + "\n" + CommandLineOptions.help
        }
    }
}
