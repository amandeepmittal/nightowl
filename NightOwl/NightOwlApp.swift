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
    @Published var keepDisplayAwake: Bool = false
    @Published var selectedMode: AwakeMode = .duration(3600 * 8)
    @Published var launchAtLogin: Bool
    @Published var defaultKeepDisplayAwake: Bool = false
    @Published var defaultMode: AwakeMode = .duration(3600 * 8)

    private var cancellables: Set<AnyCancellable> = []
    private let logger = Logger(subsystem: "com.nightowl", category: "ViewModel")

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
    }

    func toggle() {
        switch state {
        case .off:
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

    private func refreshWarnings() {
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
