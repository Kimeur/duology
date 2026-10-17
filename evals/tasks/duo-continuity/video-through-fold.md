---
id: duo-continuity/video-through-fold
skill: duo-continuity
also: duo-layout, duo-lint
title: Keep video playing through fold and unfold
readme: yes
fixture: Reel
project: Reel.xcodeproj
scheme: Reel
build: yes
lint: yes
checklist: R2 R3 R12
timeout: 1800
status: ready
---

# Keep video playing through fold and unfold

A README task. Folding swaps the size class, the player view is rebuilt, and the video starts again from zero.

## Prompt

```text prompt
When I fold or unfold the phone, the video starts again from the beginning. Make it keep playing from the same spot through fold, unfold and rotation, on both displays.
```

## Starting point

Fixture [`Reel`](../../fixtures/Reel): a player screen with an "Up next" list. It switches between an `HStack` and a `VStack` with `if sizeClass == .regular`, and each branch creates its own `VideoPane`, which owns an `AVPlayer` in `@State` and pauses it in `onDisappear`. It also sizes the video from `UIScreen.main` and gives the list a fixed 320 pt width. The bundled clip is a 60-second test pattern with a running counter, so a restart is easy to see.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check player-survives-layout-switch
# The AVPlayer has one owner, created once, above any layout switch
# (a model object, the root view, or a view whose identity never changes).
pycheck single_owner.py 'AVPlayer\(|AVQueuePlayer\('
```

```sh check no-pause-on-disappear
# A layout change must not pause playback through onDisappear.
python3 - <<'PY'
import os, re, sys
bad = []
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in {".git", "DerivedData", "build"}]
    for f in files:
        if not f.endswith(".swift"):
            continue
        lines = open(os.path.join(root, f), encoding="utf-8", errors="replace").read().splitlines()
        for i, line in enumerate(lines):
            if ".onDisappear" in line and any(".pause()" in l for l in lines[i:i + 6]):
                bad.append("%s:%d" % (os.path.join(root, f), i + 1))
if bad:
    print("onDisappear pauses the player at: " + ", ".join(bad))
    sys.exit(1)
PY
```

```sh check launches
launch_ok
```

## Checklist

- **R2**: play to about 0:20, then in Device Hub press Closed, Open, rotate, Partially Open. After each step the counter keeps going from where it was and playback doesn't stop.
- **R3**: closed and open, the video and the list fit the window; no fixed widths.
- **R12**: no black frame or reload when the layout changes.
