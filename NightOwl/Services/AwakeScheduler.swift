import Foundation
import os

@MainActor
final class AwakeScheduler {
    private let log = Logger(subsystem: "com.nightowl", category: "AwakeScheduler")
    private var timer: DispatchSourceTimer?

    func schedule(expiresAt: Date, onExpire: @escaping () -> Void) {
        cancel()

        let interval = max(0, expiresAt.timeIntervalSinceNow)
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(
            deadline: .now() + interval,
            repeating: .never,
            leeway: .milliseconds(250)
        )

        var fired = false
        source.setEventHandler { [weak self] in
            guard !fired else { return }
            fired = true
            self?.timer = nil
            self?.log.info("AwakeScheduler fired")
            onExpire()
        }

        timer = source
        source.resume()
        log.info("AwakeScheduler scheduled for \(expiresAt, privacy: .public) (in \(interval, privacy: .public)s)")
    }

    func cancel() {
        guard let timer else { return }
        timer.cancel()
        self.timer = nil
        log.debug("AwakeScheduler cancelled")
    }
}
