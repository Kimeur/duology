---
id: duo-reading/two-facing-pages
skill: duo-reading
also: duo-patterns, duo-continuity, duo-postures
title: A reader with two facing pages at the fold
readme: no
fixture: Starter
project: Starter.xcodeproj
scheme: Starter
build: yes
lint: yes
checklist: R2 R4 R7 R10
timeout: 3000
status: ready
---

# A reader with two facing pages at the fold

Apple says scrolling text may cross the fold, but a page is not scrolling text ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=225)). Two facing pages must meet at the fold, and the fold is not always in the middle of the reader: duo-reading measured the reader at 867 pt wide on the open phone, because the vertical bar takes 84 pt of the 951 pt window, so the middle of the reader sits about 40 pt from the fold (derived from the measured frames). The fold comes from the `.division` reserved region (`reservedRegions(kind:options:layoutDirectionBehavior:)`, iOS 27.1), or an `ArrangementView` puts its two sides on each side of it ([api-index.md](../../../reference/api-index.md#reserved-regions-and-margins)). Every fold, rotation and text size change moves the page breaks, so the place in the book has to be kept as a position in the text, not as a page number.

## Prompt

```text prompt
Turn this app into a reader for one short book. Write the book yourself, an original story of at least 2,000 words bundled with the app, and show it as pages, not as one long scroll. On the closed phone show one page at a time. On the open phone show two facing pages that meet exactly at the fold, also when the phone is half folded like a book. Turn pages with buttons. When the phone is folded, unfolded or rotated, or the text size changes, the reader must stay at the same place in the text. Keep the StarterUITests target.
```

## Starting point

Fixture [`Starter`](../../fixtures/Starter): an empty SwiftUI app ("Hello"), iOS 26 target, Swift 6, main-actor isolation by default, with a placeholder UI test target, `StarterUITests`. The reserved-region API is iOS 27.1, so the build gate also checks that code using it sits behind an availability check.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check pages-meet-at-the-fold
# Two pages split where the fold is: the .division reserved region, or an arrangement
# that places its two sides around it. Halving the reader misses the fold when a bar
# takes part of the width.
has_src 'reservedRegions|ArrangementView|UIArrangementViewController'
```

```sh check a-real-book
# At least about 2,000 words of text ship with the app, in a resource file or in Swift
# string literals, so pagination has something to do.
python3 - <<'PY'
import os, re, sys
words = 0
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in {".git", "DerivedData", "build", ".build"}
               and not d.endswith((".xcassets", ".xcodeproj", ".xcresult"))]
    for f in files:
        if f.lower().startswith("readme"):
            continue
        path = os.path.join(root, f)
        text = open(path, encoding="utf-8", errors="replace").read() if f.endswith(
            (".txt", ".md", ".json", ".html", ".rtf", ".xml", ".strings", ".swift")) else ""
        if f.endswith(".swift"):
            text = " ".join(re.findall(r'"""(.*?)"""', text, re.S) + re.findall(r'"((?:[^"\\\n]|\\.){80,})"', text))
        words += len(re.findall(r"[A-Za-z][A-Za-z'’-]*", text))
print("words of text in the app: %d" % words)
sys.exit(0 if words >= 1800 else 1)
PY
```

```sh check ui-tests-kept
[ -d StarterUITests ] || { echo "the StarterUITests folder is gone"; exit 1; }
```

```sh check launches
launch_ok
```

## Checklist

Set each pose in Device Hub, and change the text size in the simulator's Settings app between steps.

- **R2**: turn to a page in the middle of the book, then press Closed, Open, Rotate Right and Partially Open, and make the text larger and smaller. The first line on screen stays on screen every time; no text is skipped.
- **R4**: partly folded, no page-turn button and no other control sits on the fold.
- **R7**: book pose: one page on each side of the fold, the fold between them, and no line of text runs across it. Tabletop: nothing the reader must tap sits in the fold band.
- **R10**: closed, the reader shows one page with every control the open phone has.
