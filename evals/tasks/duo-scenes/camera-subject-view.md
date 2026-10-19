---
id: duo-scenes/camera-subject-view
skill: duo-scenes
title: Show the person being filmed a countdown on the outer display
readme: no
fixture: Shoot
project: Shoot.xcodeproj
scheme: Shoot
build: yes
lint: yes
checklist: R10
timeout: 1800
status: ready
---

# Show the person being filmed a countdown on the outer display

When iPhone Duo is fully open and an app captures with the rear camera, the app can show extra content on the outer display through a camera capture accessory: `CameraCaptureAccessory` inside `.sceneAccessory` in SwiftUI, or `UISceneAccessory.cameraCapture(sceneConfiguration:)` in UIKit. The system decides when it shows, so the app must work without it ([Registering a camera capture accessory](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), [api-index.md](../../../reference/api-index.md#scenes-and-scene-accessories)). The other accessory in the SDK, `ExternalNonInteractiveAccessory`, is for connected displays; Apple names no other route to the outer display while the app runs on the inner one.

## Prompt

```text prompt
This is a camera app for filming other people. On iPhone Duo, when the phone is open and the rear camera is filming, show the person being filmed the countdown and a recording light on the outer display. The person filming must be able to turn that off. Everything must keep working when the outer display can't be used.
```

## Starting point

Fixture [`Shoot`](../../fixtures/Shoot): a full-screen rear camera preview with a record button (`shoot.record`), a 3-second countdown and a recording badge, all driven by one `CameraModel`. iOS 17 target, Swift 5. The simulator has no camera, so the preview says "Camera unavailable"; the countdown and badge still work. duo-lint finds nothing.

The deployment target is below iOS 27.1, so the build gate also checks that the accessory code sits behind an availability check.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing (so no `UIScreen.screens`).

```sh check uses-the-camera-accessory
has_src 'CameraCaptureAccessory|cameraCapture\(sceneConfiguration'
has_src 'sceneAccessory|registerSceneAccessory'
```

```sh check no-display-hunting
# External-display scenes and non-interactive accessories are for connected
# displays, not the outer display.
no_src 'UIScreen\.screens|ExternalDisplay|ExternalNonInteractiveAccessory|externalNonInteractive'
```

```sh check follows-availability
# The app hears when the system shows or hides the accessory.
has_src 'onAvailabilityChange|\.isAvailable'
```

```sh check can-be-turned-off
# A setting the person filming controls: the accessory's isEnabled.
has_src 'CameraCaptureAccessory\(isEnabled:|\.isEnabled *='
```

```sh check record-kept
has_src '"shoot.record"'
```

```sh check one-camera-model
# The accessory shows the same model as the main screen, so its countdown matches.
# CameraModel if the app still has one, otherwise the countdown and recording state
# itself (duo-scenes' recipe calls its model ShootModel). Renamed past both: the
# check says so and passes. Shoot targets iOS 17, so a fix may pick its screen with
# `if #available(iOS 27.1, *)`; the branch iPhone Duo never runs is left out.
python3 - owner "$EVALS/lib/checks/single_owner.py" 'CameraModel\(' '\bvar +(secondsToStart|isRecording)\b' <<'PY'
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

The simulator shows the accessory without a running capture session (an Xcode 27.1 known issue), so this checks layout only. Availability with a real camera needs a device.

- **R10**: Open: start a recording. The countdown and the recording badge still show on the inner display, the record button works, and the switch that turns the outer display view off is reachable. Closed: the app works the same, with no error and no missing control.
- Outside the rule verdict, note what the outer display shows in the simulator when open: the countdown, then the recording light, readable from a distance.
