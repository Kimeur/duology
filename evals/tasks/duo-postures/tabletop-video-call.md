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
# Talk targets iOS 17, so a fix may keep a fallback under `if #available(iOS 27.1, *)
# { ... } else { ... }`. That choice is made once per OS and never changes with the
# pose, so the branch iPhone Duo never runs doesn't count.
python3 - count RemoteVideoView CallControls <<'PY'
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

```sh check call-state-survives
# Mute, camera and speaker state live in one place that a pose change can't rebuild.
# It looks for isMuted, then any other mute state. If the agent renamed it past
# both, the check says so and passes. Fallbacks iPhone Duo never runs are left out,
# as above.
python3 - owner "$EVALS/lib/checks/single_owner.py" '\bvar +isMuted\b' '\bvar +\w*[Mm]ute\w*\b' <<'PY'
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

```sh check launches
launch_ok
```

## Checklist

The reviewer sets the pose in Device Hub (Partially Open, then Rotate Right once, for held tall) and marks:

- **R7**: the remote video sits in the top half, every control in the bottom half, and the same controls exist as when flat.
- **R4**: no control touches the fold, and none sits under the inner camera on the right edge of the bottom half.
- **R3**: closed and fully open, the screen still fits its window; the self view isn't sized from the screen.
- **R10**: every control is available in every pose.
