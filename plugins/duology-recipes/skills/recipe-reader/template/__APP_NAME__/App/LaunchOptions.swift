import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting          animations off, test markers on
///   -resetState         forget every saved place and the text size
///   -open ID            open a book in the reader
///   -chapter N          with -open: at this chapter (0 is the first)
///   -offset N           with -open: at this character offset in the chapter
///   -textStep N         text size steps above (or below, negative) the system size
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }
    static var resetsState: Bool { arguments.contains("-resetState") }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        if resetsState, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
    }

    /// Applies the switches to a new store: the text size, then the book to open.
    static func apply(to store: LibraryStore) {
        if let step = number("-textStep") { store.textStep = step }
        guard let id = value("-open"), let book = store.library.book(id) else { return }
        let chapter = number("-chapter")
        let offset = number("-offset")
        if chapter != nil || offset != nil {
            store.move(book, to: ReadingPosition(chapter: chapter ?? 0, offset: offset ?? 0))
        }
        store.open(book)
    }

    /// The word after the last `name`, so a later switch overrides an earlier one.
    private static func value(_ name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static func number(_ name: String) -> Int? {
        value(name).flatMap { Int($0) }
    }
}
