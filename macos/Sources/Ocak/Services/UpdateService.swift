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
/// Ocak is a menu-bar accessory app that rarely quits, so Sparkle's default
/// "download silently and install on quit" behavior is unreliable here.
/// Instead we always run silent info-only checks and surface found updates
/// through `availableUpdate` so `UpdateAvailableBox` can render in the drawer.
/// The actual download + relaunch only happens when the user clicks "Update"
/// in the banner (or "Check for Updates" in the menu), at which point we hand
/// off to Sparkle's standard user-driver flow.
///
/// The auto-update toggle controls whether we also run periodic background
/// info checks while the app is running — without it, the only checks are
/// on launch and when the user explicitly asks.
@MainActor
@Observable
final class UpdateService: NSObject {
    static let shared = UpdateService()

    private static let autoUpdateKey = "ocak.autoUpdateEnabled"
    private static let skippedVersionKey = "ocak.skippedUpdateVersion"
    private static let periodicCheckInterval: TimeInterval = 6 * 60 * 60

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
    private var periodicCheckTimer: Timer?

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

    /// Called once on app launch. Always runs a silent info-only check and,
    /// if auto-update is enabled, schedules periodic re-checks.
    func checkOnLaunch() {
        runSilentCheck()
        rescheduleTimerIfNeeded()
    }

    /// User-initiated "Check for updates…" button in Settings or menu bar.
    /// Uses Sparkle's standard user driver, which surfaces progress and errors.
    func checkNow() {
        guard let controller = updaterController else { return }
        controller.checkForUpdates(nil)
    }

    /// User clicked "Update" in the session-list box. Hand off to Sparkle's
    /// standard install flow. Sparkle will re-fetch the appcast, but for the
    /// same update we already showed, then download + prompt for relaunch.
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
        // Disable Sparkle's own scheduler entirely — it can surface UI prompts
        // we don't control. Our timer (rescheduleTimerIfNeeded) drives all
        // periodic info-only checks instead.
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false
        rescheduleTimerIfNeeded()
    }

    private func runSilentCheck() {
        guard let updater = updaterController?.updater else { return }
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        updater.checkForUpdateInformation()
    }

    private func rescheduleTimerIfNeeded() {
        periodicCheckTimer?.invalidate()
        periodicCheckTimer = nil
        guard isAutoUpdateEnabled else { return }
        let timer = Timer.scheduledTimer(
            withTimeInterval: Self.periodicCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.runSilentCheck() }
        }
        periodicCheckTimer = timer
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
            self?.lastCheckDate = Date()
        }
    }
}
