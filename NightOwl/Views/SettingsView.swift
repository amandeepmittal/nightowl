import SwiftUI

struct SettingsView<VM: NightOwlViewModeling>: View {
    @ObservedObject var vm: VM
    let onBack: () -> Void

    @State private var showingCustomDefaultSheet = false

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

                    HStack {
                        Text("Default mode")
                        Spacer()
                        Menu(vm.defaultMode.displayLabel) {
                            Button("Indefinite") { vm.defaultMode = .indefinite }
                            Button("Until next 8:00 AM") {
                                vm.defaultMode = .until(TimerPickerView.nextEightAM(from: Date()))
                            }
                            Divider()
                            Button("For 1 hour") { vm.defaultMode = .duration(3600) }
                            Button("For 4 hours") { vm.defaultMode = .duration(3600 * 4) }
                            Button("For 8 hours") { vm.defaultMode = .duration(3600 * 8) }
                            Button("For 12 hours") { vm.defaultMode = .duration(3600 * 12) }
                            Divider()
                            Button("Custom duration…") { showingCustomDefaultSheet = true }
                        }
                        .fixedSize()
                        .accessibilityLabel("Default awake mode")
                        .accessibilityValue(vm.defaultMode.displayLabel)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: NightOwlLayout.windowWidth)
        .sheet(isPresented: $showingCustomDefaultSheet) {
            CustomDefaultDurationSheet(
                mode: $vm.defaultMode,
                isPresented: $showingCustomDefaultSheet
            )
        }
    }
}

private struct CustomDefaultDurationSheet: View {
    @Binding var mode: AwakeMode
    @Binding var isPresented: Bool

    @State private var hours: Int
    @State private var minutes: Int

    init(mode: Binding<AwakeMode>, isPresented: Binding<Bool>) {
        self._mode = mode
        self._isPresented = isPresented
        let (h, m): (Int, Int) = {
            if case .duration(let s) = mode.wrappedValue {
                let total = Int(s)
                return (total / 3600, (total % 3600) / 60)
            }
            return (8, 0)
        }()
        self._hours = State(initialValue: h)
        self._minutes = State(initialValue: m)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom default duration")
                .font(.headline)

            HStack(spacing: 20) {
                Stepper(value: $hours, in: 0...24) {
                    Text("Hours: \(hours)")
                }
                Stepper(value: $minutes, in: 0...59) {
                    Text("Minutes: \(minutes)")
                }
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let seconds = TimeInterval(hours * 3600 + minutes * 60)
                    mode = .duration(seconds)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding(20)
        .frame(width: 360)
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
