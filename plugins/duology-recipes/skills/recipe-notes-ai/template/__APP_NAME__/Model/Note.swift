import Foundation

/// One note: a title, the text, when it last changed, and its last summary.
nonisolated struct Note: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var body: String
    var modified: Date
    /// The last summary, kept until the note is summarized again or the summary is cleared.
    /// It may describe an older version of the note: see `summaryIsCurrent`.
    var digest: Digest?

    init(id: String = UUID().uuidString, title: String = "", body: String = "",
         modified: Date = Date(), digest: Digest? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.modified = modified
        self.digest = digest
    }

    /// What gets summarized: the title, then the text.
    var text: String {
        [title, body].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var isEmpty: Bool { text.isEmpty }

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Too short a note gives a summary longer than itself. The pane asks for a few more lines.
    static let minimumWordsToSummarize = 12
    var canBeSummarized: Bool { wordCount >= Self.minimumWordsToSummarize }

    /// The title, or the first line of the text, or "New Note".
    var displayTitle: String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return firstLines(1).first ?? "New Note"
    }

    /// Up to two lines of the text after the title, for the list.
    var preview: String {
        let lines = firstLines(3)
        let rest = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Array(lines.dropFirst()) : lines
        return rest.prefix(2).joined(separator: " ")
    }

    /// True when the summary was made from the note as it is now.
    var summaryIsCurrent: Bool {
        digest?.source == Fingerprint.of(text)
    }

    private func firstLines(_ count: Int) -> [String] {
        body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(count)
            .map { $0 }
    }
}

/// Every note, and the changes the app makes to them. A value type, so the rules are tested
/// on the Mac; `NotesStore` keeps one and saves it after every change.
nonisolated struct Notebook: Codable, Equatable, Sendable {
    /// Bump when the saved format changes, and keep reading the old one.
    static let currentVersion = 1

    var version = Notebook.currentVersion
    private(set) var notes: [Note]

    init(notes: [Note] = []) {
        self.notes = notes
    }

    /// Newest first; notes changed at the same moment keep a fixed order.
    var sorted: [Note] {
        notes.sorted { $0.modified != $1.modified ? $0.modified > $1.modified : $0.id < $1.id }
    }

    func note(_ id: Note.ID) -> Note? {
        notes.first { $0.id == id }
    }

    mutating func add(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        notes.append(note)
    }

    /// Changes the title or the text. `modified` moves only when something really changed,
    /// so opening a note and leaving it doesn't bring it to the top.
    mutating func edit(_ id: Note.ID, title: String? = nil, body: String? = nil, at date: Date = Date()) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[index]
        if let title { note.title = title }
        if let body { note.body = body }
        if note.title != notes[index].title || note.body != notes[index].body {
            note.modified = date
            notes[index] = note
        }
    }

    /// Saves or clears a summary. The note's date doesn't change: a summary isn't an edit.
    mutating func setDigest(_ digest: Digest?, for id: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].digest = digest
    }

    mutating func remove(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
    }

    /// Drops a note left empty, as when someone taps New Note and goes back. True if it did.
    @discardableResult
    mutating func removeIfEmpty(_ id: Note.ID) -> Bool {
        guard note(id)?.isEmpty == true else { return false }
        remove(id)
        return true
    }

    // Reads files without a version too, so a future format can still read this one.
    private enum CodingKeys: String, CodingKey { case version, notes }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
    }
}

extension Notebook {
    /// The saved file: JSON, dates as ISO 8601 text, so it reads the same on every device.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Notebook {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Notebook.self, from: data)
    }
}

/// A short, stable fingerprint of a note's text: the same text gives the same fingerprint on
/// every launch and every device (Swift's `hashValue` changes on every launch). FNV-1a, 64 bits.
nonisolated enum Fingerprint {
    static func of(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }
}
