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
    private(set) var hasPendingReminder = false
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
        hasPendingReminder = false
        NSApp.dockTile.badgeLabel = nil
        updater.checkForUpdates()
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                               andInImmediateFocus: Bool) -> Bool {
        // A URL launch must not take focus back from Chrome when an update is found.
        managementIsVisible && NSApp.isActive
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        hasPendingReminder = true
        onReminder?(update.displayVersionString)
        NSApp.dockTile.badgeLabel = "更新"
        NSApp.requestUserAttention(.informationalRequest)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        hasPendingReminder = false
        NSApp.dockTile.badgeLabel = nil
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
                 error: Error?) {
        if let error { logger.info("Update check finished: \(error.localizedDescription, privacy: .public)") }
        hasPendingReminder = false
        NSApp.dockTile.badgeLabel = nil
        onStateChange?()
    }
}
