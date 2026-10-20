import Foundation

/// Where each page of a chapter starts and ends, as character ranges. The paginator
/// (Text/Paginator.swift) makes them for one page size and one text size.
///
/// The place is an offset, so it survives any new set of breaks: after a fold, the
/// reader shows the page that holds the offset.
nonisolated struct PageBreaks: Equatable, Sendable {
    var ranges: [NSRange] = []

    var count: Int { ranges.count }
    var isEmpty: Bool { ranges.isEmpty }

    /// The page that holds a character offset: the last page if the offset is past
    /// the end, the first if it is negative.
    func page(containing offset: Int) -> Int {
        ranges.firstIndex { NSMaxRange($0) > offset } ?? max(ranges.count - 1, 0)
    }

    /// The first page on screen for an offset. With two pages a spread starts on an
    /// even page, so a page never changes sides and the offset is always on screen:
    /// on the leading page or on the trailing one.
    func firstPage(showing offset: Int, perSpread: Int) -> Int {
        let page = page(containing: offset)
        return perSpread == 2 ? page - page % 2 : page
    }

    /// The characters on screen, from the first page's start to the last page's end.
    func shown(from firstPage: Int, perSpread: Int) -> NSRange? {
        guard ranges.indices.contains(firstPage) else { return nil }
        let last = min(firstPage + perSpread, ranges.count) - 1
        let start = ranges[firstPage].location
        return NSRange(location: start, length: NSMaxRange(ranges[last]) - start)
    }

    /// True when no page follows the ones on screen.
    func isAtEnd(from firstPage: Int, perSpread: Int) -> Bool {
        firstPage + perSpread >= ranges.count
    }

    /// What a page turn does from `offset`: a new offset in this chapter, the next
    /// chapter's start, the previous chapter's end, or nothing at either end of the book.
    func turn(forward: Bool, from offset: Int, perSpread: Int, chapter: Int, chapterCount: Int) -> PageTurn {
        guard !ranges.isEmpty else { return .none }
        let first = firstPage(showing: offset, perSpread: perSpread)
        if forward {
            let target = first + perSpread
            if target < ranges.count { return .offset(ranges[target].location) }
            return chapter + 1 < chapterCount ? .chapter(chapter + 1, atEnd: false) : .none
        }
        if first > 0 { return .offset(ranges[max(0, first - perSpread)].location) }
        return chapter > 0 ? .chapter(chapter - 1, atEnd: true) : .none
    }
}

nonisolated enum PageTurn: Equatable, Sendable {
    /// Stay in this chapter, at this offset.
    case offset(Int)
    /// Open another chapter, at its start or at its end.
    case chapter(Int, atEnd: Bool)
    /// Nothing before the first page of the book or after its last.
    case none
}
