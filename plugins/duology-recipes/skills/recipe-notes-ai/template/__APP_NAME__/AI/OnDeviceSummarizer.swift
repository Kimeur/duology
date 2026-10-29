import FoundationModels

/// The summary the on-device model writes, in the order it writes it: the headline first, so
/// the closed phone's bar fills in before the points are done.
@Generable
struct GeneratedDigest {
    @Guide(description: "One line of at most eight words that says what the note is about")
    var headline: String
    @Guide(description: "The main ideas of the note, one short sentence each", .count(1...4))
    var points: [String]
    @Guide(description: "Tasks the note asks its writer to do, each a few words; empty when there are none", .maximumCount(5))
    var todos: [String]
}

/// Summaries from Apple's on-device model, through Foundation Models. Nothing here leaves the
/// device: no Private Cloud Compute, no network.
enum OnDeviceSummarizer {
    /// Nil when the model can run here; otherwise why not, in words for the summary pane.
    /// Availability can say yes and a request still fail (measured on the simulator), so the
    /// caller falls back on failure too.
    static var unavailableReason: String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? nil : "AI summaries don't support this language yet."
        case .unavailable(.deviceNotEligible):
            return "This device can't run Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to get AI summaries."
        case .unavailable(.modelNotReady):
            return "AI summaries will work once the model finishes downloading."
        case .unavailable:
            return "AI summaries aren't available right now."
        }
    }

    /// Streams a summary of `prompt`, calling `update` with each partial result, and returns the
    /// last one. Throws on any failure, and `CancellationError` when the task is cancelled.
    static func summarize(_ prompt: String, update: (DigestDraft) -> Void) async throws -> DigestDraft {
        // A new session per summary: each note is summarized on its own, with no history.
        let session = LanguageModelSession(instructions: AppFacts.summaryInstructions)
        let stream = session.streamResponse(to: prompt, generating: GeneratedDigest.self,
                                            options: GenerationOptions(temperature: 0.3))
        var last = DigestDraft()
        for try await snapshot in stream {
            try Task.checkCancellation()
            let partial = snapshot.content
            last = DigestDraft(headline: partial.headline, points: partial.points ?? [], todos: partial.todos ?? [])
            update(last)
        }
        return last
    }
}
