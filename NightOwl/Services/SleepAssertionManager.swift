import Foundation
import IOKit
import IOKit.pwr_mgt
import os

final class SleepAssertionManager {
    enum AssertionError: Error {
        case systemAssertionFailed(IOReturn)
        case displayAssertionFailed(IOReturn)
    }

    private let logger = Logger(subsystem: "com.nightowl", category: "SleepAssertion")
    private var systemAssertionID: IOPMAssertionID?
    private var displayAssertionID: IOPMAssertionID?

    var isActive: Bool {
        systemAssertionID != nil || displayAssertionID != nil
    }

    func assert(preventDisplaySleep: Bool) throws {
        release()

        var sysID: IOPMAssertionID = 0
        let sysResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NightOwl keep-awake" as CFString,
            &sysID
        )
        guard sysResult == kIOReturnSuccess else {
            logger.error("System assertion failed: \(sysResult, privacy: .public)")
            throw AssertionError.systemAssertionFailed(sysResult)
        }
        systemAssertionID = sysID

        if preventDisplaySleep {
            var dispID: IOPMAssertionID = 0
            let dispResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NightOwl keep-display-awake" as CFString,
                &dispID
            )
            guard dispResult == kIOReturnSuccess else {
                IOPMAssertionRelease(sysID)
                systemAssertionID = nil
                logger.error("Display assertion failed: \(dispResult, privacy: .public)")
                throw AssertionError.displayAssertionFailed(dispResult)
            }
            displayAssertionID = dispID
        }
    }

    func release() {
        if let id = systemAssertionID {
            IOPMAssertionRelease(id)
            systemAssertionID = nil
        }
        if let id = displayAssertionID {
            IOPMAssertionRelease(id)
            displayAssertionID = nil
        }
    }

    deinit {
        release()
    }
}
