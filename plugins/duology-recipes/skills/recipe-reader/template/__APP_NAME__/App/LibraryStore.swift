import Foundation
import Observation

/// The books, the place in each one and the navigation path. `RootView` owns the one
/// store, above the navigation stack and every layout decision, so folding,
/// unfolding and rotating never lose a place. The place is saved on every change.
@Observable
final class LibraryStore {
    let library: Library
    private(set) var log: ReadingLog
    /// The navigation stack's path: the book open in the reader, if any.
    var path: [Book.ID] = []

    @ObservationIgnored private var texts: [String: ChapterText] = [:]
    @ObservationIgnored private let defaults: UserDefaults

    init(library: Library, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.logKey),
           let saved = try? JSONDecoder().decode(ReadingLog.self, from: data) {
            log = saved
        } else {
            log = ReadingLog()
        }
    }

    /// The store the app starts with: the bundled books, then the launch switches.
    static func launch() -> LibraryStore {
        let store = LibraryStore(library: .bundled)
        LaunchOptions.apply(to: store)
        return store
    }

    // MARK: Places

    /// Where a book is open, kept inside its chapters.
    func position(of book: Book) -> ReadingPosition {
        var position = log.position(of: book.id)
        position.chapter = min(position.chapter, max(book.chapters.count - 1, 0))
        return position
    }

    /// Moves the place in a book and saves it.
    func move(_ book: Book, to position: ReadingPosition) {
        guard position != self.position(of: book) else { return }
        log.record(position, in: book.id)
        save()
    }

    /// Applies a page turn the reader worked out from its page breaks.
    func apply(_ turn: PageTurn, in book: Book) {
        let chapter = position(of: book).chapter
        switch turn {
        case .offset(let offset):
            move(book, to: ReadingPosition(chapter: chapter, offset: offset))
        case .chapter(let index, let atEnd):
            // The end of the previous chapter: its last character, so the reader
            // shows its last page whatever the page size.
            let offset = atEnd ? max(0, text(of: book, chapter: index).length - 1) : 0
            move(book, to: ReadingPosition(chapter: index, offset: offset))
        case .none:
            break
        }
    }

    /// Opens a book in the reader at its saved place.
    func open(_ book: Book) {
        log.opened(book.id)
        save()
        path = [book.id]
    }

    /// The book under "Continue Reading": the last one opened, once it has a place.
    var continueBook: Book? {
        guard let id = log.lastOpened, log.hasStarted(id) else { return nil }
        return library.book(id)
    }

    /// How far through a book, from 0 to 1.
    func progress(of book: Book) -> Double {
        let lengths = book.chapters.indices.map { text(of: book, chapter: $0).length }
        return ReadingLog.progress(position(of: book), chapterLengths: lengths)
    }

    func hasStarted(_ book: Book) -> Bool {
        log.hasStarted(book.id)
    }

    // MARK: Text size

    /// Steps above or below the system text size, for the reader only.
    var textStep: Int {
        get { log.textStep }
        set {
            log.textStep = newValue
            save()
        }
    }

    // MARK: Chapters

    /// A chapter's text, read from the app bundle once and kept.
    func text(of book: Book, chapter index: Int) -> ChapterText {
        guard book.chapters.indices.contains(index) else { return ChapterText(title: "", body: "") }
        let chapter = book.chapters[index]
        if let cached = texts[chapter.file] { return cached }
        var body = ""
        if let resource = chapter.resource,
           let url = Bundle.main.url(forResource: resource.name, withExtension: resource.ext) {
            body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        assert(!body.isEmpty, "Books/\(chapter.file) is missing or empty")
        let text = ChapterText(title: chapter.title, body: body)
        texts[chapter.file] = text
        return text
    }

    // MARK: Saving

    private func save() {
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: Self.logKey)
        }
    }

    private static let logKey = "readingLog"
}

extension Library {
    /// Books/Library.json from the app bundle.
    static var bundled: Library {
        guard let url = Bundle.main.url(forResource: "Library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? Library.decode(from: data) else {
            assertionFailure("Books/Library.json is missing or doesn't decode")
            return Library(books: [])
        }
        return library
    }
}
