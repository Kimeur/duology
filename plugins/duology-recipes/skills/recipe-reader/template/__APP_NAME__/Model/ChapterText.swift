import Foundation

/// A chapter as the reader lays it out: the title, then one paragraph per line.
///
/// The reading position is a character offset into `string`, counted in UTF-16 units
/// like `NSString` and `NSAttributedString`, so the same number works for the
/// paginator, the page views and the saved position.
nonisolated struct ChapterText: Equatable, Sendable {
    let string: String
    /// The title paragraph, line break included, so it can get its own style.
    let titleRange: NSRange

    /// Builds the text from a title and a plain-text body. Blank lines separate
    /// paragraphs; a single line break inside a paragraph becomes a space.
    init(title: String, body: String) {
        let lines = body.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var paragraphs: [String] = []
        var current: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
                current = []
            } else {
                current.append(trimmed)
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        string = ([heading] + paragraphs).joined(separator: "\n")
        titleRange = NSRange(location: 0, length: min((heading as NSString).length + 1, (string as NSString).length))
    }

    /// Length in UTF-16 units: the largest offset plus one.
    var length: Int { (string as NSString).length }

    /// The paragraphs after the title.
    var paragraphCount: Int { string.components(separatedBy: "\n").count - 1 }

    /// A few words from `offset` on, starting at a word boundary: "…the supply boat
    /// came in late". The library shows it under "Continue Reading".
    func excerpt(at offset: Int, words: Int = 12) -> String {
        let text = string as NSString
        guard text.length > 0 else { return "" }
        var start = min(max(0, offset), text.length - 1)
        // Back up to the start of the word the offset falls in.
        while start > 0, !CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(text.character(at: start - 1)) ?? " ") {
            start -= 1
        }
        let rest = text.substring(from: start)
        let all = rest.split(whereSeparator: { $0 == " " || $0 == "\n" })
        let joined = all.prefix(words).joined(separator: " ")
        // "…" only when more text follows and the last word doesn't already end a sentence.
        let endsSentence = joined.last.map { ".!?…".contains($0) } ?? false
        let more = all.count > words && !endsSentence ? "…" : ""
        return (start > 0 ? "…" : "") + joined + more
    }
}
