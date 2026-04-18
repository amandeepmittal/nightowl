import Foundation

enum SystemWarning: Identifiable, Equatable, Sendable {
    case onBattery
    case clamshellOnBattery
    case autoLogoutEnabled(minutes: Int)
    case screenWillLock

    var id: String {
        switch self {
        case .onBattery:            return "onBattery"
        case .clamshellOnBattery:   return "clamshellOnBattery"
        case .autoLogoutEnabled:    return "autoLogoutEnabled"
        case .screenWillLock:       return "screenWillLock"
        }
    }

    var title: String {
        switch self {
        case .onBattery:
            return "Running on battery"
        case .clamshellOnBattery:
            return "Lid closed on battery"
        case .autoLogoutEnabled:
            return "Auto log-out is on"
        case .screenWillLock:
            return "Screen will lock"
        }
    }

    var body: String {
        switch self {
        case .onBattery:
            return "Keeping your Mac awake on battery will drain it faster. Plug in to avoid unexpected sleep."
        case .clamshellOnBattery:
            return "macOS may still sleep when the lid is closed and the Mac is unplugged. Connect power or an external display to stay awake."
        case .autoLogoutEnabled(let minutes):
            return "macOS will log you out after \(minutes) minutes of inactivity, which will end your awake session."
        case .screenWillLock:
            return "Your screen is set to lock after inactivity or when the screen saver starts. NightOwl keeps the Mac awake but cannot stop the lock screen."
        }
    }

    var settingsURL: URL? {
        switch self {
        case .onBattery, .clamshellOnBattery:
            return nil
        case .autoLogoutEnabled:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")
        case .screenWillLock:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Lock")
        }
    }
}
