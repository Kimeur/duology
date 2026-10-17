---
id: duo-patterns/feed-reflow
skill: duo-patterns
title: A gallery grid that reflows with even columns
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R3 R5
timeout: 1800
status: ready
---

# A gallery grid that reflows with even columns

## Prompt

```text prompt
Make the Gallery grid reflow well on iPhone Duo, closed and open, in every orientation. Put the rule that picks the number of columns in its own Swift file as `static func columnCount(forWidth width: CGFloat) -> Int` on a type named `GalleryLayout`, with no UI code in that file, so we can test it on its own.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `GalleryScreen` picks 3 or 5 columns from `UIDevice.current.orientation`.

## Pass checks

Gate: builds for the iPhone Duo simulator.

```sh check rule-exists
has_src 'static func columnCount\(forWidth'
```

```sh check even-columns-open
# Compile the rule on its own for the Mac and probe it. 951 pt is the inner display
# fully open and held wide (measured; reference/device-facts.md), where the fold
# runs down the middle of the grid. 466 and 669 pt are the outer display and the
# inner display held tall.
file="$(src_grep '(struct|enum|class) +GalleryLayout\b' | awk -F: 'NR == 1 { print $1 }')"
[ -n "$file" ] || { echo "no GalleryLayout type"; exit 1; }
tmp="$(mktemp -d)"
cp "$file" "$tmp/GalleryLayout.swift"
cat > "$tmp/main.swift" <<'SWIFT'
import Foundation
let widths: [CGFloat] = [300, 466, 669, 951]
let counts = widths.map { GalleryLayout.columnCount(forWidth: $0) }
print("widths", widths, "columns", counts)
var ok = true
if counts.contains(where: { $0 < 1 }) { print("a width got fewer than 1 column"); ok = false }
if zip(counts, counts.dropFirst()).contains(where: { $0 > $1 }) { print("columns shrink as width grows"); ok = false }
let open = GalleryLayout.columnCount(forWidth: 951)
if open < 2 || open % 2 != 0 { print("open and held wide (951 pt) needs an even count of 2 or more, got \(open)"); ok = false }
exit(ok ? 0 : 1)
SWIFT
xcrun -sdk macosx swiftc -o "$tmp/probe" "$tmp/GalleryLayout.swift" "$tmp/main.swift" 2>&1 | tail -20
"$tmp/probe"
```

```sh check no-orientation
no_src 'UIDevice\.current\.orientation'
```

## Checklist

- **R5**: open, held wide, flat and partly folded: the fold runs through a gap between tiles, never through a tile.
- **R3**: closed and open, tiles are sized by the container; nothing is clipped or stretched.
