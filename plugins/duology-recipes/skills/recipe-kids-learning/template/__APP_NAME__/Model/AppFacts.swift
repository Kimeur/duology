import Foundation

/// Facts about this app that more than one screen needs.
nonisolated enum AppFacts {
    /// Your privacy policy. Replace it before you ship: App Store Connect asks for the same
    /// address, and the grown-ups area opens it in Safari, after the parental gate.
    static let privacyPolicy = URL(string: "https://example.com/privacy")!

    /// The language of the sample questions, for the spoken prompts. Change it with the content.
    static let speechLanguage = "en-US"

    /// Said when the parental gate opens, for children who can't read the screen yet.
    static let gatePrompt = "This part is for grown-ups. Please ask a grown-up to help you."

    /// Gentle feedback, shown and read aloud. No sounds that scold, no timers.
    static let rightFeedback = "Great job!"
    static let wrongFeedback = "Not that one. Try again!"
}
