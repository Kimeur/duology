# __APP_NAME__

A shop for iPhone Duo that sells sound packs with StoreKit 2. Closed, it shows the packs two per row, with each pack on its own screen. Open, the grid spans both halves with the fold as its middle gap; pick a pack and it opens beside the grid. The basket and the Plus subscription screen split on the fold too: what you get on one side, the price and the button on the other. Made from Duology's `recipe-shop`.

## Run it

```bash
Tools/run-model-tests.sh      # basket, checkout and catalog rules, on your Mac, in seconds
open __APP_NAME__.xcodeproj   # choose the iPhone Duo simulator, then Run
Tools/run-ui-tests.sh         # the UI tests on the iPhone Duo simulator
```

You need Xcode 27.1 or later. The scripts use `/Applications/Xcode-27.1.app` unless you set `DEVELOPER_DIR`.

## No network, no real products

Prices and purchases come from `StoreKit/Shop.storekit`, a local StoreKit configuration. The scheme passes it to the app when Xcode runs it (Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration). Purchases in the simulator are free and stay on this Mac. To clear them, choose Debug > StoreKit > Manage Transactions in Xcode and delete them.

The UI tests don't get the scheme's configuration under `xcodebuild test`, so they open their own StoreKit test session on the same file (see `__APP_NAME__UITests`). The simulator keeps that session for the app afterwards, purchases included.

Before Xcode or the UI tests have run it with the configuration, the app shows "–" for prices, for example when you install it with `simctl` and launch it from the Home Screen.

Before you ship:

1. Create the same products in App Store Connect, with the same IDs.
2. Replace the sample in `__APP_NAME__/Model/SampleCatalog.swift` and in `StoreKit/Shop.storekit` together. `Tools/run-model-tests.sh` fails when they disagree.
3. Replace the Privacy Policy link in `__APP_NAME__/Plus/PlusScreen.swift`.

StoreKit sells digital goods that people use in the app. For physical goods, use Apple Pay or your payment provider; the layouts stay the same.

## What's where

| Folder | What it holds |
|---|---|
| `__APP_NAME__/Model/` | The catalog, the basket, what the person owns, checkout one pack at a time, plan savings, the grid math (`DuoColumns`, `PaneFrames`). Foundation only. |
| `__APP_NAME__/Store/` | The only StoreKit code: products, purchases, entitlements, restore. |
| `__APP_NAME__/Shop/` | The grid, the Plus card and the new pack card. |
| `__APP_NAME__/Detail/` | One pack: price, basket button, sounds. |
| `__APP_NAME__/Basket/` | The basket and checkout. |
| `__APP_NAME__/Plus/` | The Plus subscription screen. |
| `__APP_NAME__/Shared/` | Design tokens, the fold reader, `FoldPanes`, `ActionPanes`, the pack artwork. |
| `__APP_NAME__/App/` | The app entry, the model the views share, the root view and the launch switches for tests. |
| `StoreKit/` | The local StoreKit configuration. |
| `__APP_NAME__UITests/` | UI tests that drive the real app. |
| `Tools/` | The model test program and both test scripts. |

## Launch switches

Debug builds only. Add them in the scheme (Product > Scheme > Edit Scheme > Arguments) or in UI tests.

| Switch | Effect |
|---|---|
| `-select ID` | Open a pack, for example `-select pack.harbor`. |
| `-category NAME` | Show one category, for example `-category rain`. |
| `-basket ID,ID` | Start with these packs in the basket. |
| `-openBasket` | Start on the basket. |
| `-openPlus` | Start on the Plus screen. |
| `-uiTesting` | Animations off. |

## Testing notes

- Poses change only in Device Hub (Closed, Partially Open, Open). Check each one by hand: closed shows two packs per row; open shows four, two on each side of the fold, and nothing in the fold when partly open.
- Pick a pack, then close the phone: the pack stays on screen. Open it again: it sits beside the grid.
- Buy a pack from the basket, then cancel the App Store sheet: checkout stops and offers "Buy the rest".
