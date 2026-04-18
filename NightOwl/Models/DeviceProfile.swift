import Foundation

enum DeviceProfile: Equatable, Sendable {
    case portable(hasBattery: Bool)
    case desktop

    var isPortable: Bool {
        if case .portable = self { return true }
        return false
    }
}
