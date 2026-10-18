import Foundation

// The game rules. Foundation only and nonisolated, so this folder builds and runs
// on the Mac without a simulator (Tools/run-engine-tests.sh) and can run off the
// main actor. The views never decide who scored: they pass touches in here.

/// The two people sharing the phone. Player one owns the first half: the top one when
/// stacked, the left one side by side, in every language.
nonisolated enum Player: Int, CaseIterable, Hashable, Sendable {
    case one = 1
    case two = 2

    var other: Player { self == .one ? .two : .one }
    /// Short id for accessibility identifiers and coordinate space names: "p1", "p2".
    var id: String { "p\(rawValue)" }
    var name: String { "Player \(rawValue)" }

    /// Clockwise quarter turns for this player's half. Face to face, the phone lies flat
    /// with one player at each far edge, so each half turns until its top edge sits on
    /// the seam between the halves. Same numbers as duo-shared-screen's Facing.
    func quarterTurns(faceToFace: Bool, sideBySide: Bool) -> Int {
        guard faceToFace else { return 0 }
        switch (self, sideBySide) {
        case (.one, false): return 2    // top half: upside down
        case (.two, false): return 0    // bottom half: as is
        case (.one, true): return 1     // left half: top edge to the right
        case (.two, true): return 3     // right half: top edge to the left
        }
    }
}

/// The settings of one duel. Plain values, so tests and launch options can change them.
nonisolated struct DuelRules: Equatable, Sendable {
    /// Hits needed to win.
    var goal = 10
    /// Seconds of "3, 2, 1" before targets appear. Taps do nothing until it ends.
    var countdown: TimeInterval = 3
    /// After a miss, that player can't score for this long. The other player can.
    var missLockout: TimeInterval = 0.6
    /// The round ends after this long and the most hits wins. `nil` means first to `goal`, however long it takes.
    var timeLimit: TimeInterval? = 60
    /// Target radius as a share of the play area's shorter side.
    var targetShare = 0.1
    /// Smallest target radius in points. 28 pt makes a 56 pt target, above the 44 pt minimum.
    var minTargetRadius = 28.0
    /// A touch this close to the edge of a target still counts, in points.
    var hitSlop = 6.0
}

/// One player's score and input state.
nonisolated struct PlayerState: Equatable, Sendable {
    var hits = 0
    var misses = 0
    var isReady = false
    var lockedUntil: Date?
}

nonisolated enum Outcome: Equatable, Sendable {
    case won(Player)
    case tie
}

nonisolated enum Phase: Equatable, Sendable {
    /// Both players tap Ready to start.
    case waiting
    /// "3, 2, 1". Taps are ignored until `endsAt`.
    case countdown(endsAt: Date)
    /// Targets are live.
    case playing(startedAt: Date)
    /// Round over. Both players tap Rematch to play again.
    case finished(Outcome)
}

nonisolated enum TapResult: Equatable, Sendable {
    case hit
    case miss
    /// The hit that reached the goal.
    case won
    /// Not counted: countdown, round over, or the player is locked out after a miss.
    case ignored
}

/// Where a target sits, as fractions (0...1) of a play area. Both players chase the
/// same sequence of spots, each in their own half, so the race is fair in any layout.
nonisolated struct Spot: Equatable, Sendable {
    var x: Double
    var y: Double

    /// The target's circle inside `area`. The whole circle stays inside the area,
    /// so a target never sits under the fold or a camera when the area avoids them.
    func circle(in area: GameRect, rules: DuelRules) -> TargetCircle? {
        let short = area.shortSide
        guard short > 0 else { return nil }
        let radius = min(max(rules.minTargetRadius, rules.targetShare * short), short / 2)
        let inner = area.insetBy(dx: radius, dy: radius)
        let center = GamePoint(x: inner.minX + x * inner.width, y: inner.minY + y * inner.height)
        return TargetCircle(center: center, radius: radius)
    }
}

nonisolated struct TargetCircle: Equatable, Sendable {
    var center: GamePoint
    var radius: Double

    func contains(_ point: GamePoint, slop: Double = 0) -> Bool {
        point.distance(to: center) <= radius + slop
    }

    /// The square the circle sits in.
    var bounds: GameRect {
        GameRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

/// A two-player race: tap your targets, first to `rules.goal` wins.
nonisolated struct Duel: Equatable, Sendable {
    private(set) var rules: DuelRules
    private(set) var seed: UInt64
    /// 0 before the first round, then 1, 2, 3...
    private(set) var round = 0
    private(set) var phase: Phase = .waiting
    private var states: [Player: PlayerState] = [.one: PlayerState(), .two: PlayerState()]
    private var spots: [Spot] = []

    init(rules: DuelRules = DuelRules(), seed: UInt64) {
        self.rules = rules
        self.seed = seed
    }

    subscript(player: Player) -> PlayerState {
        states[player] ?? PlayerState()
    }

    var outcome: Outcome? {
        if case .finished(let outcome) = phase { return outcome }
        return nil
    }

    // MARK: Ready and rematch

    /// Marks a player ready, or not ready if they tap again. When both are ready,
    /// a new round starts with its countdown. This is also how Rematch works.
    mutating func toggleReady(_ player: Player, now: Date) {
        switch phase {
        case .waiting, .finished:
            states[player, default: PlayerState()].isReady.toggle()
            if Player.allCases.allSatisfy({ self[$0].isReady }) {
                startRound(now: now)
            }
        case .countdown, .playing:
            return
        }
    }

    /// Back to the start screen state, for leaving the game.
    mutating func reset() {
        phase = .waiting
        round = 0
        spots = []
        for player in Player.allCases { states[player] = PlayerState() }
    }

    private mutating func startRound(now: Date) {
        round += 1
        spots = Self.makeSpots(count: rules.goal, seed: seed &+ UInt64(round))
        for player in Player.allCases { states[player] = PlayerState() }
        phase = rules.countdown > 0
            ? .countdown(endsAt: now.addingTimeInterval(rules.countdown))
            : .playing(startedAt: now)
    }

    // MARK: Clock

    /// Moves from countdown to playing, and ends the round when time runs out.
    /// Call it often (the app does, ten times a second). Taps call it too.
    mutating func tick(now: Date) {
        switch phase {
        case .countdown(let endsAt) where now >= endsAt:
            phase = .playing(startedAt: endsAt)
            tick(now: now)
        case .playing(let startedAt):
            if let limit = rules.timeLimit, now >= startedAt.addingTimeInterval(limit) {
                let one = self[.one].hits
                let two = self[.two].hits
                phase = .finished(one == two ? .tie : .won(one > two ? .one : .two))
            }
        default:
            break
        }
    }

    /// Whole seconds left in the countdown, rounded up (3, 2, 1), or nil outside it.
    func countdownRemaining(now: Date) -> Int? {
        guard case .countdown(let endsAt) = phase else { return nil }
        return max(1, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    /// Time left in the round, or nil when there is no limit or no round running.
    func timeRemaining(now: Date) -> TimeInterval? {
        guard case .playing(let startedAt) = phase, let limit = rules.timeLimit else { return nil }
        return max(0, limit - now.timeIntervalSince(startedAt))
    }

    // MARK: Input gating

    /// Whether a tap from this player can count right now.
    func canTap(_ player: Player, now: Date) -> Bool {
        guard case .playing = phase else { return false }
        return !isLocked(player, now: now)
    }

    func isLocked(_ player: Player, now: Date) -> Bool {
        guard case .playing = phase, let until = self[player].lockedUntil else { return false }
        return now < until
    }

    /// The player's current target as fractions of their play area.
    func spot(for player: Player) -> Spot? {
        guard case .playing = phase else { return nil }
        let hits = self[player].hits
        return hits < spots.count ? spots[hits] : nil
    }

    /// The player's current target inside `area`, in the coordinates of their own half.
    func target(for player: Player, in area: GameRect) -> TargetCircle? {
        spot(for: player)?.circle(in: area, rules: rules)
    }

    /// A touch from `player` at `point`. `point` and `area` are in the same coordinates:
    /// the player's own half. Any touch off the target is a miss.
    @discardableResult
    mutating func tap(_ player: Player, at point: GamePoint, in area: GameRect, now: Date) -> TapResult {
        tick(now: now)
        guard canTap(player, now: now), let target = target(for: player, in: area) else { return .ignored }
        var state = self[player]
        guard target.contains(point, slop: rules.hitSlop) else {
            state.misses += 1
            state.lockedUntil = now.addingTimeInterval(rules.missLockout)
            states[player] = state
            return .miss
        }
        state.hits += 1
        state.lockedUntil = nil
        states[player] = state
        if state.hits >= rules.goal {
            phase = .finished(.won(player))
            return .won
        }
        return .hit
    }

    // MARK: Targets

    /// The same seed always gives the same spots. Each spot is at least 0.35 away
    /// from the one before, so every hit means moving to a new place.
    static func makeSpots(count: Int, seed: UInt64) -> [Spot] {
        var generator = SeededGenerator(seed: seed)
        var spots: [Spot] = []
        var last = Spot(x: 0.5, y: 0.5)
        var attempts = 0
        while spots.count < count {
            let spot = Spot(x: Double.random(in: 0...1, using: &generator),
                            y: Double.random(in: 0...1, using: &generator))
            attempts += 1
            if hypot(spot.x - last.x, spot.y - last.y) >= 0.35 || attempts > 50 {
                spots.append(spot)
                last = spot
                attempts = 0
            }
        }
        return spots
    }
}

/// SplitMix64: small, fast and the same on every platform, so a seed replays a game exactly.
nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
