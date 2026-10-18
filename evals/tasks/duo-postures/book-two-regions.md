---
id: duo-postures/book-two-regions
skill: duo-postures
also: duo-layout, duo-patterns, duo-continuity
title: Book layout for a cooking screen
readme: no
fixture: Steps
project: Steps.xcodeproj
scheme: Steps
build: yes
lint: yes
checklist: R2 R4 R7 R10
timeout: 2400
status: ready
---

# Book layout for a cooking screen

"Book" is Duology's shorthand for what Apple describes as the phone partially folded, like a book: held wide, the fold running top to bottom through the inner display. Apple's advice for that pose is to fit content to one side of the fold and move controls off it, toward the trailing side ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)). Apple has no posture API: an active `.division` reserved region running top to bottom is what tells a view it is folded like a book ([api-index.md](../../../reference/api-index.md#reserved-regions-and-margins)).

## Prompt

```text prompt
This is the cooking screen of our recipe app, for iPhone Duo. When someone half-opens the phone and holds it like a book, put the step text on the left page and the timer on the right page, with no button in the fold. Closed and fully open, keep a layout that works. The timer must keep counting when the phone is opened, closed or folded. Don't remove any control or its accessibility identifier.
```

## Starting point

Fixture [`Steps`](../../fixtures/Steps): one screen with a recipe step, a timer panel and Previous and Next buttons (`cook.previous`, `cook.next`, `cook.timer`). iOS 17 target, Swift 5.

- An `if` on the width size class builds the step card and the timer panel once in each branch. The timer (`CookTimer`) is a `@StateObject` inside the timer panel, so opening or closing the phone builds a new panel and the countdown starts over.
- The open layout sizes the step column from `UIScreen.main.bounds.width / 2` (duo-lint DUO001). The vertical bar sits on one side, so half the screen is not where the fold is.
- Previous and Next float centred at the bottom of the whole window. Folded like a book, they sit on the fold.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check controls-kept
for id in cook.previous cook.next cook.timer; do
  has_src "\"$id\""
done
```

```sh check layout-from-fold
# The two pages come from the fold itself (the .division region) or from an
# arrangement that splits at it, not from half the screen or the hinge alone.
has_src 'reservedRegions\(kind: *\.division|ArrangementView|UIArrangementViewController'
```

```sh check no-posture-guessing
no_src 'UIDevice\.current\.orientation'
```

```sh check timer-survives
# One CookTimer, created where a fold or unfold can't rebuild it.
pycheck single_owner.py 'CookTimer\('
```

```sh check launches
launch_ok
```

## Checklist

The reviewer starts the timer on step 1, then sets each pose in Device Hub:

- **R7**: Partially Open, held wide: the step text fills the leading page and the timer the trailing page. Nothing reads across the fold.
- **R4**: in the same pose, no button (Previous, Next, the timer button) touches the fold.
- **R2**: Closed, Open, Partially Open and back to Closed: the timer keeps counting down and the same step stays on screen.
- **R10**: closed, upright and sideways, every control is on screen or one scroll away.
