---
id: duo-swiftui-27/reorder-and-swipe-grid
skill: duo-swiftui-27
also: duo-patterns, duo-continuity, duo-design-system
title: Drag to reorder and swipe in a grid that reflows
readme: no
fixture: Trips
project: Trips.xcodeproj
scheme: Trips
build: yes
lint: no
checklist: R2 R5 R13
timeout: 2400
status: ready
---

# Drag to reorder and swipe in a grid that reflows

On iPhone Duo a grid has one or two columns on the outer display and more on the inner display, so it can't be a `List`, and before iOS 27 only `List` rows had system reordering and swipe actions. iOS 27 adds both to any container: `reorderable()` on a `ForEach` inside a `reorderContainer(for:isEnabled:move:)`, and `swipeActions` outside `List`, with `swipeActionsContainer()` so only one card stays open ([What's new in SwiftUI, WWDC26 session 269](https://developer.apple.com/videos/play/wwdc2026/269/?time=932), [api-index.md](../../../reference/api-index.md#ios-27-swiftui-wwdc26)). They are iOS 27.0 APIs, so an app that still supports iOS 17 needs `if #available`. Whatever the agent uses, the new order is data: it must live where a fold can't rebuild it.

## Prompt

```text prompt
Let people reorder the trip cards by dragging them, and swipe a card to delete it or to mark it as a favourite. It has to work in the single column on the closed phone and in the grid on the open phone, and the new order must stay when the phone is folded or unfolded. The app still supports iOS 17, so use newer APIs only where they are available. Keep the accessibility identifiers and the TripsUITests target.
```

## Starting point

Fixture [`Trips`](../../fixtures/Trips): a grid of trip cards with a heart button on each (`trip.favorite.<id>`) and a "Plan a trip" button (`trips.plan`). iOS 17 target, Swift 5, with a UI test target, `TripsUITests`. The trips live in `@State` in `TripsScreen`, the root view. The cards can't be moved, swiped or deleted.

The fixture also picks its sizes and column count (1 closed, 3 open) from `UIScreen.main`, a duo-lint finding that belongs to `duo-design-system/tokens-from-two-frames`. This task turns the lint gate off; the checklist still asks for an even column count on the open phone.

## Pass checks

Gates: builds for the iPhone Duo simulator (which also checks that iOS 27 APIs sit behind `if #available`).

```sh check can-reorder
# Any working drag to reorder: iOS 27's reorder containers, or drag and drop.
has_src 'reorderable\(|reorderContainer\(|onMove\(|dropDestination\(|onDrop\(|onDrag\(|draggable\('
```

```sh check reorder-has-a-container
# reorderable() does nothing without a reorderContainer around it.
if [ -n "$(src_grep 'reorderable\(')" ]; then
  has_src 'reorderContainer\('
fi
```

```sh check can-swipe
# iOS 27 swipe actions on the cards, or a swipe built with a drag gesture.
has_src 'swipeActions|DragGesture'
```

```sh check order-survives-fold
# The trips have one owner that a fold can't rebuild.
pycheck single_owner.py '\bvar +trips\b'
```

```sh check identifiers-kept
has_src '"trip\.favorite\.'
has_src '"trips\.plan"'
[ -d TripsUITests ] || { echo "the TripsUITests folder is gone"; exit 1; }
```

```sh check launches
launch_ok
```

## Checklist

- **R2**: drag a card to a new place, then press Closed and Open in Device Hub. The new order stays, and a deleted card stays deleted.
- **R5**: open, the grid has an even number of columns, so the fold falls between cards, and dragging a card across the fold works.
- **R13**: the swipe actions and the heart buttons are at least 44 pt tall.
