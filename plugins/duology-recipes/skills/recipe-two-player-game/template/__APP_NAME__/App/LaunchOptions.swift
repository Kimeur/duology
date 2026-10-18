import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting      animations off
///   -openDuel       skip the home screen
///   -autoReady      with -openDuel: both players ready, so the round starts at once
///   -faceToFace     turn each half to face its player, for a phone lying flat between two people
///   -goal N         hits to win
///   -countdown N    countdown seconds (0 starts at once)
///   -lockout N      seconds a miss locks that player out
///   -timeLimit N    round length in seconds (0 means no limit)
///   -seed N         fixed target positions, so a test replays the same game
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var opensDuel: Bool { arguments.contains("-openDuel") }

    /// The duel to open at launch, if -openDuel is set.
    static func launchDuel() -> DuelModel? {
        guard opensDuel else { return nil }
        let model = DuelModel(setup: setup())
        if arguments.contains("-autoReady") {
            model.toggleReady(.one)
            model.toggleReady(.two)
        }
        return model
    }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    /// The home screen's starting setup, with any switches applied.
    static func setup() -> DuelSetup {
        var setup = DuelSetup()
        if arguments.contains("-faceToFace") { setup.faceToFace = true }
        if let goal = number("-goal") { setup.rules.goal = max(1, Int(goal)) }
        if let countdown = number("-countdown") { setup.rules.countdown = max(0, countdown) }
        if let lockout = number("-lockout") { setup.rules.missLockout = max(0, lockout) }
        if let limit = number("-timeLimit") { setup.rules.timeLimit = limit > 0 ? limit : nil }
        if let seed = number("-seed") { setup.seed = UInt64(max(0, seed)) }
        return setup
    }

    /// The value after the last `name`, so a later switch overrides an earlier one.
    private static func number(_ name: String) -> Double? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return Double(arguments[index + 1])
    }
}
