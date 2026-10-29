# __APP_NAME__

A video podcast player for iPhone Duo. Browse the shows, play an episode, and keep watching when you fold, unfold or turn the phone. Set it on a table half folded and the video sits above the fold with the same controls below it. Made from Duology's `recipe-media-player`.

## Run it

```bash
Tools/run-model-tests.sh      # queue, up next, resume points and fold regions, on your Mac, in seconds
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The rules: catalogue, queue, up next, resume points, fold geometry and player regions. Foundation and CoreGraphics only. |
| `__APP_NAME__/Player/` | `PlayerModel` (one `AVPlayer`, its layer, Picture in Picture), the player screen and its controls. |
| `__APP_NAME__/Library/` | The split view: shows and episodes, the episode detail, the mini player. |
| `__APP_NAME__/Shared/` | `FoldRegionsLayout`, the fold reader and the test markers. |
| `__APP_NAME__/Media/` | `Catalog.json` and six 12-second sample clips made with ffmpeg. |
| `__APP_NAME__/App/` | The app entry, the root view and the launch switches for tests. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `__APP_NAME__/Assets.xcassets/` | The accent colour and a placeholder app icon: one 1024 × 1024 image, from which Xcode makes the other sizes. Replace the icon with your own before you ship. |
| `Tools/` | The model test program and both test scripts. |

## Your own shows

Edit `Media/Catalog.json`. `media` takes a file name in the app bundle or an `https` URL, such as an HLS playlist. Put the real length in `duration`; the player reads the true length once the media loads. Run `Tools/run-model-tests.sh` afterwards: it checks every bundled file is there.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-play ID` | Open the player on an episode and start it. |
| `-paused` | With `-play`: open it paused. Handy for screenshots. |
| `-start S` | With `-play`: start S seconds in. |
| `-miniPlayer` | With `-play`: stay in the library, with the mini player. |
| `-select ID` | Select an episode in the library. |
| `-upNextLead S` | Show the up next card S seconds before the end. |
| `-autoplay 0` | Don't start the next episode on its own. |
| `-loop` | Replay the episode at its end, for screenshots in every pose. |
| `-resetState` | Forget saved positions and played episodes. |
| `-uiTesting` | Animations off, test markers on. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each by hand: closed and open, the controls float over the video; folded like a book, the video is on the left and the controls on the right; Partially Open then Rotate Right (tabletop), the video is above the fold and the controls below it.
- Fold and unfold while a video plays: it keeps playing, from the same point.
- Picture in Picture needs the audio background mode, which `Info.plist` sets.
