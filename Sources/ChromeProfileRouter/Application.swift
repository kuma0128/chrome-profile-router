import AppKit
import OSLog
import RouterCore

@MainActor
final class RouterDelegate: NSObject, NSApplicationDelegate {
    private let store: ConfigurationStore
    private let initialURLs: [URL]
    private let logger = Logger(subsystem: "local.ChromeProfileRouter", category: "routing")
    private var pendingLaunches = 0
    private var shutdownTimer: Timer?
    private(set) var failed = false

    init(store: ConfigurationStore, initialURLs: [URL]) {
        self.store = store
        self.initialURLs = initialURLs
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if initialURLs.isEmpty {
            // A Finder launch also prepares settings, even without a URL to route.
            do { _ = try store.fileURL } catch { report(error) }
        } else {
            open(initialURLs)
        }
        scheduleExit()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls)
    }

    private func open(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        shutdownTimer?.invalidate()
        do {
            let configuration = try store.load()
            // Validate the entire batch before opening any of its URLs.
            let plans = try urls.map { try configuration.plan(for: $0) }
            guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
                throw RoutingError.invalidConfiguration("Google Chromeが見つかりません。")
            }
            let runningChrome = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome")
                .filter { !$0.isTerminated }
                .min { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
            for batch in LaunchBatch.grouping(plans) {
                pendingLaunches += 1
                let options = NSWorkspace.OpenConfiguration()
                // A new launch delivers the arguments even when Chrome is already running.
                // Chrome then forwards the request to its existing browser process.
                options.createsNewApplicationInstance = true
                // Only the first browser process owns windows. A forwarding process
                // must not take focus and then return it to the source app on exit.
                options.activates = runningChrome == nil
                options.arguments = batch.arguments
                for plan in batch.plans {
                    logger.info("host=\(plan.host, privacy: .public) profile=\(plan.profileDirectory, privacy: .public)")
                }
                NSWorkspace.shared.openApplication(at: chromeURL, configuration: options) { _, error in
                    Task { @MainActor in
                        if let error {
                            self.report(error)
                        } else {
                            // The new Chrome process forwards URLs and exits. Activate the
                            // existing browser process, which owns the destination window.
                            if let runningChrome {
                                if #available(macOS 14, *) {
                                    NSApp.yieldActivation(to: runningChrome)
                                    runningChrome.activate(from: .current, options: [])
                                } else {
                                    runningChrome.activate(options: [.activateIgnoringOtherApps])
                                }
                            }
                        }
                        self.pendingLaunches -= 1
                        self.scheduleExit()
                    }
                }
            }
        } catch {
            report(error)
        }
        scheduleExit()
    }

    private func report(_ error: Error) {
        failed = true
        logger.error("Routing failed: \(error.localizedDescription, privacy: .private)")
        if !initialURLs.isEmpty {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            return
        }
        let alert = NSAlert()
        alert.messageText = "リンクを開けませんでした"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "閉じる")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func scheduleExit() {
        shutdownTimer?.invalidate()
        guard pendingLaunches == 0 else { return }
        // CLI input is complete; it does not need to wait for URL Apple Events.
        if !initialURLs.isEmpty {
            stop()
            return
        }
        // Allow Launch Services to deliver the initial URL event and closely spaced clicks.
        shutdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pendingLaunches == 0 else { return }
                self.stop()
            }
        }
    }

    private func stop() {
        NSApp.stop(nil)
        // Wake the event loop so stop() also works when no window is present.
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            subtype: 0, data1: 0, data2: 0) {
            NSApp.postEvent(event, atStart: true)
        }
    }
}

@main
struct ChromeProfileRouter {
    @MainActor
    static func main() {
        do {
            let options = try CommandLineOptions(arguments: Array(CommandLine.arguments.dropFirst()))
            let store = ConfigurationStore(overrideURL: options.configURL)
            switch options.mode {
            case .help:
                print(CommandLineOptions.help)
            case .check:
                _ = try store.load()
                print("設定は有効です: \(try store.fileURL.path)")
            case .resolve:
                let configuration = try store.load()
                let plans = try options.urls.map { try configuration.plan(for: $0) }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                FileHandle.standardOutput.write(try encoder.encode(plans))
                print()
            case .receive, .open:
                let application = NSApplication.shared
                application.setActivationPolicy(.accessory)
                let delegate = RouterDelegate(store: store, initialURLs: options.urls)
                application.delegate = delegate
                withExtendedLifetime(delegate) { application.run() }
                if delegate.failed { exit(1) }
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
