import AppKit
import OSLog
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController!
    private var observation: NSKeyValueObservation?
    private let logger = Logger(subsystem: "local.ChromeProfileRouter", category: "updates")
    var onStateChange: (() -> Void)?
    var onReminder: ((String) -> Void)?
    var managementIsVisible = false
    private(set) var availableVersion: String?
    var hasPendingReminder: Bool { availableVersion != nil }
    private(set) var startupError: Error?

    var updater: SPUUpdater { controller.updater }
    var isBusy: Bool { startupError == nil && updater.sessionInProgress }

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: self, userDriverDelegate: self)
        observation = updater.observe(\.sessionInProgress, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.onStateChange?() }
        }
    }

    func start() {
        do { try updater.start() }
        catch {
            startupError = error
            logger.error("Updater could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates() {
        guard startupError == nil, updater.canCheckForUpdates else { return }
        availableVersion = nil
        updater.checkForUpdates()
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                               andInImmediateFocus: Bool) -> Bool {
        // Scheduled checks only change the management window's status text.
        // The user must choose Check for Updates to open Sparkle's update UI.
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        availableVersion = update.displayVersionString
        onReminder?(update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        if let error { logger.info("Update check finished: \(error.localizedDescription, privacy: .public)") }
        availableVersion = nil
        onStateChange?()
    }
}
