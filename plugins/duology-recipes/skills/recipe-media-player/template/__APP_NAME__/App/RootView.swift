import Observation
import SwiftUI

/// What the library has selected. Lives above the split view, so a fold never loses it.
@Observable
final class LibraryModel {
    var selection: Episode.ID?

    init(selection: Episode.ID? = nil) {
        self.selection = selection
    }
}

/// The window's root. It owns the library selection and the one `PlayerModel`, and
/// never changes identity: the split view, the player screen and every layout
/// decision sit below it. The player screen is a full-screen cover attached here,
/// so folding, unfolding and rotating never close it or restart playback.
struct RootView: View {
    @State private var library = LibraryModel(selection: LaunchOptions.selection)
    @State private var player = PlayerModel.launch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        LibraryView(library: library, player: player)
            .fullScreenCover(isPresented: $player.isPlayerPresented) {
                PlayerScreen(model: player)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: player.sceneMovedToBackground(true)
                case .active: player.sceneMovedToBackground(false)
                default: player.saveProgress()
                }
            }
            // Keep the screen on while a video plays on screen, and only then.
            .onChange(of: player.isPlaying && player.isPlayerPresented, initial: true) { _, watching in
                UIApplication.shared.isIdleTimerDisabled = watching
            }
            .testMarker("player.state", value: player.testSummary)
    }
}
