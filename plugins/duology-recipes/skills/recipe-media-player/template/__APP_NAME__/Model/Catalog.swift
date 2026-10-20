import Foundation

/// The shows and episodes the library lists, read from Media/Catalog.json.
///
/// Everything in Model/ uses Foundation (and CoreGraphics for geometry), never UIKit
/// or SwiftUI, and every type is `nonisolated` and `Sendable`. So the rules build and
/// run on the Mac in seconds: Tools/run-model-tests.sh.
nonisolated struct Catalog: Codable, Hashable, Sendable {
    let shows: [Show]

    static func decode(from data: Data) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: data)
    }

    /// Every episode, show by show, in catalogue order.
    var episodes: [Episode] { shows.flatMap(\.episodes) }

    func episode(_ id: Episode.ID) -> Episode? {
        episodes.first { $0.id == id }
    }

    /// The show an episode belongs to.
    func show(of id: Episode.ID) -> Show? {
        shows.first { show in show.episodes.contains { $0.id == id } }
    }

    /// The episodes that come after `id` in its show. Playing an episode queues these.
    func following(_ id: Episode.ID) -> [Episode] {
        guard let show = show(of: id), let index = show.episodes.firstIndex(where: { $0.id == id }) else {
            return []
        }
        return Array(show.episodes[(index + 1)...])
    }
}

nonisolated struct Show: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let host: String
    let summary: String
    /// An SF Symbol for the artwork.
    let symbol: String
    /// Two colours for the artwork, as hex RGB such as "E8743B".
    let colors: [String]
    let episodes: [Episode]
}

nonisolated struct Episode: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let number: Int
    let title: String
    let summary: String
    /// Length in seconds, as the catalogue gives it. The player reads the real
    /// length once the media loads.
    let duration: Double
    /// A file name in the app bundle ("small-repairs-1.mp4") or an https URL.
    let media: String
    /// Publication day, "yyyy-MM-dd".
    let published: String

    /// The bundle resource name and extension, or nil when `media` is a URL.
    var bundledFile: (name: String, ext: String)? {
        guard !media.contains("://") else { return nil }
        let parts = media.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let ext = parts.last, !ext.isEmpty else { return nil }
        return (parts.dropLast().joined(separator: "."), String(ext))
    }

    /// The publication day as a date, at midnight in the current time zone.
    var publishedDate: Date? {
        let parts = published.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// The stream URL when `media` is one, for example an HLS playlist.
    var remoteURL: URL? {
        guard media.hasPrefix("https://") else { return nil }
        return URL(string: media)
    }
}
