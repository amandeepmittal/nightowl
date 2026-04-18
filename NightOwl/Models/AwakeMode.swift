import Foundation

enum AwakeMode: Equatable, Sendable {
    case indefinite
    case until(Date)
    case duration(TimeInterval)

    func expiresAt(now: Date) -> Date? {
        switch self {
        case .indefinite:
            return nil
        case .until(let date):
            return date
        case .duration(let interval):
            return now.addingTimeInterval(interval)
        }
    }

    var displayLabel: String {
        switch self {
        case .indefinite:
            return "Indefinite"

        case .until(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Until \(formatter.string(from: date))"

        case .duration(let interval):
            return Self.formatDuration(interval)
        }
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval.rounded())

        if totalSeconds < 60 {
            let s = max(totalSeconds, 0)
            return s == 1 ? "For 1 second" : "For \(s) seconds"
        }

        let totalMinutes = totalSeconds / 60
        if totalMinutes < 60 {
            return totalMinutes == 1 ? "For 1 minute" : "For \(totalMinutes) minutes"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if minutes == 0 {
            return hours == 1 ? "For 1 hour" : "For \(hours) hours"
        }

        let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
        let minutePart = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return "For \(hourPart) \(minutePart)"
    }
}
