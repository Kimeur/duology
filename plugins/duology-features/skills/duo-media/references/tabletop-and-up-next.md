# Tabletop player and "up next"

A player whose controls move below the fold when the phone sits on a table, and an "up next" queue that floats over the video when flat and opens up beside or below it when folded. Built on `ArrangementView` with `.overlay`, so there is no fold code. Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode.

"Tabletop" and "book" are Duology's words for what Apple describes as the phone seated on a table like a laptop, and partly folded like a book. Neither is an API.

Apple's sources: [Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=276) (the optional tabletop layout), [Tech Talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=801) (the overlay arrangement and its z-index, demonstrated with a player and an "up next" view), [overlayArrangementZIndex](https://developer.apple.com/documentation/swiftui/environmentvalues/overlayarrangementzindex).

## Two ways to build it

| | `ArrangementView` with `.overlay` (this page) | `FoldRegionsLayout` (`duo-postures`) |
|---|---|---|
| Fold code | None | Reads the `.division` region |
| Where it can't go | Inside a `List`, a `ScrollView` or a `NavigationSplitView` | Anywhere |
| Placement inside a region | The system's | Yours |
| Tells you the state | `overlayArrangementZIndex`, read one view down | You hold the fold value |
| Checked folded on the simulator | Yes, 20 Oct 2026 (below) | Yes: the gallery's [tabletop player](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/TabletopPlayerView.swift), 18 Oct 2026 |

Pick the arrangement for a plain "controls over video" screen. Pick `FoldRegionsLayout` when the screen sits where an arrangement can't, or when you want to place the controls yourself; the recipe is in [duo-postures tabletop-media.md](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-postures/references/tabletop-media.md). Screenshots of the gallery screen in each pose: [gallery README](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/README.md#screenshots).

## What the overlay arrangement does

*Measured* on the iPhone Duo simulator (iOS 27.1, Device Hub poses set with `duo-pose`), 20 October 2026. The primary was a panel; the secondary was a playing video. The z-index was read in a view nested one level inside the primary, because the view passed in directly reads default values (`duo-layout`).

| Pose | Window | Primary | Secondary | `overlayArrangementZIndex` in the primary |
|---|---|---|---|---|
| Closed | 466 × 678 pt | Over the secondary, the whole window | The whole window | 1 |
| Open, flat | 951 × 669 pt | Over the secondary, the whole window | The whole window | 1 |
| Book (Partially Open) | 951 × 669 pt | Trailing region: 455 × 669 pt at x 495 | Leading region | 0 |
| Tabletop (then Rotate Right) | 669 × 951 pt | Bottom region: 669 × 455 pt at y 495 | Top region | 0 |

- Closing from tabletop, the value went 1, 0, 1 within 0.06 s while the window resized. Don't animate or log on every change; treat it as state.
- The secondary view was created once and never rebuilt, and the video kept playing.
- The primary covers the whole window when it floats. Align its content to the bottom edge yourself.

## The panel and the controls

`TabletopWatchScreen` in SKILL.md places these views. The panel reads the z-index one view down and shows more of the queue when it has its own region:

```swift
import SwiftUI

// requires: PlaybackModel (player-ownership.md)

@available(iOS 27.1, *)
struct NowPlayingPanel: View {
    let playback: PlaybackModel

    var body: some View {
        ZStack { PanelContent(playback: playback) }   // read arrangement values one view down
    }
}

@available(iOS 27.1, *)
private struct PanelContent: View {
    let playback: PlaybackModel
    @Environment(\.overlayArrangementZIndex) private var zIndex

    var body: some View {
        // Measured: 1 while the panel floats over the video, 0 once they sit side by side.
        let floating = zIndex > 0
        VStack(alignment: .leading, spacing: 12) {
            UpNextList(playback: playback, limit: floating ? 1 : 6)
            TransportControls(playback: playback)
        }
        .padding()
        .background(floating ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear),
                    in: .rect(cornerRadius: 24))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

/// The same queue in every pose: one row when it floats, more when it has room.
struct UpNextList: View {
    let playback: PlaybackModel
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up Next").font(.headline)
            ForEach(playback.upNext.prefix(limit)) { episode in
                Button(episode.title) { playback.play(episode) }
            }
        }
        .foregroundStyle(.white)
    }
}

/// Playback state lives in the model, not in @State here, so a rebuilt view can't drift.
struct TransportControls: View {
    let playback: PlaybackModel

    var body: some View {
        HStack(spacing: 28) {
            Button(playback.isPlaying ? "Pause" : "Play",
                   systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                playback.togglePlayback()
            }
            Button("Next", systemImage: "forward.end.fill") { playback.playNext() }
            Button("Picture in Picture", systemImage: "pip.enter") { playback.pictureInPicture.toggle() }
                .disabled(!playback.pictureInPicture.isPossible)
        }
        .labelStyle(.iconOnly)
        .font(.title)
        .foregroundStyle(.white)
    }
}
```

The video surface. It has no system controls, so yours are the only ones, and Picture in Picture comes from the same layer:

```swift
import AVKit
import SwiftUI
import UIKit

// requires: PlaybackModel (player-ownership.md)

final class VideoLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoSurface: UIViewRepresentable {
    let playback: PlaybackModel

    func makeUIView(context: Context) -> VideoLayerView {
        let view = VideoLayerView()
        view.playerLayer.player = playback.player
        view.playerLayer.videoGravity = .resizeAspect
        playback.pictureInPicture.attach(to: view.playerLayer)
        return view
    }

    func updateUIView(_ view: VideoLayerView, context: Context) {}
}
```

Why it is built this way:

- **Same controls, more room.** The queue shows one row when the panel floats and up to six when it has its own region. Every control exists in every pose; only the amount of content changes ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=295)).
- **The primary is what people touch.** The overlay arrangement puts the primary in the bottom or trailing region when folded. In tabletop that is the stable half on the table; in book it is the side where alerts go and where the controls sit once the phone closes ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)).
- **No autoplay on fold.** Nothing here reacts to the fold except the layout. Folding is not a request to play.
- **The vertical bar off.** Apple's doc for `toolbarVerticalBehavior(_:)` suggests `.disabled` as a stable choice for a full-screen video player, never toggled from view state.
- **Placement inside an arrangement.** Apple's overview says not to put an arrangement inside a `List`, a `ScrollView` or a `NavigationSplitView`. Put it inside a `NavigationStack` or present it full screen.

## Overlay or split for "up next"

Apple's talk demonstrates "up next" in an overlay arrangement, with a collapsed version when it floats and an expanded one when folded. The same talk then gives the rule for choosing ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=879)):

| The queue is | Use |
|---|---|
| Something that floats over the video and may cover part of it: the video is the background | `.overlay` (this page) |
| Detail about what is playing that must never be covered, such as a transcript or a full queue in an audio app | `.split`, side by side or stacked; see `duo-layout` |

For an audio app with no video, the talk picks `.split`: the queue is detail about the playing item, not a layer over it.

## The system player in tabletop

`AVPlayerViewController` and SwiftUI's `VideoPlayer` draw their controls over the video. Apple's HIG says to prefer the system player and, if you build your own, to match its behaviour ([HIG: Playing video](https://developer.apple.com/design/human-interface-guidelines/playing-video)). Whether it moves them when the phone is partly folded is not measured yet ([testing.md](testing.md#the-system-player-in-each-pose)).

- Use the system player when its controls over the video are fine in every pose.
- Use your own controls when you want the tabletop layout. Then also bring what the system player gave you: Picture in Picture ([pip-and-audio.md](pip-and-audio.md)), Now Playing (`PlaybackModel`), captions, AirPlay (`AVRoutePickerView`) and play and pause with the Space key, which the HIG says people expect.

## UIKit

`UIArrangementViewController` with `UIOverlayArrangement` does the same. Put the panel's view controller in the `.primary` placement and the video's in `.secondary`, then read `state(for: .primary)?.zIndex` to switch between the compact and the expanded panel ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=861), [api-index](https://github.com/Kimeur/duology/blob/main/reference/api-index.md#arrangement-uikit)). Not measured folded in UIKit (unverified).

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (overview), D2 (HIG), V3 (layouts talk), V6 (design talk).
