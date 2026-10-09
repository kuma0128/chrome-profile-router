import Foundation

struct CommandLineOptions {
    enum Mode { case receive, resolve, open, check, help }
    var mode: Mode = .receive
    var configURL: URL?
    var urls: [URL] = []

    static let help = """
    Chrome Profile Router
      --resolve URL [URL ...]   振り分け結果をJSONで表示（Chromeは起動しない）
      --open URL [URL ...]      Chromeの指定プロファイルで開く
      --check-config           設定ファイルを検証
      --config PATH            この起動で使う設定ファイルを指定
      --help                   この説明を表示
    オプションなしの .app はmacOSからURLを受け取り、Chromeへ渡して終了します。
    ローカルHTMLファイルは file:///... 形式で指定できます。
    """

    init(arguments: [String]) throws {
        var index = 0
        var selectedMode = false
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
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
        var errorDescription: String? { "引数を確認してください。\n\(CommandLineOptions.help)" }
    }
}
