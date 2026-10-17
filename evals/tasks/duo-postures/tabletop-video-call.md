---
id: duo-postures/tabletop-video-call
skill: duo-postures
also: duo-layout, duo-patterns
depends: duo-postures (v0.2) and duo-media (v0.3); until they ship, the run with Duology has only the v0.1 skills
title: Tabletop layout for a video call
readme: yes
fixture: Talk
project: Talk.xcodeproj
scheme: Talk
build: yes
lint: yes
checklist: R3 R4 R7 R10
timeout: 2400
status: ready
---

# Tabletop layout for a video call

A README task. "Tabletop" is Duology's shorthand for what Apple describes as the phone seated on a table like a laptop: held tall, partly folded, with the fold running across the inner display. Apple has no posture API; layout comes from size classes, reserved regions and arrangement views, and the hinge is for effects ([api-index.md](../../../reference/api-index.md#hinge)).

This task depends on `duo-postures` (v0.2) and `duo-media` (v0.3). Until they ship, the run with Duology loads only the v0.1 skills, so expect a smaller gap between the two runs.

## Prompt

```text prompt
This is a video call screen for iPhone Duo. When someone half-opens the phone and stands it on a table like a small laptop (held tall, with the fold running across the middle of the inner display), put the other person's video in the top half and all the call controls in the bottom half, clear of the fold. In every other pose, keep a layout that works. Don't remove any control.
```

## Starting point

Fixture [`Talk`](../../fixtures/Talk): a full-screen remote video placeholder, a self view in the top corner and a row of four controls (`call.mute`, `call.camera`, `call.speaker`, `call.end`) at the bottom. It sizes the self view from `UIScreen.main` and branches on `UIDevice.current.orientation`.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check controls-kept
for id in call.mute call.camera call.speaker call.end; do
  has_src "\"$id\""
done
```

```sh check layout-from-fold-not-hinge-alone
# The tabletop layout reads the fold region (or uses an arrangement), not only the
# hinge angle or device orientation.
has_src 'reservedRegions\(kind: *\.division|ArrangementView|UIArrangementViewController'
```

```sh check no-posture-guessing
no_src 'UIDevice\.current\.orientation'
```

```sh check launches
launch_ok
```

## Checklist

The reviewer sets the pose in Device Hub (Partially Open, held tall) and marks:

- **R7**: the remote video sits in the top half, every control in the bottom half, and the same controls exist as when flat.
- **R4**: no control touches the fold.
- **R3**: closed and fully open, the screen still fits its window; the self view isn't sized from the screen.
- **R10**: every control is available in every pose.
