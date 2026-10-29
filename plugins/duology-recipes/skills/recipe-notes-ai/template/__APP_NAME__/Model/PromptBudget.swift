import Foundation

/// The part of a note the on-device model gets. Its context window holds 4,096 tokens for the
/// instructions, the summary's format, the note and the answer together, so a long note is cut
/// at a sentence or line end and the summary says it covers only the start.
///
/// 6,000 characters is about 1,500 tokens of English text. Other scripts can use more tokens
/// per character; if a note still overflows, the request fails and the app falls back to
/// `SimpleSummary` like on any other failure.
nonisolated struct PromptBudget: Equatable, Sendable {
    static let characterLimit = 6_000

    /// What to send: the note, or its start.
    let text: String
    /// False when `text` is only the start of the note.
    let isWhole: Bool

    init(_ full: String, limit: Int = PromptBudget.characterLimit) {
        guard full.count > limit else {
            text = full
            isWhole = true
            return
        }
        let start = String(full.prefix(limit))
        // Cut after the last sentence or line end in the second half; else after the last space.
        let half = start.index(start.startIndex, offsetBy: limit / 2)
        let ends = [". ", "! ", "? ", "\n"].compactMap { start.range(of: $0, options: .backwards, range: half..<start.endIndex)?.upperBound }
        if let cut = ends.max() {
            text = String(start[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let space = start.lastIndex(of: " ") {
            text = String(start[..<space])
        } else {
            text = start
        }
        isWhole = false
    }
}
