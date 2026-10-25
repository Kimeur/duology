import Foundation

/// A small random number generator with a seed (SplitMix64). The same seed always gives
/// the same numbers, so a UI test that launches with -gateSeed knows the questions are
/// repeatable. The app seeds it at random.
nonisolated struct SeededGenerator: RandomNumberGenerator, Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in `range`, from this generator's own arithmetic, so the sequence for a seed
    /// never depends on how the standard library maps random bits to a range.
    mutating func pick(_ range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}

/// A question an adult answers in a moment and a young child can't: a multiplication
/// with a two-digit answer.
nonisolated struct GateQuestion: Equatable, Sendable {
    let left: Int
    let right: Int

    static let leftFactors = 6...9
    static let rightFactors = 4...9

    var answer: Int { left * right }
    /// On screen.
    var text: String { "What is \(left) × \(right)?" }
    /// For VoiceOver: "×" alone can be read as a letter.
    var spoken: String { "What is \(left) times \(right)?" }
}

/// The parental gate in front of the grown-ups area (reset, the privacy policy link).
///
/// One question at a time, typed on a number pad. A right answer opens the area; a wrong
/// one closes the gate, and the next opening asks a different question. Either way the
/// question is used once. Plain Swift, tested on the Mac.
nonisolated struct ParentalGate: Equatable, Sendable {
    nonisolated enum Outcome: Equatable, Sendable {
        case passed, failed
        /// Nothing typed yet: no attempt counted.
        case notReady
    }

    /// Answers have two digits; a third digit is allowed so the pad gives no hint.
    static let maxDigits = 3

    private(set) var question: GateQuestion
    /// The digits typed so far.
    private(set) var entry = ""
    /// Answers checked since launch.
    private(set) var attempts = 0
    /// Wrong answers since launch.
    private(set) var failures = 0
    private var generator: SeededGenerator

    init(seed: UInt64) {
        var generator = SeededGenerator(seed: seed)
        question = Self.draw(using: &generator, avoiding: nil)
        self.generator = generator
    }

    var canCheck: Bool { !entry.isEmpty }

    mutating func type(_ digit: Int) {
        guard (0...9).contains(digit), entry.count < Self.maxDigits else { return }
        entry = entry == "0" ? String(digit) : entry + String(digit)
    }

    mutating func deleteLast() {
        if !entry.isEmpty { entry.removeLast() }
    }

    /// Checks the typed answer. Right or wrong, the next opening gets a new question.
    mutating func check() -> Outcome {
        guard let value = Int(entry) else { return .notReady }
        attempts += 1
        let passed = value == question.answer
        if !passed { failures += 1 }
        newQuestion()
        return passed ? .passed : .failed
    }

    /// Closing the gate without an answer clears what was typed and keeps the question.
    mutating func cancel() {
        entry = ""
    }

    /// A different question from the one on screen, and an empty entry.
    mutating func newQuestion() {
        question = Self.draw(using: &generator, avoiding: question)
        entry = ""
    }

    private static func draw(using generator: inout SeededGenerator, avoiding last: GateQuestion?) -> GateQuestion {
        while true {
            let next = GateQuestion(left: generator.pick(GateQuestion.leftFactors),
                                    right: generator.pick(GateQuestion.rightFactors))
            if next != last { return next }
        }
    }
}
