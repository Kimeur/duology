# Architecture of the kids learning recipe

How the generated project fits together, why each piece sits where it does, and what we ran to check it. Paths use `<App>` for the app name you gave `new-project.sh`.

## The layers

```text
<App>App                          launch switches, nothing else
 └─ RootView                      owns the one LearningStore; never changes identity
     ├─ NavigationStack(path:)    the path lives in the store
     │   ├─ HomeScreen            PaneSplit: welcome | activity cards; Grown-ups in the bar
     │   └─ LessonScreen          pushed for an Activity.ID
     │       └─ PaneSplit         question pane | answers pane, one layout in every pose
     │           ├─ question      stars, picture, question, feedback, speaker button
     │           └─ answers       TileGrid of answers, or Next, or Play Again | All Activities
     └─ .sheet                    GrownupsSheet: GateScreen, then GrownupsScreen once passed
```

`<App>/Model/` sits under all of it and imports Foundation and CoreGraphics only: `Activity`, `SampleActivities`, `Progress`, `ParentalGate`, `LessonLayout`, `AnswerGrid`, `FoldGeometry`, `AppFacts`. Every type is `nonisolated` and `Sendable`, so the same files compile in the app (default main actor isolation) and in the Mac test program.

## Who owns what

| Thing | Owner | Why there |
|---|---|---|
| Stars, the question each activity is on, wrong tries on it, "solved, Next showing" | `Progress` in `LearningStore`, saved to `UserDefaults` as JSON on every change | A fold rebuilds what sits below a layout change; the store sits above all of it, so nothing a child did can be lost, and it survives quitting. |
| The navigation path | `LearningStore.path` | The lesson stays pushed through every fold. |
| The gate: question, digits typed, attempts | `ParentalGate` in `LearningStore` | A half-typed answer survives a fold; the sheet is attached to `RootView`, which never changes identity. |
| Gate open, grown-ups area unlocked | `isGateOpen`, `gatePassed` in the store | Closing the sheet any way (Done, Close, a swipe, a wrong answer) runs `closeGate()`, which locks the area again. |
| The speech setting | `LearningStore.readsAloud`, its own `UserDefaults` key | Set in the grown-ups area; read by the lesson and the gate. |
| The speaker | `Speaker` in the store | One `AVSpeechSynthesizer` for the app; a fold never cuts a sentence by rebuilding it. |
| The fold, the screen's size, the answers pane's size | `@State` in each screen | Derived from geometry, rebuilt whenever it changes. |

The rule behind the table is `duo-continuity`'s: state above a layout switch survives it. Here the state that matters is a few numbers and IDs, and it lives above everything.

## One answer, start to finish

1. The child taps an answer. `LessonScreen.choose(_:)` calls `LearningStore.pick(_:in:)`.
2. `Progress.pick(_:in:)` answers `.right`, `.wrong` or `.ignored` (the question is solved, that answer was tried, or it isn't there). Right: the question's ID joins `solved` (one star, once) and the turn is marked solved. Wrong: the answer joins the turn's `wrong` list. The store saves.
3. The lesson redraws from the store: a wrong answer is dimmed and disabled; a right one swaps the answers for a star, "Great job!" and a Next button in the same pane.
4. Feedback is spoken: VoiceOver posts it as an announcement when it's on; otherwise the speaker says it, if speech is on.
5. Next calls `Progress.next(in:)`. After the last question the turn's index equals the question count: the activity is done, and the answers pane offers Play Again and All Activities.

No timers anywhere, and nothing taken away for a wrong answer. The views never decide what an answer means; that keeps every rule testable on the Mac.

## The layout in each pose

`LessonLayout(size:fold:firstShare:spacing:)` returns a mode and two rectangles. `PaneSplit`, a SwiftUI `Layout`, places its two subviews in them; the screen reads the fold with `.onFoldChange` on the `PaneSplit` itself, so the fold's frame and the rectangles share one coordinate space. `FoldGeometry` and `onFoldChange` are `recipe-reader`'s files: the `.division` reserved region read with `.includeInactive` inside `onGeometryChange`.

| Fold in the screen | Mode | First pane (question, welcome) | Second pane (answers, cards) |
|---|---|---|---|
| Top to bottom, crossing the middle half, flat or folded | `foldLeftRight` | up to the fold's frame | after it |
| Side to side, crossing the middle half, flat or folded | `foldTopBottom` | above the fold's frame | below it, the half on the table |
| None, taller than wide | `stacked` | top half (home: 30%) | the rest, 16 pt below |
| None, wider than tall | `sideBySide` | left half (home: 30%) | the rest, 16 pt beside |

- Flat and folded give the same rectangles, so folding moves nothing (checked on the Mac).
- A fold near the screen's edge (Split View beside the fold) is ignored, as in `recipe-reader`.
- There is no `if` on the pose around the panes: one `PaneSplit`, so neither pane is rebuilt.

Inside the answers pane, `AnswerGrid(count:in:spacing:largest:)` picks the column count (only counts that fill every row: one row, one column, or two by two) whose buttons' shorter side is longest, with buttons capped at 360 × 220 pt. `TileGrid` lays the buttons out from it.

### Big targets: our number

`AnswerGrid.minimumTarget` is 88 pt: twice the 44 pt minimum Apple asks for. That is our choice for small, less precise fingers, not an Apple rule. The Mac tests check that two, three and four answers stay above it in every measured pose; the UI tests check every answer, the speaker button, Next and the home cards on the simulator. The gate's keys are 64 pt high (adults use them) and the Grown-ups button is a system bar button.

### Size feedback (measured)

The first run on the closed phone drew the answers 434 pt wide in a 382 pt screen: a `.frame(maxWidth: .infinity)` grows to fit fixed-size children, so the measured width fed the buttons, and the buttons held the width. `recipe-reader` measured the same loop for its pages. Every measured frame now has `minWidth: 0` and `minHeight: 0`; after the fix the three answers measured 106 × 220 pt inside the 382 pt pane.

## The parental gate

`ParentalGate(seed:)` holds the question, the typed digits, `attempts` and `failures`, and a `SeededGenerator` (SplitMix64) that maps numbers to ranges with its own arithmetic, so a seed always gives the same questions.

- `type(_:)` takes digits 0 to 9, at most three, with no leading zero; `deleteLast()`; `canCheck` once something is typed.
- `check()` returns `.passed`, `.failed`, or `.notReady` with nothing typed (no attempt counted). Either way a new question replaces the old one, never the same one twice in a row.
- `cancel()` clears the digits and keeps the question.

`LearningStore.checkGate()` opens the grown-ups area on `.passed` and closes the sheet on `.failed`. `GateScreen` speaks `AppFacts.gatePrompt` when it appears (speech on, VoiceOver off), and has a button to say it again. More on the rules it follows: [kids-rules.md](kids-rules.md).

## Speech

`Speaker.say(_:)` stops anything still being said, then speaks with `AVSpeechSynthesizer` in `AppFacts.speechLanguage` (`en-US`, the sample's language) at 85% of the default rate. Before the first sentence it sets the audio session to `.playback` with the `.spokenAudio` mode and `.interruptSpokenAudioAndMixWithOthers`: the words play with the Ring/Silent switch on silent, a podcast in another app pauses, music mixes in (*unverified* on a device; the simulator has no switch). With `-uiTesting` it is muted and records `lastRequest`, which the lesson's marker reports as `said=`.

A new question is read aloud when it appears, through `.task(id: question?.id)`: a fold doesn't change the ID, so it never repeats a question. Parents turn automatic speech off in the grown-ups area; the speaker button always works.

## Model API

| Member | What it does |
|---|---|
| `Activity`, `Question`, `Answer`, `Art`, `Tint` | Content as plain data. `Activity.problems` lists what is wrong with an activity's content. |
| `SampleActivities.all` | Counting, First letters, Shapes: four questions each. |
| `Progress.pick(_:in:)`, `next(in:)`, `playAgain(_:)`, `jump(to:in:)`, `reset()` | What a tap does. |
| `Progress.stars`, `stars(in:)`, `turn(in:)`, `question(in:)`, `isFinished(_:)` | What the screens show. |
| `ParentalGate`, `GateQuestion`, `SeededGenerator` | The gate. |
| `LessonLayout`, `AnswerGrid` | The panes and the buttons. |
| `FoldGeometry(candidates:in:)` | Which reserved region is the fold. Same type as `recipe-reader` and `duo-postures`. |
| `AppFacts` | Privacy policy address, speech language, the spoken prompts. |

## Launch switches and test markers

Debug builds only (`#if DEBUG`); the last copy of a switch wins: `-uiTesting`, `-resetState`, `-open ID`, `-question N`, `-gateSeed N`. The table is in the generated project's `README.md`.

With `-uiTesting`, screens add 1 × 1 pt markers whose values the tests parse: `home.state` (`stars=0|mode=stacked|folded=0|size=382x562|fold=|`), `lesson.state` (`activity=counting|question=0|of=4|solved=0|wrong=|finished=0|stars=0|mode=stacked|folded=0|size=382x562|fold=|grid=3x1|button=106x220|said=How many stars can you count?|`), `gate.state` (`left=7|right=5|entry=|attempts=0|failures=0|`) and `grownups.state`. Two more kinds of marker give real frames: `frameMarker` puts an element the size of each pane behind it (a container's frame in a UI test is the union of its children, not the pane: *measured*), and `foldMarker` puts one exactly where the fold is. Without `-uiTesting` none of them exist, so VoiceOver never meets them.

## The UI tests

| Test | Checks |
|---|---|
| `testHomeOpensAnActivity` | Three cards, no stars; a card opens its activity at question 1; the question is read aloud. |
| `testAnsweringEarnsAStar` | A wrong answer is set aside with gentle words, no star and no penalty, and can't be picked again; the right one earns a star, shown on screen; Next moves on. |
| `testProgressSurvivesARelaunch` | After a relaunch, the star, the card's count and the solved question with Next are back. |
| `testSpeakerReadsTheQuestion` | The speaker button is at least 88 pt and reads the question again. |
| `testFinishingAnActivity` | After the last question, the activity is done; Play Again starts over and keeps the stars. |
| `testGateClosesOnAWrongAnswerAndOpensOnTheRightOne` | A wrong answer closes the gate and the area stays shut; the next question differs; the right answer opens the area (reset, privacy policy, speech setting); Done locks it again; the same seed asks the same first question after a relaunch. |
| `testResetProgressIsBehindTheGate` | The area shows the stars; reset asks first, then clears them everywhere. |
| `testLessonLayoutInThisPose` | Panes don't overlap; by mode, the question ends at the fold and the answers start after it or below it; every answer, the speaker and Next at least 88 pt and off the fold. Attaches the frames and a screenshot of each display. |
| `testHomeAndGateInThisPose` | Panes don't overlap; cards at least 88 pt and off the fold; every gate key there, at least 44 pt. Attaches frames and screenshots. |

Duo simulator notes (*measured*):

- Tap through `element.coordinate(withNormalizedOffset:)` (`tapCentre()`), as in the other recipes.
- The simulator is shared. While these tests ran, other sessions launched their own apps on it; XCUITest logged waiting for those apps, then reactivated ours, and a tap made in between was lost. So every tap goes through `tap(_:in:until:)`, which taps, waits for the state the tap causes, and taps again (three times at most) only if it never came. All the taps in the suite are safe to repeat; a typed gate digit is checked before the next one.
- Read a button's frame before tapping it: `PressableStyle` shrinks a pressed button to 95%, and a frame read just after the tap came back as 87.3 pt.
- `XCUIScreen.main` is the outer display; the tests attach one screenshot per display from `XCUIScreen.screens`.
- `run-ui-tests.sh` passes `-parallel-testing-enabled NO` (no simulator clones) and `-collect-test-diagnostics never`.

## What we ran

See [the pose table in SKILL.md](../SKILL.md#3-how-it-behaves-in-each-pose) for the numbers per pose.

| Check | Result |
|---|---|
| `Tools/run-model-tests.sh` (Mac, Swift 6.4, `-default-isolation MainActor`) | 164 passed, 0 failed, in the template and in a freshly generated project |
| `swiftc -typecheck` of the app sources, iOS 26.0 and iOS 27.1 simulator targets | no errors, no warnings |
| `xcodebuild build-for-testing`, iPhone Duo simulator (iOS 27.1) | succeeded, no warnings from the app's code |
| `duo-lint.py --strict` on a generated project | 0 findings (25 files) |
| The nine UI tests, closed | all passed (about 160 s), after the fixes described above |
| `performAccessibilityAudit`, closed: lesson, home, gate | no clipped text and no missing labels after the fixes; still reported: the answer numbers' fixed font size (they are pictures scaled to fill their tile) and contrast and Dynamic Type on the gate's Close, a system toolbar button |
| Largest accessibility size (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`, this app only), closed | looked at: the question pane scrolls with the question first; cards and the gate header stack; nothing cut off. Before the fix the question read "Whic…" |
| Open (flat, held wide), book and tabletop, each set with `duo-pose` | `testLessonLayoutInThisPose` and `testHomeAndGateInThisPose` passed in each pose (2 of 2, 45 to 55 s), with the frames in SKILL.md section 3 |
| `new-project.sh` refusals | `Tools`, `tools`, `1abc`, `Swift-UI`, `AVFoundation` and `bad_bundle` exit 65; a non-empty folder and a file exit 73; two arguments exit 64; nothing created |

## Not yet verified

- The open phone held tall. The Mac tests cover it at `recipe-reader`'s measured sizes only.
- Progress through a real fold. The store above the stack is the pattern `duo-continuity` and `recipe-reader` measured through Device Hub's poses; this app's own runs measured relaunch, not a fold.
- The closed phone held sideways.
- Speech on a device: the Ring/Silent switch, the effect on other apps' audio, voice quality.
- A VoiceOver walk with `XCUIDevice.shared.voiceOverService` (the audit ran; the walk didn't).
- Right-to-left languages.
- Whether App Review accepts the privacy policy link one gate away as easy to reach (guideline 5.1.1(i)); our reading says yes.
- A real iPhone Duo.
