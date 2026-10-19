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

Opening or closing iPhone Duo resizes the app ([talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=142)). `duo-transitions` measured on the simulator that the system adds no motion of its own to the app's layout. So whatever the person sees during that change comes from the app: views that keep their identity move to their new place, and views that are rebuilt start over ([AnyLayout](https://developer.apple.com/documentation/swiftui/anylayout)).

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
# If the agent replaced TrackStore, the track list itself (tracks) must have one
# owner. Renamed past both: the check says so and passes, and R2 decides. Branches
# of `if #available` that iPhone Duo never runs are left out.
python3 - owner "$EVALS/lib/checks/single_owner.py" 'TrackStore\(' '\bvar +tracks\b' <<'PY'
import os, re, shutil, subprocess, sys, tempfile
# Reads the Swift sources as iPhone Duo (iOS 27.1) runs them. An `if #available` or
# `#unavailable` with no other condition is decided once per OS, so the branch iOS 27.1
# never takes is blanked, and so is a guard that passes. Comments, strings and previews
# are blanked too; line breaks stay.
#   count NAME...          fails when a NAME(...) view is built in more than one place
#   owner CHECKER PAT...   single_owner.py on the first PAT that matches; none: a note
def mask(t):
    o, i, n = list(t), 0, len(t)
    def upto(end, i, extra):
        j = t.find(end, i)
        return n if j < 0 else j + extra
    while i < n:
        if t.startswith("//", i): j = upto("\n", i, 0)
        elif t.startswith("/*", i): j = upto("*/", i + 2, 2)
        elif t.startswith('"""', i): j = upto('"""', i + 3, 3)
        elif t[i] == '"':
            j = i + 1
            while j < n and t[j] not in '"\n': j += 2 if t[j] == "\\" else 1
            j = min(j + 1, n)
        else:
            i += 1; continue
        o[i:j] = [c if c == "\n" else " " for c in o[i:j]]; i = j
    return "".join(o)

def close(s, i):  # index of the bracket that closes s[i]
    d = 0
    for j in range(i, len(s)):
        d += (s[j] == s[i]) - (s[j] == {"(": ")", "{": "}"}[s[i]])
        if d == 0: return j
    return len(s) - 1

def ws(s, i):
    return len(s) - len(s[i:].lstrip())

def kw(s, i, w):
    return re.match(w + r"\b", s[i:]) is not None

def chain_end(s, i):  # s[i:] starts an if statement: the end of its else chain
    j, d = i + 2, 0
    while j < len(s) and not (s[j] == "{" and d == 0):
        d += (s[j] in "([") - (s[j] in ")]"); j += 1
    if j >= len(s): return len(s)
    j = close(s, j) + 1; k = ws(s, j)
    if not kw(s, k, "else"): return j
    e = ws(s, k + 4)
    return chain_end(s, e) if kw(s, e, "if") else close(s, e) + 1

def resolve(text):
    s = mask(text); out = list(s); cut = []
    def drop(a, b):
        cut.append((a, b)); out[a:b] = [c if c == "\n" else " " for c in out[a:b]]
    for m in re.finditer(r"\b(if|guard)\s+#(available|unavailable)\s*\(", s):
        if any(a <= m.start() < b for a, b in cut): continue
        q = close(s, m.end() - 1); v = re.search(r"\biOS\s+(\d+)(?:\.(\d+))?", s[m.end():q])
        runs = (v is None or (int(v.group(1)), int(v.group(2) or 0)) <= (27, 1)) == (m.group(2) == "available")
        j = ws(s, q + 1)
        if m.group(1) == "guard":
            if runs and kw(s, j, "else") and s[ws(s, j + 4):][:1] == "{": drop(m.start(), close(s, ws(s, j + 4)) + 1)
            continue
        if s[j:j + 1] != "{": continue  # combined with another condition: not decided per OS
        a = close(s, j); k = ws(s, a + 1); e = ws(s, k + 4) if kw(s, k, "else") else None
        if runs:
            drop(m.start(), j + 1)
            drop(a, a + 1 if e is None else chain_end(s, e) if kw(s, e, "if") else close(s, e) + 1)
        else:
            drop(m.start(), a + 1)
            if e is not None and kw(s, e, "if"): drop(k, e)
            elif e is not None: drop(k, e + 1); drop(close(s, e), close(s, e) + 1)
    s = "".join(out)
    for m in reversed(list(re.finditer(r"#Preview\b[^{]*\{|struct\s+\w+\s*:\s*PreviewProvider\s*\{", s))):
        b = close(s, m.end() - 1) + 1; s = s[:m.start()] + re.sub(r"[^\n]", " ", s[m.start():b]) + s[b:]
    return s

files = {}
for folder, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "DerivedData", "build", ".build") and not d.endswith((".xcresult", ".app"))]
    for f in names:
        if f.endswith(".swift"):
            path = os.path.join(folder, f)
            files[path] = resolve(open(path, encoding="utf-8", errors="replace").read())
if sys.argv[1] == "count":
    counts = {n: sum(len(re.findall(r"(?<![\w.])%s\s*\(" % n, t)) for t in files.values()) for n in sys.argv[2:]}
    print("built on iOS 27.1, outside previews:", counts)
    many = [n for n, c in counts.items() if c > 1]
    if many: print("built more than once: " + ", ".join(many))
    sys.exit(1 if many else 0)
root = tempfile.mkdtemp()
try:
    for path, text in files.items():
        dst = os.path.join(root, os.path.relpath(path, "."))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w", encoding="utf-8").write(text)
    for pat in sys.argv[3:]:
        r = subprocess.run([sys.executable, sys.argv[2], pat, root], stdout=subprocess.PIPE, universal_newlines=True)
        if r.stdout.startswith("FAIL: nothing matches"):
            print("nothing matches %s, so trying the next pattern" % pat); continue
        print(r.stdout.strip()); sys.exit(r.returncode)
    print("note: the state was renamed or replaced, so the checklist decides")
finally:
    shutil.rmtree(root, ignore_errors=True)
PY
```

```sh check cover-built-once
# The cover is built once, so a fold moves it instead of building a new one that
# starts over. Previews don't count. A cover the agent renamed counts as 0, which
# passes. The branch of an `if #available` that iPhone Duo never runs doesn't count.
python3 - count AlbumArt <<'PY'
import os, re, shutil, subprocess, sys, tempfile
# Reads the Swift sources as iPhone Duo (iOS 27.1) runs them. An `if #available` or
# `#unavailable` with no other condition is decided once per OS, so the branch iOS 27.1
# never takes is blanked, and so is a guard that passes. Comments, strings and previews
# are blanked too; line breaks stay.
#   count NAME...          fails when a NAME(...) view is built in more than one place
#   owner CHECKER PAT...   single_owner.py on the first PAT that matches; none: a note
def mask(t):
    o, i, n = list(t), 0, len(t)
    def upto(end, i, extra):
        j = t.find(end, i)
        return n if j < 0 else j + extra
    while i < n:
        if t.startswith("//", i): j = upto("\n", i, 0)
        elif t.startswith("/*", i): j = upto("*/", i + 2, 2)
        elif t.startswith('"""', i): j = upto('"""', i + 3, 3)
        elif t[i] == '"':
            j = i + 1
            while j < n and t[j] not in '"\n': j += 2 if t[j] == "\\" else 1
            j = min(j + 1, n)
        else:
            i += 1; continue
        o[i:j] = [c if c == "\n" else " " for c in o[i:j]]; i = j
    return "".join(o)

def close(s, i):  # index of the bracket that closes s[i]
    d = 0
    for j in range(i, len(s)):
        d += (s[j] == s[i]) - (s[j] == {"(": ")", "{": "}"}[s[i]])
        if d == 0: return j
    return len(s) - 1

def ws(s, i):
    return len(s) - len(s[i:].lstrip())

def kw(s, i, w):
    return re.match(w + r"\b", s[i:]) is not None

def chain_end(s, i):  # s[i:] starts an if statement: the end of its else chain
    j, d = i + 2, 0
    while j < len(s) and not (s[j] == "{" and d == 0):
        d += (s[j] in "([") - (s[j] in ")]"); j += 1
    if j >= len(s): return len(s)
    j = close(s, j) + 1; k = ws(s, j)
    if not kw(s, k, "else"): return j
    e = ws(s, k + 4)
    return chain_end(s, e) if kw(s, e, "if") else close(s, e) + 1

def resolve(text):
    s = mask(text); out = list(s); cut = []
    def drop(a, b):
        cut.append((a, b)); out[a:b] = [c if c == "\n" else " " for c in out[a:b]]
    for m in re.finditer(r"\b(if|guard)\s+#(available|unavailable)\s*\(", s):
        if any(a <= m.start() < b for a, b in cut): continue
        q = close(s, m.end() - 1); v = re.search(r"\biOS\s+(\d+)(?:\.(\d+))?", s[m.end():q])
        runs = (v is None or (int(v.group(1)), int(v.group(2) or 0)) <= (27, 1)) == (m.group(2) == "available")
        j = ws(s, q + 1)
        if m.group(1) == "guard":
            if runs and kw(s, j, "else") and s[ws(s, j + 4):][:1] == "{": drop(m.start(), close(s, ws(s, j + 4)) + 1)
            continue
        if s[j:j + 1] != "{": continue  # combined with another condition: not decided per OS
        a = close(s, j); k = ws(s, a + 1); e = ws(s, k + 4) if kw(s, k, "else") else None
        if runs:
            drop(m.start(), j + 1)
            drop(a, a + 1 if e is None else chain_end(s, e) if kw(s, e, "if") else close(s, e) + 1)
        else:
            drop(m.start(), a + 1)
            if e is not None and kw(s, e, "if"): drop(k, e)
            elif e is not None: drop(k, e + 1); drop(close(s, e), close(s, e) + 1)
    s = "".join(out)
    for m in reversed(list(re.finditer(r"#Preview\b[^{]*\{|struct\s+\w+\s*:\s*PreviewProvider\s*\{", s))):
        b = close(s, m.end() - 1) + 1; s = s[:m.start()] + re.sub(r"[^\n]", " ", s[m.start():b]) + s[b:]
    return s

files = {}
for folder, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "DerivedData", "build", ".build") and not d.endswith((".xcresult", ".app"))]
    for f in names:
        if f.endswith(".swift"):
            path = os.path.join(folder, f)
            files[path] = resolve(open(path, encoding="utf-8", errors="replace").read())
if sys.argv[1] == "count":
    counts = {n: sum(len(re.findall(r"(?<![\w.])%s\s*\(" % n, t)) for t in files.values()) for n in sys.argv[2:]}
    print("built on iOS 27.1, outside previews:", counts)
    many = [n for n, c in counts.items() if c > 1]
    if many: print("built more than once: " + ", ".join(many))
    sys.exit(1 if many else 0)
root = tempfile.mkdtemp()
try:
    for path, text in files.items():
        dst = os.path.join(root, os.path.relpath(path, "."))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w", encoding="utf-8").write(text)
    for pat in sys.argv[3:]:
        r = subprocess.run([sys.executable, sys.argv[2], pat, root], stdout=subprocess.PIPE, universal_newlines=True)
        if r.stdout.startswith("FAIL: nothing matches"):
            print("nothing matches %s, so trying the next pattern" % pat); continue
        print(r.stdout.strip()); sys.exit(r.returncode)
    print("note: the state was renamed or replaced, so the checklist decides")
finally:
    shutil.rmtree(root, ignore_errors=True)
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
