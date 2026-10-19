---
id: duo-postures/book-two-regions
skill: duo-postures
also: duo-layout, duo-patterns, duo-continuity
title: Book layout for a cooking screen
readme: no
fixture: Steps
project: Steps.xcodeproj
scheme: Steps
build: yes
lint: yes
checklist: R2 R4 R7 R10
timeout: 2400
status: ready
---

# Book layout for a cooking screen

"Book" is Duology's shorthand for what Apple describes as the phone partially folded, like a book: held wide, the fold running top to bottom through the inner display. Apple's advice for that pose is to fit content to one side of the fold and move controls off it, toward the trailing side ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=249)). Apple has no posture API: an active `.division` reserved region running top to bottom is what tells a view it is folded like a book ([api-index.md](../../../reference/api-index.md#reserved-regions-and-margins)).

## Prompt

```text prompt
This is the cooking screen of our recipe app, for iPhone Duo. When someone half-opens the phone and holds it like a book, put the step text on the left page and the timer on the right page, with no button in the fold. Closed and fully open, keep a layout that works. The timer must keep counting when the phone is opened, closed or folded. Don't remove any control or its accessibility identifier.
```

## Starting point

Fixture [`Steps`](../../fixtures/Steps): one screen with a recipe step, a timer panel and Previous and Next buttons (`cook.previous`, `cook.next`, `cook.timer`). iOS 17 target, Swift 5.

- An `if` on the width size class builds the step card and the timer panel once in each branch. The timer (`CookTimer`) is a `@StateObject` inside the timer panel, so opening or closing the phone builds a new panel and the countdown starts over.
- The open layout sizes the step column from `UIScreen.main.bounds.width / 2` (duo-lint DUO001). The vertical bar sits on one side, so half the screen is not where the fold is.
- Previous and Next float centred at the bottom of the whole window. Folded like a book, they sit on the fold.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check controls-kept
for id in cook.previous cook.next cook.timer; do
  has_src "\"$id\""
done
```

```sh check layout-from-fold
# The two pages come from the fold itself (the .division region) or from an
# arrangement that splits at it, not from half the screen or the hinge alone.
has_src 'reservedRegions\(kind: *\.division|ArrangementView|UIArrangementViewController'
```

```sh check no-posture-guessing
no_src 'UIDevice\.current\.orientation'
```

```sh check timer-survives
# One countdown, owned where a fold or unfold can't rebuild it: the CookTimer object
# if the app still has one, otherwise the countdown value itself (secondsLeft,
# remaining and similar names), as in a fix that keeps it in the screen's @State
# the way duo-postures' book recipe does. Steps targets iOS 17, so a fix may keep a
# fallback under `if #available(iOS 27.1, *) { ... } else { ... }`; the branch iPhone
# Duo never runs is left out. If the timer was renamed past both patterns, the check
# says so and passes, and R2 decides.
python3 - owner "$EVALS/lib/checks/single_owner.py" 'CookTimer\(' '\bvar +\w*([Rr]emaining|[Ss]econdsLeft|[Tt]imeLeft|[Ee]ndDate|[Dd]eadline)\w*\b' <<'PY'
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

The reviewer starts the timer on step 1, then sets each pose in Device Hub:

- **R7**: Partially Open, held wide: the step text fills the leading page and the timer the trailing page. Nothing reads across the fold.
- **R4**: in the same pose, no button (Previous, Next, the timer button) touches the fold.
- **R2**: Closed, Open, Partially Open and back to Closed: the timer keeps counting down and the same step stays on screen.
- **R10**: closed, upright and sideways, every control is on screen or one scroll away.
