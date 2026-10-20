import Foundation

/// A place in a book: a chapter, and a character offset into that chapter's text.
///
/// Never a page number. Page breaks move with every fold, rotation and text size;
/// the first character on screen doesn't.
nonisolated struct ReadingPosition: Codable, Hashable, Sendable {
    var chapter = 0
    var offset = 0
}

/// Where each book is open, which book was read last, and the text size step.
/// Saved as JSON, so the place survives quitting the app.
nonisolated struct ReadingLog: Codable, Equatable, Sendable {
    private(set) var positions: [Book.ID: ReadingPosition] = [:]
    private(set) var lastOpened: Book.ID?
    /// Steps above (positive) or below (negative) the system text size.
    var textStep = 0

    /// Where to open a book: its saved place, or the start.
    func position(of book: Book.ID) -> ReadingPosition {
        positions[book] ?? ReadingPosition()
    }

    /// True once the book has a saved place past its first character.
    func hasStarted(_ book: Book.ID) -> Bool {
        guard let position = positions[book] else { return false }
        return position.chapter > 0 || position.offset > 0
    }

    /// Records a new place. Negative values become 0.
    mutating func record(_ position: ReadingPosition, in book: Book.ID) {
        positions[book] = ReadingPosition(chapter: max(0, position.chapter), offset: max(0, position.offset))
    }

    mutating func opened(_ book: Book.ID) {
        lastOpened = book
    }

    mutating func forget(_ book: Book.ID) {
        positions[book] = nil
        if lastOpened == book { lastOpened = nil }
    }

    /// How far through a book, from 0 to 1, by characters: the chapters before this
    /// one, plus the offset in this one. Needs every chapter's length.
    static func progress(_ position: ReadingPosition, chapterLengths: [Int]) -> Double {
        let total = chapterLengths.reduce(0, +)
        guard total > 0, !chapterLengths.isEmpty else { return 0 }
        let chapter = min(max(0, position.chapter), chapterLengths.count - 1)
        let before = chapterLengths.prefix(chapter).reduce(0, +)
        let inside = min(max(0, position.offset), chapterLengths[chapter])
        return min(1, Double(before + inside) / Double(total))
    }
}

/// The reader's text size: the system's Dynamic Type size moved by a few steps.
/// Sizes are indexes into SwiftUI's `DynamicTypeSize.allCases` (12 of them).
nonisolated enum TextSizeStep {
    /// The size index to use, kept inside 0..<count.
    static func index(system: Int, step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, system + step), count - 1)
    }

    /// The step that `index(system:step:count:)` really applies, so a step can't
    /// grow past the largest size or below the smallest.
    static func clamped(_ step: Int, system: Int, count: Int) -> Int {
        index(system: system, step: step, count: count) - system
    }
}
