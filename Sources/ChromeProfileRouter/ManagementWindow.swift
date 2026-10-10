import AppKit

@MainActor
final class ManagementWindow: NSWindowController, NSWindowDelegate {
    private let store: ConfigurationStore
    private let updates: UpdateController
    private let status = NSTextField(wrappingLabelWithString: String(localized: "Links open in the Chrome profile chosen by your settings."))
    private let updateButton = NSButton(title: String(localized: "Check for Updates…"), target: nil, action: nil)
    private var observation: NSKeyValueObservation?
    var onClose: (() -> Void)?

    init(store: ConfigurationStore, updates: UpdateController) {
        self.store = store
        self.updates = updates
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Chrome Profile Router"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let title = NSTextField(labelWithString: "Chrome Profile Router")
        title.font = .boldSystemFont(ofSize: 21)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "Development build")
        let versionLabel = NSTextField(labelWithString: String(localized: "Version \(version)"))
        versionLabel.textColor = .secondaryLabelColor
        status.textColor = .secondaryLabelColor
        let configButton = NSButton(title: String(localized: "Open Settings File…"), target: self, action: #selector(openConfiguration))
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        let automatic = NSButton(checkboxWithTitle: String(localized: "Automatically check for updates"), target: self,
                                 action: #selector(changeAutomaticChecks(_:)))
        automatic.state = updates.updater.automaticallyChecksForUpdates ? .on : .off
        let footnote = NSTextField(wrappingLabelWithString: String(localized: "Checks about once a day while in use. Asks before installing."))
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        let buttons = NSStackView(views: [updateButton, configButton])
        buttons.spacing = 10
        let content = NSStackView(views: [title, versionLabel, status, buttons, automatic, footnote])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            content.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24),
        ])
        observation = updates.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateButton.isEnabled = self.updates.startupError == nil && self.updates.updater.canCheckForUpdates
            }
        }
        if let error = updates.startupError { status.stringValue = String(localized: "Could not start the updater: \(error.localizedDescription)") }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(activate: Bool, availableVersion: String? = nil) {
        if let availableVersion {
            status.stringValue = String(localized: "Version \(availableVersion) is available. Choose “Check for Updates…” to install it.")
        }
        NSApp.setActivationPolicy(.regular)
        if activate {
            showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window?.orderFront(nil)
        }
    }

    func windowWillClose(_ notification: Notification) { onClose?() }

    @objc private func checkForUpdates() { updates.checkForUpdates() }

    @objc private func changeAutomaticChecks(_ sender: NSButton) {
        updates.updater.automaticallyChecksForUpdates = sender.state == .on
    }

    @objc private func openConfiguration() {
        Task { @MainActor in
            do {
                let url = try store.fileURL
                // NSWorkspace's completion-handler API calls back on a concurrent queue.
                // Awaiting the operation resumes here on the main actor, including on failure.
                _ = try await NSWorkspace.shared.open([url],
                    withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                    configuration: NSWorkspace.OpenConfiguration())
            } catch { NSAlert(error: error).runModal() }
        }
    }
}
