import SwiftUI

/// The library: shows and episodes in the sidebar, the chosen episode in the detail.
///
/// One `NavigationSplitView` for both displays. Closed, it collapses to one stack
/// on its own; open, both columns show; folded like a book, the system evens the
/// columns out at the fold. The selection lives in `LibraryModel`, above the split
/// view, so a fold never loses it. Never swap this for a `NavigationStack` by size class.
struct LibraryView: View {
    @Bindable var library: LibraryModel
    @Bindable var player: PlayerModel
    @State private var fold = FoldGeometry()
    @State private var width: CGFloat = 0

    var body: some View {
        NavigationSplitView {
            List(selection: $library.selection) {
                ForEach(player.catalog.shows) { show in
                    Section {
                        ForEach(show.episodes) { episode in
                            EpisodeRow(episode: episode, show: show, player: player)
                                .tag(episode.id)
                                .accessibilityIdentifier("episode.\(episode.id)")
                        }
                    } header: {
                        ShowHeader(show: show)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Toggle("Play Next Episode Automatically", isOn: $player.upNextPolicy.autoplay)
                    } label: {
                        Label("Playback Options", systemImage: "ellipsis")
                    }
                    .accessibilityIdentifier("library.options")
                }
            }
        } detail: {
            if let id = library.selection, let episode = player.catalog.episode(id),
               let show = player.catalog.show(of: id) {
                EpisodeDetailView(episode: episode, show: show, player: player, library: library)
                    // A new episode gets a fresh detail (scrolled to the top), on purpose.
                    .id(episode.id)
            } else {
                ContentUnavailableView("Choose an Episode", systemImage: "play.rectangle.on.rectangle",
                                       description: Text("Pick an episode from the library to read about it and play it."))
            }
        }
        // The mini player rides under both columns. Its span comes from the fold, so on
        // the open phone it stays on the trailing side of the fold line, flat or folded.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.current != nil, !player.isPlayerPresented {
                let span = FoldRegions.floatingBarSpan(width: width, fold: fold)
                MiniPlayer(player: player)
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 16)
                    .frame(width: max(0, span.maxX - span.minX))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 8)
            }
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct ShowHeader: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(show.title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text("With \(show.host)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }
}
