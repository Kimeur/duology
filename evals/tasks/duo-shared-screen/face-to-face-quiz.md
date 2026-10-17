---
id: duo-shared-screen/face-to-face-quiz
skill: duo-shared-screen
title: A two-person quiz on one phone
readme: no
fixture: Starter
project: Starter.xcodeproj
scheme: Starter
build: yes
lint: yes
checklist: R3 R4 R13
timeout: 2400
status: ready
---

# A two-person quiz on one phone

## Prompt

```text prompt
Build a two-person quiz as the first screen of this app, for iPhone Duo. Each person gets their own half of the screen with the same question, four answer buttons and their own score. People may sit side by side, or face to face across the phone lying flat, so add a switch that turns one half around. Answering on one side must never change the other person's score.

Give each person's answer buttons the accessibility identifiers p1.answer.0 to p1.answer.3 and p2.answer.0 to p2.answer.3, and the scores p1.score and p2.score. Keep the StarterUITests target.
```

## Starting point

Fixture [`Starter`](../../fixtures/Starter): an empty SwiftUI app (iOS 26 target, Swift 6, main-actor isolation by default) with a placeholder UI test target, `StarterUITests`.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check oracle-ui-tests
# Copy the hidden oracle test into the UI test target and run it on the simulator.
# It checks the identifiers exist, each person's buttons sit in their own half of
# the window, every button is at least 44 x 44 pt, and p1's answers never change
# p2's score. See evals/oracles/duo-shared-screen/QuizOracleTests.swift.
[ -d StarterUITests ] || { echo "the StarterUITests folder is gone"; exit 1; }
cp "$EVALS/oracles/duo-shared-screen/QuizOracleTests.swift" StarterUITests/
xcb_test -only-testing:StarterUITests/QuizOracleTests
```

```sh check turn-around
# One half can be turned to face the other person.
has_src 'rotationEffect|rotation3DEffect|scaleEffect\(x: *-1, *y: *-1'
```

## Checklist

- **R3**: closed and open, in both orientations, each half fits; nothing is sized for the other display.
- **R4**: open and partly folded, no answer button touches the fold.
- **R13**: every answer button is at least 44 pt (the oracle test checks this too).
