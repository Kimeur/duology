# Picture in Picture, Now Playing and audio

What changes on iPhone Duo, and the setup every player needs anyway. Every block typechecks against the iOS 27.1 simulator SDK in Swift 5 and Swift 6 mode.

Apple's sources: [Tech Talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201) (Picture in Picture on Duo), [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback), [Adopting Picture in Picture in a standard player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player), [Adopting Picture in Picture in a custom player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player), [HIG: Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio).

## Picture in Picture on iPhone Duo

Apple's design talk describes what the system does ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201)):

- People can pin a Picture in Picture video to the top of the screen. The app underneath resizes vertically to fit the space left.
- Partly folded, the pinned video grows to fill half the screen, and apps adjust to the new height as it happens.

What that means for your app:

| Situation | Your window | Do |
|---|---|---|
| Another app's video pinned on top, phone open | Shorter, full width | Lay out by the space you get. A list-detail screen may now be wide and short. |
| Pinned video, phone in tabletop | About the bottom half (*derived* from the talk; not measured) | Your app lives on the half people touch. Keep every control reachable there. |
| Your own video goes into Picture in Picture | Your app keeps running below it | Show the queue or the episode page, not an empty player. |
| A fold or an unfold | No change to Picture in Picture state | Nothing. A fold doesn't send the app to the background: `scenePhase` stayed `active` through close and open (`duo-scenes`, *measured*), and automatic Picture in Picture starts on backgrounding, so a fold shouldn't start it (*derived*). |

- *Measured:* `AVPictureInPictureController.isPictureInPictureSupported()` returned `false` on the iPhone Duo simulator (20 Oct 2026). Check Picture in Picture on a device.
- In Split View your app already has half the inner display; a pinned video takes height on top of that. `duo-scenes` covers Split View.

## Picture in Picture for your own player

`AVPlayerViewController` supports Picture in Picture by default once the audio session and the background mode are set (`allowsPictureInPicturePlayback` is `true` by default). A custom player built on `AVPlayerLayer`, such as the tabletop player, needs `AVPictureInPictureController`.

```swift
import AVKit
import Observation

/// Picture in Picture for a custom player. Needs the "Audio, AirPlay, and Picture
/// in Picture" background mode and the playback audio category.
@MainActor @Observable
final class PictureInPicture: NSObject, AVPictureInPictureControllerDelegate {
    private(set) var isPossible = false
    @ObservationIgnored private var controller: AVPictureInPictureController?
    @ObservationIgnored private var possible: NSKeyValueObservation?

    /// Call when the layer is created. If a fold ever rebuilt the layer, call it again.
    func attach(to layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let controller = AVPictureInPictureController(playerLayer: layer) else { return }
        // The video is the main thing on screen, so let it float when people leave the app.
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        possible = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.isPossible = value }
        }
        self.controller = controller
    }

    func toggle() {
        guard let controller else { return }
        controller.isPictureInPictureActive ? controller.stopPictureInPicture() : controller.startPictureInPicture()
    }

    // The player layer never left the screen, so there is nothing to rebuild.
    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
```

- Keep a strong reference to the controller; Apple's guide says Picture in Picture needs one to work. The model holds this object for the whole window.
- `canStartPictureInPictureAutomaticallyFromInline` tells the system the inline video is the main content, so it can float when people go home. Set it only when that is true.
- While Picture in Picture is active, AVFoundation stops sending frames to the player layer you passed in (custom player guide). Your inline surface goes blank; show a placeholder there.
- The restore callback asks you to put the player UI back. Here the layer stayed in the window through every pose (*measured* with the overlay arrangement), so there is nothing to rebuild. If your player view can leave the screen, present it again before you call the handler with `true`.
- Use the system's start and stop images (`pictureInPictureButtonStartImage`, `pictureInPictureButtonStopImage`) if your button should match the system player's (custom player guide).

## The audio session

| Step | What | Source |
|---|---|---|
| Category | `.playback`, with mode `.moviePlayback` for video. Audio keeps playing with the Ring/Silent switch on silent. | [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback) |
| Background mode | Audio, AirPlay, and Picture in Picture, in Signing & Capabilities. Needed for background audio, AirPlay and Picture in Picture. | Same page |
| Activation | Apple suggests activating when playback starts, not at launch, so you don't stop other audio early. An `AVPlayer` connected to system audio activates the session itself when it starts playing. | Same page; `AVPlayer.h` (`disconnectedFromSystemAudio`, iOS 27.0) |
| Interruptions | After a call ends, resume only when the system recommends it. iOS 27.0 deprecates `interruptionNotification` and its `.shouldResume` option; use `didBecomeInactiveNotification` and `resumptionRecommendationNotification` (code below). | [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), `AVAudioSessionTypes.h` in the iOS 27.1 SDK |
| Route changes | People expect playback to pause when headphones come out. | [HIG: Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio), [Responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes) |

None of this changes on iPhone Duo, with one rule that does: a fold is not an interruption and not a route change. Never pause, deactivate the session or reset the player because the window resized.

Resuming after an interruption with the iOS 27 notifications:

```swift
import AVFoundation

// requires: PlaybackModel (player-ownership.md)

extension PlaybackModel {
    /// iOS 27 splits the old interruption notification in two: the session tells you
    /// it became inactive, then later whether the system recommends resuming.
    /// Run it from the window root: `.task { await playback.resumeWhenRecommended() }`.
    @available(iOS 27.0, *)
    func resumeWhenRecommended() async {
        let name = AVAudioSession.resumptionRecommendationNotification
        for await note in NotificationCenter.default.notifications(named: name) {
            let context = note.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
            if context?.recommendation == .shouldResume, current != nil { resume() }
        }
    }
}
```

- Below iOS 27, keep your `interruptionNotification` handler and its `.shouldResume` check behind `if #available`.
- `didBecomeInactiveNotification` carries an `AVAudioSession.DeactivationContext` that says what deactivated the session. Read it if you show why playback stopped.
- *Unverified:* these notifications on a device. The simulator can't place a phone call.

## Now Playing

- With `AVPlayerViewController`, Now Playing updates for you (`updatesNowPlayingInfoCenter`, `true` by default).
- With your own player, publish it from the model: `MPNowPlayingSession(players:)` with `automaticallyPublishesNowPlayingInfo` (iOS 16), your keys on the item's `nowPlayingInfo`, and play and pause handlers on the session's `remoteCommandCenter`. `PlaybackModel` in [player-ownership.md](player-ownership.md) does this.
- Respond to remote commands only for audio you are playing, and don't give them new meanings ([HIG: Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)).
- Apple's spec page lists a Dynamic Island on each display ([device facts](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#displays)). How Now Playing shows there on the closed phone is unverified.

## No second picture on the outer display

No scene accessory is meant for video on the outer display. The iOS 27.1 SDK has two: `CameraCaptureAccessory`, which shows only while a camera app captures, and `ExternalNonInteractiveAccessory`, which Apple documents for a connected or AirPlay display (`duo-scenes`). Plan a video app around one picture on the display in use, and use AirPlay (`AVRoutePickerView`) for a second screen. Whether the external accessory ever reaches the outer display is unverified.

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): V4 (scenes talk), V6 (design talk). Apple pages are linked inline.
