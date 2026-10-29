import Foundation

/// What writes the summaries. The app uses `.automatic`; the others are for tests and for
/// trying things by hand (`-summarizer` in LaunchOptions).
nonisolated enum SummaryEngine: String, CaseIterable, Sendable {
    /// The on-device model when it can run, `SimpleSummary` when it can't or fails.
    case automatic
    /// Always ask the on-device model first, even when it says it isn't available. Still falls
    /// back on failure. For measuring what the model does on a simulator or device.
    case onDeviceAI = "ai"
    /// `SimpleSummary` only, at once.
    case simple
    /// A stand-in for the model: `SimpleSummary`'s result, streamed one word at a time at a
    /// steady pace, so tests can fold the phone or press Stop mid-stream on any simulator.
    case standIn = "standin"
    /// A stand-in that fails after a moment, like the model on our simulator, to test the fallback.
    case failing

    init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

/// The steps a stand-in stream goes through: the headline word by word, then each point and
/// to-do whole, the way the model's partial results fill in. The last step is the whole draft.
nonisolated enum StandInStream {
    static func steps(toward draft: DigestDraft) -> [DigestDraft] {
        var steps: [DigestDraft] = []
        var words: [Substring] = []
        for word in (draft.headline ?? "").split(separator: " ") {
            words.append(word)
            steps.append(DigestDraft(headline: words.joined(separator: " ")))
        }
        var step = DigestDraft(headline: draft.headline)
        for point in draft.points {
            step.points.append(point)
            steps.append(step)
        }
        for todo in draft.todos {
            step.todos.append(todo)
            steps.append(step)
        }
        return steps
    }
}
