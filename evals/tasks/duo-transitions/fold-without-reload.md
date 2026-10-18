---
id: duo-transitions/fold-without-reload
skill: duo-transitions
also: duo-continuity, duo-layout
title: Open and close without a reload flash
readme: no
fixture: Album
project: Album.xcodeproj
scheme: Album
build: yes
lint: yes
checklist: R2 R10 R12
timeout: 1800
status: ready
---

# Open and close without a reload flash

Opening or closing iPhone Duo resizes the app, and the system adds no motion of its own. Whatever the person sees during that change comes from the app: views that keep their identity move to their new place, views that are rebuilt start over ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=142), [AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)).

## Prompt

```text prompt
Opening or closing the phone makes this album screen look like it reloads: the cover fades in again, the track list shows a spinner, the background changes colour, and the player buttons vanish and come back at a different size. Make opening and closing feel like the same screen changing shape. Keep the stacked layout on the closed phone and the cover beside the tracks on the open phone. Don't remove any button or its accessibility identifier.
```

## Starting point

Fixture [`Album`](../../fixtures/Album): an album screen with a cover, a track list and a player bar (`player.previous`, `player.play`, `player.next`). iOS 17 target, Swift 5. duo-lint finds nothing: every problem here is about identity and timing.

- An `if` on a copy of the size class builds the cover and the track list once in each branch. Each `TrackList` creates its own `TrackStore` and loads the tracks again (a 0.7 s stand-in for a network request), so every fold shows a spinner. Each cover fades in on appear.
- `.onChange(of: sizeClass)` copies the size class into `@State` inside a long bouncy `withAnimation`, hides the player bar and brings it back 0.4 s later with `DispatchQueue.main.asyncAfter`.
- The background colour and the player bar's font and spacing change with the width.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check buttons-kept
for id in player.previous player.play player.next; do
  has_src "\"$id\""
done
```

```sh check tracks-load-once
# One TrackStore, created where a fold can't rebuild it: the tracks don't load again.
pycheck single_owner.py 'TrackStore\('
```

```sh check cover-built-once
# The cover is built once, so a fold moves it instead of building a new one that
# starts over. Previews don't count. A cover the agent renamed counts as 0, which passes.
python3 - AlbumArt <<'PY'
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

```sh check changes-with-the-size
# Layout follows the size class in the same update. No copy of it made in
# onChange, and no change scheduled for later.
no_src 'onChange\(of: *[A-Za-z_.]*[Ss]izeClass'
no_src 'asyncAfter'
```

```sh check same-look-at-every-size
# Background, fonts and tint don't change with the width (a flash, and text that cross-fades).
no_src '\.(background|font|foregroundStyle|tint)\([^)]*(isWide|[Ss]izeClass|== *\.regular|== *\.compact)'
```

```sh check animation-keyed-on-a-discrete-value
# An animation keyed on the raw size retargets several times per fold.
no_src 'animation\([^)]*value: *[A-Za-z_.]*\b(size|width|height)\b'
```

```sh check reduce-motion
# Any animation the app adds respects Reduce Motion. A plain .transition(.opacity)
# alone doesn't trigger this check: a fade is what Reduce Motion asks for.
if [ -n "$(src_grep '\.animation\(|withAnimation')" ]; then
  has_src 'accessibilityReduceMotion|isReduceMotionEnabled|accessibilityPrefersCrossFadeTransitions|prefersCrossFadeTransitions'
fi
```

```sh check launches
launch_ok
```

## Checklist

The reviewer plays a track, scrolls the list a little, then presses Closed, Open and Closed in Device Hub with Device > Slow Animations on, and records each display (`xcrun simctl io <UDID> recordVideo --display=primary-1 open.mov`):

- **R12**: no blank frame, spinner, fade-in or jump; the cover and the list move to their new places. A short spring of about 0.3 s, or no animation, both pass. A long or bouncy one is a Minor note.
- **R2**: the playing track and the list's scroll position are the same after each change.
- **R10**: the player bar shows the same three buttons, same size and order, closed and open.
