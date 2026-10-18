---
id: duo-continuity/list-through-fold
skill: duo-continuity
title: Search, selection and scroll survive a fold
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R2 R12
timeout: 1800
status: ready
---

# Search, selection and scroll survive a fold

## Prompt

```text prompt
When I unfold the phone on the Places screen, the list jumps back to the top, the search box empties and the place I picked is gone. Fix it so nothing resets when I fold, unfold or rotate the phone.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `PlacesScreen` picks `PhonePlacesLayout` or `PadPlacesLayout` with an `if` on size class. Each layout owns its own `@State` for the search text, sort order and selection, so a fold that swaps them throws that state away.

## Pass checks

Gate: builds for the iPhone Duo simulator.

```sh check search-survives
pycheck single_owner.py '\bvar +(query|searchText|searchQuery|searchTerm)\b'
```

```sh check sort-order-survives
pycheck single_owner.py '\bvar +(order|sortOrder|sorting)\b'
```

```sh check no-identity-reset
# No .id() tied to the layout, which would rebuild everything on a fold.
no_src '\.id\([^)]*(sizeClass|SizeClass|isPad|isWide|isRegular|isCompact)'
```

```sh check launches
xcb_test -only-testing:PlacesUITests
```

## Checklist

- **R2**: search "lake", scroll, pick a place; Device Hub Open, then Closed, then rotate. The search text, the selected place and the first visible row stay the same. Open may add the detail beside the list.
- **R12**: no blank frame or reload during the change.
