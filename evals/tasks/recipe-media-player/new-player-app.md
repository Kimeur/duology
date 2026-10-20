---
id: recipe-media-player/new-player-app
skill: recipe-media-player
also: duo-media, duo-postures, duo-continuity, duo-testing
title: Build a video podcast player
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R4 R7 R8 R12
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 3000
status: ready
---

# Build a video podcast player

The agent starts from an empty folder and must produce a whole Xcode project. A player on iPhone Duo must keep playing through every fold, so the player is owned above the layout switch (`duo-continuity`). Apple's one optional per-pose layout is for media: with the phone seated on a table like a laptop, the video in the top half and the same controls in the bottom half ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=276)). The fold comes from the `.division` reserved region or an arrangement; no API reports the pose ([api-index.md](../../../reference/api-index.md#not-in-the-sdk)).

## Prompt

```text prompt
Create a new iPhone Duo video podcast app in this folder: a library of shows and episodes, and a full-screen player. The video must keep playing from the same spot through fold, unfold and rotation. When the phone is half folded and stood on a table, put the video above the fold and the same controls below it. Support Picture in Picture. The app must play without a network connection, so bundle at least one short sample clip that you make yourself; never download media. Put the queue and resume logic in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs those tests. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-media-player` skill and `/duo-new` can create the project from a template, sample clips included. Without it, the agent has to write the Xcode project itself and make a clip with the tools it is allowed: it can compile Swift for the Mac and run programs under `Tools/`, for example one that writes a clip with AVFoundation's `AVAssetWriter`.

The run with Duology also gets the recipe's own `new-project.sh`, by its exact path in the plugin copy (`PLUGIN_SCRIPTS` in [`lib/evalkit.py`](../../lib/evalkit.py)).

## Pass checks

Gates: an Xcode project in the folder builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check one-project
n="$(find . \( -name .git -o -name DerivedData \) -prune -o -name '*.xcodeproj' -type d -print | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "no Xcode project"; exit 1; }
```

```sh check logic-tests-pass
# At least one test script under Tools/ runs without the simulator, and every such
# script passes. Scripts that drive the simulator are skipped here.
found=0
for s in $(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -path '*/Tools/*' -name '*test*.sh' -print); do
  if grep -qE 'simctl|xcodebuild +test|-destination' "$s"; then
    echo "skipping $s: it drives the simulator"
    continue
  fi
  found=1
  bash "$s" || { echo "$s failed"; exit 1; }
done
[ "$found" = 1 ] || { echo "no test script under Tools/ that runs without the simulator"; exit 1; }
```

```sh check bundled-clip
n="$(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -type f \
      \( -name '*.mp4' -o -name '*.mov' -o -name '*.m4v' -o -name '*.m4a' \) -print | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "no bundled clip (.mp4, .mov, .m4v or .m4a)"; exit 1; }
```

```sh check one-player
# The AVPlayer has one owner, created once, above any layout switch.
pycheck single_owner.py 'AVPlayer\(|AVQueuePlayer\('
```

```sh check no-pause-on-disappear
# A layout change must not pause playback through onDisappear.
python3 - <<'PY'
import os, sys
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

```sh check picture-in-picture
has_src 'AVPictureInPictureController|AVPlayerViewController'
```

```sh check tabletop-reads-the-fold
# Video above the fold and controls below it: the .division reserved region or an
# arrangement view, not the hinge angle or the device orientation alone.
has_src 'reservedRegions|ArrangementView|UIArrangementViewController'
no_src 'UIDevice\.current\.orientation'
```

```sh check launches
launch_ok
```

## Checklist

recipe-media-player measured that the iPhone Duo simulator doesn't support Picture in Picture, so R8 judges Split View in the simulator and Picture in Picture only on a device.

- **R2**: play an episode, then press Closed, Open, Rotate Right and Partially Open in Device Hub. Playback goes on from the same spot every time.
- **R4**: partly folded, no control sits on the fold or under the inner camera.
- **R7**: tabletop (Partially Open, held tall): the video in the top half, every control in the bottom half, the same controls as when flat.
- **R8**: in Split View the player fits either half. On a device: Picture in Picture starts and comes back to the player.
- **R12**: no black frame or reload when the pose changes.
