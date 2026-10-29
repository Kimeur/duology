import Foundation
import Observation

/// The notes, the navigation path, the summary sheet and the one `SummaryService`. `RootView`
/// owns the one store, above the navigation stack and every layout decision, so opening,
/// closing and folding the phone never lose a word, a summary or one still streaming in.
/// The notes are saved to a file on this device after every change.
@Observable
final class NotesStore {
    private(set) var notebook: Notebook
    /// The navigation stack's path: the note on screen, if any. A note left empty is dropped
    /// when it leaves the path, as when someone taps New Note and goes straight back.
    var path: [Note.ID] = [] {
        didSet {
            for id in Set(oldValue).subtracting(path) where notebook.removeIfEmpty(id) {
                save()
            }
        }
    }
    /// The full summary, in a sheet, when the screen has no room for the pane beside the note.
    var showsSummarySheet = false

    let summaries: SummaryService

    @ObservationIgnored private let fileURL: URL?

    /// - Parameter fileURL: where the notes are saved; nil keeps them in memory only.
    init(fileURL: URL?, summaries: SummaryService, firstNotes: [Note]) {
        self.fileURL = fileURL
        self.summaries = summaries
        if let fileURL, let data = try? Data(contentsOf: fileURL) {
            if let saved = try? Notebook.decode(data) {
                notebook = saved
            } else {
                // A file this version can't read: keep it beside the new one instead of saving
                // the samples over it, so nobody's notes are lost.
                let aside = fileURL.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: fileURL, to: aside)
                notebook = Notebook(notes: firstNotes)
            }
        } else {
            notebook = Notebook(notes: firstNotes)
        }
    }

    /// The store the app starts with: the saved notes (or the samples on a first launch), then
    /// the launch switches.
    static func launch() -> NotesStore {
        let url = notesFileURL()
        if LaunchOptions.resetsState, let url {
            try? FileManager.default.removeItem(at: url)
        }
        let store = NotesStore(fileURL: url,
                               summaries: SummaryService(engine: LaunchOptions.engine, standInPace: LaunchOptions.standInPace),
                               firstNotes: SampleNotes.all())
        LaunchOptions.apply(to: store)
        return store
    }

    /// Application Support/Notes.json, inside the app's container. Not in Documents, so the
    /// Files app doesn't show it.
    static func notesFileURL() -> URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Notes.json")
    }

    var notes: [Note] { notebook.sorted }

    func note(_ id: Note.ID) -> Note? { notebook.note(id) }

    // MARK: Notes

    func newNote() {
        let note = Note()
        notebook.add(note)
        save()
        path = [note.id]
    }

    func open(_ id: Note.ID) {
        guard notebook.note(id) != nil else { return }
        path = [id]
    }

    func setTitle(_ title: String, of id: Note.ID) {
        notebook.edit(id, title: title)
        save()
    }

    func setBody(_ body: String, of id: Note.ID) {
        notebook.edit(id, body: body)
        save()
    }

    func delete(_ id: Note.ID) {
        if summaries.isWorking(on: id) { summaries.stop() }
        path.removeAll { $0 == id }
        notebook.remove(id)
        save()
    }

    // MARK: Summaries

    /// Summarizes the note as it is now. The result is saved with the note when it arrives,
    /// whatever is on screen by then.
    func summarize(_ id: Note.ID) {
        guard let note = notebook.note(id), note.canBeSummarized else { return }
        summaries.summarize(note) { [weak self] digest in
            self?.notebook.setDigest(digest, for: id)
            self?.save()
        }
    }

    func stopSummary() {
        summaries.stop()
    }

    func clearSummary(of id: Note.ID) {
        if summaries.isWorking(on: id) { summaries.stop() }
        notebook.setDigest(nil, for: id)
        save()
    }

    // MARK: Saving

    /// Written whole after every change, atomically, with the default data protection. A few
    /// hundred notes are a few hundred kilobytes; move to a database well before that hurts.
    private func save() {
        guard let fileURL, let data = try? notebook.encoded() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
