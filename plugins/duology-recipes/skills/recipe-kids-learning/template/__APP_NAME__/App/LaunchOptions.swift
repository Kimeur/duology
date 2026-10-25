import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting          animations off, speech muted (what would be said is still recorded),
///                       test markers on
///   -resetState         forget the stars, where each activity is, and the settings
///   -open ID            open an activity: counting, letters or shapes
///   -question N         with -open: start at this question (0 is the first)
///   -gateSeed N         the parental gate's questions come from this seed, so they repeat
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var resetsState: Bool { arguments.contains("-resetState") }

    /// The seed for the parental gate: -gateSeed in tests, otherwise a new one each launch.
    static var gateSeed: UInt64 {
        value("-gateSeed").flatMap { UInt64($0) } ?? UInt64.random(in: 0...UInt64.max)
    }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        if resetsState, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
    }

    /// Opens an activity, at a question if one is given.
    static func apply(to store: LearningStore) {
        guard let id = value("-open"), let activity = store.activity(id) else { return }
        if let question = value("-question").flatMap({ Int($0) }) {
            store.jump(to: question, in: activity)
        }
        store.open(activity)
    }

    /// The word after the last `name`, so a later switch overrides an earlier one.
    private static func value(_ name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
