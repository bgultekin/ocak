import AppKit
import Foundation
import Observation
import Sparkle

/// Minimal metadata for the session-list "Update available" box.
struct AvailableUpdate: Equatable {
    let version: String
    let currentVersion: String
    let releaseNotesURL: URL?
}

/// Drives Sparkle-based update checks and publishes state for the in-app UI.
///
/// Manual mode (default): silent background check via `checkForUpdateInformation()`.
/// A found update is surfaced through `availableUpdate` so `UpdateAvailableBox` can render.
/// Clicking "Update" in the box triggers Sparkle's standard install flow.
///
/// Auto mode: Sparkle's built-in automatic check + download handles everything.
@MainActor
@Observable
final class UpdateService: NSObject {
    static let shared = UpdateService()

    private static let autoUpdateKey = "ocak.autoUpdateEnabled"
    private static let skippedVersionKey = "ocak.skippedUpdateVersion"

    private(set) var availableUpdate: AvailableUpdate?
    private(set) var lastCheckDate: Date?
    private(set) var isCheckingForUpdates = false
    private(set) var lastPluginUpdate: Date?

    var isAutoUpdateEnabled: Bool {
        didSet {
            guard oldValue != isAutoUpdateEnabled else { return }
            UserDefaults.standard.set(isAutoUpdateEnabled, forKey: Self.autoUpdateKey)
            applyAutoUpdatePreference()
        }
    }

    private var skippedVersion: String? {
        get { UserDefaults.standard.string(forKey: Self.skippedVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.skippedVersionKey) }
    }

    /// Session-only: set when the user clicks "Not now" so the box stays hidden until relaunch.
    private var snoozedThisSession = false

    private var updaterController: SPUStandardUpdaterController?

    override private init() {
        self.isAutoUpdateEnabled = UserDefaults.standard.bool(forKey: Self.autoUpdateKey)
        super.init()
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        applyAutoUpdatePreference()
    }

    // MARK: - Public API

    /// Called once on app launch. Performs a silent background check (manual mode)
    /// or a full check (auto mode).
    func checkOnLaunch() {
        guard let updater = updaterController?.updater else { return }
        if isAutoUpdateEnabled {
            updater.checkForUpdatesInBackground()
        } else {
            isCheckingForUpdates = true
            updater.checkForUpdateInformation()
        }
    }

    /// User-initiated "Check for updates…" button in Settings.
    func checkNow() {
        guard let controller = updaterController else { return }
        controller.checkForUpdates(nil)
    }

    /// User clicked "Update" in the session-list box. Hand off to Sparkle's install flow.
    func installUpdateNow() {
        guard let controller = updaterController else { return }
        availableUpdate = nil
        controller.checkForUpdates(nil)
    }

    /// User clicked "Not now". Hide the box until next app launch.
    func snoozeUntilNextLaunch() {
        snoozedThisSession = true
        availableUpdate = nil
    }

    /// User clicked "Skip this version". Persist and stay hidden until a newer version appears.
    func skipCurrentVersion() {
        if let version = availableUpdate?.version {
            skippedVersion = version
        }
        availableUpdate = nil
    }

    var lastCheckDescription: String {
        guard let lastCheckDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Checked \(formatter.localizedString(for: lastCheckDate, relativeTo: Date()))"
    }

    var lastPluginUpdateDescription: String {
        guard let lastPluginUpdate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Plugin updated \(formatter.localizedString(for: lastPluginUpdate, relativeTo: Date()))"
    }

    func recordPluginUpdate() {
        lastPluginUpdate = Date()
    }

    // MARK: - Internal

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    private func applyAutoUpdatePreference() {
        guard let updater = updaterController?.updater else { return }
        updater.automaticallyChecksForUpdates = isAutoUpdateEnabled
        updater.automaticallyDownloadsUpdates = isAutoUpdateEnabled
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateService: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let notesURL = item.releaseNotesURL
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCheckingForUpdates = false
            self.lastCheckDate = Date()

            if self.isAutoUpdateEnabled {
                // Sparkle's own machinery will download + install; we stay quiet.
                return
            }
            if self.snoozedThisSession { return }
            if let skipped = self.skippedVersion, skipped == version { return }

            self.availableUpdate = AvailableUpdate(
                version: version,
                currentVersion: Self.currentVersion,
                releaseNotesURL: notesURL
            )
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
            self?.lastCheckDate = Date()
            self?.availableUpdate = nil
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isCheckingForUpdates = false
        }
    }
}
