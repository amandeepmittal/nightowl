import SwiftUI
import AppKit

struct AboutView: View {
    let modelDisplayName: String
    let onBack: () -> Void

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
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

            VStack(spacing: 14) {
                Group {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
                    } else {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                    }
                }
                .accessibilityHidden(true)

                Text("NightOwl")
                    .font(.title2.weight(.semibold))

                Text(versionString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(versionString)

                Text("A tiny menu bar app that keeps your Mac awake, without the jargon.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    footerLink(title: "GitHub", systemImage: "link", urlString: "https://github.com/amandeepmittal/nightowl")
                    footerDot
                    footerLink(title: "amanhimself.dev", systemImage: "globe", urlString: "https://amanhimself.dev")
                    footerDot
                    footerLink(title: "Aman Mittal", systemImage: "person.crop.circle", urlString: "https://amanhimself.dev")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

                if !modelDisplayName.isEmpty {
                    Text("Running on \(modelDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .frame(width: NightOwlLayout.windowWidth)
    }

    private func footerLink(title: String, systemImage: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var footerDot: some View {
        Circle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 3, height: 3)
    }
}

#if DEBUG
#Preview("MacBook Pro") {
    AboutView(modelDisplayName: "MacBook Pro", onBack: {})
}

#Preview("Unknown model") {
    AboutView(modelDisplayName: "", onBack: {})
}
#endif
