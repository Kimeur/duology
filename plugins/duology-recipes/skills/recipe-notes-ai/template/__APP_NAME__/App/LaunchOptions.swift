import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch and uses `.automatic`.
///
///   -uiTesting            animations off, test markers on
///   -resetState           delete the saved notes; the sample notes come back
///   -open ID              open a note, such as sample.offsite; "new" makes a new one
///   -summarize            with -open: start summarizing it at once
///   -summarizer NAME      automatic (the default), ai, simple, standin or failing
///                         (see SummaryEngine.swift)
///   -standInPace SECONDS  the stand-in's time per step, 0.15 by default
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var resetsState: Bool { arguments.contains("-resetState") }

    static var engine: SummaryEngine {
        value("-summarizer").flatMap(SummaryEngine.init(argument:)) ?? .automatic
    }

    static var standInPace: Duration {
        .milliseconds(Int(1000 * (value("-standInPace").flatMap(Double.init) ?? 0.15)))
    }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    /// Opens a note, and starts its summary if asked.
    static func apply(to store: NotesStore) {
        guard let id = value("-open") else { return }
        if id == "new" {
            store.newNote()
        } else {
            store.open(id)
            if arguments.contains("-summarize") { store.summarize(id) }
        }
    }

    /// The word after the last `name`, so a later switch overrides an earlier one.
    private static func value(_ name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
