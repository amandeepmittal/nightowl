import SwiftUI
import AppKit
import Combine
import ServiceManagement
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: NightOwlViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        viewModel = NightOwlViewModel()

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(
            rootView: MenuBarView(vm: viewModel, modelDisplayName: viewModel.modelDisplayName)
        )
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.setAccessibilityLabel("NightOwl")
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

@MainActor
final class NightOwlViewModel: NightOwlViewModeling {
    private let sleepAssertion: SleepAssertionManager
    private let deviceProfile: DeviceProfileService
    private let powerMonitor: PowerStateMonitor
    private let settings: SystemSettingsReader
    private let scheduler: AwakeScheduler

    let modelDisplayName: String

    @Published var state: AwakeState = .off
    @Published var profile: DeviceProfile
    @Published var warnings: [SystemWarning] = []
    @Published var keepDisplayAwake: Bool
    @Published var selectedMode: AwakeMode
    @Published var launchAtLogin: Bool
    @Published var defaultKeepDisplayAwake: Bool
    @Published var defaultMode: AwakeMode

    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(subsystem: "com.nightowl", category: "ViewModel")

    private static let defaultKeepDisplayAwakeKey = "defaultKeepDisplayAwake"
    private static let defaultModeKindKey = "defaultModeKind"
    private static let defaultModeDurationKey = "defaultModeDurationSeconds"
    private static let fallbackDuration: TimeInterval = 3600 * 8

    init() {
        let sleepAssertion = SleepAssertionManager()
        let deviceProfile = DeviceProfileService()
        let powerMonitor = PowerStateMonitor()
        let settings = SystemSettingsReader()
        let scheduler = AwakeScheduler()

        self.sleepAssertion = sleepAssertion
        self.deviceProfile = deviceProfile
        self.powerMonitor = powerMonitor
        self.settings = settings
        self.scheduler = scheduler
        self.profile = deviceProfile.current()
        self.modelDisplayName = deviceProfile.modelDisplayName()
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        let loadedKeepDisplay = Self.loadDefaultKeepDisplayAwake()
        let loadedMode = Self.loadDefaultMode()
        self.defaultKeepDisplayAwake = loadedKeepDisplay
        self.defaultMode = loadedMode
        self.keepDisplayAwake = loadedKeepDisplay
        self.selectedMode = loadedMode

        refreshWarnings()

        if case .portable = self.profile {
            powerMonitor.observe { [weak self] _ in
                self?.refreshWarnings()
            }
        }

        $launchAtLogin
            .dropFirst()
            .sink { [weak self] enabled in
                self?.applyLaunchAtLogin(enabled)
            }
            .store(in: &cancellables)

        $keepDisplayAwake
            .dropFirst()
            .sink { [weak self] newValue in
                self?.applyKeepDisplayAwakeChange(newValue)
            }
            .store(in: &cancellables)

        $defaultKeepDisplayAwake
            .dropFirst()
            .sink { newValue in
                UserDefaults.standard.set(newValue, forKey: Self.defaultKeepDisplayAwakeKey)
            }
            .store(in: &cancellables)

        $defaultMode
            .dropFirst()
            .sink { newValue in
                Self.storeDefaultMode(newValue)
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDidWake()
            }
            .store(in: &cancellables)
    }

    private func handleDidWake() {
        refreshWarnings()
        guard case .on(_, _, let expiresAt?, _) = state else { return }
        if Date() >= expiresAt {
            logger.info("Wake: session expired during sleep; releasing")
            turnOff()
            return
        }
        scheduler.cancel()
        scheduler.schedule(expiresAt: expiresAt) { [weak self] in
            self?.turnOff()
        }
        logger.info("Wake: rescheduled for \(expiresAt, privacy: .public)")
    }

    private static func loadDefaultKeepDisplayAwake() -> Bool {
        UserDefaults.standard.bool(forKey: defaultKeepDisplayAwakeKey)
    }

    private static func loadDefaultMode() -> AwakeMode {
        let kind = UserDefaults.standard.string(forKey: defaultModeKindKey) ?? "duration"
        switch kind {
        case "indefinite":
            return .indefinite
        case "until8AM":
            return .until(TimerPickerView.nextEightAM(from: Date()))
        case "duration":
            let seconds = UserDefaults.standard.double(forKey: defaultModeDurationKey)
            return .duration(seconds > 0 ? seconds : fallbackDuration)
        default:
            return .duration(fallbackDuration)
        }
    }

    private static func storeDefaultMode(_ mode: AwakeMode) {
        let d = UserDefaults.standard
        switch mode {
        case .indefinite:
            d.set("indefinite", forKey: defaultModeKindKey)
        case .until:
            d.set("until8AM", forKey: defaultModeKindKey)
        case .duration(let seconds):
            d.set("duration", forKey: defaultModeKindKey)
            d.set(seconds, forKey: defaultModeDurationKey)
        }
    }

    private func applyKeepDisplayAwakeChange(_ newValue: Bool) {
        guard case .on(let mode, let startedAt, let expiresAt, let current) = state,
              current != newValue else { return }
        do {
            try sleepAssertion.assert(preventDisplaySleep: newValue)
            state = .on(mode: mode, startedAt: startedAt, expiresAt: expiresAt, keepDisplayAwake: newValue)
            logger.info("Re-asserted; keepDisplayAwake=\(newValue, privacy: .public)")
        } catch {
            logger.error("Re-assert failed: \(String(describing: error), privacy: .public)")
            turnOff()
        }
    }

    func toggle() {
        switch state {
        case .off:
            keepDisplayAwake = defaultKeepDisplayAwake
            do {
                try sleepAssertion.assert(preventDisplaySleep: keepDisplayAwake)
                let now = Date()
                let expires = selectedMode.expiresAt(now: now)
                state = .on(
                    mode: selectedMode,
                    startedAt: now,
                    expiresAt: expires,
                    keepDisplayAwake: keepDisplayAwake
                )
                if let expires {
                    scheduler.schedule(expiresAt: expires) { [weak self] in
                        self?.turnOff()
                    }
                }
                logger.info("NightOwl active; mode=\(self.selectedMode.displayLabel, privacy: .public)")
            } catch {
                logger.error("assert() failed: \(String(describing: error), privacy: .public)")
            }
        case .on:
            turnOff()
        }
    }

    private func turnOff() {
        sleepAssertion.release()
        scheduler.cancel()
        state = .off
        logger.info("NightOwl released")
    }

    func setMode(_ mode: AwakeMode) {
        selectedMode = mode
    }

    func openSettings(for warning: SystemWarning) {
        guard let url = warning.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshWarnings() {
        var result: [SystemWarning] = []

        if case .portable(let hasBattery) = profile, hasBattery,
           powerMonitor.currentSource() == .battery {
            result.append(.onBattery)
        }

        if let minutes = settings.autoLogoutDelayMinutes(), minutes > 0 {
            result.append(.autoLogoutEnabled(minutes: minutes))
        }

        if settings.screenWillLockOnDisplaySleep() {
            result.append(.screenWillLock)
        }

        warnings = result
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("SMAppService registered")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("SMAppService unregistered")
            }
        } catch {
            logger.error("SMAppService \(enabled ? "register" : "unregister", privacy: .public) failed: \(String(describing: error), privacy: .public)")
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = !enabled
            }
        }
    }
}
