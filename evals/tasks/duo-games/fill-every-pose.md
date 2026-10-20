---
id: duo-games/fill-every-pose
skill: duo-games
also: duo-layout, duo-continuity, duo-postures
title: A SpriteKit game that fills every pose
readme: no
fixture: Starter
project: Starter.xcodeproj
scheme: Starter
build: yes
lint: yes
checklist: R1 R2 R4 R13
timeout: 2400
status: ready
---

# A SpriteKit game that fills every pose

Apple asks games on iPhone Duo to fill the screen in every pose instead of letterboxing ([HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). The window changes shape a lot: about 466 × 678 pt closed and upright, 951 × 669 pt open and held wide (*measured*, [device-facts.md](../../../reference/device-facts.md#displays)). A SpriteKit scene left at its default scale mode, `.fill` ([scaleMode](https://developer.apple.com/documentation/spritekit/skscene/scalemode)), stretches to that new shape; `.aspectFit` adds bars. `.resizeFill`, or a scene that lays itself out again in `didChangeSize(_:)`, changes the playfield's shape instead ([SKSceneScaleMode](https://developer.apple.com/documentation/spritekit/skscenescalemode)). The scene object must also outlive the fold: a scene that a view creates again on resize restarts the game.

## Prompt

```text prompt
Make this app a small arcade game with SpriteKit: the player moves a paddle left and right with two on-screen buttons to catch falling stars, and a score counts the catches. On iPhone Duo it must fill the whole display closed and open, upright and sideways, with no black bars and nothing stretched. Folding, unfolding or rotating the phone mid-game must not restart the game or reset the score, and the buttons must never sit on the fold when the phone is half open. Keep the StarterUITests target.
```

## Starting point

Fixture [`Starter`](../../fixtures/Starter): an empty SwiftUI app ("Hello"), iOS 26 target, Swift 6, main-actor isolation by default, with a placeholder UI test target, `StarterUITests`. The reserved-region API is iOS 27.1, so the build gate also checks that code using it sits behind an availability check.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check uses-spritekit
has_src '^ *import +SpriteKit'
```

```sh check fills-without-bars
# The playfield follows the view's shape: .resizeFill, or didChangeSize that lays
# the scene out again. .aspectFit leaves bars; .fill (SpriteKit's default) stretches.
has_src '\.resizeFill\b|didChangeSize'
no_src 'scaleMode *[=:] *\.(aspectFit|fill)\b'
```

```sh check scene-survives-fold
# Each SKScene subclass is created in one place that a fold can't rebuild: a model
# or @State that keeps it, not a view body that makes a new scene on every resize.
names="$(src_grep 'class +[A-Za-z_][A-Za-z0-9_]* *: *SKScene\b' \
         | sed -E 's/.*class +([A-Za-z_][A-Za-z0-9_]*).*/\1/' | sort -u | paste -sd'|' -)"
[ -n "$names" ] || { echo "no SKScene subclass found"; exit 1; }
echo "scene classes: $names"
# A scene made inline in SpriteView(scene:) is made again whenever the view updates.
no_src "SpriteView\\(scene: *($names)\\("
pycheck single_owner.py "\\b($names)\\("
```

```sh check ui-tests-kept
[ -d StarterUITests ] || { echo "the StarterUITests folder is gone"; exit 1; }
```

```sh check launches
launch_ok
```

## Checklist

Start a game, catch a few stars, then go through the poses in Device Hub.

- **R1**: closed upright, closed sideways, open held wide and open held tall: the game fills the window edge to edge, with no bars and no stretched stars or paddle.
- **R2**: press Closed, Open, Rotate Right and Partially Open mid-game. The score and the falling stars carry on; the game doesn't restart or show its start screen again.
- **R4**: partly folded, held wide and held tall: neither button touches the fold band or sits under the inner camera.
- **R13**: both buttons are at least 44 × 44 pt.
