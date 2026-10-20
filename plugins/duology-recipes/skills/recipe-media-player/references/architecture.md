# Architecture of the media player recipe

How the generated project fits together, why each piece sits where it does, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`.

## The layers

```text
<App>App                         sets the .playback audio category once, at launch
 └─ RootView                     owns LibraryModel and the one PlayerModel; never changes identity
     ├─ LibraryView              one NavigationSplitView, closed and open
     │   ├─ sidebar: List        shows (sections) and episodes (EpisodeRow), selection in LibraryModel
     │   ├─ detail               EpisodeDetailView, or "Choose an Episode"
     │   └─ safeAreaInset        MiniPlayer, spanning the part of the width the fold allows
     └─ fullScreenCover          PlayerScreen, attached to RootView, presented by PlayerModel.isPlayerPresented
         └─ FoldRegionsLayout    the same two children in every pose
             ├─ VideoFrame       VideoSurface (hosts PlayerModel.playerLayer), kept at the video's aspect
             └─ PlayerControls   header, up next card, scrubber, transport
```

`<App>/Model/` sits under all of it. It imports Foundation and CoreGraphics only, so its rules build and run on the Mac.

## Who owns what

| Thing | Owner | Why there |
|---|---|---|
| `AVPlayer`, `AVPlayerLayer`, `AVPictureInPictureController` | `PlayerModel` | One of each for the app's life. Views come and go; the player doesn't. |
| `PlayerModel` | `@State` in `RootView` | `RootView` is the window's root and never changes identity, so no fold, rotation or size class change can make a new model. |
| The player screen | `fullScreenCover` on `RootView` | Presented from above the split view, so the split view collapsing or expanding never dismisses it. |
| Library selection | `LibraryModel`, `@State` in `RootView` | The split view collapses to one stack on the closed phone. The selection lives above it, so the same episode shows after the phone opens again. |
| Resume points | `ResumePositions` inside `PlayerModel`, saved to `UserDefaults` as JSON | Saved on pause, on episode change, and when the scene leaves the foreground. |
| The fold | `@State` in `PlayerScreen` and `LibraryView` | Layout input, read from reserved regions. Never stored in a model: it belongs to the view that measured it. |

`duo-continuity` explains the rule behind this table: state above a layout switch survives it, state below it is rebuilt.

## One play, start to finish

1. In the detail, Play calls `player.play(episode)`, then sets `isPlayerPresented = true`.
2. `play(_:from:startPaused:)` records the old episode's position, starts a new `PlaybackQueue` (this episode, then the rest of its show from `Catalog.following(_:)`), and loads the item at the saved position.
3. `load` replaces the player's item, seeks with zero tolerance, activates the audio session and calls `playImmediately(atRate:)` with the chosen speed.
4. The periodic time observer runs four times a second. `tick` updates `position`, the real `duration` once the item knows it, the video's aspect from `presentationSize`, and `isPlaying` from `timeControlStatus`. Picture in Picture's own buttons can pause or play, so the model follows the player instead of trusting its own flag.
5. `upNext` is computed from `UpNextPolicy.card(position:duration:hasNext:dismissed:)`. The controls show the card when it is visible.
6. At the end, `AVPlayerItem.didPlayToEndTimeNotification` calls `itemDidEnd`. With autoplay on and a next episode, `playNext()` loads it. Otherwise playback stops and the position is saved.

The views never decide what plays next or when the card shows. That keeps the rules testable without a simulator.

## The fold, in three steps

1. **Read it.** `onFoldChange` (in `Shared/FoldReader.swift`) asks `reservedRegions(kind: .division, options: .includeInactive)` inside `onGeometryChange`, because the first layout pass has no regions yet. `.includeInactive` matters: the flat open phone reports its fold as inactive, and the mini player uses it so it doesn't jump when someone folds the phone. Before iOS 27.1 the modifier does nothing; there is no fold to read.
2. **Choose it.** `FoldGeometry(candidates:in:)` keeps only a region that splits the view into two non-empty parts, and prefers an active one. *Measured:* on the closed phone the query returned a region past the view's trailing edge (the status bar column), which must not read as a fold.
3. **Use it.** `FoldRegions.split(_:fold:)` returns the video region and the controls region, or `nil` when the controls should float. It needs an active fold that crosses the middle half of the view, so a narrow window beside the fold (Split View) keeps the overlay.

`FoldRegionsLayout` is one `Layout` type for every pose. Its two children keep their identity whatever it decides, so the video view and the controls are never rebuilt by a fold. An `if` on the fold would put them in two branches and rebuild them ([Layout](https://developer.apple.com/documentation/swiftui/layout)).

Frames the model tests use, *measured* on the iPhone Duo simulator (iOS 27.1):

| Pose | Window | Fold frame |
|---|---|---|
| Open, held wide, flat or book | 951 × 669 pt | x 455, y 0, 40 × 669 pt; active only in book |
| Open, held tall, flat or tabletop | 669 × 951 pt | x 0, y 455, 669 × 40 pt; active only in tabletop |
| Closed | 466 × 678 pt | none inside the view |

## Why `FoldRegionsLayout` and not `ArrangementView`

`duo-media` builds the tabletop player with `ArrangementView` and `.overlay`, which needs no fold code. This recipe deploys to iOS 26, where `ArrangementView` doesn't exist, so it uses one layout that works on both: below iOS 27.1 there are no regions and the controls simply float. It also gives you exact placement: the controls centre in their region, and the video moves up above the floating controls on the closed phone held upright (`FoldRegions.picture(aspect:in:covered:)`). If your app deploys to iOS 27.1, `ArrangementView` is a fine swap; keep the player model where it is.

## The library

- One `NavigationSplitView` with the selection bound to `LibraryModel`. Closed, it collapses to one stack; open, it shows both columns; in book pose the system evens the columns out at the fold (*measured*). Don't swap it for a `NavigationStack` by size class: that rebuilds the navigation state on every fold.
- The detail gets `.id(episode.id)`, so a new episode starts scrolled to the top. A fold doesn't change the ID, so the detail keeps its scroll position through a fold.
- The mini player rides in `safeAreaInset(edge: .bottom)` under both columns. `FoldRegions.floatingBarSpan(width:fold:)` puts it on the trailing side of a top-to-bottom fold, flat or folded, and full width otherwise. A bar across the open phone would put its buttons on the fold line.

## Background and Picture in Picture

- `RootView` reads `scenePhase`. In the background, `sceneMovedToBackground(true)` saves progress and takes the player off its layer unless Picture in Picture is running; iOS would otherwise pause a video whose layer is on screen. Back in the foreground, the layer gets the player again.
- `VideoSurface` tells the model when its view reaches a window. The model then makes the Picture in Picture controller from its own layer, once. The controller and the layer outlive every view.
- `canStartPictureInPictureAutomaticallyFromInline` is on: going home while a video plays floats it.
- The restore callback sets `isPlayerPresented = true`, so returning from the floating window opens the player screen again.

Details and limits: [media.md](media.md).

## Model API

| Member | What it does |
|---|---|
| `Catalog.decode(from:)`, `.episodes`, `episode(_:)`, `show(of:)`, `following(_:)` | The bundled catalogue and its lookups. `following` never crosses into another show. |
| `Episode.bundledFile`, `remoteURL`, `publishedDate` | A file in the bundle or an `https` URL; the day as a date. |
| `PlaybackQueue.start(_:then:)`, `advance()`, `goBack()`, `current`, `next`, `previous` | What plays now and next. A new start replaces the queue. |
| `UpNextPolicy.lead(for:)`, `card(position:duration:hasNext:dismissed:)`, `shouldAdvance(...)` | When the card shows (never more than half the episode before the end) and when the next episode starts. |
| `UpNextState` | `.hidden`, `.counting(seconds)`, `.waiting`. |
| `ResumePositions.record(_:at:duration:)`, `resume(_:)`, `progress(_:duration:)`, `isFinished(_:)`, `forget(_:)` | Where each episode stopped. Within 2 s of the start counts as not started; within 2 s or 3 percent of the end counts as finished. |
| `FoldGeometry(candidates:in:)`, `liesInside(_:of:)`, `isVertical` | Which region is the fold. |
| `FoldRegions.split(_:fold:)`, `floatingBarSpan(width:fold:)`, `fit(aspect:in:)`, `picture(aspect:in:covered:)` | Where the video, the controls and the mini player go. |
| `TimeText.clock(_:)`, `remaining(_:of:)`, `spoken(_:)` | "0:07", "−0:05", "12 seconds". |

Every type is `nonisolated` and `Sendable`. The app compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and so does the test program. Its last check runs in `Task.detached` and uses every model type, so a type that loses `nonisolated` stops the build. Add a line there for each new model type.

## Launch switches and the test marker

Debug builds only (`#if DEBUG`). The last copy of a switch wins. The full list is in the generated project's `README.md` and in `App/LaunchOptions.swift`: `-play`, `-paused`, `-start`, `-miniPlayer`, `-select`, `-upNextLead`, `-autoplay 0`, `-loop`, `-resetState`, `-uiTesting`.

With `-uiTesting`, `RootView` and `PlayerScreen` add a 1 × 1 pt accessibility element, `player.state`, whose value is the model's state: `item=small-repairs-1|playing=1|time=4|upNext=counting|pip=0|surfaces=1|presented=1|`. Each field ends with `|`, so a test waiting for `time=1|` never matches `time=12|`. `PlayerScreen` adds `player.layout`: `layout=overlay`, `layout=side-by-side` or `layout=stacked`. Without `-uiTesting` neither element exists, so VoiceOver never meets them.

## The UI tests

| Test | Checks |
|---|---|
| `testLibraryOpensAnEpisode` | Tapping a row shows its detail and the Play button. |
| `testPlayOpensThePlayerAndPlays` | Play presents the player; the time moves on. |
| `testPauseStopsTheClock` | Pause stops playback and the time. |
| `testSkipForwardAndBack` | The 10-second buttons move the position. |
| `testUpNextCardAppearsNearTheEnd` | No card 8 s before the end; the card appears and counts down near the end. |
| `testUpNextPlayNowStartsTheNextEpisode` | Play Now moves to the next episode and the card goes away. |
| `testCancelledUpNextStopsAtTheEnd` | Cancel closes the card; the episode stops at its end without moving on. |
| `testAutoplayMovesOnAtTheEnd` | The next episode starts by itself. |
| `testClosingThePlayerKeepsPlaying` | Closing the player shows the mini player and playback goes on; reopening shows the same episode further on. |
| `testSoundGoesOnInTheBackground` | The time goes on while the app is on the Home Screen. |
| `testPictureInPictureStarts` | The button starts Picture in Picture and goes back to the library. Skips where Picture in Picture isn't supported. |
| `testPlayerLayoutInThisPose` | Video and controls in the current pose (over, beside or below), every transport control at least 44 pt; saves a screenshot of each display. |

*Measured* (20 Oct 2026, closed Duo simulator, iOS 27.1): 11 passed, `testPictureInPictureStarts` skipped, about 140 s of tests. `testPlayerLayoutInThisPose` also passed in book pose (`layout=side-by-side`) and in tabletop (`layout=stacked`).

Duo simulator notes:

- Tap through `element.coordinate(withNormalizedOffset:)` (`tapCentre()` in the test file). Points worked out from the app's frame can miss the app on this simulator.
- The tests never set the pose. Set it in Device Hub (or with `duo-pose`), then run `testPlayerLayoutInThisPose` once per pose:

  ```bash
  Tools/run-ui-tests.sh -only-testing:FieldCastUITests/FieldCastUITests/testPlayerLayoutInThisPose
  ```

- `-parallel-testing-enabled NO` in `run-ui-tests.sh` stops `xcodebuild` from cloning the simulator; `-collect-test-diagnostics never` keeps a failing run from collecting a system diagnosis for minutes.
- `XCUIScreen.main` is the outer display, black while the phone is open (*measured*). The layout test attaches one screenshot per display from `XCUIScreen.screens`.

## What we measured

On the iPhone Duo simulator (Xcode 27.1, iOS 27.1, 20 Oct 2026), with Device Hub's pose buttons pressed by `duo-pose`:

- The player in closed, open, book and tabletop: controls over the video closed and flat, trailing in book, below the fold in tabletop, with the up next card inside them in every pose.
- One app process playing `-loop` through open, book, tabletop and closed: the time kept counting and the surface count stayed at 1 (see [media.md](media.md#what-we-measured)).
- Picture in Picture: `isPictureInPictureSupported()` returned `false` on the simulator, so the button is hidden there. Check it on a device.

Not yet checked: a real iPhone Duo, Split View with the player on one side, the system's own Picture in Picture placement when the phone is partly folded, Lock Screen controls (the template doesn't publish Now Playing yet).
