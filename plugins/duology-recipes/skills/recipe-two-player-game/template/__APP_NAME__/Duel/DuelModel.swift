import Foundation
import Observation

/// Holds one duel for the views and runs its clock. The rules live in `Duel`
/// (Engine/); this class only adds the current time and haptic triggers.
@Observable
final class DuelModel {
    private(set) var duel: Duel
    /// The time the views draw with. Updated by the clock and by every touch.
    private(set) var now = Date()
    let faceToFace: Bool
    /// Bumped on every hit and every miss, to trigger each half's own haptics.
    private(set) var hitCount: [Player: Int] = [:]
    private(set) var missCount: [Player: Int] = [:]

    init(setup: DuelSetup) {
        duel = Duel(rules: setup.rules, seed: setup.seed ?? UInt64.random(in: 0...UInt64.max))
        faceToFace = setup.faceToFace
    }

    func toggleReady(_ player: Player) {
        now = Date()
        duel.toggleReady(player, now: now)
    }

    /// A touch in `player`'s half. `point` and `area` are in that half's own coordinate space.
    func tap(_ player: Player, at point: GamePoint, in area: GameRect) {
        now = Date()
        switch duel.tap(player, at: point, in: area, now: now) {
        case .hit, .won: hitCount[player, default: 0] += 1
        case .miss: missCount[player, default: 0] += 1
        case .ignored: break
        }
    }

    /// VoiceOver and Switch Control: activating the target counts as a tap on its centre.
    func activateTarget(_ player: Player, in area: GameRect) {
        guard let target = duel.target(for: player, in: area) else { return }
        tap(player, at: target.center, in: area)
    }

    func tick() {
        now = Date()
        var next = duel
        next.tick(now: now)
        if next != duel { duel = next }
    }

    /// Ticks ten times a second until the view that started it goes away.
    func runClock() async {
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
