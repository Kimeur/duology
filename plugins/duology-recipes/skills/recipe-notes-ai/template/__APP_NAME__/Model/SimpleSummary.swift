import Foundation

/// A summary made without AI, from the note's own words: the first sentence as the headline,
/// the note's bullet points (or its next sentences) as the points, and its open to-dos.
///
/// The fallback whenever the on-device model can't run or fails, so the feature never just
/// disappears. It picks; it never rewrites. Same input, same output, on any device.
nonisolated enum SimpleSummary {
    static func digest(of note: Note, fallbackReason: String? = nil) -> Digest? {
        draft(of: note).finished(origin: .simple, source: Fingerprint.of(note.text), fallbackReason: fallbackReason)
    }

    static func draft(of note: Note) -> DigestDraft {
        let lines = note.body.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let todos = lines.compactMap(todo)
        let bullets = lines.filter { todo($0) == nil && isBullet($0) && !isDone($0) }.map(Digest.tidy)
        let prose = lines.filter { todo($0) == nil && !isBullet($0) && !isDone($0) }.joined(separator: "\n")
        let sentences = sentences(in: prose)

        // A note can be all to-dos, even ticked ones: then the title, the first to-do or the
        // first line heads it, so any note with words gets a summary.
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = sentences.first ?? bullets.first ?? (title.isEmpty ? nil : title) ?? todos.first
            ?? lines.first { !$0.isEmpty }
        let points = bullets.count >= 2 ? bullets : Array(sentences.dropFirst())
        return DigestDraft(headline: headline, points: points.filter { $0 != headline }, todos: todos)
    }

    /// The text of an open to-do line ("- [ ] Book the train", "TODO: call Sam"), or nil.
    static func todo(_ line: String) -> String? {
        let text = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- [ ]", "* [ ]", "[ ]", "☐"] where text.hasPrefix(marker) {
            let rest = text.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }
        for marker in ["todo:", "todo ", "to do:"] where text.lowercased().hasPrefix(marker) {
            let rest = text.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }
        return nil
    }

    /// A ticked to-do ("- [x] Book the train"): done, so neither a point nor a to-do.
    static func isDone(_ line: String) -> Bool {
        let text = line.lowercased()
        return ["- [x]", "* [x]", "[x]", "☑", "✓"].contains { text.hasPrefix($0) }
    }

    static func isBullet(_ line: String) -> Bool {
        ["- ", "* ", "• ", "– "].contains { line.hasPrefix($0) }
            || line.range(of: #"^\d{1,2}[.)]\s"#, options: .regularExpression) != nil
    }

    /// Sentences, split after ".", "!" or "?" followed by a space, and at line ends. Simple on
    /// purpose: "e.g. this" splits in two, which a fallback can live with.
    static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character.isNewline {
                result.append(current)
                current = ""
                continue
            }
            current.append(character)
            let next = index + 1 < characters.count ? characters[index + 1] : " "
            if ".!?".contains(character) && (next == " " || next.isNewline) {
                result.append(current)
                current = ""
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.count > 1 }
    }
}
