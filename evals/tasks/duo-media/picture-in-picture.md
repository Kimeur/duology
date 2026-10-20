---
id: duo-media/picture-in-picture
skill: duo-media
also: duo-continuity, duo-layout
title: Picture in Picture and background audio that survive a fold
readme: no
fixture: Reel
project: Reel.xcodeproj
scheme: Reel
build: yes
lint: no
checklist: R2 R8 R12
timeout: 2400
status: ready
---

# Picture in Picture and background audio that survive a fold

A video app on iPhone Duo is expected to support Picture in Picture, and the floating video changes the space the app gets: pinned to the top, and stretched to half the screen when the phone is partly folded ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=201)). Picture in Picture runs on `AVPlayerViewController` or on an `AVPictureInPictureController` made from the app's own player layer. Apple's playback guide asks a media app for the `.playback` audio session, and says Picture in Picture and sound in the background need the audio background mode ([Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)). The Lock Screen and Control Center read Now Playing: `AVPlayerViewController` updates it by default (`updatesNowPlayingInfoCenter`, iOS 27.1 SDK), otherwise the app publishes it with MediaPlayer ([MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)). On Duo, all of this must sit above the layout switch that a fold triggers: a player or a Picture in Picture controller that a view rebuilds stops (`duo-continuity`, `duo-media`).

## Prompt

```text prompt
Add Picture in Picture to this player, plus Lock Screen and Control Center controls, and keep the sound going when the person leaves the app. On iPhone Duo people fold, unfold and rotate the phone while the video plays: none of that may stop, restart or pause the video, and Picture in Picture must keep working through it.
```

## Starting point

Fixture [`Reel`](../../fixtures/Reel): a player screen with an "Up next" list. It switches between an `HStack` and a `VStack` with `if sizeClass == .regular`, and each branch creates its own `VideoPane`, which owns an `AVPlayer` in `@State`, shows it with SwiftUI's `VideoPlayer` and pauses it in `onDisappear`. iOS 17 target, Swift 5, no `Info.plist` file. The bundled clip is a 60-second test pattern with a running counter.

The fixture's two duo-lint findings (`UIScreen.main` and a 320 pt list) belong to `duo-continuity/video-through-fold`, so this task turns the lint gate off. Its own subject is the player's ownership, Picture in Picture, Now Playing and the audio session.

## Pass checks

Gates: builds for the iPhone Duo simulator.

```sh check picture-in-picture
# SwiftUI's VideoPlayer has no Picture in Picture of its own in Apple's guides.
has_src 'AVPictureInPictureController|AVPlayerViewController'
```

```sh check playback-audio-session
has_src 'setCategory'
has_src '\.playback\b'
```

```sh check background-audio-mode
# The built app declares the audio background mode (Picture in Picture and sound
# after leaving the app need it). Xcode has no generated key for it, so it comes
# from an Info.plist file the agent adds.
skip_if_light "reads the app built by the build gate"
app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'Reel.app' 2>/dev/null | awk 'NR == 1' || true)"
[ -n "$app" ] || { echo "no built Reel.app under $DERIVED_DATA (did the build gate pass?)"; exit 1; }
modes="$(/usr/bin/plutil -extract UIBackgroundModes json -o - "$app/Info.plist" 2>/dev/null || true)"
case "$modes" in
  *'"audio"'*) ;;
  *) echo "UIBackgroundModes in the built app is '$modes', without audio"; exit 1 ;;
esac
```

```sh check now-playing
# Lock Screen and Control Center: AVPlayerViewController updates Now Playing by
# default; otherwise the app publishes it.
has_src 'MPNowPlayingInfoCenter|MPNowPlayingSession|AVPlayerViewController'
```

```sh check one-player
# The AVPlayer has one owner, created once, above any layout switch.
pycheck single_owner.py 'AVPlayer\(|AVQueuePlayer\('
```

```sh check pip-survives-the-fold
# Picture in Picture ends when its controller goes away, so the controller (or the
# AVPlayerViewController that runs it) also has one owner a fold can't rebuild.
pycheck single_owner.py 'AVPictureInPictureController\(|AVPlayerViewController\('
```

```sh check no-pause-on-disappear
# A layout change must not pause playback through onDisappear.
python3 - <<'PY'
import os, sys
bad = []
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in {".git", "DerivedData", "build"}]
    for f in files:
        if not f.endswith(".swift"):
            continue
        lines = open(os.path.join(root, f), encoding="utf-8", errors="replace").read().splitlines()
        for i, line in enumerate(lines):
            if ".onDisappear" in line and any(".pause()" in l for l in lines[i:i + 6]):
                bad.append("%s:%d" % (os.path.join(root, f), i + 1))
if bad:
    print("onDisappear pauses the player at: " + ", ".join(bad))
    sys.exit(1)
PY
```

```sh check launches
launch_ok
```

## Checklist

recipe-media-player measured that the iPhone Duo simulator doesn't support Picture in Picture (`isPictureInPictureSupported()` returned `false`). So the reviewer checks Picture in Picture itself on a device, if there is one, and judges the rest in the simulator.

- **R2**: play to about 0:20, then press Closed, Open, Rotate Right and Partially Open in Device Hub. The counter keeps going from where it was and playback never stops.
- **R8**: in Split View, in either half, the player and its controls fit. On a device: Picture in Picture starts from the button and on going home, and comes back to the same spot.
- **R12**: no black frame or reload when the layout changes.
