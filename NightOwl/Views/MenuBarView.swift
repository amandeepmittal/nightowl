import SwiftUI

@MainActor protocol NightOwlViewModeling: ObservableObject {
    var state: AwakeState { get }
    var profile: DeviceProfile { get }
    var warnings: [SystemWarning] { get }
    var keepDisplayAwake: Bool { get set }
    var selectedMode: AwakeMode { get set }
    var launchAtLogin: Bool { get set }
    var defaultKeepDisplayAwake: Bool { get set }
    var defaultMode: AwakeMode { get set }

    func toggle()
    func setMode(_ mode: AwakeMode)
    func openSettings(for warning: SystemWarning)
    func refreshWarnings()
}

enum MenuBarScreen {
    case main
    case about
    case settings
}

struct MenuBarView<VM: NightOwlViewModeling>: View {
    @ObservedObject var vm: VM
    var modelDisplayName: String = ""

    @State private var screen: MenuBarScreen = .main
    @State private var showKeepDisplayInfo = false

    var body: some View {
        Group {
            switch screen {
            case .main:
                mainScreen
            case .about:
                AboutView(modelDisplayName: modelDisplayName) {
                    screen = .main
                }
            case .settings:
                SettingsView(vm: vm) {
                    screen = .main
                }
            }
        }
        .frame(width: NightOwlLayout.windowWidth)
    }

    private var mainScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            TimerPickerView(selectedMode: Binding(
                get: { vm.selectedMode },
                set: { vm.setMode($0) }
            ))
            .disabled(vm.state.isOn)

            HStack(spacing: 6) {
                Text("Keep display awake too")
                Button {
                    showKeepDisplayInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About keep display awake")
                .popover(isPresented: $showKeepDisplayInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prevents the lock screen")
                            .font(.headline)
                        Text("macOS locks your screen when the display sleeps. Turn this on to keep the display lit so the lock screen never triggers. Without it, NightOwl keeps the Mac awake but your screen will still lock after the display timeout.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(width: 280)
                }
                Spacer()
                Toggle("", isOn: $vm.keepDisplayAwake)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!vm.state.isOn)
                    .accessibilityLabel("Keep display awake too")
            }

            if !vm.warnings.isEmpty {
                WarningsView(warnings: vm.warnings) { warning in
                    vm.openSettings(for: warning)
                }
            }

            if vm.state.isOn {
                statusLine
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: NightOwlLayout.windowWidth, alignment: .leading)
        .onAppear { vm.refreshWarnings() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Keep Mac Awake")
                .font(.headline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { vm.state.isOn },
                set: { _ in vm.toggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.large)
            .accessibilityLabel("Keep Mac awake")
        }
    }

    private var statusLine: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(Self.statusLine(for: vm.state, now: context.date) ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Self.statusLine(for: vm.state, now: context.date) ?? "")
        }
    }

    private var footer: some View {
        HStack {
            Button("About") { screen = .about }
                .accessibilityLabel("About NightOwl")
            Button("Settings") { screen = .settings }
                .accessibilityLabel("Open settings")
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .accessibilityLabel("Quit NightOwl")
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    static func statusLine(for state: AwakeState, now: Date) -> String? {
        guard case let .on(_, startedAt, expiresAt, _) = state else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let startedText = timeFormatter.string(from: startedAt)

        guard let expiresAt else {
            return "Awake since \(startedText). No scheduled release."
        }

        let releaseText = timeFormatter.string(from: expiresAt)
        let remainingText = formatRemaining(from: now, to: expiresAt)
        return "Awake since \(startedText). Releases at \(releaseText) (\(remainingText))."
    }

    private static func formatRemaining(from now: Date, to expiresAt: Date) -> String {
        let remaining = max(0, Int(expiresAt.timeIntervalSince(now).rounded()))
        if remaining < 60 { return "<1m" }
        let totalMinutes = remaining / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

#if DEBUG
@MainActor final class PreviewMockViewModel: NightOwlViewModeling {
    @Published var state: AwakeState
    @Published var profile: DeviceProfile
    @Published var warnings: [SystemWarning]
    @Published var keepDisplayAwake: Bool
    @Published var selectedMode: AwakeMode
    @Published var launchAtLogin: Bool
    @Published var defaultKeepDisplayAwake: Bool
    @Published var defaultMode: AwakeMode

    init(
        state: AwakeState = .off,
        profile: DeviceProfile = .portable(hasBattery: true),
        warnings: [SystemWarning] = [],
        keepDisplayAwake: Bool = false,
        selectedMode: AwakeMode = .duration(3600),
        launchAtLogin: Bool = true,
        defaultKeepDisplayAwake: Bool = false,
        defaultMode: AwakeMode = .duration(3600)
    ) {
        self.state = state
        self.profile = profile
        self.warnings = warnings
        self.keepDisplayAwake = keepDisplayAwake
        self.selectedMode = selectedMode
        self.launchAtLogin = launchAtLogin
        self.defaultKeepDisplayAwake = defaultKeepDisplayAwake
        self.defaultMode = defaultMode
    }

    func toggle() {
        switch state {
        case .off:
            let now = Date()
            state = .on(
                mode: selectedMode,
                startedAt: now,
                expiresAt: selectedMode.expiresAt(now: now),
                keepDisplayAwake: keepDisplayAwake
            )
        case .on:
            state = .off
        }
    }

    func setMode(_ mode: AwakeMode) { selectedMode = mode }
    func openSettings(for warning: SystemWarning) { _ = warning.settingsURL }
    func refreshWarnings() {}
}

#Preview("Off") {
    MenuBarView(vm: PreviewMockViewModel(), modelDisplayName: "MacBook Pro")
}

#Preview("On, indefinite") {
    let now = Date()
    return MenuBarView(
        vm: PreviewMockViewModel(
            state: .on(mode: .indefinite, startedAt: now, expiresAt: nil, keepDisplayAwake: true),
            keepDisplayAwake: true,
            selectedMode: .indefinite
        ),
        modelDisplayName: "MacBook Pro"
    )
}

#Preview("On, with warnings") {
    let now = Date()
    let expires = now.addingTimeInterval(3600)
    return MenuBarView(
        vm: PreviewMockViewModel(
            state: .on(mode: .duration(3600), startedAt: now, expiresAt: expires, keepDisplayAwake: false),
            warnings: [.onBattery, .autoLogoutEnabled(minutes: 10)],
            selectedMode: .duration(3600)
        ),
        modelDisplayName: "MacBook Pro"
    )
}
#endif
