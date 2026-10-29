# __APP_NAME__

A notes app for iPhone Duo with summaries from Apple's on-device model. Each note can be summarized into a headline, its key points and its to-dos. Closed, the note fills the screen and the summary is one line at the bottom, with Details for the rest. Open, the note takes the left page and the summary pane the right. Set it on a table half folded and the note sits above the fold with the summary below. A summary still streaming in keeps going through every fold.

Summaries are made on the device with Foundation Models. The notes never leave it: no network, no Private Cloud Compute, no tracking. When the model can't run (Apple Intelligence off, an older iPhone, the simulator) or a request fails, the app makes a simple summary from the note's own sentences instead and says so.

## Run it

```bash
Tools/run-model-tests.sh      # notes, summaries, layouts and privacy checks, on your Mac
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

On the simulator the on-device model fails every request, so every summary there is the simple one. Try AI summaries on a device with Apple Intelligence turned on.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The rules: notes and the notebook file, summaries, the simple summary (no AI), the prompt budget, the layouts, fold geometry, sample notes. Foundation and CoreGraphics only. |
| `__APP_NAME__/AI/` | `OnDeviceSummarizer` (the only file that talks to the model) and `SummaryService` (one summary at a time, and the fallback). |
| `__APP_NAME__/Notes/` | The notes list, the note screen with its editor, and the summary pane, bar and sheet. |
| `__APP_NAME__/Shared/` | The fold reader, the two layouts, test markers. |
| `__APP_NAME__/App/` | The app entry, the root view, the store and the launch switches for tests. |
| `__APP_NAME__/PrivacyInfo.xcprivacy` | No tracking, no data collected, no required-reason API. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `__APP_NAME__/Assets.xcassets/` | The accent colour and a placeholder app icon: one 1024 × 1024 image, from which Xcode makes the other sizes. Replace the icon with your own before you ship. |
| `Tools/` | The model test program and both test scripts. |

## Before you ship

- Try the summaries on a device with Apple Intelligence, in each language you support. Judge them on your own notes, not ours.
- Replace the sample notes in `Model/SampleNotes.swift`, or start with none.
- Replace the placeholder app icon in `Assets.xcassets/AppIcon.appiconset` with your own 1024 × 1024 image, without transparency.
- Keep the line "Your notes never leave it" true. If you add sync, sharing or Private Cloud Compute, change that line, the privacy manifest and your App Store Connect privacy answers together. `Tools/run-model-tests.sh` fails if networking or Private Cloud Compute appear in the app's sources.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-open ID` | Open a note: `sample.offsite`, `sample.sourdough`, `sample.garden`, `sample.groceries`, or `new` for a new one. |
| `-summarize` | With `-open`: start summarizing that note at launch. |
| `-summarizer NAME` | `automatic` (the default), `ai` (always ask the model), `simple`, `standin` (streams a simple summary word by word) or `failing` (fails after a second). |
| `-standInPace SECONDS` | The stand-in's time per step. 0.15 by default. |
| `-resetState` | Delete the saved notes; the sample notes come back. |
| `-uiTesting` | Animations off, test markers on. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each by hand: closed, the note with the bar below; open and held wide, the note left of the fold and the summary right of it; folded like a book, the same; Partially Open then Rotate Right (tabletop), the note above the fold and the summary below it.
- Start a summary with `-summarizer standin -standInPace 1`, then close, open and fold the phone while it streams: the words keep coming, with no restart.
- The model's failures are in the log, without the note's text: `xcrun simctl spawn <UDID> log show --last 5m --predicate 'subsystem == "__BUNDLE_ID__"'` (the simulator's UDID from `xcrun simctl list devices`).
