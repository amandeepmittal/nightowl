import Foundation
import IOKit.ps
import Darwin
import os

final class DeviceProfileService {
    private let logger = Logger(subsystem: "com.nightowl", category: "DeviceProfile")

    func current() -> DeviceProfile {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return .desktop
        }

        let isPresent = (info[kIOPSIsPresentKey as String] as? Bool) ?? false
        return .portable(hasBattery: isPresent)
    }

    func modelDisplayName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }

        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        let identifier = String(cString: buffer)

        switch identifier {
        case let id where id.hasPrefix("MacBookPro"): return "MacBook Pro"
        case let id where id.hasPrefix("MacBookAir"): return "MacBook Air"
        case let id where id.hasPrefix("MacBook"):    return "MacBook"
        case let id where id.hasPrefix("Macmini"):    return "Mac mini"
        case let id where id.hasPrefix("MacStudio"):  return "Mac Studio"
        case let id where id.hasPrefix("MacPro"):     return "Mac Pro"
        case let id where id.hasPrefix("iMac"):       return "iMac"
        case "Mac15,11", "Mac15,9", "Mac15,7", "Mac15,6", "Mac15,3":
            return "MacBook Pro"
        case "Mac15,12", "Mac15,13", "Mac14,15", "Mac14,2":
            return "MacBook Air"
        case "Mac14,3", "Mac14,12":
            return "Mac mini"
        case "Mac14,13", "Mac14,14":
            return "Mac Studio"
        case "Mac14,8":
            return "Mac Pro"
        default:
            return identifier
        }
    }
}
