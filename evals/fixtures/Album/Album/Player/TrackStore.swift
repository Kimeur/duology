import Foundation

/// Loads the track list. The delay stands in for a network request.
@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published var nowPlaying: Track?

    func load(_ album: Album) async {
        try? await Task.sleep(for: .milliseconds(700))
        tracks = album.tracks
        if nowPlaying == nil { nowPlaying = album.tracks.first }
    }
}
