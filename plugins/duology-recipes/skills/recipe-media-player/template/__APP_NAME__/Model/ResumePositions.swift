import Foundation

/// Where each episode stopped, and which ones are finished. Saved as JSON.
nonisolated struct ResumePositions: Codable, Equatable, Sendable {
    /// Closer to the start than this, an episode counts as not started.
    static let startSlack: Double = 2
    /// Closer to the end than this (seconds, or 3 percent of the episode, whichever
    /// is larger), an episode counts as finished.
    static let endSlack: Double = 2

    private(set) var seconds: [Episode.ID: Double] = [:]
    private(set) var finished: Set<Episode.ID> = []

    /// Records how far someone got. Near the start, forgets the position; near the
    /// end, marks the episode finished, so the next play starts from the top.
    mutating func record(_ id: Episode.ID, at position: Double, duration: Double) {
        guard duration > 0, position.isFinite else { return }
        let endSlack = max(Self.endSlack, duration * 0.03)
        if position >= duration - endSlack {
            seconds[id] = nil
            finished.insert(id)
        } else if position < Self.startSlack {
            seconds[id] = nil
        } else {
            seconds[id] = position
            finished.remove(id)
        }
    }

    /// Where to start this episode: the saved position, or 0.
    func resume(_ id: Episode.ID) -> Double {
        seconds[id] ?? 0
    }

    func isFinished(_ id: Episode.ID) -> Bool {
        finished.contains(id)
    }

    /// How far through, from 0 to 1. Finished episodes report 1.
    func progress(_ id: Episode.ID, duration: Double) -> Double {
        if finished.contains(id) { return 1 }
        guard duration > 0, let position = seconds[id] else { return 0 }
        return min(1, max(0, position / duration))
    }

    mutating func forget(_ id: Episode.ID) {
        seconds[id] = nil
        finished.remove(id)
    }
}
