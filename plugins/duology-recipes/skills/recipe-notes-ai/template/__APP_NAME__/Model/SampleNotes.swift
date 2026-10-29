import Foundation

/// The notes a new install starts with, so there is something to summarize at once. Replace
/// them with your own welcome notes, or start empty (`all(now:)` returning []).
nonisolated enum SampleNotes {
    /// The sample notes, newest first, dated just before `now`.
    static func all(now: Date = Date()) -> [Note] {
        [
            Note(id: "sample.offsite", title: "Team offsite plan", body: offsite, modified: now.addingTimeInterval(-3_600)),
            Note(id: "sample.sourdough", title: "Sourdough, attempt 3", body: sourdough, modified: now.addingTimeInterval(-86_400)),
            Note(id: "sample.garden", title: "", body: garden, modified: now.addingTimeInterval(-3 * 86_400)),
            Note(id: "sample.groceries", title: "Groceries", body: groceries, modified: now.addingTimeInterval(-6 * 86_400)),
        ]
    }

    static let offsite = """
        We meet in Lyon on 12 March for two days. Most of the team arrives the night before, so the first session starts at 10.
        - Day one is for the roadmap and the hiring plan
        - Day two is for customer interviews, in small groups
        - Dinner on the first evening, near the hotel
        Budget is tight this year, so we share rooms and take the train.
        - [ ] Book the train tickets before Friday
        - [ ] Send the agenda to everyone
        - [x] Reserve the meeting room
        TODO: ask Sam about a vegetarian menu
        """

    static let sourdough = """
        The third loaf finally rose. I fed the starter twice the day before and kept the dough near the oven, which made the difference. The crumb was open but the crust burned on the bottom, so the stone needs to go one shelf higher. Next time I'll try 75% water instead of 70% and bake for five minutes less. The starter smells sour after three days in the fridge; feeding it twice brings it back.
        """

    static let garden = """
        Garden ideas for spring
        The tomatoes did well against the south wall last year, so they stay there. The shady corner by the shed could take ferns and hostas instead of grass. We should build a second compost bin before April, because the first one is full. Watering by hand took too long in July. A soaker hose on a timer would save an hour a day.
        """

    static let groceries = """
        Eggs, oats, lemons
        Coffee
        """
}
