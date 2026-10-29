# Architecture of the notes recipe

How the app made by `recipe-notes-ai` is put together, who owns what, and what we ran. *Measured* means on the iPhone Duo simulator (iOS 27.1, Xcode 27.1) on 29 October 2026.

## The layers

| Layer | Files | Rules |
|---|---|---|
| Model | `Model/*.swift` | Foundation and CoreGraphics only. Every type `nonisolated` and `Sendable`, so the Mac tests build it with the app's settings and use it off the main actor. |
| AI | `AI/OnDeviceSummarizer.swift`, `AI/SummaryService.swift` | The only code that imports Foundation Models (`OnDeviceSummarizer`), and the one place that owns a request's task (`SummaryService`). |
| Views | `Notes/*.swift`, `Shared/*.swift` | Read the store; never own a request, never pick a layout from the device or the pose. |
| App | `App/*.swift` | `RootView` owns the one `NotesStore`; `LaunchOptions` reads the switches in Debug builds only. |

## Who owns what

| State | Owner | Survives |
|---|---|---|
| The notes and their summaries | `Notebook` in `NotesStore`, saved to `Application Support/Notes.json` after every change; a file the app can't read is moved aside (`Notes.unreadable-<time>.json`), never saved over | folds, quitting, relaunch |
| The summary in progress (`phase`, `draft`, the task) | `SummaryService` in `NotesStore` | folds, leaving the note's screen |
| The note on screen | `NotesStore.path` | folds |
| The summary sheet | `NotesStore.showsSummarySheet`, presented by `RootView` | folds; `NoteScreen` closes it when the pane fits beside |
| The fold and the size | `@State` in `NoteScreen` and `NotesListScreen` | read again after every change |

`RootView` never changes identity, so neither does the store. A fold resizes the window; the editor is the first subview of one `PaneSplit` in every pose, so SwiftUI keeps the same text view, its cursor and its scroll position.

## One summary, start to finish

1. Summarize calls `NotesStore.summarize(_:)`. A note under 12 words can't be summarized: the button is disabled and the pane says to write more.
2. `SummaryService.summarize(_:finish:)` cancels any request still running, sets `phase = .working(id)` and an empty `draft`, takes the note's fingerprint (FNV-1a of its text) and its `PromptBudget`, and starts one `Task`.
3. The engine decides what runs. `.automatic` asks the model when `OnDeviceSummarizer.unavailableReason` is nil, otherwise makes the simple summary with that reason. `.onDeviceAI` always asks the model. `.standIn`, `.failing` and `.simple` are for tests.
4. `OnDeviceSummarizer.summarize` opens a new `LanguageModelSession` with the constant instructions and streams `GeneratedDigest`. Each snapshot's partial content becomes a `DigestDraft`; the views show it as it grows.
5. The last draft is tidied into a `Digest` (`DigestDraft.finished`): list markers and quotes removed, blank and repeated lines dropped, the headline cut to 10 words, at most 4 points and 5 to-dos.
6. Any error other than cancellation is logged (domain and code public, the description private) and replaced by `SimpleSummary.digest(of:fallbackReason:)`.
7. `finish` saves the digest with the note. The note's date doesn't change: a summary isn't an edit. If the note changed meanwhile, the digest's fingerprint no longer matches and the pane says "The note changed after this summary".
8. Stop cancels the task: no digest is saved and the note keeps the one it had.

## The layout in each pose

`NoteLayout(size:fold:barHeight:)` has four modes:

| Mode | When | Editor | Summary |
|---|---|---|---|
| `foldLeftRight` | a fold runs top to bottom across the middle half (open, book) | left of the fold's frame | right of it: the full pane |
| `foldTopBottom` | a fold runs side to side across the middle half (tabletop, open held tall) | above the fold's frame | below it: the full pane |
| `sideBySide` | no fold, at least 700 pt wide and wider than tall (an iPad) | 58 % of the width | the rest: the full pane |
| `single` | anything else (closed, closed sideways, narrow Split View) | all but the bar | the bar at the bottom, 64 pt at the default text size, never more than half the screen |

The fold is read with `.division` and `.includeInactive` on the `PaneSplit` itself, so flat and folded give the same regions and folding moves nothing. A fold that doesn't cross the middle half (a window beside it in Split View) is ignored.

The list uses `NoteColumns`: where a fold runs top to bottom, two columns meet at its frame; otherwise as many columns of at least 280 pt as fit, up to three. In tabletop the list scrolls across the horizontal fold; the cards are 119 pt tall, so a card under the fold is half visible above it and can be scrolled clear. A list of full-width rows would put every row across the fold of an open phone.

### The keyboard in tabletop

In `foldTopBottom` the note screen ignores the keyboard's safe area: the keyboard covers the summary pane on the bottom half and leaves the note above the fold as it was. Elsewhere the regions make room for it, so the text being typed stays visible. *Unverified* with a software keyboard on a device.

## The UI tests

All tests read markers, never positions, so the same test passes in every pose. `testNoteLayoutInThisPose` and `testListInThisPose` attach the real frames and a screenshot of each display.

What the first runs found, now fixed:

- On the closed iPhone Duo the navigation bar's buttons sit in a vertical bar beside the screen and aren't children of `app.navigationBars`. The back button's identifier, `BackButton`, is the same everywhere; the tests use it.
- The list's marker isn't on screen while a note is pushed above it, so a test reads it only on the list.
- The `simple` engine attached a reason ("by this build's settings") to every summary; a simple summary by choice now has none, and the label already says it isn't AI.

## What we ran

### A summary through real folds

`testStreamKeepsGoingThroughFolds` reads the `note.state` marker every half second while the stand-in streams the offsite note's summary at 2.5 s a step. While it ran, `duo-pose set` pressed Open, Partially Open and Closed in Device Hub.

| Time | Layout | What had arrived |
|---|---|---|
| 0 s | `single` (closed) | nothing yet |
| 5.6 s | `foldLeftRight` (open) | 2 words of the headline |
| 17.8 s | `foldLeftRight`, folded (book) | 7 words |
| 28.3 s | `single` (closed) | the 10-word headline and 1 point |
| about 40 s | `single` | the whole summary, saved once |

The headline and the points never shrank, so nothing restarted; the test fails if either count goes down. In an earlier run at 1.5 s a step, the step after the change to open came 0.7 s late, then the pace went back to normal (`duo-intelligence` measured up to 1.4 s for its probe).

| Run | Result |
|---|---|
| `Tools/run-model-tests.sh`, template and a generated project | 119 checks, 0 failed |
| `xcodebuild build`, generated project, iPhone Duo simulator | succeeded, no warnings from the app's code |
| `Tools/run-ui-tests.sh`, closed | all 11 passed, about 210 s, in a freshly generated project |
| `testNoteLayoutInThisPose`, `testListInThisPose`, `testSummaryGoesOutOfDateAndSurvivesARelaunch` in open, book, tabletop and closed (poses set with `duo-pose`) | all passed; frames in SKILL.md section 3 |
| `-summarizer ai` on the simulator | every request failed; the log's underlying error: "InferenceError::operationNotAllowed::Simulator is not supported" from the guardrail's text sanitizer, reported as `FoundationModels.LanguageModelError` code -1; the app showed the simple summary with its reason |
| `duo-lint --strict` on a generated project | 0 findings (24 files) |

## Not yet verified

- Summaries from the real model: quality, speed, refusals, other languages. They need a device with Apple Intelligence.
- `PromptBudget`'s 6,000 characters against the real token count (`SystemLanguageModel.tokenCount(for:)`, iOS 26.4).
- The software keyboard in tabletop, the closed phone held sideways, the open phone held tall, Split View, VoiceOver, right-to-left languages, a real iPhone Duo.
