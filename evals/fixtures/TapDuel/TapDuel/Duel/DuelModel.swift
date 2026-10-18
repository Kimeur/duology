import Observation

enum Seat: String, CaseIterable, Identifiable, Sendable {
    case first
    case second

    var id: String { rawValue }
    var title: String { self == .first ? "Player 1" : "Player 2" }
}

/// First player to reach the goal wins.
@Observable
final class DuelModel {
    let goal: Int
    private(set) var taps: [Seat: Int] = [.first: 0, .second: 0]
    private(set) var winner: Seat?

    init(goal: Int = 20) {
        self.goal = goal
    }

    func count(for seat: Seat) -> Int {
        taps[seat, default: 0]
    }

    func tap(_ seat: Seat) {
        guard winner == nil else { return }
        taps[seat, default: 0] += 1
        if count(for: seat) >= goal {
            winner = seat
        }
    }

    func reset() {
        taps = [.first: 0, .second: 0]
        winner = nil
    }
}
