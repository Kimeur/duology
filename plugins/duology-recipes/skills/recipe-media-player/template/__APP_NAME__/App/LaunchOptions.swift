import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting          animations off, test markers on
///   -resetState         forget saved positions and finished episodes
///   -select ID          select an episode in the library
///   -play ID            open the player on an episode and start it
///   -paused             with -play: open it paused
///   -start S            with -play: start S seconds in
///   -miniPlayer         with -play: stay in the library, with the mini player
///   -upNextLead S       show the up next card S seconds before the end
///   -autoplay 0|1       start the next episode on its own (default 1)
///   -loop               replay the current episode at its end, for pose screenshots
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var resetsState: Bool { arguments.contains("-resetState") }
    static var loops: Bool { arguments.contains("-loop") }

    static var selection: Episode.ID? { value("-select") ?? value("-play") }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        if resetsState, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
    }

    /// Applies the switches to a new player: policy first, then the episode to open.
    static func apply(to player: PlayerModel) {
        if let lead = number("-upNextLead") { player.upNextPolicy.lead = max(0, lead) }
        if let autoplay = number("-autoplay") { player.upNextPolicy.autoplay = autoplay != 0 }
        player.loops = loops
        guard let id = value("-play"), let episode = player.catalog.episode(id) else { return }
        player.play(episode, from: number("-start"), startPaused: arguments.contains("-paused"))
        player.isPlayerPresented = !arguments.contains("-miniPlayer")
    }

    /// The word after the last `name`, so a later switch overrides an earlier one.
    private static func value(_ name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static func number(_ name: String) -> Double? {
        value(name).flatMap(Double.init)
    }
}
