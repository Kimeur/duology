# __APP_NAME__

A two-player game for one iPhone Duo. Each player gets half the screen. Targets pop up, you tap yours, and the first to the goal wins. Made from Duology's `recipe-two-player-game`.

## Run it

```bash
Tools/run-engine-tests.sh     # the game rules, on your Mac, in seconds
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Engine/` | The rules: players, rounds, countdown, hits, misses, lockout, winner, rematch, where targets go. Foundation only. |
| `__APP_NAME__/Duel/` | The game screen: the split, each player's half, the score bar, haptics. |
| `__APP_NAME__/Shared/EvenSplit.swift` | Two equal halves in every pose: side by side when wide, stacked when tall. |
| `__APP_NAME__/Home/` | The start screen: goal, face to face, haptics. |
| `__APP_NAME__/App/` | The app entry, the root view and the launch switches for tests. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `Tools/` | The engine test program and both test scripts. |

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-openDuel` | Skip the home screen. |
| `-autoReady` | With `-openDuel`: start the round at once. Handy for screenshots. |
| `-faceToFace` | Turn each half to face its player, for a phone lying flat between two people. |
| `-goal N` | Hits to win. |
| `-countdown N` | Countdown seconds. |
| `-lockout N` | Seconds a miss locks that player out. |
| `-timeLimit N` | Round length in seconds; 0 means no limit. |
| `-seed N` | Fixed target positions. |
| `-uiTesting` | Animations off. |

## Testing notes

- Two people can't touch at once in the simulator. The UI tests take turns. Try real two-player play on a device.
- Poses change only in Device Hub (Closed, Partially Open, Open). Check each pose by hand: both halves show, and no target sits on the fold.
- Right to left: add `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` to the scheme's arguments. Player 1 keeps the top or left half; the text reads right to left.
