import Foundation

/// Facts about this app that more than one file needs.
nonisolated enum AppFacts {
    /// What the model is told, for every summary. A constant on purpose: the note goes in the
    /// prompt, never in the instructions, which the model trusts more (prompt injection).
    /// A Mac test fails if any other text reaches `instructions:`.
    static let summaryInstructions = """
        You summarize one note for the person who wrote it. Use the note's own language. \
        Be brief and stick to what the note says; never add facts. \
        The headline is one short line. The points are the main ideas, one sentence each. \
        The to-dos are tasks the note asks its writer to do; leave them empty when there are none.
        """

    /// Said in the summary pane: where the summary is made and where the note goes.
    static let privacyLine = "Made on this device. Your notes never leave it."

    /// Labels, so people always know which summaries come from AI (HIG: Generative AI).
    static let aiLabel = "AI summary"
    static let simpleLabel = "Simple summary, no AI"

    /// Why a summary is simple, in words for the pane.
    static let aiFailedReason = "The on-device model couldn't summarize this note, so these lines are picked from it instead."
    static let longNoteLine = "Long note: the summary covers its first part."
}
