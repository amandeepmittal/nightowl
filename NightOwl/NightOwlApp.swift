import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover = NSPopover()
        popover.contentSize = NSSize(width: NightOwlLayout.windowWidth, height: NightOwlLayout.popoverHeight)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PlaceholderRootView())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.create()
            button.action = #selector(togglePopover(_:))
            button.target = self
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

private struct PlaceholderRootView: View {
    var body: some View {
        Text("NightOwl")
            .frame(width: NightOwlLayout.windowWidth, height: NightOwlLayout.popoverHeight)
    }
}

enum MenuBarIcon {
    static func create() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let path = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: size - 6, height: size - 6))
        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
