import Foundation
import os

@MainActor
final class SystemSettingsReader {
    private let log = Logger(subsystem: "com.nightowl", category: "SystemSettingsReader")

    func autoLogoutDelayMinutes() -> Int? {
        guard let raw = copyPref("autoLogOutDelay", domain: "com.apple.loginwindow") else {
            log.debug("autoLogOutDelay not set")
            return nil
        }
        guard let seconds = asInt(raw) else {
            log.info("autoLogOutDelay present but unparseable: \(String(describing: raw), privacy: .public)")
            return nil
        }
        if seconds == 0 { return 0 }
        return seconds / 60
    }

    func screenWillLockOnDisplaySleep() -> Bool {
        guard let askRaw = copyPref("askForPassword", domain: "com.apple.screensaver") else {
            log.debug("askForPassword not set")
            return false
        }
        guard let ask = asBool(askRaw) else {
            log.info("askForPassword present but unparseable: \(String(describing: askRaw), privacy: .public)")
            return false
        }
        guard ask else { return false }

        guard let delayRaw = copyPref("askForPasswordDelay", domain: "com.apple.screensaver") else {
            log.debug("askForPasswordDelay missing; treating as 0")
            return true
        }
        guard let delay = asInt(delayRaw) else {
            log.info("askForPasswordDelay unparseable: \(String(describing: delayRaw), privacy: .public)")
            return true
        }
        return delay <= 5
    }

    private func copyPref(_ key: String, domain: String) -> CFPropertyList? {
        CFPreferencesCopyValue(
            key as CFString,
            domain as CFString,
            kCFPreferencesAnyUser,
            kCFPreferencesCurrentHost
        )
    }

    private func asInt(_ value: CFPropertyList) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    private func asBool(_ value: CFPropertyList) -> Bool? {
        if let n = value as? NSNumber { return n.boolValue }
        if let s = value as? String {
            if let i = Int(s) { return i != 0 }
            switch s.lowercased() {
            case "true", "yes": return true
            case "false", "no": return false
            default: return nil
            }
        }
        return nil
    }
}
