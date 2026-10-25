import Foundation

/// Everything the child has done: the stars, and where each activity is. Saved on this
/// device only, as JSON in the app's own UserDefaults, on every change.
///
/// No timers and no penalties: a wrong answer is set aside and the child tries again.
/// The first right answer to a question earns its star; answering it again later
/// doesn't take the star away or add another.
nonisolated struct Progress: Codable, Equatable, Sendable {
    /// Where one activity is: the question on screen and what was tried on it.
    nonisolated struct Turn: Codable, Equatable, Sendable {
        /// Index of the question on screen. Equal to the question count when the activity is done.
        var question = 0
        /// Answers already tried on this question that were not right, in the order picked.
        var wrong: [String] = []
        /// The right answer was picked; the Next button is showing.
        var isSolved = false
    }

    /// What a tap on an answer did.
    nonisolated enum Pick: Equatable, Sendable {
        case right, wrong
        /// Nothing: the question was already solved, or that answer was tried, or it isn't there.
        case ignored
    }

    /// IDs of the questions answered right at least once. One star each.
    private(set) var solved: Set<String> = []
    /// Where each activity is, by activity ID.
    private(set) var turns: [String: Turn] = [:]

    init() {}

    var stars: Int { solved.count }

    func stars(in activity: Activity) -> Int {
        activity.questions.filter { solved.contains($0.id) }.count
    }

    /// The turn in an activity, kept inside its questions (content can change between versions).
    func turn(in activity: Activity) -> Turn {
        guard var turn = turns[activity.id] else { return Turn() }
        if turn.question > activity.questions.count || turn.question < 0 {
            turn = Turn(question: min(max(turn.question, 0), activity.questions.count))
        }
        return turn
    }

    /// The question on screen, or nil when the activity is done.
    func question(in activity: Activity) -> Question? {
        let index = turn(in: activity).question
        return activity.questions.indices.contains(index) ? activity.questions[index] : nil
    }

    func isFinished(_ activity: Activity) -> Bool {
        !activity.questions.isEmpty && turn(in: activity).question >= activity.questions.count
    }

    /// A tap on an answer.
    mutating func pick(_ answer: Answer.ID, in activity: Activity) -> Pick {
        guard let question = question(in: activity) else { return .ignored }
        var turn = turn(in: activity)
        guard !turn.isSolved, !turn.wrong.contains(answer),
              question.answers.contains(where: { $0.id == answer }) else { return .ignored }
        if answer == question.correct {
            turn.isSolved = true
            solved.insert(question.id)
        } else {
            turn.wrong.append(answer)
        }
        turns[activity.id] = turn
        return turn.isSolved ? .right : .wrong
    }

    /// The next question, once this one is solved. After the last, the activity is done.
    mutating func next(in activity: Activity) {
        let turn = turn(in: activity)
        guard turn.isSolved else { return }
        turns[activity.id] = Turn(question: min(turn.question + 1, activity.questions.count))
    }

    /// Back to the first question. The stars stay.
    mutating func playAgain(_ activity: Activity) {
        turns[activity.id] = Turn()
    }

    /// Starts an activity at a question (a launch switch for tests and screenshots).
    mutating func jump(to index: Int, in activity: Activity) {
        turns[activity.id] = Turn(question: min(max(index, 0), activity.questions.count))
    }

    /// Forget everything: no stars, every activity back at its first question.
    mutating func reset() {
        self = Progress()
    }
}
