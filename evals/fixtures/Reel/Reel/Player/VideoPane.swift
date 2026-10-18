import AVKit
import SwiftUI

enum Clip {
    /// A 60-second test pattern with a running counter, bundled with the app.
    static var url: URL {
        Bundle.main.url(forResource: "clip", withExtension: "mp4")!
    }
}

struct VideoPane: View {
    @State private var player = AVPlayer(url: Clip.url)
    @State private var elapsed: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
            Text(Self.format(elapsed))
                .font(.caption.monospacedDigit())
                .padding(6)
                .background(.thinMaterial, in: Capsule())
                .padding(8)
                .accessibilityLabel("Elapsed time")
        }
        .onAppear {
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { time in
                elapsed = time.seconds
            }
            player.play()
        }
        .onDisappear {
            player.pause()
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
            }
        }
    }

    static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
