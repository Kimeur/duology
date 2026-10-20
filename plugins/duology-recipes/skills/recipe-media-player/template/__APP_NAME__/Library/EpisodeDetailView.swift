import SwiftUI

/// The detail column: what the episode is about, and the button that plays it.
/// One readable column, so it works at the outer display's width and in the
/// trailing half of the open phone when the split view evens out at the fold.
struct EpisodeDetailView: View {
    let episode: Episode
    let show: Show
    let player: PlayerModel
    let library: LibraryModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Artwork(show: show, episodeNumber: episode.number)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 22))

                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title)
                        .font(.subheadline.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(episode.title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(metadata)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                playButton

                Text(episode.summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Hosted by \(show.host).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                let following = player.catalog.following(episode.id)
                if !following.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Next in \(show.title)")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                        ForEach(following) { next in
                            Button {
                                library.selection = next.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(next.title)
                                            .font(.headline)
                                        Text("Episode \(next.number) · \(TimeText.clock(next.duration))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .frame(minHeight: 44)
                                .background(.fill.tertiary, in: .rect(cornerRadius: 14))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Shows this episode")
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadata: String {
        var parts = ["Episode \(episode.number)"]
        if let date = episode.publishedDate {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        parts.append(TimeText.spoken(episode.duration))
        return parts.joined(separator: " · ")
    }

    private var playButton: some View {
        let resumeAt = player.resume.resume(episode.id)
        let title: String
        if player.current?.id == episode.id {
            title = "Open Player"
        } else if resumeAt > 0 {
            title = "Resume from \(TimeText.clock(resumeAt))"
        } else if player.resume.isFinished(episode.id) {
            title = "Play Again"
        } else {
            title = "Play"
        }
        return Button {
            if player.current?.id != episode.id {
                player.play(episode)
            }
            player.isPlayerPresented = true
        } label: {
            Label(title, systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: 360, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .accessibilityIdentifier("detail.play")
    }
}
