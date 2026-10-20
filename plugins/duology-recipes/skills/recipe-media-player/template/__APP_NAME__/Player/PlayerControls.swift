import SwiftUI

/// One set of controls for every pose: close, titles, Picture in Picture, AirPlay,
/// the up next card, the scrubber and the transport. In tabletop they all sit
/// below the fold; folded like a book, they all sit in the trailing region.
/// Every control has a title for VoiceOver and Voice Control, and a hit region of
/// at least 44 × 44 pt.
struct PlayerControls: View {
    @Bindable var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if model.upNext.isVisible, let next = model.next {
                UpNextView(model: model, next: next, show: model.catalog.show(of: next.id))
                    .transition(.opacity)
            }
            scrubber
            transport
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            IconButton("Close Player", systemImage: "chevron.down") {
                model.isPlayerPresented = false
            }
            .accessibilityIdentifier("player.close")
            VStack(alignment: .leading, spacing: 2) {
                Text(model.current?.title ?? "")
                    .font(.headline)
                if let show = model.currentShow {
                    Text(show.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if model.canPictureInPicture {
                IconButton(model.isPictureInPictureActive ? "Stop Picture in Picture" : "Picture in Picture",
                           systemImage: model.isPictureInPictureActive ? "pip.exit" : "pip.enter") {
                    model.togglePictureInPicture()
                }
                .disabled(!model.isPictureInPicturePossible && !model.isPictureInPictureActive)
                .accessibilityIdentifier("player.pip")
            }
            RoutePicker()
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")
        }
    }

    private var scrubber: some View {
        VStack(spacing: 2) {
            Slider(value: Binding(get: { model.position }, set: { model.seek(to: $0) }),
                   in: 0...max(model.duration, 0.1)) {
                Text("Playback Position")
            } onEditingChanged: { editing in
                model.setScrubbing(editing)
            }
            .tint(.white)
            .accessibilityValue("\(TimeText.spoken(model.position)) of \(TimeText.spoken(model.duration))")
            .accessibilityIdentifier("player.scrubber")
            HStack {
                Text(TimeText.clock(model.position))
                Spacer()
                Text(TimeText.remaining(model.position, of: model.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
    }

    private var transport: some View {
        HStack(spacing: 0) {
            speedMenu
            Spacer(minLength: 4)
            IconButton("Back 10 Seconds", systemImage: "gobackward.10") { model.skip(by: -10) }
                .accessibilityIdentifier("player.back")
            Button {
                model.togglePlayback()
            } label: {
                Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(.black)
                    .frame(width: 64, height: 64)
                    .background(.white, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .accessibilityIdentifier("player.playPause")
            IconButton("Forward 10 Seconds", systemImage: "goforward.10") { model.skip(by: 10) }
                .accessibilityIdentifier("player.forward")
            Spacer(minLength: 4)
            IconButton("Next Episode", systemImage: "forward.end.fill") { model.playNext() }
                .disabled(model.next == nil)
                .accessibilityIdentifier("player.next")
        }
        .font(.title2)
    }

    private var speedMenu: some View {
        Menu {
            Picker("Playback Speed", selection: Binding(get: { model.rate }, set: { model.setRate($0) })) {
                ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { rate in
                    Text(Self.rateLabel(rate)).tag(rate)
                }
            }
        } label: {
            Text(Self.rateLabel(model.rate))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Playback Speed")
        .accessibilityValue(Self.rateLabel(model.rate))
        .accessibilityIdentifier("player.speed")
    }

    static func rateLabel(_ rate: Float) -> String {
        Double(rate).formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}

/// "Up next" at the end of an episode. It lives inside the controls, so it moves
/// with them: below the fold in tabletop, trailing in book pose, never on the fold.
/// One row when it fits; on the narrow outer display the button drops below.
struct UpNextView: View {
    let model: PlayerModel
    let next: Episode
    let show: Show?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                summary
                Spacer(minLength: 4)
                playNow()
                cancel
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    summary
                    Spacer(minLength: 4)
                    cancel
                }
                playNow(fillsWidth: true)
            }
        }
        .padding(10)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upNext.card")
    }

    private var summary: some View {
        HStack(spacing: 12) {
            if let show {
                Artwork(show: show)
                    .frame(width: 48, height: 48)
                    .clipShape(.rect(cornerRadius: 10))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Text(next.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        }
    }

    /// On its own row, the button takes the card's whole width.
    private func playNow(fillsWidth: Bool = false) -> some View {
        Button {
            model.playNext()
        } label: {
            Text("Play Now")
                .font(.subheadline.weight(.semibold))
                .fixedSize()
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 32)
        }
        .buttonStyle(.glassProminent)
        .accessibilityIdentifier("upNext.playNow")
    }

    private var cancel: some View {
        IconButton("Cancel Up Next", systemImage: "xmark") { model.dismissUpNext() }
            .accessibilityIdentifier("upNext.cancel")
    }

    private var caption: String {
        switch model.upNext {
        case .counting(let seconds): "Up Next in \(seconds) s"
        default: "Up Next"
        }
    }
}

/// An icon-only button with a title for VoiceOver and Voice Control, and a 44 × 44 pt
/// hit region. The frame and content shape sit inside the label, so taps beside
/// the glyph still count.
struct IconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
