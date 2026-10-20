import SwiftUI

/// One episode in the library list: artwork, title, length, progress.
struct EpisodeRow: View {
    let episode: Episode
    let show: Show
    let player: PlayerModel

    var body: some View {
        let progress = player.resume.progress(episode.id, duration: episode.duration)
        let finished = player.resume.isFinished(episode.id)
        let playing = player.current?.id == episode.id
        HStack(spacing: 14) {
            Artwork(show: show)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if playing {
                        Image(systemName: "waveform")
                            .foregroundStyle(.tint)
                            .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    }
                    Text("Episode \(episode.number) · \(TimeText.clock(episode.duration))")
                    if finished {
                        Label("Played", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if progress > 0, !finished {
                    ProgressView(value: progress)
                        .frame(maxWidth: 160)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState(progress: progress, finished: finished, playing: playing))
    }

    private func accessibilityState(progress: Double, finished: Bool, playing: Bool) -> String {
        if playing { return "Now playing" }
        if finished { return "Played" }
        if progress > 0 { return "\(Int(progress * 100)) percent played" }
        return ""
    }
}
