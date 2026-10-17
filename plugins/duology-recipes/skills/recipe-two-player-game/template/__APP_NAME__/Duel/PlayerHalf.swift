import SwiftUI

/// One player's half: the play field and a score bar, turned around in face-to-face mode.
struct PlayerHalf: View {
    let player: Player
    let model: DuelModel
    var isTurned = false
    var onLeave: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            PlayField(player: player, model: model)
            ScoreBar(player: player, model: model, onLeave: onLeave)
        }
        // Clip first, so nothing in this half can draw over or take touches from the other.
        .clipped()
        // Turning the whole half keeps its coordinate space: touches still arrive in
        // the half's own coordinates, so the engine never knows the half is upside down.
        .rotationEffect(isTurned ? .degrees(180) : .zero)
        // The colour runs to the screen edges; the content stays inside the safe area.
        .background {
            ZStack {
                Color(.systemBackground)
                player.tint.opacity(0.14)
            }
            .ignoresSafeArea()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(player.name)
        .accessibilityIdentifier("\(player.id).half")
    }
}

/// Where the targets appear. It has its own coordinate space and its own tap gesture,
/// so the same code runs in the top, bottom, left or right half, turned or not.
struct PlayField: View {
    let player: Player
    let model: DuelModel
    /// The part of this field where targets may sit: clear of the fold and the cameras.
    @State private var area = GameRect.zero

    private var space: NamedCoordinateSpace { .named("\(player.id).field") }

    var body: some View {
        ZStack {
            // The touch surface: a clear layer under everything, so the whole field takes
            // taps. It sits beside the content, not around it: a .contentShape on the
            // container gives every element inside it the container's accessibility frame.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture(coordinateSpace: space)
                        .onEnded { value in
                            model.tap(player, at: GamePoint(value.location), in: area)
                        }
                )
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(space)
        .onGeometryChange(for: GameRect.self) { proxy in
            FoldAvoidance.playArea(in: proxy, margin: 12)
        } action: { newArea in
            area = newArea
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.hitCount[player, default: 0])
        .sensoryFeedback(.error, trigger: model.missCount[player, default: 0])
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(player.id).field")
    }

    @ViewBuilder
    private var content: some View {
        let duel = model.duel
        switch duel.phase {
        case .waiting:
            ReadyPanel(player: player, model: model)
        case .countdown:
            let seconds = duel.countdownRemaining(now: model.now) ?? 0
            Text("\(seconds)")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(player.tint)
                .accessibilityLabel("Starting in \(seconds)")
                .accessibilityIdentifier("\(player.id).countdown")
                .allowsHitTesting(false)
        case .playing:
            if let target = duel.target(for: player, in: area) {
                // Accessibility inside TargetView, then .position: the element keeps
                // the circle's frame, so VoiceOver and UI tests find the real target.
                TargetView(player: player, radius: target.radius) {
                    model.activateTarget(player, in: area)
                }
                .position(CGPoint(target.center))
            }
            if duel.isLocked(player, now: model.now) {
                Text("Missed. Wait.")
                    .font(.title3.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .accessibilityIdentifier("\(player.id).locked")
                    .allowsHitTesting(false)
            }
        case .finished(let outcome):
            ResultPanel(player: player, outcome: outcome, model: model)
        }
    }
}

struct TargetView: View {
    let player: Player
    let radius: Double
    let activate: () -> Void

    var body: some View {
        Circle()
            .fill(player.tint.gradient)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 4))
            .overlay(Circle().fill(.white).frame(width: radius * 0.5, height: radius * 0.5))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .frame(width: radius * 2, height: radius * 2)
            .accessibilityElement()
            .accessibilityLabel("Target")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { activate() }
            .accessibilityIdentifier("\(player.id).target")
            // Touches go through to the field's touch surface, which judges hit or miss.
            // VoiceOver uses the accessibility action instead.
            .allowsHitTesting(false)
    }
}

/// Score, misses, time left and, in one half only, the leave button.
struct ScoreBar: View {
    let player: Player
    let model: DuelModel
    let onLeave: (() -> Void)?

    var body: some View {
        // The full bar if it fits, a shorter one in narrow halves or at large text sizes.
        ViewThatFits(in: .horizontal) {
            bar(showsMisses: true)
            bar(showsMisses: false)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(player.tint.opacity(0.12))
    }

    private func bar(showsMisses: Bool) -> some View {
        let duel = model.duel
        let state = duel[player]
        return HStack(spacing: 12) {
            Circle()
                .fill(player.tint)
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text("\(state.hits) / \(duel.rules.goal)")
                .font(.title2.bold())
                .monospacedDigit()
                .accessibilityLabel("\(player.name), \(state.hits) of \(duel.rules.goal) hits")
                .accessibilityIdentifier("\(player.id).score")
            if showsMisses && state.misses > 0 {
                Text(state.misses == 1 ? "1 miss" : "\(state.misses) misses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(player.id).misses")
            }
            Spacer(minLength: 8)
            if let left = duel.timeRemaining(now: model.now) {
                let seconds = Int(left.rounded(.up))
                Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityLabel("\(seconds) seconds left")
                    .accessibilityIdentifier("\(player.id).clock")
            }
            if let onLeave {
                Button(action: onLeave) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Leave game")
                .accessibilityIdentifier("duel.leave")
            }
        }
        .lineLimit(1)
    }
}

/// Before a round: each player says they're ready, in their own half.
struct ReadyPanel: View {
    let player: Player
    let model: DuelModel

    var body: some View {
        let isReady = model.duel[player].isReady
        VStack(spacing: 14) {
            Text(player.name)
                .font(.largeTitle.bold())
                .foregroundStyle(player.tint)
            Text(isReady ? "Waiting for \(player.other.name)" : "Tap Ready when you're set.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(player.id).prompt")
            Button {
                model.toggleReady(player)
            } label: {
                Text(isReady ? "Not ready" : "Ready")
                    .font(.title3.bold())
                    .frame(minWidth: 160, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.tint)
            .accessibilityIdentifier("\(player.id).ready")
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

/// After a round: the result from this player's side, and Rematch.
struct ResultPanel: View {
    let player: Player
    let outcome: Outcome
    let model: DuelModel

    private var title: String {
        switch outcome {
        case .won(let winner): winner == player ? "You win!" : "\(winner.name) wins"
        case .tie: "Tie game"
        }
    }

    var body: some View {
        let duel = model.duel
        let isReady = duel[player].isReady
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(player.tint)
                .accessibilityIdentifier("\(player.id).result")
            Text("\(duel[player].hits) to \(duel[player.other].hits)")
                .font(.title3.monospacedDigit())
                .accessibilityLabel("You \(duel[player].hits), \(player.other.name) \(duel[player.other].hits)")
            if isReady {
                Text("Waiting for \(player.other.name)")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(player.id).prompt")
            }
            Button {
                model.toggleReady(player)
            } label: {
                Text(isReady ? "Cancel rematch" : "Rematch")
                    .font(.title3.bold())
                    .frame(minWidth: 160, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(player.tint)
            .accessibilityIdentifier("\(player.id).rematch")
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}
