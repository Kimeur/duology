import Foundation

/// A colour for a picture. The views turn it into a system colour, so it follows
/// dark mode and Increase Contrast.
nonisolated enum Tint: String, CaseIterable, Sendable {
    case red, orange, yellow, green, mint, blue, purple, pink, brown
}

/// What a question or an answer shows.
nonisolated enum Art: Hashable, Sendable {
    /// A number, drawn large: "3".
    case number(Int)
    /// A letter, drawn large: "B".
    case letter(String)
    /// One SF Symbol, such as "bus.fill".
    case symbol(String, Tint)
    /// The same SF Symbol `count` times, to count. `name` is what VoiceOver says for one ("star").
    case group(String, count: Int, name: String, Tint)

    /// Every SF Symbol name it draws, for the checks on the Mac.
    var symbolNames: [String] {
        switch self {
        case .number, .letter: return []
        case .symbol(let name, _), .group(let name, _, _, _): return [name]
        }
    }
}

/// One answer button.
nonisolated struct Answer: Identifiable, Hashable, Sendable {
    /// Unique in its question. The UI tests find the button as "answer.<id>".
    let id: String
    /// What VoiceOver says, and the caption under a picture: "Bus".
    let label: String
    let art: Art
    /// Show `label` under the picture. Off for numbers: the number is the label.
    var showsCaption: Bool {
        if case .number = art { return false }
        return true
    }
}

/// One question: a picture, a line of text, the words read aloud, and two to four answers.
nonisolated struct Question: Identifiable, Equatable, Sendable {
    /// Unique in the app: the stars are saved by question ID.
    let id: String
    /// On screen, under the picture.
    let text: String
    /// Read aloud by the speaker button, for children who can't read yet.
    let spoken: String
    let art: Art
    /// What VoiceOver says for the picture. For a group it names the container, and each
    /// item inside it is read on its own, so a VoiceOver user can count them too.
    let artLabel: String
    let answers: [Answer]
    let correct: Answer.ID

    var correctAnswer: Answer? { answers.first { $0.id == correct } }
}

/// A set of questions on one theme, shown as a card on the home screen.
nonisolated struct Activity: Identifiable, Equatable, Sendable {
    /// Used by -open and in identifiers: "activity.counting".
    let id: String
    let title: String
    let symbol: String
    let tint: Tint
    let questions: [Question]

    /// What is wrong with this activity's content, in words. Empty when it is fine.
    var problems: [String] {
        var found: [String] = []
        if questions.isEmpty { found.append("\(id): no questions") }
        if Set(questions.map(\.id)).count != questions.count { found.append("\(id): question IDs repeat") }
        for question in questions {
            let ids = question.answers.map(\.id)
            if !(2...4).contains(ids.count) { found.append("\(question.id): needs 2 to 4 answers") }
            if Set(ids).count != ids.count { found.append("\(question.id): answer IDs repeat") }
            if question.correctAnswer == nil { found.append("\(question.id): the right answer is not among the answers") }
            if question.text.isEmpty || question.spoken.isEmpty || question.artLabel.isEmpty {
                found.append("\(question.id): text, spoken words and picture label are all needed")
            }
            // The UI test marker separates fields with "|".
            let words = [question.text, question.spoken, question.artLabel] + question.answers.map(\.label)
            if words.contains(where: { $0.contains("|") }) { found.append("\(question.id): no \"|\" in texts") }
        }
        return found
    }
}
