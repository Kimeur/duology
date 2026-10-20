import Foundation

/// What plays now and what plays next, as episode IDs.
///
/// Playing an episode starts a new queue: that episode, then the rest of its show.
nonisolated struct PlaybackQueue: Equatable, Sendable {
    private(set) var items: [Episode.ID] = []
    private(set) var index: Int?

    var current: Episode.ID? {
        index.map { items[$0] }
    }

    /// The episode after the current one, if any.
    var next: Episode.ID? {
        guard let index, index + 1 < items.count else { return nil }
        return items[index + 1]
    }

    var previous: Episode.ID? {
        guard let index, index > 0 else { return nil }
        return items[index - 1]
    }

    /// Starts `first`, then plays `then` in order. Duplicates of `first` are dropped.
    mutating func start(_ first: Episode.ID, then: [Episode.ID]) {
        var seen: Set<Episode.ID> = [first]
        items = [first] + then.filter { seen.insert($0).inserted }
        index = 0
    }

    /// Moves to the next episode and returns it. At the end, nothing changes.
    @discardableResult
    mutating func advance() -> Episode.ID? {
        guard let index, index + 1 < items.count else { return nil }
        self.index = index + 1
        return current
    }

    /// Moves to the episode before. At the start, nothing changes.
    @discardableResult
    mutating func goBack() -> Episode.ID? {
        guard let index, index > 0 else { return nil }
        self.index = index - 1
        return current
    }

    mutating func clear() {
        items = []
        index = nil
    }
}
