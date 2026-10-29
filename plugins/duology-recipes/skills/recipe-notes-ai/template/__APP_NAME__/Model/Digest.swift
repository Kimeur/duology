import Foundation

/// A note's summary: a one-line headline (all the closed phone shows), the key points and the
/// to-dos (the pane beside the note when the phone is open). Saved with the note.
nonisolated struct Digest: Codable, Equatable, Sendable {
    nonisolated enum Origin: String, Codable, Sendable {
        /// Written by the on-device model (Foundation Models).
        case onDeviceAI
        /// Picked from the note's own sentences, without AI: `SimpleSummary`.
        case simple
    }

    var headline: String
    var points: [String]
    var todos: [String]
    var origin: Origin
    /// The `Fingerprint` of the note text it was made from.
    var source: String
    /// False when the note was too long for the model and only its start was summarized.
    var coversWholeNote = true
    /// Why this is a simple summary although AI was asked for. Shown under it; nil otherwise.
    var fallbackReason: String?

    static let maximumHeadlineWords = 10
    static let maximumPoints = 4
    static let maximumTodos = 5
    static let maximumPointWords = 30

    /// Cleans one line from the model or the note: no list marker ("- ", "• ", "1. ", "[ ] "),
    /// no wrapping quotes, no spaces at the ends.
    static func tidy(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["- [ ] ", "* [ ] ", "[ ] ", "☐ ", "- ", "* ", "• ", "– ", "— "]
        var changed = true
        while changed {
            changed = false
            for marker in markers where text.hasPrefix(marker) {
                text = String(text.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                changed = true
            }
            if let range = text.range(of: #"^\d{1,2}[.)]\s+"#, options: .regularExpression) {
                text.removeSubrange(range)
                changed = true
            }
        }
        for (open, close) in [("\"", "\""), ("“", "”"), ("'", "'")]
        where text.count > 1 && text.hasPrefix(open) && text.hasSuffix(close) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    /// At most `count` words, with "…" when words were cut.
    static func limit(_ text: String, words count: Int) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > count else { return text }
        let kept = words.prefix(count).joined(separator: " ")
        return kept.trimmingCharacters(in: CharacterSet(charactersIn: ",;:.")) + "…"
    }
}

/// A summary while it streams in: each field fills in as the model writes it, headline first.
/// What the views show until the summary is finished; never saved.
nonisolated struct DigestDraft: Equatable, Sendable {
    var headline: String?
    var points: [String] = []
    var todos: [String] = []

    init(headline: String? = nil, points: [String] = [], todos: [String] = []) {
        self.headline = headline
        self.points = points
        self.todos = todos
    }

    /// The finished summary, tidied: blank and repeated items dropped, list markers removed,
    /// the headline and points cut to length, the counts capped. Nil without a headline.
    func finished(origin: Digest.Origin, source: String, coversWholeNote: Bool = true,
                  fallbackReason: String? = nil) -> Digest? {
        let headline = Digest.limit(Digest.tidy(headline ?? ""), words: Digest.maximumHeadlineWords)
        guard !headline.isEmpty else { return nil }
        return Digest(headline: headline,
                      points: Self.clean(points, cap: Digest.maximumPoints).map { Digest.limit($0, words: Digest.maximumPointWords) },
                      todos: Self.clean(todos, cap: Digest.maximumTodos),
                      origin: origin, source: source, coversWholeNote: coversWholeNote, fallbackReason: fallbackReason)
    }

    private static func clean(_ lines: [String], cap: Int) -> [String] {
        var seen = Set<String>()
        return lines.map(Digest.tidy).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(cap).map { $0 }
    }
}
