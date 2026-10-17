---
id: duo-layout/existing-list-app
skill: duo-layout
also: duo-start, duo-lint, duo-continuity, duo-navigation
title: Make an existing list app work on Duo
readme: yes
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: yes
checklist: R2 R3 R4 R5 R6 R10
timeout: 2400
status: ready
---

# Make an existing list app work on Duo

The flagship task in the main README. A typical SwiftUI app written before iPhone Duo existed has to work on both displays and through folds.

## Prompt

```text prompt
Make this app work well on iPhone Duo. People will use it closed, on the outer display, and open, on the inner display, and they fold and unfold it all the time. Keep every feature the app has today.
```

## Starting point

Fixture [`Places`](../../fixtures/Places): three tabs (Places, Gallery, Settings), iOS 17 target, Swift 5 mode, builds with Xcode 27.1. It has the mistakes listed in [fixtures/README.md](../../fixtures/README.md#places): `UIScreen.main`, an idiom check, regular width treated as iPad, a 390 pt column, an orientation-based grid with odd column counts, a floating button centred on the screen, a custom bottom bar and search and selection state that a fold throws away.

## Pass checks

Gates: the app builds for the iPhone Duo simulator, and duo-lint reports nothing.

```sh check no-ipad-assumption
# Layout is chosen by size class or space, never by "iPad".
no_src '\b(isPad|isIPad|isiPad)\b'
no_src 'userInterfaceIdiom'
```

```sh check search-survives-fold
# The search text has one owner (a view's @State or @SceneStorage, or a model object),
# created once, above any layout switch.
pycheck single_owner.py '\bvar +(query|searchText|searchQuery|searchTerm)\b'
```

```sh check add-button-off-fold
# The floating + button no longer sits centred at the bottom of the whole screen,
# or the code reads the fold's reserved region and moves it.
if [ -n "$(src_grep 'reservedRegions\(kind: *\.division')" ]; then exit 0; fi
no_src 'overlay\(alignment: *\.bottom\)'
```

```sh check features-kept
has_src 'New place'
has_src 'Directions'
has_src 'deviceSummary'
```

```sh check launches
# The existing UI test still passes on the iPhone Duo simulator.
xcb_test -only-testing:PlacesUITests
```

## Checklist

A reviewer runs the app on the iPhone Duo simulator closed and open, and partly folded in Device Hub, and marks:

- **R2**: scroll halfway, search, pick a place, then unfold and fold. Same search text, same place, same scroll position.
- **R3**: nothing is sized for the other display; no fixed column with dead space.
- **R4**: partly folded, no control touches the fold.
- **R5**: open and held wide, the gallery has an even number of columns and the fold falls in a gap.
- **R6**: closed, every bar item sits in the side bar with a symbol and a title; no custom bottom bar.
- **R10**: every action open is reachable closed.
