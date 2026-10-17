import SwiftUI

/// Tabs to sidebar: a music library.
///
/// Closed, the tabs are a tab bar, on the side of the outer display. Open, the
/// same tabs become a sidebar, with the Library tabs grouped in a section.
/// `defaultTabBarPlacement(.sidebar)` (iOS 27.0) only acts on a `TabView`
/// with the `sidebarAdaptable` style, so the two always go together.
///
/// Pattern guide: `duo-patterns/references/tabs-to-sidebar.md`.
struct TabsToSidebarView: View {
    enum MusicTab: String, Hashable {
        case listenNow, browse, radio, recent, albums, artists, songs, search
    }

    // The same tab stays selected through fold, unfold and relaunch.
    @SceneStorage("music.tab") private var selection = MusicTab.listenNow

    var body: some View {
        TabView(selection: $selection) {
            Tab("Listen Now", systemImage: "play.circle", value: MusicTab.listenNow) {
                MusicScreen(title: "Listen Now") { ListenNowScreen(selection: $selection) }
            }
            Tab("Browse", systemImage: "square.grid.2x2", value: MusicTab.browse) {
                MusicScreen(title: "Browse") { BrowseScreen() }
            }
            Tab("Radio", systemImage: "dot.radiowaves.left.and.right", value: MusicTab.radio) {
                MusicScreen(title: "Radio") { RadioScreen() }
            }
            // Sections group tabs in the sidebar. Every one of these tabs is still
            // reachable from the tab bar when the phone is closed.
            TabSection("Library") {
                Tab("Recently Added", systemImage: "clock", value: MusicTab.recent) {
                    MusicScreen(title: "Recently Added") { AlbumGrid(albums: Array(Album.samples.prefix(6))) }
                }
                Tab("Albums", systemImage: "square.stack", value: MusicTab.albums) {
                    MusicScreen(title: "Albums") { AlbumGrid(albums: Album.samples) }
                }
                Tab("Artists", systemImage: "music.mic", value: MusicTab.artists) {
                    MusicScreen(title: "Artists") { ArtistList() }
                }
                Tab("Songs", systemImage: "music.note", value: MusicTab.songs) {
                    MusicScreen(title: "Songs") { SongList() }
                }
            }
            Tab(value: MusicTab.search, role: .search) {
                MusicScreen(title: "Search") { SearchScreen() }
            }
        }
        // Required: defaultTabBarPlacement only acts on this style.
        .tabViewStyle(.sidebarAdaptable)
        .sidebarWhereAvailable()
    }
}

extension View {
    /// Asks for a sidebar where the bar can't switch between forms (iPhone Duo's
    /// inner display). Earlier systems keep their tab bar.
    @ViewBuilder
    func sidebarWhereAvailable() -> some View {
        if #available(iOS 27.0, *) {
            defaultTabBarPlacement(.sidebar)
        } else {
            self
        }
    }
}

/// Each tab gets its own navigation stack, title and Close button.
/// A stack, not a split view: a split view inside a tab would put a second
/// sidebar next to the tab sidebar.
private struct MusicScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .galleryCloseButton()
        }
    }
}

// MARK: - Screens

private struct ListenNowScreen: View {
    @Binding var selection: TabsToSidebarView.MusicTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if #available(iOS 27.0, *) {
                    LibraryShortcuts(selection: $selection)
                } else {
                    // No sidebar before iOS 27: the shortcuts always help.
                    LibraryShortcutGrid(selection: $selection)
                }
                ShelfRow(title: "Top Picks for You", albums: Array(Album.samples.prefix(6)))
                ShelfRow(title: "Recently Played", albums: Array(Album.samples.suffix(6)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Made for You").font(.title3.weight(.bold))
                    ForEach(Song.samples.prefix(4)) { song in
                        SongRow(song: song)
                        Divider()
                    }
                }
            }
            .containerMargins(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

/// Shortcuts that repeat the Library tabs. Hidden when the sidebar already lists them.
/// This removes a duplicate, never a feature.
@available(iOS 27.0, *)
private struct LibraryShortcuts: View {
    @Binding var selection: TabsToSidebarView.MusicTab
    @Environment(\.isTabViewSidebarAvailable) private var sidebarAvailable

    var body: some View {
        if !sidebarAvailable {
            LibraryShortcutGrid(selection: $selection)
        }
    }
}

private struct LibraryShortcutGrid: View {
    @Binding var selection: TabsToSidebarView.MusicTab

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library").font(.title3.weight(.bold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                shortcut("Albums", "square.stack", .albums)
                shortcut("Artists", "music.mic", .artists)
                shortcut("Songs", "music.note", .songs)
                shortcut("Recently Added", "clock", .recent)
            }
        }
    }

    private func shortcut(_ title: String, _ symbol: String, _ section: TabsToSidebarView.MusicTab) -> some View {
        Button {
            selection = section
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ShelfRow: View {
    let title: String
    let albums: [Album]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(albums) { album in
                        AlbumCard(album: album)
                            .frame(width: 150)
                    }
                }
            }
            // Stop at the margin, so shelves don't run under a vertical tab bar.
            .clipped()
        }
    }
}

private struct AlbumGrid: View {
    let albums: [Album]
    @ScaledMetric(relativeTo: .body) private var minTile = 150.0

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minTile), spacing: 16)], spacing: 20) {
                ForEach(albums) { album in
                    AlbumCard(album: album)
                }
            }
            .containerMargins(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct AlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArt(album: album)
            Text(album.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(album.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AlbumArt: View {
    let album: Album
    var cornerRadius: CGFloat = 12

    var body: some View {
        LinearGradient(colors: [album.colors.0, album.colors.1], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: album.symbol)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct BrowseScreen: View {
    private let genres: [(String, String, Color)] = [
        ("Indie", "guitars.fill", Color(hex: 0xC0266D)), ("Jazz", "music.quarternote.3", Color(hex: 0x2B55C7)),
        ("Electronic", "waveform", Color(hex: 0x7A4CD9)), ("Classical", "pianokeys", Color(hex: 0x0E7490)),
        ("Folk", "leaf.fill", Color(hex: 0x3F7D20)), ("Focus", "headphones", Color(hex: 0x4A5A6E)),
        ("Soul", "heart.fill", Color(hex: 0xC2410C)), ("Ambient", "cloud.fill", Color(hex: 0x5BC0BE))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(genres, id: \.0) { genre in
                    ZStack(alignment: .bottomLeading) {
                        Rectangle().fill(genre.2.gradient)
                        Image(systemName: genre.1)
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(14)
                        Text(genre.0)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(14)
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .containerMargins(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

private struct RadioScreen: View {
    private let stations: [(String, String, Color)] = [
        ("Harbour FM", "Live · coastal folk and slow rock", Color(hex: 0x0E7490)),
        ("Night Shift", "Live · deep house until 6 a.m.", Color(hex: 0x7A4CD9)),
        ("The Long Read", "Talk · essays read aloud", Color(hex: 0xC2410C))
    ]

    var body: some View {
        List {
            ForEach(stations, id: \.0) { station in
                HStack(spacing: 14) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(station.2.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.0).font(.headline)
                        Text(station.1).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Play", systemImage: "play.fill") {}
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct ArtistList: View {
    var body: some View {
        List(Album.artists, id: \.self) { artist in
            HStack(spacing: 12) {
                InitialsAvatar(name: artist, color: Album.samples.first { $0.artist == artist }?.colors.1 ?? .gray, size: 44)
                Text(artist).font(.body.weight(.medium))
            }
        }
    }
}

private struct SongList: View {
    var body: some View {
        List(Song.samples) { song in
            SongRow(song: song)
        }
        .listStyle(.plain)
    }
}

private struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            AlbumArt(album: song.album, cornerRadius: 6)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.body)
                Text(song.album.artist).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(song.length)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct SearchScreen: View {
    @State private var query = ""

    private var results: [Song] {
        query.isEmpty ? Song.samples
            : Song.samples.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.album.artist.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(results) { song in
            SongRow(song: song)
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Artists, albums, songs")
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

// MARK: - Sample library

struct Album: Identifiable, Hashable {
    let id: Int
    var title: String
    var artist: String
    var symbol: String
    var colors: (Color, Color)

    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let samples: [Album] = [
        Album(id: 1, title: "Low Tide Hours", artist: "The Marlowe Set", symbol: "water.waves", colors: (Color(hex: 0x5BC0BE), Color(hex: 0x0E7490))),
        Album(id: 2, title: "Copper Lines", artist: "Ines Vale", symbol: "sun.horizon.fill", colors: (Color(hex: 0xE8B65A), Color(hex: 0xC2410C))),
        Album(id: 3, title: "North of Nowhere", artist: "Kestrel Avenue", symbol: "mountain.2.fill", colors: (Color(hex: 0x98A6B8), Color(hex: 0x2B55C7))),
        Album(id: 4, title: "Night Bus Tapes", artist: "Corvo", symbol: "moon.stars.fill", colors: (Color(hex: 0x6E5BD6), Color(hex: 0x1E2A4A))),
        Album(id: 5, title: "Glass Orchard", artist: "Halden", symbol: "leaf.fill", colors: (Color(hex: 0x8DB580), Color(hex: 0x3F7D20))),
        Album(id: 6, title: "Second Light", artist: "Maren Ash", symbol: "sparkles", colors: (Color(hex: 0xF08BB4), Color(hex: 0x7A4CD9))),
        Album(id: 7, title: "Weather Report From Home", artist: "Ines Vale", symbol: "cloud.sun.fill", colors: (Color(hex: 0x6E8EF5), Color(hex: 0x5BC0BE))),
        Album(id: 8, title: "Small Hours", artist: "The Marlowe Set", symbol: "clock.fill", colors: (Color(hex: 0x4A5A6E), Color(hex: 0x17221B))),
        Album(id: 9, title: "Paper Boats", artist: "Kestrel Avenue", symbol: "sailboat.fill", colors: (Color(hex: 0xE07A4F), Color(hex: 0xC0266D))),
        Album(id: 10, title: "Signal Fires", artist: "Halden", symbol: "flame.fill", colors: (Color(hex: 0xE8B65A), Color(hex: 0xB4441F)))
    ]

    static var artists: [String] {
        Array(Set(samples.map(\.artist))).sorted()
    }
}

struct Song: Identifiable {
    let id: Int
    var title: String
    var album: Album
    var length: String

    static let samples: [Song] = [
        Song(id: 1, title: "Harbour Lights", album: Album.samples[0], length: "3:42"),
        Song(id: 2, title: "Slow Ferry", album: Album.samples[0], length: "4:15"),
        Song(id: 3, title: "Rust and Gold", album: Album.samples[1], length: "3:28"),
        Song(id: 4, title: "Altitude", album: Album.samples[2], length: "5:02"),
        Song(id: 5, title: "Last Stop", album: Album.samples[3], length: "6:11"),
        Song(id: 6, title: "Windfall", album: Album.samples[4], length: "3:57"),
        Song(id: 7, title: "Early Riser", album: Album.samples[5], length: "2:49"),
        Song(id: 8, title: "Kitchen Radio", album: Album.samples[6], length: "3:33"),
        Song(id: 9, title: "Two A.M.", album: Album.samples[7], length: "4:40"),
        Song(id: 10, title: "Fold the Map", album: Album.samples[8], length: "3:16"),
        Song(id: 11, title: "Ember", album: Album.samples[9], length: "4:05"),
        Song(id: 12, title: "Open Water", album: Album.samples[0], length: "5:24")
    ]
}
