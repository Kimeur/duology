---
id: duo-navigation/vertical-bars
skill: duo-navigation
title: Get the toolbars ready for the vertical bar
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R6 R10
timeout: 1800
status: ready
---

# Get the toolbars ready for the vertical bar

On the outer display, and on the inner display in landscape, iPhone Duo merges the navigation bar, toolbar and tab bar into one vertical bar on the side. Items need a symbol and a title; custom bars don't take part.

## Prompt

```text prompt
On iPhone Duo the system moves the toolbar into a vertical bar on the side of the screen. Get the Places list and the place detail screen ready for that, so every action shows up properly in the side bar and its overflow menu. Keep every action the screens have today.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). The list's toolbar has a text-only "Edit" button and an icon-only sort menu. The detail screen draws its own bottom bar (Share, Directions, Favorite) with `safeAreaInset(edge: .bottom)`. A closed-phone screenshot of that bar is in [`fixtures/review-shots`](../../fixtures/review-shots/places-closed-detail.png).

## Pass checks

Gate: the app builds for the iPhone Duo simulator.

```sh check no-custom-bottom-bar
no_src 'safeAreaInset\(edge: *\.bottom'
```

```sh check no-icon-only-items
# The sort menu and Share used a bare Image as their label: no title for the
# overflow menu or VoiceOver.
no_src 'Image\(systemName: *"(arrow\.up\.arrow\.down|square\.and\.arrow\.up)"\)'
```

```sh check no-text-only-items
no_src 'Button\("(Edit|Directions)"\) *\{'
```

```sh check vertical-bar-not-disabled
no_src 'toolbarVerticalBehavior\(\.disabled\)'
```

```sh check actions-kept
has_src 'square\.and\.arrow\.up|ShareLink'
has_src 'Directions'
has_src '"heart'
has_src 'arrow\.up\.arrow\.down|[Ss]ort'
```

## Checklist

- **R6**: closed: the detail screen's actions sit in the side bar; each has a symbol, and its title shows in the overflow menu; Back is at the top.
- **R10**: Share, Directions, Favorite, Sort and Edit are all reachable closed and open.
