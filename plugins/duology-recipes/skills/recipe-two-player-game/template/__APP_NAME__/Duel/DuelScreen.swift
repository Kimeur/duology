import SwiftUI
import UIKit

/// The game screen: one half per player, in every pose and on both displays.
struct DuelScreen: View {
    let model: DuelModel
    let onLeave: () -> Void
    @State private var confirmsLeave = false
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        GeometryReader { proxy in
            // EvenSplit's own rule, read here so each half knows how to face its player.
            let sideBySide = proxy.size.width >= proxy.size.height
            // EvenSplit, not ArrangementView: closed and held sideways, a split arrangement
            // shows only its first view, and a two-player game needs both halves always.
            EvenSplit(spacing: 2) {
                half(.one, sideBySide: sideBySide)
            } secondary: {
                half(.two, sideBySide: sideBySide)
            }
            // Seats are places at the table: player 1 keeps the top or left half in every
            // language. Each half's content still lays out in the reader's direction.
            .environment(\.layoutDirection, .leftToRight)
        }
        .background(Color.secondary.ignoresSafeArea())    // shows through the 2 pt gap as a divider
        .persistentSystemOverlays(.hidden)                 // no home indicator over the game
        .defersSystemGestures(on: .all)                    // an edge swipe in play needs a second swipe
        .task { await model.runClock() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("Leave the game?", isPresented: $confirmsLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onLeave)
            Button("Keep playing", role: .cancel) {}
        }
    }

    /// One player's half. The only shared control (leave) lives in player 2's score bar,
    /// which sits at the edge away from the seam in every seating.
    private func half(_ player: Player, sideBySide: Bool) -> some View {
        PlayerHalf(
            player: player,
            model: model,
            direction: direction,
            quarterTurns: player.quarterTurns(faceToFace: model.faceToFace, sideBySide: sideBySide),
            onLeave: player == .two ? { confirmsLeave = true } : nil
        )
    }
}

extension Player {
    var tint: Color { self == .one ? .indigo : .orange }
}
