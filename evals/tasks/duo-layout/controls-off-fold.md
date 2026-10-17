---
id: duo-layout/controls-off-fold
skill: duo-layout
title: Keep a floating button off the fold
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R4 R12
timeout: 1800
status: ready
---

# Keep a floating button off the fold

A custom control, centred on the full window, lands in the fold when the phone is open. System bars move aside on their own; custom controls don't.

## Prompt

```text prompt
On iPhone Duo, when the phone is open and partly folded, the round + button on the Places screen sits right on the fold, where it's hard to tap. Keep it off the fold in every pose. Don't move the list itself, and keep the button's sheet working.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `AddPlaceButton` is an overlay with `alignment: .bottom` on the whole Places screen, in both the narrow and the wide layout. Other mistakes in the fixture are out of scope for this task, so duo-lint is not a gate here.

## Pass checks

Gate: the app builds for the iPhone Duo simulator.

```sh check button-off-fold
# Either the code reads the fold (division reserved region) and moves the button,
# or the button is no longer centred on the whole screen (for example it became a
# toolbar item, which the system keeps off the fold).
if [ -n "$(src_grep 'reservedRegions\(kind: *\.division')" ]; then exit 0; fi
no_src 'overlay\(alignment: *\.bottom\)'
```

```sh check button-kept
has_src '"plus"'
has_src 'New place'
```

```sh check list-not-padded-for-fold
# Apple: never displace scrolling content. The list must not get padding or an
# offset computed from the fold.
no_src '(List|ScrollView).*\.(padding|offset)\([^)]*(division|fold|hinge)'
```

## Checklist

- **R4**: Device Hub, Partially Open, held wide: the + button sits wholly on one side of the fold. Repeat held tall.
- **R12**: fold and unfold: the button moves a short way, not across the screen.
