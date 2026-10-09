import AppKit
import Testing
@testable import ChromeProfileRouter

@MainActor
struct ChromeForwarderTests {
    private func run(_ forwarder: ChromeForwarder, executable: String = "/bin/sh",
                     arguments: [String]) async -> Result<NSRunningApplication, Error> {
        await withCheckedContinuation { continuation in
            forwarder.open(executableURL: URL(fileURLWithPath: executable), arguments: arguments,
                           browser: .current) { continuation.resume(returning: $0) }
        }
    }

    @Test func argumentsArriveUnmodifiedBeforeCompletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("arguments.txt")
        let expected = ["--profile-directory=Profile 1",
                        "https://example.com/path?q=a%20b&literal=$(touch%20bad)&quote='#section",
                        "file:///tmp/router%20check.html"]
        let result = await run(ChromeForwarder(), arguments: [
            "-c", #"destination=$1; shift; printf '%s\n' "$@" > "$destination""#,
            "forwarder-test", output.path,
        ] + expected)
        #expect(try result.get().processIdentifier == NSRunningApplication.current.processIdentifier)
        #expect(try String(contentsOf: output, encoding: .utf8) == expected.joined(separator: "\n") + "\n")
    }

    @Test func unsuccessfulExitIsReported() async {
        let result = await run(ChromeForwarder(), arguments: ["-c", "exit 17"])
        switch result {
        case .success: Issue.record("A failed forwarding process was accepted.")
        case .failure(let error): #expect(error.localizedDescription.contains("17"))
        }
    }

    @Test func signalTerminationIsReported() async {
        let result = await run(ChromeForwarder(), arguments: ["-c", "kill -TERM $$"])
        if case .success = result { Issue.record("A terminated forwarding process was accepted.") }
    }

    @Test func launchFailureDoesNotPreventTheNextLaunch() async throws {
        let forwarder = ChromeForwarder()
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let failure = await run(forwarder, executable: missing, arguments: [])
        if case .success = failure { Issue.record("A missing executable was accepted.") }
        let success = await run(forwarder, arguments: ["-c", "exit 0"])
        #expect(try success.get().processIdentifier == NSRunningApplication.current.processIdentifier)
    }
}
