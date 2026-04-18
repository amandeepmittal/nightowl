import SwiftUI

struct WarningsView: View {
    let warnings: [SystemWarning]
    var onOpenSettings: (SystemWarning) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Heads up", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(warnings) { warning in
                    row(for: warning)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func row(for warning: SystemWarning) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(warning.title)
                .font(.subheadline.weight(.semibold))
            Text(warning.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if warning.settingsURL != nil {
                Button("Open Settings") { onOpenSettings(warning) }
                    .buttonStyle(.link)
                    .font(.caption)
                    .accessibilityLabel("Open Settings for \(warning.title)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(warning.title)
        .accessibilityHint(warning.body)
    }
}

#if DEBUG
#Preview("All warnings") {
    WarningsView(
        warnings: [
            .onBattery,
            .clamshellOnBattery,
            .autoLogoutEnabled(minutes: 10),
            .screenWillLock
        ],
        onOpenSettings: { _ in }
    )
    .padding()
    .frame(width: NightOwlLayout.windowWidth)
}

#Preview("Single warning") {
    WarningsView(
        warnings: [.autoLogoutEnabled(minutes: 15)],
        onOpenSettings: { _ in }
    )
    .padding()
    .frame(width: NightOwlLayout.windowWidth)
}
#endif
