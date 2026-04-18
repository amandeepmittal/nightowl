import Foundation
import IOKit.ps
import os

final class PowerStateMonitor {
    enum Source {
        case ac
        case battery
        case unknown
    }

    private let logger = Logger(subsystem: "com.nightowl", category: "PowerState")
    private var runLoopSource: CFRunLoopSource?
    private var callback: ((Source) -> Void)?

    func currentSource() -> Source {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let typeRef = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else {
            return .unknown
        }
        let type = typeRef as String
        switch type {
        case kIOPMACPowerKey:
            return .ac
        case kIOPMBatteryPowerKey:
            return .battery
        default:
            return .unknown
        }
    }

    func observe(_ callback: @escaping (Source) -> Void) {
        self.callback = callback

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(ctx).takeUnretainedValue()
            let current = monitor.currentSource()
            DispatchQueue.main.async {
                monitor.callback?(current)
            }
        }, context)?.takeRetainedValue() else {
            logger.error("IOPSNotificationCreateRunLoopSource returned nil")
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
}
