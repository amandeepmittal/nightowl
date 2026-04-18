import SwiftUI

struct TimerPickerView: View {
    @Binding var selectedMode: AwakeMode

    @State private var showingCustomSheet = false

    var body: some View {
        HStack {
            Text("Mode")
                .font(.subheadline)
            Spacer()
            Menu {
                Button("Indefinite") { selectedMode = .indefinite }
                Button("Until 8:00 AM") { selectedMode = .until(Self.nextEightAM(from: Date())) }
                Divider()
                Button("For 1 hour") { selectedMode = .duration(3600) }
                Button("For 4 hours") { selectedMode = .duration(3600 * 4) }
                Button("For 8 hours") { selectedMode = .duration(3600 * 8) }
                Button("For 12 hours") { selectedMode = .duration(3600 * 12) }
                Divider()
                Button("Custom duration…") { showingCustomSheet = true }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedMode.displayLabel)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Awake mode")
            .accessibilityValue(selectedMode.displayLabel)
        }
        .sheet(isPresented: $showingCustomSheet) {
            CustomDurationSheet(selectedMode: $selectedMode, isPresented: $showingCustomSheet)
        }
    }

    static func nextEightAM(from now: Date) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        components.second = 0
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600 * 8)
    }
}

private struct CustomDurationSheet: View {
    @Binding var selectedMode: AwakeMode
    @Binding var isPresented: Bool

    @State private var releaseDate: Date = Date().addingTimeInterval(3600)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom release time")
                .font(.headline)

            DatePicker(
                "Release at",
                selection: $releaseDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .accessibilityLabel("Release time")

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    selectedMode = .until(releaseDate)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

#if DEBUG
private struct TimerPickerPreviewHost: View {
    @State var mode: AwakeMode = .duration(3600)
    var body: some View {
        TimerPickerView(selectedMode: $mode)
            .padding()
            .frame(width: NightOwlLayout.windowWidth)
    }
}

#Preview("Duration") {
    TimerPickerPreviewHost(mode: .duration(3600 * 4))
}

#Preview("Indefinite") {
    TimerPickerPreviewHost(mode: .indefinite)
}
#endif
