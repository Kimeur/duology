import SwiftUI

/// Two players, one phone. Each player taps their own half as fast as they can.
struct DuelScreen: View {
    @State private var model = DuelModel()

    var body: some View {
        ArrangementView {
            PlayerHalf(seat: .first, model: model)
        } secondary: {
            PlayerHalf(seat: .second, model: model)
        }
        .arrangementViewStyle(.split)
        .ignoresSafeArea()
        .overlay {
            if let winner = model.winner {
                VStack(spacing: 16) {
                    Text("\(winner.title) wins")
                        .font(.largeTitle.bold())
                    Button("Play again") {
                        model.reset()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("duel.playAgain")
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

struct PlayerHalf: View {
    let seat: Seat
    let model: DuelModel

    var body: some View {
        ZStack {
            (seat == .first ? Color.orange : Color.purple)
            VStack(spacing: 8) {
                Text(seat.title)
                    .font(.title2.bold())
                Text("\(model.count(for: seat)) / \(model.goal)")
                    .font(.system(size: 64, weight: .heavy).monospacedDigit())
                    .accessibilityIdentifier("\(seat.rawValue).score")
                Text("Tap anywhere on your side")
                    .font(.callout)
            }
            .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.tap(seat)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(seat.rawValue).half")
        .accessibilityAddTraits(.isButton)
    }
}
