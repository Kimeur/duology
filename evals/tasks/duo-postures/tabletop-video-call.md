---
id: duo-postures/tabletop-video-call
skill: duo-postures
also: duo-layout, duo-patterns, duo-ergonomics
depends: duo-media (v0.3); until it ships, the run with Duology has the v0.1 and v0.2 skills
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

`duo-postures` shipped in v0.2. Its tabletop recipe and video call variant (`FoldRegionsLayout`, or an `ArrangementView` with the overlay style) are the fix this task looks for. `duo-media` (v0.3) will add more on players and calls; until it ships, the gap between the two runs may be smaller than it will be.

## Prompt

```text prompt
This is a video call screen for iPhone Duo. When someone half-opens the phone and stands it on a table like a small laptop (held tall, with the fold running across the middle of the inner display), put the other person's video in the top half and all the call controls in the bottom half, clear of the fold. In every other pose, keep a layout that works. Don't remove any control or its accessibility identifier.
```

## Starting point

Fixture [`Talk`](../../fixtures/Talk): a full-screen remote video placeholder, a self view in the top corner and a row of four controls (`call.mute`, `call.camera`, `call.speaker`, `call.end`) at the bottom. It sizes the self view from `UIScreen.main` and branches on `UIDevice.current.orientation`, building the row of controls once in each branch.

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

```sh check one-copy-of-each-view
# The remote video and the row of controls are each built once, so a pose change
# moves them instead of building new ones. A new video view starts blank, and a
# second row made for one pose is not "the same controls" Apple asks for.
# Previews don't count. A view the agent renamed or replaced counts as 0, which passes.
python3 - RemoteVideoView CallControls <<'PY'
import os, re, sys

def code(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    out, i = [], 0
    preview = re.compile(r"#Preview\b[^{]*\{|struct\s+\w+\s*:\s*PreviewProvider\s*\{")
    while True:
        m = preview.search(text, i)
        if not m:
            out.append(text[i:])
            return "".join(out)
        out.append(text[i:m.start()])
        depth, j = 1, m.end()
        while j < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[j], 0)
            j += 1
        i = j

counts = {name: 0 for name in sys.argv[1:]}
for folder, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "DerivedData", "build")]
    for f in files:
        if f.endswith(".swift"):
            src = code(open(os.path.join(folder, f), encoding="utf-8", errors="replace").read())
            for name in counts:
                counts[name] += len(re.findall(r"(?<![\w.])%s\s*\(" % name, src))
print("created outside previews:", counts)
too_many = [name for name, n in counts.items() if n > 1]
if too_many:
    print("built more than once: " + ", ".join(too_many))
    sys.exit(1)
PY
```

```sh check call-state-survives
# Mute, camera and speaker state live in one place that a pose change can't rebuild.
pycheck single_owner.py '\bvar +isMuted\b'
```

```sh check launches
launch_ok
```

## Checklist

The reviewer sets the pose in Device Hub (Partially Open, then Rotate Right once, for held tall) and marks:

- **R7**: the remote video sits in the top half, every control in the bottom half, and the same controls exist as when flat.
- **R4**: no control touches the fold, and none sits under the inner camera on the right edge of the bottom half.
- **R3**: closed and fully open, the screen still fits its window; the self view isn't sized from the screen.
- **R10**: every control is available in every pose.
