---
id: duo-shared-screen/both-halves-always
skill: duo-shared-screen
also: duo-layout
title: Both players' halves show in every pose
readme: no
fixture: TapDuel
project: TapDuel.xcodeproj
scheme: TapDuel
build: yes
lint: yes
checklist: R3 R4 R13
timeout: 1800
status: ready
---

# Both players' halves show in every pose

## Prompt

```text prompt
This is a two-player tap game for iPhone Duo. Players say that when the phone is closed and turned sideways, only one player's side shows up. Both sides must show, side by side or one above the other, in every pose and orientation. Fix it without changing the game rules.
```

## Starting point

Fixture [`TapDuel`](../../fixtures/TapDuel): iOS 27.1 target, Swift 6. The two halves are the primary and secondary views of an `ArrangementView` with `.split` style. With compact width and compact height (the closed phone held sideways), a split `ArrangementView` shows only its primary view. Duology measured this on the iOS 27.1 simulator (`duo-layout`, section on arrangements); Apple's docs don't say it.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check no-arrangement-for-players
# Two halves that must always show need a split you control.
no_src 'ArrangementView'
```

```sh check rules-unchanged
unchanged TapDuel/Duel/DuelModel.swift
```

```sh check halves-kept
has_src 'onTapGesture|TapGesture|Button'
has_src '\.first'
has_src '\.second'
```

```sh check launches
launch_ok
```

## Checklist

- **R3**: closed held upright, closed held sideways, open held wide and held tall: both halves show, each fills its share, nothing is clipped.
- **R4**: partly folded, the line between the halves sits on the fold, and no text or button crosses it.
- **R13**: each half is a large tap target.
