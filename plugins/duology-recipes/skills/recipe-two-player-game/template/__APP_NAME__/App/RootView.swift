import SwiftUI

/// What the home screen sets up before a duel.
struct DuelSetup: Equatable {
    var rules = DuelRules()
    /// Turns player 1's half around, for a phone lying flat between two people.
    var faceToFace = false
    /// A fixed seed replays the same targets. `nil` picks new ones every game.
    var seed: UInt64?
}

/// Home, or a duel. The duel's model lives here, above every layout decision, so
/// folding, unfolding and rotating never restart a game.
struct RootView: View {
    @State private var setup = LaunchOptions.setup()
    @State private var duel: DuelModel? = LaunchOptions.launchDuel()

    var body: some View {
        if let duel {
            DuelScreen(model: duel) {
                self.duel = nil
            }
        } else {
            HomeView(setup: $setup) {
                duel = DuelModel(setup: setup)
            }
        }
    }
}
