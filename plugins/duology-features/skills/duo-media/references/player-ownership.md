# One player above the layout switch

Playback survives a fold only when the player lives above the part of the view tree that the fold rebuilds. This page has the model, the root that owns it, and what we measured. Every Swift block in this skill typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode, with iOS 27.1 and iOS 26 deployment targets.

`duo-continuity` covers the rule for every kind of state ([playback section](https://github.com/Kimeur/duology/blob/main/plugins/duology/skills/duo-continuity/SKILL.md#7-playback)). This page adds what a media app needs around the player: the queue, Now Playing and the audio session.

## The model

```swift
import AVFoundation
import MediaPlayer
import Observation

struct Episode: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
}

/// One player for the window. Create it once, above every layout switch, so a
/// fold, an unfold or a rotation never builds a second player.
@MainActor @Observable
final class PlaybackModel {
    let player = AVPlayer()
    private(set) var current: Episode?
    private(set) var isPlaying = false
    var upNext: [Episode] = []
    let pictureInPicture = PictureInPicture()
    @ObservationIgnored private var nowPlaying: MPNowPlayingSession?
    @ObservationIgnored private var status: NSKeyValueObservation?

    init() {
        // Follow the player, not your own guesses: the system pauses it too
        // (calls, Picture in Picture controls, headphones).
        status = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, change in
            let playing = change.newValue.map { $0 != .paused } ?? false
            Task { @MainActor in self?.isPlaying = playing }
        }
    }

    func play(_ episode: Episode) {
        guard episode != current else { return }   // the same item again is a no-op
        current = episode
        let item = AVPlayerItem(url: episode.url)
        item.nowPlayingInfo = [MPMediaItemPropertyTitle: episode.title]
        player.replaceCurrentItem(with: item)
        // Set the category before playback. The player activates the session when it starts.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        player.play()
        publishNowPlaying()
    }

    func togglePlayback() { isPlaying ? player.pause() : player.play() }
    func resume() { player.play() }
    func pause() { player.pause() }

    func playNext() {
        guard !upNext.isEmpty else { return }
        play(upNext.removeFirst())
    }

    /// Lock Screen, Control Center and headphone controls. Owned here, not by a view,
    /// so they keep working while the views rebuild after a fold.
    private func publishNowPlaying() {
        if nowPlaying == nil {
            let session = MPNowPlayingSession(players: [player])
            session.automaticallyPublishesNowPlayingInfo = true
            let commands = session.remoteCommandCenter
            commands.playCommand.addTarget { @Sendable [weak self] _ in
                Task { @MainActor in self?.resume() }
                return .success
            }
            commands.pauseCommand.addTarget { @Sendable [weak self] _ in
                Task { @MainActor in self?.pause() }
                return .success
            }
            nowPlaying = session
        }
        nowPlaying?.becomeActiveIfPossible { _ in }
    }
}
```

`PictureInPicture` is in [pip-and-audio.md](pip-and-audio.md#picture-in-picture-for-your-own-player).

Notes on the choices:

- `AVPlayer` is main-actor isolated in the iOS 27.1 SDK (`NS_SWIFT_UI_ACTOR` in `AVPlayer.h`), so the model is `@MainActor` too.
- `isPlaying` follows `timeControlStatus` through key-value observation. A flag you flip yourself drifts the first time the system pauses the player. iOS 26 also offers `AVPlayer.isObservationEnabled`, which makes players observable with Swift Observation; it must be set before you create any player, so turn it on at launch or not at all ([doc](https://developer.apple.com/documentation/avfoundation/avplayer/isobservationenabled)).
- `play(_:)` ignores the episode that is already playing. If a view calls it from `.task(id:)` and the view is rebuilt on a fold, nothing restarts.
- `MPNowPlayingSession` (iOS 16) ties Now Playing to the player. With `automaticallyPublishesNowPlayingInfo`, don't write to the session's `nowPlayingInfoCenter`; put your own keys on the item's `nowPlayingInfo` ([doc](https://developer.apple.com/documentation/mediaplayer/mpnowplayingsession/automaticallypublishesnowplayinginfo)). If you show `AVPlayerViewController`, it updates Now Playing for you by default (`updatesNowPlayingInfoCenter`).
- The remote command handlers are `@Sendable` and hop to the main actor, so they are safe whichever queue MediaPlayer calls them on.

## The root owns it

```swift
import AVKit
import SwiftUI

// requires: PlaybackModel (this file)

/// The window root owns playback. Everything below it may change layout on a fold.
struct ShowsRoot: View {
    @State private var playback = PlaybackModel()
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        let layout = widthClass == .regular
            ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0))
        layout {
            VideoPlayer(player: playback.player)       // a view of the player, nothing more
            EpisodeList(playback: playback)
        }
    }
}

struct EpisodeList: View {
    let playback: PlaybackModel

    var body: some View {
        List(playback.upNext) { episode in
            Button(episode.title) { playback.play(episode) }
        }
    }
}
```

- `AnyLayout` keeps the views' identity when the layout changes ([AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)). Even if a view is rebuilt, the player isn't.
- For more than one window, give each window its own model: hold it in the root view of the `WindowGroup`, not in the `App`.

## What we measured

On the iPhone Duo simulator (iOS 27.1), 20 October 2026, with a model-owned `AVQueuePlayer` looping a 12-second movie, shown through an `AVPlayerLayer` as the secondary view of an `ArrangementView` with `.overlay`:

- The player layer's view was created once and never again through Open, Partially Open, Rotate Right (tabletop) and Closed.
- Playback ran on through book, tabletop and closing: the logged time rose by about 3 s every 3 s, with `timeControlStatus` playing throughout.
- `duo-continuity` measured the same with `VideoPlayer`: a model-owned player kept playing while `VideoPlayer` was torn down and rebuilt on each size-class flip.

## Don't

| Don't | Why | Do |
|---|---|---|
| `@State private var player = AVPlayer(url:)` in a view below a layout switch | A fold builds a new view and a new player from zero | The model above, as here |
| `.onDisappear { player.pause() }` | A fold can make a view disappear for a moment | Pause on a person's action, or on `.background` if your app needs that |
| `.task { player = AVPlayer(...) }` in a view that changes identity | The task runs again after a fold | Key the task on the item (`.task(id:)`) and make the call idempotent |
| `.id(sizeClass)` on the player view | Forces a rebuild on every unfold | Stable identity |
| Autoplay in `onAppear` | Opening the phone reruns `onAppear` on rebuilt views | Start from an action or a model decision |

## UIKit

Keep one `AVPlayerViewController` in a container that never goes away, and move the container's frame. `duo-continuity` has the code ([players](https://github.com/Kimeur/duology/blob/main/plugins/duology/skills/duo-continuity/references/uikit.md#players)). Don't pause in `viewWillDisappear(_:)` because a layout change hid the view.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): V1 (resizing talk), V6 (design talk). Apple pages: [MPNowPlayingSession](https://developer.apple.com/documentation/mediaplayer/mpnowplayingsession), [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback), [VideoPlayer](https://developer.apple.com/documentation/avkit/videoplayer).
