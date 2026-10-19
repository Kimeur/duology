import Foundation

struct Recipe {
    struct Step: Identifiable, Equatable {
        let id: Int
        let title: String
        let text: String
        /// How long the step takes, if it needs a timer.
        let minutes: Int?
    }

    let name: String
    let steps: [Step]
}

extension Recipe {
    static let shakshuka = Recipe(name: "Shakshuka", steps: [
        Step(id: 1, title: "Soften the onion",
             text: "Warm two tablespoons of olive oil in a wide pan over medium heat. Add the sliced onion and a pinch of salt, and cook until soft and golden.",
             minutes: 8),
        Step(id: 2, title: "Add the peppers",
             text: "Stir in the sliced red pepper and two crushed garlic cloves. Cook until the pepper starts to collapse, stirring now and then.",
             minutes: 6),
        Step(id: 3, title: "Toast the spices",
             text: "Add a teaspoon each of cumin and sweet paprika and a pinch of chilli flakes. Stir for a minute until they smell toasty.",
             minutes: 1),
        Step(id: 4, title: "Simmer the tomatoes",
             text: "Pour in two tins of crushed tomatoes, season with salt and pepper, and let the sauce thicken over low heat.",
             minutes: 10),
        Step(id: 5, title: "Cook the eggs",
             text: "Make six small wells in the sauce and crack an egg into each. Cover the pan and cook until the whites are set but the yolks are still soft.",
             minutes: 7),
        Step(id: 6, title: "Finish and serve",
             text: "Scatter crumbled feta and chopped parsley over the top. Serve straight from the pan with warm bread.",
             minutes: nil),
    ])
}
