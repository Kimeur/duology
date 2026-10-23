---
id: duo-migrate/ship-on-duo
skill: duo-migrate
also: duo-start, duo-lint, duo-scenes
title: Move a shipping UIKit app to Xcode 27.1 and iPhone Duo
readme: no
fixture: Tally
project: Tally.xcodeproj
scheme: Tally
build: yes
lint: yes
checklist: R1 R2 R3 R10
timeout: 2400
status: ready
---

# Move a shipping UIKit app to Xcode 27.1 and iPhone Duo

The SDK an app is built with decides how it looks on iPhone Duo ([Apple: Three steps](https://developer.apple.com/iphone-duo/prepare/)), so an app that ships today has to be rebuilt with Xcode 27.1 and the iOS 27.1 SDK. That rebuild is where old habits break: Apple says UIKit apps built with the latest SDK fail to launch without scenes ([Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)), and the Tally fixture does crash at launch (measured, see [fixtures/README.md](../../fixtures/README.md#tally)). `UIRequiresFullScreen` is deprecated ([TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)) and doesn't stop the app from resizing on iPhone Duo ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)).

## Prompt

```text prompt
People with the new iPhone Duo say our app looks small and boxed in. Our next release has to be built with Xcode 27.1, here and on CI. Get the app ready for iPhone Duo and keep everything it does today.
```

## Starting point

Fixture [`Tally`](../../fixtures/Tally): a UIKit expense list (a total, swipe to delete, a + button, a pushed detail screen), iOS 16.0 target, Swift 5 mode. It builds with Xcode 27.1 but crashes at launch. Its mistakes are listed in [fixtures/README.md](../../fixtures/README.md#tally):

- no scene life cycle: an `@main` app delegate makes its window with `UIWindow(frame: UIScreen.main.bounds)`, the target generates no scene manifest, and the list is saved in `applicationDidEnterBackground`, which UIKit no longer calls once the app uses scenes;
- `UIRequiresFullScreen = YES` in both configurations;
- `UIScreen.main` for the header height and the row icons, an idiom check and a 667 pt height check in the detail screen, and `UIDevice.current.orientation` for the header layout;
- CI pinned to Xcode 26.4 in `.xcode-version` and `.github/workflows/build.yml`.

duo-lint on the untouched fixture: 8 findings, 3 errors and 5 warnings.

## Pass checks

Gates: the app builds for the iPhone Duo simulator, and duo-lint reports nothing.

```sh check scene-life-cycle
# The app uses the scene life cycle: a SwiftUI App, or a UIWindowSceneDelegate that the
# app connects, through configurationForConnecting (delegateClass) or a plist that names
# it (UISceneDelegateClassName). No window is made from a frame any more.
no_src 'UIWindow\(frame:'
python3 - <<'PY'
import os, plistlib, re, sys
skip = {".git", "DerivedData", "build", ".build", "Pods"}
code, plists = "", []
for folder, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in skip and not d.endswith(".xcresult")]
    for f in names:
        p = os.path.join(folder, f)
        if f.endswith(".swift"):
            text = open(p, encoding="utf-8", errors="replace").read()
            code += re.sub(r"/\*.*?\*/", "", re.sub(r"//[^\n]*", "", text), flags=re.S) + "\n"
        elif f.endswith(".plist"):
            plists.append(p)

def names_scene_delegate(value):
    if isinstance(value, dict):
        return "UISceneDelegateClassName" in value or any(names_scene_delegate(v) for v in value.values())
    if isinstance(value, list):
        return any(names_scene_delegate(v) for v in value)
    return False

swiftui = re.search(r"@main\s+(?:@\w+\s+)*(?:(?:public|internal|final)\s+)*(?:struct|class|enum)\s+\w+\s*:"
                    r"\s*(?:[\w.]+\s*,\s*)*(?:SwiftUI\.)?App\b", code)
if swiftui:
    print("scene life cycle: SwiftUI App entry point")
    sys.exit(0)
adopts = re.search(r"\b(?:class|extension)\s+\w+\s*:[^{]*\bUIWindowSceneDelegate\b", code)
if not adopts:
    print("no SwiftUI App entry point and no type adopts UIWindowSceneDelegate")
    sys.exit(1)
wired = []
if re.search(r"configurationForConnecting", code) and re.search(r"\bdelegateClass\b", code):
    wired.append("configurationForConnecting")
for p in plists:
    try:
        with open(p, "rb") as fh:
            data = plistlib.load(fh)
    except Exception:
        continue
    if isinstance(data, dict) and names_scene_delegate(data.get("UIApplicationSceneManifest")):
        wired.append(p)
if not wired:
    print("a UIWindowSceneDelegate exists, but neither configurationForConnecting (delegateClass) "
          "nor a plist's UISceneConfigurations connects it")
    sys.exit(1)
print("scene life cycle: UIWindowSceneDelegate connected by " + ", ".join(wired))
PY
```

```sh check full-screen-off
# UIRequiresFullScreen is gone or false in the build settings, in every plist and, when
# the build gate passed, in the built app. Keeping it for older systems only, with
# UIRequiresFullScreenIgnoredStartingWithVersion (TN3192), is also fine, as in duo-lint.
app=""
if [ "${EVALS_SKIP_HEAVY:-0}" != 1 ]; then
  app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'Tally.app' 2>/dev/null | awk 'NR == 1' || true)"
fi
python3 - "$app" <<'PY'
import os, plistlib, re, sys
skip = {".git", "DerivedData", "build", ".build", "Pods"}
ignore_key = "UIRequiresFullScreenIgnoredStartingWithVersion"
on, ignored = [], []
plists = []
for folder, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in skip and not d.endswith(".xcresult")]
    for f in names:
        p = os.path.join(folder, f)
        if f.endswith((".pbxproj", ".xcconfig")):
            text = open(p, encoding="utf-8", errors="replace").read()
            for m in re.finditer(r"\bINFOPLIST_KEY_UIRequiresFullScreen(?:\[[^\]]*\])?\s*=\s*\"?(YES|true|1)\b", text):
                on.append("%s: %s" % (p, m.group(0)))
            if ignore_key in text:
                ignored.append(p)
        elif f.endswith(".plist"):
            plists.append(p)
if sys.argv[1]:
    plists.append(os.path.join(sys.argv[1], "Info.plist"))
for p in plists:
    try:
        with open(p, "rb") as fh:
            data = plistlib.load(fh)
    except Exception:
        continue
    if not isinstance(data, dict):
        continue
    if ignore_key in data:
        ignored.append(p)
    for key, value in data.items():
        if re.match(r"UIRequiresFullScreen(~\w+)?$", key) and value is True:
            on.append("%s: %s = true" % (p, key))
if on and not ignored:
    print("UIRequiresFullScreen is still on:")
    print("\n".join(on[:10]))
    sys.exit(1)
if on:
    print("UIRequiresFullScreen stays on for older systems only (%s)" % ", ".join(ignored))
PY
```

```sh check ci-on-xcode-27-1
# CI builds with Xcode 27.1 or later: .xcode-version (if it is kept) names 27.1 or later,
# no workflow names Xcode 26 any more, and a workflow still runs xcodebuild with Xcode
# 27.1 or later, named in the workflow or read from .xcode-version.
python3 - <<'PY'
import os, re, sys

def version(text):
    return tuple(int(x) for x in text.split("."))

def new_enough(text):
    v = version(text)
    return v + (0,) * (2 - len(v)) >= (27, 1)

problems = []
pin = None
if os.path.isfile(".xcode-version"):
    words = open(".xcode-version", encoding="utf-8", errors="replace").read().split()
    pin = words[0] if words else ""
    if not re.fullmatch(r"\d+(\.\d+)*", pin) or not new_enough(pin):
        problems.append(".xcode-version says %r, not 27.1 or later" % pin)
flows = []
for folder in (".github/workflows",):
    if os.path.isdir(folder):
        flows += [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if f.endswith((".yml", ".yaml"))]
if not flows:
    problems.append("no CI workflow left in .github/workflows")
xcode = re.compile(r"(?i)\bxcode(?:[ _-]|[ _-]?version\s*:\s*['\"]?)(\d+(?:\.\d+)*)")
pinned = []
for f in flows:
    text = open(f, encoding="utf-8", errors="replace").read()
    for m in xcode.finditer(text):
        if not new_enough(m.group(1)):
            problems.append("%s still names Xcode %s" % (f, m.group(1)))
    if "xcodebuild" not in text:
        continue
    if any(new_enough(m.group(1)) for m in xcode.finditer(text)):
        pinned.append(f)
    elif ".xcode-version" in text and pin and re.fullmatch(r"\d+(\.\d+)*", pin) and new_enough(pin):
        pinned.append(f + " (through .xcode-version)")
if flows and not pinned:
    problems.append("no workflow runs xcodebuild with Xcode 27.1 or later")
if problems:
    print("\n".join(problems))
    sys.exit(1)
print("CI on Xcode 27.1 or later: " + ", ".join(pinned))
PY
```

```sh check still-saves-in-background
# Once the app uses scenes, UIKit no longer calls the app delegate's
# applicationDidEnterBackground, so the save that lived there has to move: to the scene
# delegate, a notification, scenePhase, or a store that saves on every change. An empty
# sceneDidEnterBackground stub, as in Xcode's template, doesn't count.
python3 - <<'PY'
import os, re, sys
skip = {".git", "DerivedData", "build", ".build", "Pods"}
code = ""
for folder, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in skip and not d.endswith(".xcresult")]
    for f in names:
        if f.endswith(".swift"):
            text = open(os.path.join(folder, f), encoding="utf-8", errors="replace").read()
            code += re.sub(r"/\*.*?\*/", "", re.sub(r"//[^\n]*", "", text), flags=re.S) + "\n"
for m in re.finditer(r"\bfunc\s+scene(DidEnterBackground|WillResignActive)\s*\([^)]*\)\s*\{", code):
    depth, j = 1, m.end()
    while j < len(code) and depth:
        depth += {"{": 1, "}": -1}.get(code[j], 0)
        j += 1
    if code[m.end():j - 1].strip():
        print("saves from scene%s" % m.group(1))
        sys.exit(0)
hooks = re.compile(r"\b(didEnterBackground|willResignActive)Notification\b|\bscenePhase\b")
if hooks.search(code):
    print("saves from a hook that runs under scenes: " + hooks.search(code).group(0))
    sys.exit(0)
old = re.search(r"\bfunc\s+application(DidEnterBackground|WillResignActive)\b", code)
if old:
    print("the save still lives only in %s, which UIKit doesn't call once the app uses scenes" % old.group(0))
    sys.exit(1)
calls = [m for m in re.finditer(r"\bsave\s*\(\s*\)", code) if not re.search(r"\bfunc\s+$", code[:m.start()])]
if not calls:
    print("nothing saves the expenses any more")
    sys.exit(1)
print("the store saves without an app delegate hook (%d calls to save())" % len(calls))
PY
```

```sh check launches
launch_ok
```

```sh check features-still-work
# Adding and deleting expenses are still in the code. Then a UI test written here, not in
# the fixture: the list shows the Groceries expense and the total, and tapping Groceries
# opens its detail (its note, "Weekly shop").
has_src 'New Expense'
has_src 'commit +editingStyle|trailingSwipeActionsConfigurationForRowAt|UIContextualAction|\.onDelete|\.swipeActions'
skip_if_light "runs a UI test on the simulator"
[ -d TallyUITests ] || { echo "the TallyUITests folder is gone"; exit 1; }
cat > TallyUITests/TallyListOracleTests.swift <<'SWIFT'
import XCTest

final class TallyListOracleTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testListAndDetail() throws {
        let app = XCUIApplication()
        app.launch()
        let groceries = app.staticTexts["Groceries"].firstMatch
        XCTAssertTrue(groceries.waitForExistence(timeout: 20), "the list does not show Groceries")
        XCTAssertTrue(app.staticTexts["Total"].firstMatch.exists, "the list does not show Total")
        groceries.tap()
        XCTAssertTrue(app.staticTexts["Weekly shop"].firstMatch.waitForExistence(timeout: 10),
                      "tapping Groceries did not open its detail")
    }
}
SWIFT
xcb_test -only-testing:TallyUITests/TallyListOracleTests
```

## Checklist

A reviewer runs the app on the iPhone Duo simulator closed and open, upright and sideways, and marks:

- **R1**: closed and open, the app fills its window: no black bars and no small box in the middle of the inner display.
- **R2**: scroll the list, open an expense, then unfold and fold. The same expense stays open and the list keeps its place. Type a name into New Expense, then unfold: the text is still there.
- **R3**: the header and the row icons are sized from the window, not the screen: closed and open, the header is not stretched or squashed and the icons line up. The detail screen picks its layout from its width, not from "iPad" or a 667 pt height.
- **R10**: closed, every feature works: add an expense, delete one, see the total change, open an expense.
