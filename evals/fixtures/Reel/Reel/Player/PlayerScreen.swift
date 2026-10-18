import SwiftUI
import UIKit

struct PlayerScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            // Big screen: video on the left, the queue on the right.
            HStack(spacing: 0) {
                VideoPane()
                UpNextList()
                    .frame(width: 320)
            }
        } else {
            // Phone: video on top, the queue below.
            VStack(spacing: 0) {
                VideoPane()
                    .frame(height: UIScreen.main.bounds.width * 9 / 16)
                UpNextList()
            }
        }
    }
}

struct UpNextList: View {
    var body: some View {
        List {
            Section("Up next") {
                ForEach(Episode.queue) { episode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.title)
                            .font(.headline)
                        Text(episode.length)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct Episode: Identifiable {
    let id: Int
    let title: String
    let length: String

    static let queue: [Episode] = [
        Episode(id: 1, title: "Test pattern, part 2", length: "1 min"),
        Episode(id: 2, title: "Test pattern, part 3", length: "1 min"),
        Episode(id: 3, title: "Colour bars", length: "2 min"),
        Episode(id: 4, title: "Counting seconds", length: "1 min"),
    ]
}
