# Media in the media player recipe

The sample clips, the catalogue, streams, audio-only episodes, Picture in Picture and background audio. For the general rules (one player above the layout switch, the tabletop layout, Now Playing), load `duo-media`.

## The sample clips

The template ships six clips in `<App>/Media/`. Nothing was downloaded: `scripts/make-sample-clips.sh` makes each one on the Mac with ffmpeg's built-in sources.

| Part | ffmpeg source or filter |
|---|---|
| Picture | `gradients` (a slow radial gradient in the show's colours), then `drawtext` for the show, the episode title, "Sample clip, made with ffmpeg" and a seconds counter |
| Sound | `anoisesrc` (quiet brown noise), low-passed, with a one-second fade in and out |
| Encoding | H.264 main profile, CRF 31, AAC 40 kb/s mono, `+faststart` |

Each clip is 12 seconds, 640 × 360 at 24 fps, about 110 KB. The counter in the corner shows the clip's own time, so a screenshot proves where playback was. The titles use Avenir Next, which ships with macOS; elsewhere ffmpeg picks a sans font.

```bash
# Longer, larger clips. Then set "duration" in Catalog.json to match.
CLIP_SECONDS=60 CLIP_SIZE=1280x720 scripts/make-sample-clips.sh ~/Developer/FieldCast/FieldCast/Media
```

The script needs an ffmpeg with the `gradients` source: `ffmpeg -h filter=gradients` should describe it (we used ffmpeg 7.1 from Homebrew). Filters: [ffmpeg filters documentation](https://ffmpeg.org/ffmpeg-filters.html#gradients). Replace the clips with your own media before you ship.

## The catalogue

`Media/Catalog.json` holds shows, each with episodes:

| Field | Type | Notes |
|---|---|---|
| `shows[].id`, `title`, `host`, `summary` | text | IDs must be unique. |
| `shows[].symbol` | text | An SF Symbol name for the drawn artwork. |
| `shows[].colors` | two hex strings | `"E8743B"`, for the artwork gradient. |
| `episodes[].id` | text | Unique across the catalogue. UI tests and launch switches use it. |
| `episodes[].number` | number | 1, 2, 3 in order; the model tests check it. |
| `episodes[].title`, `summary` | text | |
| `episodes[].duration` | seconds | Shown before the media loads. The player switches to the item's real length once it knows it. |
| `episodes[].media` | text | A file in the app bundle (`small-repairs-1.mp4`) or an `https` URL. |
| `episodes[].published` | `yyyy-MM-dd` | |

`Tools/run-model-tests.sh` reads the real file and checks that it decodes, IDs are unique, every bundled file exists, numbers run in order and every date parses.

## Streams

Put an `https` URL in `media`, for example an HLS playlist (`.m3u8`). `PlayerModel` makes an `AVPlayerItem` from it exactly as it does for a bundled file, so the queue, up next, resume points and every pose work the same. Plain `http` URLs fail App Transport Security unless you add an exception; prefer `https`. With a network stream, expect `duration` from the catalogue until the item loads, and a short stall on the first play. The template shows no loading state yet: read `player.timeControlStatus == .waitingToPlayAtSpecifiedRate` in `tick` if you want one.

## Audio-only episodes

An audio podcast has no video track. The surface then shows black. Show the artwork instead:

```swift
import AVFoundation
import SwiftUI

// requires: PlayerModel, VideoSurface, Artwork (the template)

/// True when the item has a video track. An audio-only podcast has none.
func hasVideoTrack(_ item: AVPlayerItem) async -> Bool {
    let tracks = (try? await item.asset.loadTracks(withMediaType: .video)) ?? []
    return !tracks.isEmpty
}

/// The picture for the current episode: its video, or the show's artwork when
/// the episode is audio only. It asks again whenever the episode changes.
struct EpisodePicture: View {
    let model: PlayerModel
    @State private var hasVideo = true

    var body: some View {
        Group {
            if hasVideo {
                VideoSurface(model: model)
            } else if let show = model.currentShow {
                Artwork(show: show)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 24))
                    .padding(24)
            }
        }
        .task(id: model.current?.id) {
            guard let item = model.player.currentItem else { return }
            hasVideo = await hasVideoTrack(item)
        }
    }
}
```

Use `EpisodePicture` in place of `VideoSurface` inside `VideoFrame` (`Player/PlayerScreen.swift`). The `.task(id:)` runs again only when the episode changes, never on a fold, so it starts and stops nothing ([`loadTracks(withMediaType:)`](https://developer.apple.com/documentation/avfoundation/avasset/loadtracks(withmediatype:completionhandler:))). Typechecked against the iOS 27.1 SDK at iOS 26.0 and 27.1 targets, with the template's types. An audio app on Duo may prefer a split over an overlay for its queue; see `duo-media` section 4.

## Picture in Picture

- `PlayerModel.surfaceIsOnScreen()` makes one `AVPictureInPictureController(playerLayer:)` from the model's own layer, the first time a `VideoSurface` reaches a window. The controller needs a layer on screen to set up; after that it belongs to the model, so closing the player screen or folding the phone doesn't tear it down ([Adopting Picture in Picture in a custom player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player)).
- `canStartPictureInPictureAutomaticallyFromInline = true`: going home while the video plays floats it.
- The button is disabled while `isPictureInPicturePossible` is false, which the model observes with key-value observing and hops to the main actor.
- Starting Picture in Picture dismisses the player screen; the mini player shows. Tapping back in the floating window calls the restore delegate method, which presents the player again.
- On iPhone Duo, people can pin the floating video to the top of the screen; your app gets the space below it, and when the phone is partly folded the pinned video takes half the screen ([Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201)). The library is a split view and the player is one flexible layout, so both fit a short window (*derived*, not measured: the simulator has no Picture in Picture).

## Background audio

Three pieces, all already in the template ([Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)):

1. `Info.plist`: `UIBackgroundModes` = `audio`. The project merges this small file with the settings Xcode generates; `project.pbxproj` keeps it out of the resources.
2. At launch: `AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)`. The session is activated only when playback starts, so another app's audio isn't cut off just by opening yours.
3. In the background: `sceneMovedToBackground(true)` takes the player off its layer unless Picture in Picture runs. iOS pauses a player whose video layer is still on screen when the app leaves; without a layer, the sound goes on. Back in the foreground, the layer gets the player again.

*Measured:* `testSoundGoesOnInTheBackground` presses Home for 3 s and finds the time moved on.

A fold is not a background event. *Measured* in `duo-scenes`: `scenePhase` stayed `active` through folds. So nothing here runs when the phone folds.

## Not in the template yet

- **Now Playing and remote commands.** The Lock Screen and Control Center show nothing for a custom player until you publish it. Use `MPNowPlayingSession(players:)` with `automaticallyPublishesNowPlayingInfo`, from `PlayerModel` ([MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter); code in `duo-media`).
- **Captions and audio tracks.** Read the item's media selection groups and add a menu next to the speed menu.
- **Downloads for offline play.** Keep the catalogue's `media` as the source of truth and swap in a local file URL when one exists.

## What we measured

On the iPhone Duo simulator, Xcode 27.1, iOS 27.1, 20 October 2026:

- **Playback through every pose.** We launched `-play night-sky-notes-1 -loop`, then set open, book, tabletop and closed with `duo-pose`, 12 to 18 s apart. A scratch build logged each second of playback and each video view made: about 60 s of ticks with no gap and `playing true` throughout, and one video view for the whole run.
- **The player in each pose**, paused 5 s before the end with the up next card up: closed, the controls float at the bottom and the card's Play Now button takes its own row; open and flat, the controls float over the video; book, the video leads and the controls trail; tabletop, the video sits above the fold and the same controls below it.
- **The library in book pose**: the split view put its column boundary at the fold.
- **Picture in Picture**: `AVPictureInPictureController.isPictureInPictureSupported()` returned `false`, so the template hides the button there and the UI test skips.
- **UI tests**: 11 passed and 1 skipped (Picture in Picture), closed.

Not measured: a real iPhone Duo, Split View, Picture in Picture pinned on a partly folded phone, AirPlay.
