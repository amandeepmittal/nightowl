import Foundation

enum AwakeState: Equatable, Sendable {
    case off
    case on(mode: AwakeMode, startedAt: Date, expiresAt: Date?, keepDisplayAwake: Bool)

    var isOn: Bool {
        if case .on = self { return true }
        return false
    }
}
