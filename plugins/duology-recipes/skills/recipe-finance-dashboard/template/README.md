# __APP_NAME__

A personal finance dashboard for iPhone Duo. Closed, it shows your balance, this month's spending and recent activity in one column. Open, it splits on the fold: balance and every transaction on one side, the spending chart or the transaction you picked on the other. Made from Duology's `recipe-finance-dashboard`.

## Run it

```bash
Tools/run-model-tests.sh      # the money maths, on your Mac, in seconds
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | Money, accounts, transactions and every total the screens show: month to date, budget pace, categories, merchant history. The pane math (`DuoColumns`, `PaneFrames`). Sample data. Foundation only. |
| `__APP_NAME__/Shared/` | Design tokens, the fold reader and `FoldPanes` (two panes split on the fold), category colours. |
| `__APP_NAME__/Dashboard/` | The dashboard: balance, money in and out, the spending chart (Swift Charts), categories, the activity list. |
| `__APP_NAME__/Detail/` | One transaction, with its category picker and what the merchant cost each month. |
| `__APP_NAME__/App/` | The app entry, the model the views share, the root view and the launch switches for tests. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `Tools/` | The model test program and both test scripts. |

## Your own data

The sample lives in `Model/SampleLedger.swift` and is pinned to 20 October 2026, so screenshots and tests don't change. To use real data, build a `Ledger` from your source in `LaunchOptions.makeModel()` and pass `Date()` as `now`. Keep amounts as `Money` (whole cents): never add up `Double`s.

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-select N` | Open transaction N. The sample's ids start at 1 with today's newest. |
| `-filter NAME` | Show one category in the activity list, for example `-filter dining`. |
| `-uiTesting` | Animations off. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each one by hand: closed shows one column; open and partly open show two panes with nothing in the fold.
- Pick a transaction, then close the phone: the transaction stays on screen. Open it again: it sits beside the list.
- Larger text: at the accessibility sizes, tiles stack and rows put the amount under the name.
