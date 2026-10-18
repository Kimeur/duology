# Tabletop media

"Tabletop" is Duology's word for what Apple describes as the phone seated on a table like a laptop: held tall, partly folded, the fold running across the inner display, the inner display facing the person ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=45)). Apple names it as the one optional layout worth designing for a single pose: media on top, tappable controls on the stable bottom half, with all the same controls and hierarchy as every other pose ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=276)).

Prior art: Samsung's [Flex mode](https://developer.samsung.com/galaxy-z/flex-mode.html) and Android's [tabletop posture](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/learn-about-foldables) do the same on other hardware. Treat them as ideas, not rules for iPhone Duo.

## How it behaves

| Pose | Video | Controls |
|---|---|---|
| Closed (outer display) | Fills the window | Over the video, at the bottom |
| Open, flat (wide or tall) | Fills the window | Over the video, at the bottom |
| Book | Leading region | Trailing region, centred |
| Tabletop | Top region | Bottom region, centred |
| Split View, narrow window | Fills the window | Over the video, at the bottom |

The controls are the same view in every row. Only their position changes.

## Recipe: video player

Needs `FoldGeometry` and `FoldRegionsLayout` from [fold-regions.md](fold-regions.md). Typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode, with iOS 27.1 and iOS 26 deployment targets, and with a new Xcode 27.1 app's settings (main actor default isolation).

```swift
import AVFoundation
import SwiftUI

// requires: FoldGeometry, FoldRegionsLayout (fold-regions.md)
// requires: PlayerSurface, PlayerControls (next block)

/// Video on top and controls below when the phone sits folded on a table.
/// Folded like a book: video leading, controls trailing.
/// Closed or flat: controls over the video. The same two views in every pose.
@available(iOS 27.1, *)
struct TabletopPlayer: View {
    let player: AVPlayer
    @State private var fold = FoldGeometry()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FoldRegionsLayout(fold: fold, unfolded: .overlay) {
            PlayerSurface(player: player)
                .ignoresSafeArea()
            PlayerControls(player: player)
        }
        .onFoldChange { fold = $0 }
        // Small, quick moves. With Reduce Motion, the controls jump instead of sliding.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fold)
        .background(.black)
    }
}
```

The two views it places:

```swift
import AVFoundation
import SwiftUI
import UIKit

/// The video with no system controls, so the same custom controls show in every pose.
struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// One set of controls for every pose. Symbols with titles, for VoiceOver and Voice Control.
struct PlayerControls: View {
    let player: AVPlayer
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 28) {
            Button("Back 10 Seconds", systemImage: "gobackward.10") { skip(by: -10) }
            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                isPlaying ? player.pause() : player.play()
                isPlaying.toggle()
            }
            .font(.largeTitle)
            Button("Forward 10 Seconds", systemImage: "goforward.10") { skip(by: 10) }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 16)
    }

    private func skip(by seconds: Double) {
        let target = player.currentTime() + CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target)
    }
}
```

What the recipe does on purpose:

- `PlayerSurface` is an `AVPlayerLayer` with no system controls. `VideoPlayer` and `AVPlayerViewController` draw their own controls over the video, so you would show two sets in tabletop.
- The video keeps its aspect ratio (`.resizeAspect`). In the top region of the tabletop pose (669 × 455 pt, *measured* window and fold), a 16:9 video gets the full width.
- The capsule keeps its size in every pose. The bottom region is roomy; resist adding buttons there.
- Real players also need a scrubber, the time and AirPlay. Add them to `PlayerControls`, so they appear in every pose.

## Variant: video call

The same layout, with the other person on top and the call controls below. Put the self view in a corner of the content, not in the controls, so it never jumps between regions.

```swift
import SwiftUI

// requires: FoldGeometry, FoldRegionsLayout (fold-regions.md)

@available(iOS 27.1, *)
struct CallScreen: View {
    @State private var fold = FoldGeometry()
    @State private var isMuted = false
    @State private var isCameraOn = true
    @State private var isSpeakerOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FoldRegionsLayout(fold: fold, unfolded: .overlay) {
            // The other person, and a small self view in the corner, inside the safe area.
            ZStack(alignment: .topTrailing) {
                RemoteVideo()
                    .ignoresSafeArea()
                SelfView()
                    .frame(width: 96, height: 128)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding()
            }
            CallControls(isMuted: $isMuted, isCameraOn: $isCameraOn, isSpeakerOn: $isSpeakerOn)
        }
        .onFoldChange { fold = $0 }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fold)
    }
}

struct RemoteVideo: View {
    var body: some View {
        Color.black.overlay {
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Video of the other person")
    }
}

struct SelfView: View {
    var body: some View {
        Color.gray.accessibilityLabel("Your video")
    }
}

struct CallControls: View {
    @Binding var isMuted: Bool
    @Binding var isCameraOn: Bool
    @Binding var isSpeakerOn: Bool

    var body: some View {
        HStack(spacing: 20) {
            Toggle("Mute", systemImage: isMuted ? "mic.slash.fill" : "mic.fill", isOn: $isMuted)
            Toggle("Camera", systemImage: isCameraOn ? "video.fill" : "video.slash.fill", isOn: $isCameraOn)
            Toggle("Speaker", systemImage: "speaker.wave.2.fill", isOn: $isSpeakerOn)
            Button("End Call", systemImage: "phone.down.fill", role: .destructive) { }
                .buttonStyle(.borderedProminent)
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .font(.title2)
        .controlSize(.large)
        .padding()
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 16)
    }
}
```

The inner front camera is the one a call uses when the phone is open. In tabletop its region sits on the right edge of the bottom half: 37 × 58 pt at (611, 677) in a 669 × 951 pt window (*measured*, inactive). While the camera runs, that region turns active ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=482)). A centred row of four buttons stays clear of it. If your controls span the full width, also read `reservedRegions(kind: .occlusion)` and keep them out of the active frame.

## The system alternative: an overlay arrangement

Apple's `ArrangementView` with `.overlay` does the same job with no fold code: the primary sits over the secondary while no division is active, and partly open it puts the primary in the trailing or bottom part and the secondary in the leading or top part ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views)).

```swift
import AVFoundation
import SwiftUI

// requires: PlayerSurface, PlayerControls (this file)

@available(iOS 27.1, *)
struct ArrangedPlayer: View {
    let player: AVPlayer

    var body: some View {
        ArrangementView {
            // Closed and flat, a short primary sat at the top edge. Align it to the bottom.
            PlayerControls(player: player)
                .frame(maxHeight: .infinity, alignment: .bottom)
        } secondary: {
            PlayerSurface(player: player)
                .ignoresSafeArea()
        }
        .arrangementViewStyle(.overlay)
        .background(.black)
    }
}
```

To choose which side the primary takes when the overlay splits side by side, add [`overlayArrangementEdge(_:)`](https://developer.apple.com/documentation/swiftui/view/overlayarrangementedge(_:)) to it, for example `.trailing`.

Choose between them:

| | `ArrangementView` `.overlay` | `FoldRegionsLayout` |
|---|---|---|
| Fold code | None | Reads `.division` |
| Tells you which state it is in | Apple documents `overlayArrangementZIndex` for this. Closed, our probe read `1` in the primary and `0` in the secondary; `duo-patterns` read `0` everywhere open and flat. Not yet checked folded | You hold `fold` |
| Placement inside a region | System | Yours (centred) |
| Checked folded on the simulator | No (unverified) | Uses region frames measured folded; the layout itself not yet run folded (unverified) |
| Where it can't go | Not inside a `List`, `ScrollView` or `NavigationSplitView` | Anywhere |

Start with the arrangement when the screen is a plain "controls over content" stack and you don't need to know the state. Use `FoldRegionsLayout` when the controls change with the region (a compact bar over the video, a full panel below it) or when the screen sits somewhere an arrangement can't.

## Picture in Picture

The system pins Picture in Picture video to the top of the screen, and stretches it to half the screen when the phone is partly folded; the app below resizes to fit ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201)). Use the system's Picture in Picture rather than a floating player of your own, and make sure your layout copes with the shorter window.

## Rules

1. Same controls in tabletop as in every other pose. Moving and resizing are fine; adding or removing is not.
2. Top region: what people watch from a distance. Bottom region: what they touch.
3. One layout type, so the video layer is never rebuilt.
4. Keep the controls clear of the fold frame and of the inner camera.
5. Don't autoplay because the phone folded. Folding is not a request to play.

## Pitfalls

- **Detecting tabletop from orientation.** The inner display ignores supported orientations, and orientation says nothing about the fold. Use `fold.isActive && !fold.isVertical`.
- **A tabletop-only control.** A "stand mode" button or a sleep timer that exists only folded breaks the rule above.
- **System player controls plus your own.** Two sets of controls in tabletop. Use a bare player layer.
- **Video that straddles the fold.** Even a flat-looking frame curves through the middle when folded. Keep the video in the top region.

## Test it

1. Closed and Open: controls over the video, bottom centre.
2. Partially Open, held wide (book): video leading, controls trailing.
3. Partially Open, then Rotate Right once (tabletop): video above the fold, controls below, nothing in the fold.
4. Play, then fold and unfold: playback doesn't stop and the video doesn't flash.
5. With Reduce Motion on (Settings > Accessibility > Motion), the controls move without sliding.
6. VoiceOver: each control reads its title in every pose.

Duology has not yet run this recipe folded on the simulator; the region frames it relies on were measured folded with the gallery app. (unverified)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (hub), D2 (HIG), V3 (talk 111463), V6 (talk 111466), P2a (Android foldables), P3 (Samsung Flex mode).
