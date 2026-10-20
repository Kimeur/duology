import SwiftUI

/// What's playing, under the library, while the player screen is closed. Playback
/// goes on: the player lives in `PlayerModel`, not in the player screen.
struct MiniPlayer: View {
    let player: PlayerModel

    var body: some View {
        if let episode = player.current, let show = player.currentShow {
            HStack(spacing: 10) {
                Button {
                    player.isPlayerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Artwork(show: show)
                            .frame(width: 44, height: 44)
                            .clipShape(.rect(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(episode.title)
                                .font(.subheadline.weight(.semibold))
                            Text(show.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Now Playing, \(episode.title)")
                .accessibilityHint("Opens the player")
                .accessibilityIdentifier("mini.open")

                IconButton(player.isPlaying ? "Pause" : "Play",
                           systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                    player.togglePlayback()
                }
                .font(.title3)
                .accessibilityIdentifier("mini.playPause")
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
    }
}
