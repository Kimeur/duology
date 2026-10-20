// Model tests. They build __APP_NAME__/Model/*.swift and __APP_NAME__/Text/*.swift with
// this file and run on the Mac. Run from the project folder: Tools/run-model-tests.sh
// duo-lint:disable-file DUO006 -- test fixtures: reader sizes measured on the Duo simulator, never used for layout
import AppKit
import CoreGraphics
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

func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.5 }
func near(_ a: CGRect, _ b: CGRect) -> Bool {
    near(a.minX, b.minX) && near(a.minY, b.minY) && near(a.width, b.width) && near(a.height, b.height)
}

// MARK: The bundled library

let booksFolder = URL(fileURLWithPath: "__APP_NAME__/Books")
let libraryData = try? Data(contentsOf: booksFolder.appendingPathComponent("Library.json"))
check(libraryData != nil, "Books/Library.json is there")
let library = libraryData.flatMap { try? Library.decode(from: $0) } ?? Library(books: [])
check(!library.books.isEmpty, "the library decodes and has books")
check(Set(library.books.map(\.id)).count == library.books.count, "book IDs are unique")
check(library.books.allSatisfy { !$0.chapters.isEmpty }, "every book has chapters")
check(library.books.allSatisfy { $0.colors.count == 2 && $0.colors.allSatisfy { UInt32($0, radix: 16) != nil } },
      "every book has two hex colours for its cover")
let files = library.books.flatMap { $0.chapters.map(\.file) }
check(Set(files).count == files.count, "chapter files are unique (the app bundle is flat)")

var realChapters: [ChapterText] = []
for book in library.books {
    for (index, chapter) in book.chapters.enumerated() {
        let url = booksFolder.appendingPathComponent(chapter.file)
        let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        check(chapter.resource?.ext == "txt", "\(book.id) \(index + 1): \(chapter.file) is a .txt file")
        check(body.count > 1_000, "\(book.id) \(index + 1): \(chapter.file) has text")
        let text = ChapterText(title: chapter.title, body: body)
        check(text.paragraphCount >= 5, "\(book.id) \(index + 1): blank lines make paragraphs")
        check(!text.string.contains("  "), "\(book.id) \(index + 1): no double spaces")
        realChapters.append(text)
    }
}
check(library.book("keeper")?.chapters.count == 3, "lookups by ID")
check(library.book("nope") == nil, "an unknown book is nil")

// MARK: Chapter text

let text = ChapterText(title: "  Fog \n", body: "First line\nsame paragraph.\r\n\r\n\n  Second  one.\n\nThird — café.\n")
check(text.string == "Fog\nFirst line same paragraph.\nSecond  one.\nThird — café.", "title, then one paragraph per line")
check(text.titleRange == NSRange(location: 0, length: 4), "the title range includes its line break")
check(text.paragraphCount == 3, "three paragraphs")
check(text.length == (text.string as NSString).length && text.length == text.string.utf16.count, "length counts UTF-16, like NSString")
check(ChapterText(title: "Empty", body: "").string == "Empty", "a chapter with no body is its title")
check(ChapterText(title: "Empty", body: "").titleRange.length == 5, "and the title range stays inside the text")
check(text.excerpt(at: 0, words: 3) == "Fog First line…", "an excerpt from the start")
let sameIndex = (text.string as NSString).range(of: "same").location
check(text.excerpt(at: sameIndex + 2, words: 2) == "…same paragraph.", "an excerpt backs up to the start of a word, and adds no … after a full stop")
check(ChapterText(title: "T", body: "one two").excerpt(at: 0, words: 3) == "T one two", "no … when nothing follows")
check(text.excerpt(at: 10_000, words: 2).hasSuffix("café."), "an offset past the end shows the last word")

// MARK: Reading log

var log = ReadingLog()
check(log.position(of: "keeper") == ReadingPosition(chapter: 0, offset: 0), "a new book opens at the start")
check(!log.hasStarted("keeper"), "and doesn't count as started")
log.record(ReadingPosition(chapter: 1, offset: 1_520), in: "keeper")
check(log.position(of: "keeper") == ReadingPosition(chapter: 1, offset: 1_520), "a recorded place comes back")
check(log.hasStarted("keeper"), "a book with a place has started")
log.record(ReadingPosition(chapter: -2, offset: -5), in: "bread")
check(log.position(of: "bread") == ReadingPosition(chapter: 0, offset: 0), "negative places become the start")
log.opened("keeper")
check(log.lastOpened == "keeper", "the last book opened is remembered")
log.textStep = 2
let saved = try? JSONEncoder().encode(log)
let loaded = saved.flatMap { try? JSONDecoder().decode(ReadingLog.self, from: $0) }
check(loaded == log, "the log survives a save and a load")
log.forget("keeper")
check(!log.hasStarted("keeper") && log.lastOpened == nil, "forget clears a book")
check(ReadingLog.progress(ReadingPosition(chapter: 1, offset: 50), chapterLengths: [100, 100]) == 0.75, "progress counts the chapters before and the offset")
check(ReadingLog.progress(ReadingPosition(chapter: 9, offset: 999), chapterLengths: [100, 100]) == 1, "progress never passes 1")
check(ReadingLog.progress(ReadingPosition(), chapterLengths: []) == 0, "no chapters, no progress")

// MARK: Text size steps

check(TextSizeStep.index(system: 3, step: 2, count: 12) == 5, "two steps up from Large is xxLarge")
check(TextSizeStep.index(system: 10, step: 5, count: 12) == 11, "never past the largest size")
check(TextSizeStep.index(system: 1, step: -4, count: 12) == 0, "never below the smallest")
check(TextSizeStep.clamped(5, system: 10, count: 12) == 1, "a step is trimmed to what can apply")

// MARK: Page breaks and turns

// Five pages of 100 characters: 0-99, 100-199, and so on.
let five = PageBreaks(ranges: (0..<5).map { NSRange(location: $0 * 100, length: 100) })
check(five.page(containing: 0) == 0 && five.page(containing: 250) == 2 && five.page(containing: 499) == 4, "the page that holds an offset")
check(five.page(containing: 9_999) == 4, "an offset past the end is on the last page")
check(five.firstPage(showing: 350, perSpread: 1) == 3, "one page: the page that holds the offset")
check(five.firstPage(showing: 350, perSpread: 2) == 2, "two pages: the spread starts on an even page")
check(five.shown(from: 2, perSpread: 2) == NSRange(location: 200, length: 200), "a spread shows both pages")
check(five.shown(from: 4, perSpread: 2) == NSRange(location: 400, length: 100), "the last spread may hold one page")
check(five.shown(from: 9, perSpread: 1) == nil, "no page, nothing shown")
check(five.isAtEnd(from: 4, perSpread: 2) && !five.isAtEnd(from: 2, perSpread: 2), "the end of the chapter")
check(five.turn(forward: true, from: 150, perSpread: 1, chapter: 0, chapterCount: 2) == .offset(200), "next page: the next page's start")
check(five.turn(forward: true, from: 150, perSpread: 2, chapter: 0, chapterCount: 2) == .offset(200), "next spread from the first one")
check(five.turn(forward: false, from: 250, perSpread: 2, chapter: 0, chapterCount: 2) == .offset(0), "previous spread")
check(five.turn(forward: false, from: 150, perSpread: 1, chapter: 0, chapterCount: 2) == .offset(0), "previous page")
check(five.turn(forward: true, from: 480, perSpread: 1, chapter: 0, chapterCount: 2) == .chapter(1, atEnd: false), "past the last page: the next chapter's start")
check(five.turn(forward: true, from: 480, perSpread: 1, chapter: 1, chapterCount: 2) == .none, "past the book's last page: nothing")
check(five.turn(forward: false, from: 40, perSpread: 2, chapter: 1, chapterCount: 2) == .chapter(0, atEnd: true), "before the first page: the previous chapter's end")
check(five.turn(forward: false, from: 40, perSpread: 1, chapter: 0, chapterCount: 2) == .none, "before the book's first page: nothing")
check(PageBreaks().turn(forward: true, from: 0, perSpread: 1, chapter: 0, chapterCount: 3) == .none, "no pages yet: no turn")

// MARK: Paginator (TextKit 1 through AppKit; the app uses UIKit's copy)

func styled(_ chapter: ChapterText, size: CGFloat) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 3
    paragraph.paragraphSpacing = 10
    paragraph.hyphenationFactor = 0.6
    let result = NSMutableAttributedString(string: chapter.string, attributes: [
        .font: NSFont.systemFont(ofSize: size), .paragraphStyle: paragraph,
    ])
    result.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: size * 1.6), range: chapter.titleRange)
    return result
}

if let keeper = realChapters.first {
    let body = styled(keeper, size: 17)
    let closedPage = Paginator.pageBreaks(for: body, pageSize: CGSize(width: 334, height: 540))
    let bookPage = Paginator.pageBreaks(for: body, pageSize: CGSize(width: 323, height: 535))
    for (name, breaks) in [("closed", closedPage), ("book", bookPage)] {
        let contiguous = zip(breaks.ranges, breaks.ranges.dropFirst()).allSatisfy { NSMaxRange($0) == $1.location }
        check(breaks.count > 2, "\(name): the first chapter fills several pages (\(breaks.count))")
        check(breaks.ranges.first?.location == 0 && contiguous && NSMaxRange(breaks.ranges.last!) == body.length,
              "\(name): every character is on exactly one page")
        check(breaks.ranges.allSatisfy { $0.length > 0 }, "\(name): no empty page")
    }
    let larger = Paginator.pageBreaks(for: styled(keeper, size: 23), pageSize: CGSize(width: 334, height: 540))
    check(larger.count > closedPage.count, "larger text makes more pages (\(closedPage.count) to \(larger.count))")
    for offset in [0, 1_520, 3_000, body.length - 1] {
        for breaks in [closedPage, bookPage, larger] {
            let page = breaks.page(containing: offset)
            check(NSLocationInRange(offset, breaks.ranges[page]), "offset \(offset) is on page \(page + 1) of \(breaks.count)")
            let first = breaks.firstPage(showing: offset, perSpread: 2)
            check(breaks.shown(from: first, perSpread: 2).map { NSLocationInRange(offset, $0) } ?? false,
                  "a spread from page \(first + 1) shows offset \(offset)")
        }
    }
}
check(Paginator.pageBreaks(for: NSAttributedString(string: "Words"), pageSize: CGSize(width: 20, height: 600)).isEmpty,
      "a page narrower than 44 pt gets no pages")
check(Paginator.pageBreaks(for: NSAttributedString(), pageSize: CGSize(width: 300, height: 600)).isEmpty, "no text, no pages")

// MARK: Fold geometry (frames measured on the iPhone Duo simulator, iOS 27.1)

// The reader's own size inside its navigation stack, and the fold's frame in the
// reader's space. Held wide, the fold runs past the reader's top and bottom: it is
// the window's full height, and the reader starts 82 pt down, below the title.
let closedReader = CGSize(width: 382, height: 562)
let wideReader = CGSize(width: 867, height: 553)
let tabletopReader = CGSize(width: 669, height: 835)
let bookFold = CGRect(x: 455.5, y: -82, width: 40, height: 669)
let tabletopFold = CGRect(x: 0, y: 373.5, width: 669, height: 40)
check(FoldGeometry.liesInside(bookFold, of: wideReader), "the open phone's fold splits the wide reader")
check(!FoldGeometry.liesInside(CGRect(x: 382, y: 0, width: 84, height: 174), of: closedReader),
      "a region past the reader's edge is not a fold")
var fold = FoldGeometry(candidates: [(CGRect(x: 900, y: 0, width: 40, height: 611), false), (bookFold, true)], in: wideReader)
check(fold.isActive && fold.frame == bookFold && fold.isVertical, "an active fold inside the view wins")
fold = FoldGeometry(candidates: [(bookFold, false)], in: wideReader)
check(fold.frame == bookFold && !fold.isActive, "flat and held wide: an inactive fold, still read")

// MARK: Reader layout

let closedLayout = ReaderLayout(size: closedReader, fold: FoldGeometry(), prefersSpread: false)
check(closedLayout.mode == .single && closedLayout.perSpread == 1, "closed: one page")
check(near(closedLayout.pageSize.width, 334) && near(closedLayout.pageSize.height, 486), "closed: the page fills the reader inside its margins")
let book = ReaderLayout(size: wideReader, fold: FoldGeometry(frame: bookFold, isActive: true), prefersSpread: true)
check(book.mode == .spread && book.perSpread == 2, "book: two facing pages")
check(near(book.regions[0], CGRect(x: 0, y: 0, width: 455.5, height: 553))
      && near(book.regions[1], CGRect(x: 495.5, y: 0, width: 371.5, height: 553)), "book: one region each side of the fold")
check(near(book.pageSize.width, 323.5) && near(book.pageSize.height, 477), "book: both pages take the narrower side's width")
let leftText = book.textFrame(in: book.regions[0])
let rightText = book.textFrame(in: book.regions[1])
check(!leftText.intersects(bookFold) && !rightText.intersects(bookFold), "book: no text in the fold's 40 pt")
check(leftText.size == rightText.size, "book: one page size for both sides")
let flatWide = ReaderLayout(size: wideReader, fold: FoldGeometry(frame: bookFold, isActive: false), prefersSpread: true)
check(flatWide.mode == .spread && flatWide.regions == book.regions, "open and flat: the same spread, so folding doesn't paginate again")
let tabletop = ReaderLayout(size: tabletopReader, fold: FoldGeometry(frame: tabletopFold, isActive: true), prefersSpread: false)
check(tabletop.mode == .tabletop, "tabletop: one page above the fold")
check(near(tabletop.regions[0], CGRect(x: 0, y: 0, width: 669, height: 373.5)), "tabletop: the page region ends at the fold")
check(tabletop.controls.map { near($0, CGRect(x: 0, y: 413.5, width: 669, height: 421.5)) } ?? false, "tabletop: the page turns sit below it")
check(tabletop.textFrame(in: tabletop.regions[0]).maxY <= tabletopFold.minY, "tabletop: no text in the fold")
check(near(tabletop.pageSize.width, 600) && near(tabletop.pageSize.height, 297.5), "tabletop: a 600 × 297.5 pt page")
let tallFlat = ReaderLayout(size: tabletopReader, fold: FoldGeometry(frame: tabletopFold, isActive: false), prefersSpread: false)
check(tallFlat.mode == .single && tallFlat.controls == nil, "open, flat and held tall: one tall page")
check(near(tallFlat.pageSize.width, 600), "a wide single page keeps lines short")
let splitView = ReaderLayout(size: CGSize(width: 420, height: 553), fold: FoldGeometry(frame: CGRect(x: 380, y: -82, width: 40, height: 669), isActive: true), prefersSpread: false)
check(splitView.mode == .single, "a fold near the reader's edge (Split View) gives one page")
let iPad = ReaderLayout(size: CGSize(width: 1180, height: 760), fold: FoldGeometry(), prefersSpread: true)
check(iPad.mode == .spread && near(iPad.regions[1].minX - iPad.regions[0].maxX, 32), "a wide regular-width window with no fold: two pages and a gutter")
check(ReaderLayout(size: CGSize(width: 100, height: 100), fold: FoldGeometry(), prefersSpread: false).pageSize == .zero, "too small to read: no page size")

// MARK: Shelf columns

let closedShelf = ShelfColumns(width: 382, fold: FoldGeometry(), minWidth: 140, spacing: 16, margin: 20)
check(closedShelf.count == 2, "closed: two columns of covers")
let bookShelf = ShelfColumns(width: 867, fold: FoldGeometry(frame: bookFold, isActive: true), minWidth: 140, spacing: 16, margin: 20)
check(bookShelf.count % 2 == 0 && bookShelf.count >= 4, "book: an even number of columns (\(bookShelf.count))")
check(bookShelf.columns.allSatisfy { $0.maxX <= bookFold.minX || $0.minX >= bookFold.maxX }, "book: no cover on the fold")
check(Set(bookShelf.columns.map { Int($0.width * 10) }).count == 1, "book: every column the same width")
check(bookShelf.isSplit && bookShelf.leadingColumns.count == bookShelf.count / 2, "book: the leading group is half the columns")
check(bookShelf.leadingColumns.allSatisfy { $0.maxX <= bookFold.minX }, "book: the leading group ends before the fold")
check(!closedShelf.isSplit && closedShelf.leadingColumns.count == closedShelf.count, "no fold: every column leads")
let flatShelf = ShelfColumns(width: 867, fold: FoldGeometry(frame: bookFold, isActive: false), minWidth: 140, spacing: 16, margin: 20)
check(flatShelf == bookShelf, "open and flat: the same columns, so folding moves nothing")
let tabletopShelf = ShelfColumns(width: 669, fold: FoldGeometry(frame: tabletopFold, isActive: true), minWidth: 140, spacing: 16, margin: 20)
check(tabletopShelf.count == 4, "a fold across the shelf doesn't split its columns")
check(ShelfColumns(width: 30, fold: FoldGeometry(), minWidth: 140, spacing: 16, margin: 20).count == 0, "no room, no columns")

// MARK: Every type stays nonisolated

// The app target compiles with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, and so does
// this program. Each line below needs its type to be nonisolated; drop `nonisolated`
// from one and this file stops compiling. Add a line for each new model type.
let offMain = await Task.detached { () -> Bool in
    let l = Library(books: [])
    let b = Book(id: "b", title: "", author: "", kind: "", summary: "", colors: [], chapters: [])
    let c = Chapter(title: "", file: "a.txt")
    let t = ChapterText(title: "T", body: "One.\n\nTwo.")
    var r = ReadingLog()
    r.record(ReadingPosition(chapter: 0, offset: 3), in: "b")
    let p = PageBreaks(ranges: [NSRange(location: 0, length: 3)])
    let turn: PageTurn = p.turn(forward: true, from: 0, perSpread: 1, chapter: 0, chapterCount: 1)
    let f = FoldGeometry(candidates: [(bookFold, true)], in: wideReader)
    let layout = ReaderLayout(size: wideReader, fold: f, prefersSpread: false, insets: PageInsets())
    let mode: ReaderLayout.Mode = layout.mode
    let shelf = ShelfColumns(width: 382, fold: f, minWidth: 140, spacing: 16, margin: 20)
    let column: ShelfColumns.Column? = shelf.columns.first
    return l.books.isEmpty && b.chapters.isEmpty && c.resource != nil && t.paragraphCount == 2
        && r.hasStarted("b") && turn == .none && mode == .spread && column != nil
        && TextSizeStep.index(system: 3, step: 1, count: 12) == 4
}.value
check(offMain, "the model works off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
