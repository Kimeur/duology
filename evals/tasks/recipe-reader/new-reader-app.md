---
id: recipe-reader/new-reader-app
skill: recipe-reader
also: duo-reading, duo-patterns, duo-continuity, duo-testing
title: Build an e-book reader with facing pages
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R4 R7 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 3000
status: ready
---

# Build an e-book reader with facing pages

The agent starts from an empty folder and must produce a whole Xcode project. Open and held wide, or folded like a book, iPhone Duo shows two facing pages, and they must meet at the fold, not at the middle of a reader that a vertical bar has narrowed (`duo-reading`). The fold comes from the `.division` reserved region or an arrangement ([api-index.md](../../../reference/api-index.md#reserved-regions-and-margins)). Every fold, rotation and text size change moves the page breaks, so the reader's place has to be a position in the text.

## Prompt

```text prompt
Create a new iPhone Duo e-book reader in this folder: a small library and a reader. Closed, the reader shows one page. Open, and when half folded like a book, it shows two facing pages that meet at the fold. Turn pages with buttons. Folding, unfolding, rotating and changing the text size must keep the reader at the same place in the text. Write two or three short original stories as sample books; don't use any existing books. Put the pagination and reading-position logic in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs those tests. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-reader` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

The run with Duology should also get the recipe's own `new-project.sh`, by its exact path in the plugin copy; that needs the script added to `PLUGIN_SCRIPTS` in [`lib/evalkit.py`](../../lib/evalkit.py).

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

```sh check pages-meet-at-the-fold
# Two pages split where the fold is: the .division reserved region, or an arrangement
# that places its two sides around it.
has_src 'reservedRegions|ArrangementView|UIArrangementViewController'
```

```sh check sample-books
# At least about 1,500 words of sample text ship with the app, in resource files or in
# Swift string literals, so pagination has something to do.
python3 - <<'PY'
import os, re, sys
words = 0
for root, dirs, files in os.walk("."):
    dirs[:] = [d for d in dirs if d not in {".git", "DerivedData", "build", ".build", "Tools"}
               and not d.endswith((".xcassets", ".xcodeproj", ".xcresult"))
               and "Tests" not in d]
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
sys.exit(0 if words >= 1500 else 1)
PY
```

```sh check launches
launch_ok
```

## Checklist

Set each pose in Device Hub, and change the text size in the simulator's Settings app between steps.

- **R2**: open a book at a page in the middle, then press Closed, Open, Rotate Right and Partially Open, and make the text larger and smaller. The first line on screen stays on screen every time; no text is skipped.
- **R4**: partly folded, no page-turn button and no other control sits on the fold.
- **R7**: book pose: one page on each side of the fold, the fold between them, and no line of text runs across it.
- **R10**: closed, the library and the reader have every feature the open phone has.
