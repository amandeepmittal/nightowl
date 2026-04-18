import SwiftUI

struct SettingsView<VM: NightOwlViewModeling>: View {
    @ObservedObject var vm: VM
    let onBack: () -> Void

    private static var defaultModeOptions: [AwakeMode] {
        [
            .indefinite,
            .until(TimerPickerView.nextEightAM(from: Date())),
            .duration(3600),
            .duration(3600 * 4),
            .duration(3600 * 8),
            .duration(3600 * 12)
        ]
    }

    private var defaultModeIndexBinding: Binding<Int> {
        Binding(
            get: {
                Self.defaultModeOptions.firstIndex(where: { Self.matches($0, vm.defaultMode) }) ?? 0
            },
            set: { newIndex in
                vm.defaultMode = Self.defaultModeOptions[newIndex]
            }
        )
    }

    private static func matches(_ a: AwakeMode, _ b: AwakeMode) -> Bool {
        switch (a, b) {
        case (.indefinite, .indefinite): return true
        case (.until, .until): return true
        case (.duration(let la), .duration(let lb)): return la == lb
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("Back to main")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section {
                    Toggle("Launch at login", isOn: $vm.launchAtLogin)
                        .accessibilityLabel("Launch NightOwl at login")
                }

                Section("Defaults") {
                    Toggle("Keep display awake too by default", isOn: $vm.defaultKeepDisplayAwake)
                        .accessibilityLabel("Keep display awake too by default")

                    Picker("Default mode", selection: defaultModeIndexBinding) {
                        ForEach(Array(Self.defaultModeOptions.enumerated()), id: \.offset) { index, mode in
                            Text(mode.displayLabel).tag(index)
                        }
                    }
                    .accessibilityLabel("Default awake mode")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: NightOwlLayout.windowWidth)
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView(
        vm: PreviewMockViewModel(
            launchAtLogin: true,
            defaultKeepDisplayAwake: false,
            defaultMode: .duration(3600 * 4)
        ),
        onBack: {}
    )
}
#endif
