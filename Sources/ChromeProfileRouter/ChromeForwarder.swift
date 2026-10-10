import AppKit

/// Runs Chrome's command-line forwarding process while a browser is already open.
@MainActor
final class ChromeForwarder {
    private struct Launch {
        let process: Process
        let browser: NSRunningApplication
        let timer: Timer
        let completion: @MainActor (Result<NSRunningApplication, Error>) -> Void
    }

    private var launches: [UUID: Launch] = [:]

    func open(executableURL: URL, arguments: [String], browser: NSRunningApplication,
              completion: @escaping @MainActor (Result<NSRunningApplication, Error>) -> Void) {
        let id = UUID()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            let exitedNormally = process.terminationReason == .exit
            Task { @MainActor in
                self?.finish(id, result: exitedNormally && status == 0
                    ? .success(browser) : .failure(ForwardingError(status: status)))
            }
        }
        // If the browser quits during launch, the child can become the new browser
        // instead of a short-lived forwarder. Wait for its startup, not its exit.
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkBrowserStartup(id) }
        }
        launches[id] = Launch(process: process, browser: browser, timer: timer, completion: completion)
        do {
            try process.run()
        } catch {
            finish(id, result: .failure(error))
        }
    }

    private func checkBrowserStartup(_ id: UUID) {
        guard let launch = launches[id], launch.browser.isTerminated, launch.process.isRunning,
              let browser = NSRunningApplication(processIdentifier: launch.process.processIdentifier),
              browser.isFinishedLaunching else { return }
        finish(id, result: .success(browser))
    }

    private func finish(_ id: UUID, result: Result<NSRunningApplication, Error>) {
        guard let launch = launches.removeValue(forKey: id) else { return }
        launch.timer.invalidate()
        launch.process.terminationHandler = nil
        launch.completion(result)
    }

    private struct ForwardingError: LocalizedError {
        let status: Int32
        var errorDescription: String? {
            String(localized: "Could not forward URLs to Chrome (exit code: \(status)).")
        }
    }
}
