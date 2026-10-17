// Engine tests. They build __APP_NAME__/Engine/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-engine-tests.sh
import Foundation

var failures = 0
var passes = 0

func check(_ ok: Bool, _ message: String) {
    if ok {
        passes += 1
        print("ok   \(message)")
    } else {
        failures += 1
        print("FAIL \(message)")
    }
}

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

/// A duel that is already playing, with no countdown and no time limit.
func playing(goal: Int = 3, lockout: TimeInterval = 1, seed: UInt64 = 7) -> Duel {
    var rules = DuelRules()
    rules.goal = goal
    rules.countdown = 0
    rules.missLockout = lockout
    rules.timeLimit = nil
    var duel = Duel(rules: rules, seed: seed)
    duel.toggleReady(.one, now: t0)
    duel.toggleReady(.two, now: t0)
    return duel
}

/// A half's play area, roughly the size of one player's half on the inner display.
let area = GameRect(x: 12, y: 12, width: 450, height: 590)

func centre(_ duel: Duel, _ player: Player, in rect: GameRect = area) -> GamePoint {
    duel.target(for: player, in: rect)?.center ?? GamePoint(x: -1000, y: -1000)
}

/// A point inside `rect` that is far from the player's target.
func away(_ duel: Duel, _ player: Player, in rect: GameRect = area) -> GamePoint {
    let c = centre(duel, player, in: rect)
    return GamePoint(x: c.x < rect.midX ? rect.maxX - 1 : rect.minX + 1,
                   y: c.y < rect.midY ? rect.maxY - 1 : rect.minY + 1)
}

// MARK: Spots

let a = Duel.makeSpots(count: 20, seed: 42)
check(a == Duel.makeSpots(count: 20, seed: 42), "the same seed gives the same spots")
check(a != Duel.makeSpots(count: 20, seed: 43), "another seed gives other spots")
check(a.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) }, "spots are fractions of the play area")
let jumps = zip([Spot(x: 0.5, y: 0.5)] + a, a).map { hypot($1.x - $0.x, $1.y - $0.y) }
check(jumps.allSatisfy { $0 >= 0.35 }, "every spot is at least 0.35 from the one before")

// MARK: Target size and position

let rules = DuelRules()
let small = GameRect(x: 0, y: 0, width: 440, height: 250)       // a closed-phone half, minus the score bar
let big = GameRect(x: 0, y: 0, width: 450, height: 590)         // an open-phone half
for (name, rect) in [("small half", small), ("big half", big)] {
    let circles = a.compactMap { $0.circle(in: rect, rules: rules) }
    check(circles.count == a.count, "\(name): every spot gives a target")
    check(circles.allSatisfy { $0.radius * 2 >= 44 }, "\(name): targets are at least 44 pt across")
    check(circles.allSatisfy { rect.contains($0.bounds) }, "\(name): the whole target stays inside the play area")
}
let corner = Spot(x: 1, y: 1).circle(in: GameRect(x: 100, y: 50, width: 300, height: 200), rules: rules)
check(corner?.center == GamePoint(x: 400 - 28, y: 250 - 28), "a spot maps into the area's own coordinates")
check(Spot(x: 0.5, y: 0.5).circle(in: .zero, rules: rules) == nil, "no target in an empty area")
let tiny = Spot(x: 0.5, y: 0.5).circle(in: GameRect(x: 0, y: 0, width: 40, height: 300), rules: rules)
check(tiny?.radius == 20, "in a sliver the target shrinks to fit rather than spill out")

// MARK: Ready, countdown, gating

var duel = Duel(rules: DuelRules(), seed: 1)
check(duel.tap(.one, at: .zero, in: area, now: t0) == .ignored, "taps before the round do nothing")
duel.toggleReady(.one, now: t0)
check(duel.phase == .waiting && duel[.one].isReady, "one player ready: still waiting")
duel.toggleReady(.one, now: t0)
check(!duel[.one].isReady, "tapping Ready again takes it back")
duel.toggleReady(.one, now: t0)
duel.toggleReady(.two, now: t0)
check(duel.phase == .countdown(endsAt: at(3)), "both ready: the countdown starts")
check(duel.round == 1, "that is round 1")
check([0, 0.5, 1.2, 2.9].map { duel.countdownRemaining(now: at($0)) } == [3, 3, 2, 1], "countdown shows 3, 3, 2, 1")
check(duel.spot(for: .one) == nil, "no target during the countdown")
check(duel.tap(.one, at: .zero, in: area, now: at(1)) == .ignored, "taps during the countdown do nothing")
check(duel[.one].misses == 0, "and are not counted as misses")
duel.tick(now: at(2.99))
check(duel.countdownRemaining(now: at(2.99)) == 1, "still counting just before the end")
duel.tick(now: at(3))
check(duel.phase == .playing(startedAt: at(3)), "the round starts when the countdown ends")
check(duel.spot(for: .one) == duel.spot(for: .two), "both players chase the same spot")
check(duel.timeRemaining(now: at(13)) == 50, "a 60 s round has 50 s left after 10 s")

// MARK: Hits, misses, lockout

duel = playing(goal: 3, lockout: 1)
let first = duel.spot(for: .one)
check(duel.tap(.one, at: centre(duel, .one), in: area, now: at(0.1)) == .hit, "a tap on the target is a hit")
check(duel[.one].hits == 1 && duel.spot(for: .one) != first, "the hit counts and the target moves")
check(duel.spot(for: .two) == first, "the other player still has their first target")

let edge = duel.target(for: .one, in: area)!
let justIn = GamePoint(x: edge.center.x + edge.radius + rules.hitSlop - 1, y: edge.center.y)
let justOut = GamePoint(x: edge.center.x + edge.radius + rules.hitSlop + 1, y: edge.center.y)
var probe = duel
check(probe.tap(.one, at: justIn, in: area, now: at(0.2)) == .hit, "a touch just outside the edge still counts")
probe = duel
check(probe.tap(.one, at: justOut, in: area, now: at(0.2)) == .miss, "a touch beyond the slop is a miss")

check(duel.tap(.one, at: away(duel, .one), in: area, now: at(1)) == .miss, "a tap off the target is a miss")
check(duel[.one].misses == 1 && duel.isLocked(.one, now: at(1.5)), "a miss locks that player out")
check(!duel.canTap(.one, now: at(1.5)), "a locked player can't score")
check(duel.tap(.one, at: centre(duel, .one), in: area, now: at(1.5)) == .ignored, "a hit during the lockout is ignored")
check(duel.canTap(.two, now: at(1.5)), "the other player is not locked")
check(duel.tap(.two, at: centre(duel, .two), in: area, now: at(1.5)) == .hit, "and can still score")
check(!duel.isLocked(.one, now: at(2)), "the lockout ends on time")
check(duel.tap(.one, at: centre(duel, .one), in: area, now: at(2)) == .hit, "then taps count again")

// MARK: Winning and rematch

check(duel.tap(.one, at: centre(duel, .one), in: area, now: at(2.5)) == .won, "the hit that reaches the goal wins")
check(duel.outcome == .won(.one), "player one wins")
check(duel.tap(.two, at: centre(duel, .two), in: area, now: at(2.6)) == .ignored, "no taps count after the win")
check(duel[.one].hits == 3 && duel[.two].hits == 1, "the scores stay for the winner screen")
let roundOneSpots = Duel.makeSpots(count: 3, seed: 7 &+ 1)
duel.toggleReady(.one, now: at(5))
check(duel.outcome == .won(.one) && duel[.one].isReady, "rematch waits for both players")
duel.toggleReady(.two, now: at(5))
check(duel.round == 2 && duel[.one].hits == 0 && duel[.two].hits == 0, "rematch resets both scores")
check(duel.spot(for: .one) != roundOneSpots.first, "rematch gives new targets")

// MARK: Time limit

var timed = DuelRules()
timed.countdown = 1
timed.timeLimit = 10
duel = Duel(rules: timed, seed: 3)
duel.toggleReady(.one, now: t0)
duel.toggleReady(.two, now: t0)
duel.tick(now: at(1))
duel.tap(.two, at: centre(duel, .two), in: area, now: at(2))
duel.tick(now: at(10.9))
check(duel.outcome == nil, "the round runs for the whole limit")
duel.tick(now: at(11))
check(duel.outcome == .won(.two), "time up: more hits wins")
duel = Duel(rules: timed, seed: 3)
duel.toggleReady(.one, now: t0)
duel.toggleReady(.two, now: t0)
duel.tick(now: at(30))
check(duel.outcome == .tie, "time up with equal hits: a tie, even if no tick came in between")

duel.reset()
check(duel.phase == .waiting && duel.round == 0 && !duel[.one].isReady, "reset goes back to the start")

// MARK: Each half has its own coordinates

let left = GameRect(x: 12, y: 12, width: 450, height: 590)
let top = GameRect(x: 12, y: 12, width: 640, height: 260)
duel = playing(goal: 5)
for (name, rect) in [("side by side", left), ("stacked", top)] {
    var copy = duel
    check(copy.tap(.one, at: centre(copy, .one, in: rect), in: rect, now: at(0.1)) == .hit,
          "\(name): a hit is judged in the half's own coordinates")
}

// MARK: Play area

let half = GameRect(x: 0, y: 0, width: 475, height: 613)
check(PlayArea.fit(half, avoiding: [], margin: 12) == half.insetBy(dx: 12, dy: 12), "no fold: the half minus a margin")
let foldOnRight = GameRect(x: 455, y: 0, width: 20, height: 613)
let byFold = PlayArea.fit(half, avoiding: [foldOnRight], margin: 12)
check(byFold.maxX <= 455 - 12 && byFold.width > 400, "a fold on the half's edge pushes targets away from it")
let foldAcross = GameRect(x: 0, y: 250, width: 475, height: 20)   // nearer the top
let byFoldAcross = PlayArea.fit(half, avoiding: [foldAcross], margin: 12)
check(byFoldAcross.minY >= 270 + 12 && byFoldAcross.maxY <= 613 - 12, "a fold across the half keeps the bigger side")
check(PlayArea.fit(half, avoiding: [GameRect(x: 600, y: 0, width: 20, height: 20)], margin: 12)
      == half.insetBy(dx: 12, dy: 12), "a region outside the half changes nothing")
check(PlayArea.fit(GameRect(x: 0, y: 0, width: 20, height: 20), avoiding: [], margin: 12) == .zero,
      "a half smaller than its margins has no play area")
check(PlayArea.fit(half, avoiding: [half], margin: 12) == .zero, "a region covering everything leaves nothing")

// MARK: Off the main actor

// The build uses -default-isolation MainActor, like the app. If an engine type lost its
// `nonisolated`, this detached task would stop compiling.
let fromBackground = await Task.detached { () -> Int in
    var quick = DuelRules()
    quick.countdown = 0
    quick.timeLimit = nil
    var background = Duel(rules: quick, seed: 9)
    let now = Date()
    background.toggleReady(.one, now: now)
    background.toggleReady(.two, now: now)
    let rect = GameRect(x: 0, y: 0, width: 300, height: 300)
    guard let target = background.target(for: .two, in: rect) else { return -1 }
    background.tap(.two, at: target.center, in: rect, now: now)
    return background[.two].hits
}.value
check(fromBackground == 1, "the engine runs off the main actor")

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
