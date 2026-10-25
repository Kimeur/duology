import Foundation

/// The built-in sample content: three activities, four questions each, written for this
/// template. Plain Swift data, so the content needs no network and the Mac tests check it.
/// Replace it with your own; keep every ID stable once people have stars for it.
nonisolated enum SampleActivities {
    static let all: [Activity] = [counting, letters, shapes]

    // MARK: Counting

    static let counting = Activity(
        id: "counting", title: "Counting", symbol: "number.circle.fill", tint: .orange,
        questions: [
            countQuestion("stars", symbol: "star.fill", one: "star", count: 3, choices: [2, 3, 4], tint: .yellow),
            countQuestion("fish", symbol: "fish.fill", one: "fish", count: 5, choices: [4, 5, 6], tint: .blue,
                          plural: "fish"),
            countQuestion("leaves", symbol: "leaf.fill", one: "leaf", count: 2, choices: [1, 2, 3], tint: .green,
                          plural: "leaves"),
            countQuestion("balloons", symbol: "balloon.fill", one: "balloon", count: 4, choices: [3, 4, 5], tint: .red),
        ])

    private static func countQuestion(_ key: String, symbol: String, one: String, count: Int, choices: [Int],
                                      tint: Tint, plural: String? = nil) -> Question {
        let many = plural ?? one + "s"
        return Question(
            id: "counting.\(key)",
            text: "How many \(many)?",
            spoken: "How many \(many) can you count?",
            art: .group(symbol, count: count, name: one, tint),
            artLabel: "\(many.capitalized) to count",
            answers: choices.map { Answer(id: "\($0)", label: "\($0)", art: .number($0)) },
            correct: "\(count)")
    }

    // MARK: First letters

    static let letters = Activity(
        id: "letters", title: "First letters", symbol: "textformat.abc", tint: .purple,
        questions: [
            letterQuestion("B", answers: [bus, sun, fish], correct: "bus"),
            letterQuestion("C", answers: [moon, car, leaf], correct: "car"),
            letterQuestion("S", answers: [house, bird, sun], correct: "sun"),
            letterQuestion("M", answers: [moon, tree, car], correct: "moon"),
        ])

    private static let bus = Answer(id: "bus", label: "Bus", art: .symbol("bus.fill", .orange))
    private static let sun = Answer(id: "sun", label: "Sun", art: .symbol("sun.max.fill", .yellow))
    private static let fish = Answer(id: "fish", label: "Fish", art: .symbol("fish.fill", .blue))
    private static let car = Answer(id: "car", label: "Car", art: .symbol("car.fill", .red))
    private static let moon = Answer(id: "moon", label: "Moon", art: .symbol("moon.fill", .purple))
    private static let leaf = Answer(id: "leaf", label: "Leaf", art: .symbol("leaf.fill", .green))
    private static let house = Answer(id: "house", label: "House", art: .symbol("house.fill", .brown))
    private static let bird = Answer(id: "bird", label: "Bird", art: .symbol("bird.fill", .blue))
    private static let tree = Answer(id: "tree", label: "Tree", art: .symbol("tree.fill", .green))

    private static func letterQuestion(_ letter: String, answers: [Answer], correct: String) -> Question {
        Question(
            id: "letters.\(letter.lowercased())",
            text: "Which one starts with \(letter)?",
            spoken: "Which picture starts with the letter \(letter)?",
            art: .letter(letter),
            artLabel: "Letter \(letter)",
            answers: answers,
            correct: correct)
    }

    // MARK: Shapes

    static let shapes = Activity(
        id: "shapes", title: "Shapes", symbol: "triangle.fill", tint: .green,
        questions: [
            shapeQuestion("circle", answers: ["circle", "square", "triangle"], tint: .blue),
            shapeQuestion("triangle", answers: ["star", "triangle", "circle"], tint: .red),
            shapeQuestion("square", answers: ["heart", "circle", "square"], tint: .purple),
            shapeQuestion("star", answers: ["star", "heart", "diamond", "circle"], tint: .orange),
        ])

    /// The question shows an outline; the answers are filled shapes in other colours,
    /// so a child matches the shape, not the colour.
    private static func shapeQuestion(_ shape: String, answers: [String], tint: Tint) -> Question {
        let colours: [Tint] = [.pink, .mint, .orange, .blue, .purple]
        return Question(
            id: "shapes.\(shape)",
            text: "Find the same shape.",
            spoken: "Can you find the same shape? Tap it.",
            art: .symbol(shape, tint),
            artLabel: shape.capitalized,
            answers: answers.enumerated().map { index, name in
                Answer(id: name, label: name.capitalized, art: .symbol(name + ".fill", colours[index % colours.count]))
            },
            correct: shape)
    }
}
