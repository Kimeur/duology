import SwiftUI

struct AlbumScreen: View {
    let album: Album
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isWide = false
    @State private var showsPlayer = false

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 32) {
                    AlbumArt(album: album)
                        .frame(maxWidth: 360)
                    TrackList(album: album)
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        AlbumArt(album: album)
                            .padding(.horizontal, 40)
                        TrackList(album: album)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isWide ? Color.black : Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            PlayerBar(isWide: isWide)
                .opacity(showsPlayer ? 1 : 0)
        }
        .onAppear {
            isWide = sizeClass == .regular
            showsPlayer = true
        }
        .onChange(of: sizeClass) { _, newValue in
            showsPlayer = false
            withAnimation(.bouncy(duration: 0.8)) {
                isWide = newValue == .regular
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeIn(duration: 0.3)) { showsPlayer = true }
            }
        }
    }
}

struct AlbumArt: View {
    let album: Album
    @State private var appeared = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title).font(.title.bold())
                    Text("\(album.artist) · \(String(album.year))").font(.headline)
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            }
            .accessibilityElement(children: .combine)
    }
}

struct TrackList: View {
    let album: Album
    @StateObject private var store = TrackStore()

    var body: some View {
        Group {
            if store.tracks.isEmpty {
                ProgressView("Loading tracks")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.tracks) { track in
                        TrackRow(track: track, isPlaying: track == store.nowPlaying)
                            .onTapGesture { store.nowPlaying = track }
                        Divider()
                    }
                }
            }
        }
        .task { await store.load(album) }
    }
}

struct TrackRow: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(track.id)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)
            Text(track.title)
                .fontWeight(isPlaying ? .semibold : .regular)
            Spacer()
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
            }
            Text(track.length)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPlaying ? [.isButton, .isSelected] : .isButton)
    }
}

struct PlayerBar: View {
    let isWide: Bool
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: isWide ? 40 : 24) {
            Button("Previous", systemImage: "backward.fill") {}
                .accessibilityIdentifier("player.previous")
            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                isPlaying.toggle()
            }
            .accessibilityIdentifier("player.play")
            Button("Next", systemImage: "forward.fill") {}
                .accessibilityIdentifier("player.next")
        }
        .labelStyle(.iconOnly)
        .font(isWide ? .largeTitle : .title2)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 8)
    }
}
