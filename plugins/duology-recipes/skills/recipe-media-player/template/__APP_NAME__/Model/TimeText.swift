import Foundation

/// Times as people read them on a player: "0:07", "12:45", "1:02:03".
nonisolated enum TimeText {
    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 {
            return "\(hours):" + twoDigits(minutes) + ":" + twoDigits(rest)
        }
        return "\(minutes):" + twoDigits(rest)
    }

    /// "−0:05": the time left, for the right end of the scrubber.
    static func remaining(_ position: Double, of duration: Double) -> String {
        "−" + clock(max(0, duration - position))
    }

    /// For VoiceOver and the library: "12 seconds", "4 minutes", "1 hour 5 minutes".
    static func spoken(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded())
        if total < 60 { return total == 1 ? "1 second" : "\(total) seconds" }
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        var parts: [String] = []
        if hours > 0 { parts.append(hours == 1 ? "1 hour" : "\(hours) hours") }
        if minutes > 0 { parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes") }
        return parts.joined(separator: " ")
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
