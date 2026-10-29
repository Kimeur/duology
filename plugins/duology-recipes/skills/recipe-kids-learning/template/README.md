# __APP_NAME__

An early-learning app for young children on iPhone Duo: counting, first letters and shapes, one question at a time. Each question can be read aloud, the answer buttons are big, and nothing scolds or times the child. Closed, the picture sits above the answers. Open, the question takes the left page and the answers the right. Set it on a table half folded and the picture sits above the fold with the answers below, on the half that rests on the table. Stars stay through every fold and after the app quits.

A Grown-ups button opens a parental gate (a multiplication typed on a number pad). Behind it: Reset Progress, the speech setting, what the app does with data, and the privacy policy link. The app has no networking, no ads, no analytics, no purchases and no tracking.

## Run it

```bash
Tools/run-model-tests.sh      # gate, activities, progress, layouts and privacy checks, on your Mac
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The rules: activities and sample questions, progress, the parental gate, the two-pane layout, the answer grid, fold geometry. Foundation and CoreGraphics only. |
| `__APP_NAME__/Learn/` | The home screen, the lesson screen and the big buttons. |
| `__APP_NAME__/Grownups/` | The gate and the grown-ups area. The only place that opens a link. |
| `__APP_NAME__/Shared/` | The fold reader, the two-pane layout, pictures, the speaker, test markers. |
| `__APP_NAME__/App/` | The app entry, the root view, the store and the launch switches for tests. |
| `__APP_NAME__/PrivacyInfo.xcprivacy` | No tracking, no data collected, UserDefaults with reason CA92.1. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `__APP_NAME__/Assets.xcassets/` | The accent colour and a placeholder app icon: one 1024 × 1024 image, from which Xcode makes the other sizes. Replace the icon with your own before you ship. |
| `Tools/` | The model test program and both test scripts. |

## Before you ship

- Replace the sample questions in `Model/SampleActivities.swift`. Keep question IDs stable once children have stars for them. `Tools/run-model-tests.sh` checks the content.
- Replace the privacy policy address in `Model/AppFacts.swift` with your own page. Use the same address in App Store Connect.
- Replace the placeholder app icon in `Assets.xcassets/AppIcon.appiconset` with your own 1024 × 1024 image, without transparency.
- Keep the text in the grown-ups area true. If you add anything that saves or sends data, update that text, the privacy manifest and your App Store Connect privacy answers together.
- In App Store Connect, the Kids Category, the age band and the privacy answers are yours to set.
- `Tools/run-model-tests.sh` fails if networking, tracking or purchase APIs appear in the app's sources, or if a link out appears anywhere but the grown-ups area.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-open ID` | Open an activity: `counting`, `letters` or `shapes`. |
| `-question N` | With `-open`: start at this question, counting from 0. |
| `-gateSeed N` | The parental gate's questions come from this seed, so they repeat. |
| `-resetState` | Forget the stars, where each activity is, and the speech setting. |
| `-uiTesting` | Animations off, speech muted (what would be said is recorded), test markers on. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each by hand: closed, the picture above the answers; open and held wide, the question on the left of the fold and the answers on the right; folded like a book, the same; Partially Open then Rotate Right (tabletop), the picture above the fold and the answers below it.
- Answer a question, then close, open and fold the phone: the stars, the question and the Next button stay.
- The speech plays through the simulator's audio. With `-uiTesting` it is muted.
