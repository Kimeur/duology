---
id: duo-patterns/list-detail
skill: duo-patterns
title: List-detail that keeps the selection
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R2 R3 R10
timeout: 1800
status: ready
---

# List-detail that keeps the selection

## Prompt

```text prompt
Turn the Places tab into a proper list-detail layout. Closed, the list pushes the detail. Open, the list and the detail sit side by side. If I pick a place on the closed phone and then open it, that place must still be selected and shown.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). Today the tab switches between two hand-made layouts with an `if` on size class; the wide one pins the list to 390 pt.

## Pass checks

Gate: builds for the iPhone Duo simulator.

```sh check system-container
# A system container that adapts to both displays and avoids the fold.
has_src 'NavigationSplitView|ArrangementView'
```

```sh check selection-survives
pycheck single_owner.py '\bvar +(selection|selected|selectedPlace|selectedID|selectedPlaceID)\b'
```

```sh check no-fixed-column
no_src 'frame\(width: *[0-9]{3}'
```

```sh check launches
xcb_test -only-testing:PlacesUITests
```

## Checklist

- **R2**: closed, open Glass Lake; Device Hub Open: Glass Lake is selected in the list and shown beside it. Close again: Glass Lake's detail is on screen.
- **R3**: open, the list column is sized by the container, not a fixed width.
- **R10**: everything open is reachable closed.
