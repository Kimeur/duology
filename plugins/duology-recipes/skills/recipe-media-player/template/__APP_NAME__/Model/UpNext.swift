import Foundation

/// When the "up next" card shows, and when the next episode starts on its own.
nonisolated struct UpNextPolicy: Equatable, Sendable {
    /// Seconds before the end that the card appears. Never more than half the episode,
    /// so a short clip still plays a while before the card covers anything.
    var lead: Double = 10
    /// Start the next episode when this one ends. Off: the card waits for a tap.
    var autoplay = true

    /// The lead time for an episode of this length.
    func lead(for duration: Double) -> Double {
        max(0, min(lead, duration / 2))
    }

    /// What the card shows at `position` in an episode of `duration` seconds.
    /// `dismissed` is true once the person closed the card for this episode.
    func card(position: Double, duration: Double, hasNext: Bool, dismissed: Bool) -> UpNextState {
        guard hasNext, !dismissed, duration > 0, position >= 0 else { return .hidden }
        let remaining = max(0, duration - position)
        guard remaining <= lead(for: duration) else { return .hidden }
        guard autoplay else { return .waiting }
        return .counting(Int(remaining.rounded(.up)))
    }

    /// True when the player should move to the next episode by itself.
    func shouldAdvance(position: Double, duration: Double, hasNext: Bool, dismissed: Bool) -> Bool {
        autoplay && hasNext && !dismissed && duration > 0 && position >= duration - 0.25
    }
}

nonisolated enum UpNextState: Equatable, Sendable {
    case hidden
    /// Autoplay is on: the next episode starts in this many seconds.
    case counting(Int)
    /// Autoplay is off: the card offers the next episode and waits.
    case waiting

    var isVisible: Bool { self != .hidden }
}
