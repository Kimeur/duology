import SwiftUI
import UIKit

/// The game screen: one half per player, in every pose and on both displays.
struct DuelScreen: View {
    let model: DuelModel
    let onLeave: () -> Void
    @State private var confirmsLeave = false

    var body: some View {
        // EvenSplit, not ArrangementView: closed and held sideways, a split arrangement
        // shows only its first view, and a two-player game needs both halves always.
        EvenSplit(spacing: 2) {
            PlayerHalf(player: .one, model: model, isTurned: model.faceToFace)
        } secondary: {
            // The only shared control (leave) lives in one half, in a half that never turns.
            PlayerHalf(player: .two, model: model) {
                confirmsLeave = true
            }
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
}

extension Player {
    var tint: Color { self == .one ? .indigo : .orange }
}
