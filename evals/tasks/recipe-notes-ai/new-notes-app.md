---
id: recipe-notes-ai/new-notes-app
skill: recipe-notes-ai
also: duo-intelligence, duo-continuity, duo-postures, duo-patterns, duo-testing
title: Build a notes app with on-device AI summaries that keep going through a fold
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R3 R4 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*), Bash(plutil -lint:*)
timeout: 3000
status: ready
---

# Build a notes app with on-device AI summaries that keep going through a fold

The agent starts from an empty folder and must produce a whole Xcode project. Foundation Models gives an app Apple's on-device model; the app checks that it is available, and still needs a path for when a request fails ([Foundation Models](https://developer.apple.com/documentation/foundationmodels), [generating content](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)). On the iPhone Duo simulator the model fails every request, so an app without a fallback shows nothing there (`duo-intelligence`). On iPhone Duo the summary belongs beside the note when the phone is open and in one line when it is closed, and a summary still streaming in must survive opening and closing the phone (`duo-continuity`).

## Prompt

```text prompt
Create a new iPhone Duo notes app in this folder: a list of notes, an editor, and a summary of each note (a one-line headline, the key points and the to-dos) written by Apple's on-device model with Foundation Models, streamed in as it is written. Closed, the summary is one line under the note with a way to see the rest. Open, the summary is in a pane on the other side of the fold from the note. Half folded and resting on a table, the note is above the fold and the summary below. A summary still being written keeps going when the phone opens, closes or folds. When the model is unavailable or fails, the app still gives a summary without AI and says so. The notes never leave the device: no network, no server model, nothing tracked, and a privacy manifest that says so. Notes and summaries survive relaunching. Put the summary rules that don't need the model, and the layout rules, in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs them. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-notes-ai` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

The run with Duology also gets the recipe's own `new-project.sh`, by its exact path in the plugin copy (`PLUGIN_SCRIPTS` in [`lib/evalkit.py`](../../lib/evalkit.py)).

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

```sh check uses-on-device-model
# The app's code asks Foundation Models for the summary and checks availability first.
has_src '^ *import +FoundationModels\b' || { echo "no import FoundationModels"; exit 1; }
has_src 'LanguageModelSession' || { echo "no LanguageModelSession"; exit 1; }
has_src '\.availability\b|\.isAvailable\b' || { echo "no availability check"; exit 1; }
```

```sh check notes-stay-on-device
# No networking, no server model and no sync in the app's code. Test code (Tools/, *Tests/)
# is left out: a test may name these APIs to scan for them.
hits="$(src_grep 'URLSession|NWConnection|PrivateCloudComputeLanguageModel|NSUbiquitousKeyValueStore|ATTrackingManager|ASIdentifierManager|^ *import +(Network|CloudKit|AdSupport|AppTrackingTransparency)\b' | grep -v -E '^\./([^:]*/)?(Tools|[^/:]*Tests)/' || true)"
if [ -n "$hits" ]; then
  echo "the notes could leave the device:"
  echo "$hits" | head -10
  exit 1
fi
```

```sh check privacy-manifest
# A privacy manifest that says nothing is tracked, and, when the app uses UserDefaults
# (or @AppStorage), declares it with a reason Apple lists for that use.
m="$(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -name 'PrivacyInfo.xcprivacy' -type f -print)"
[ -n "$m" ] || { echo "no PrivacyInfo.xcprivacy"; exit 1; }
uses_defaults=0
if [ -n "$(src_grep 'UserDefaults|@AppStorage' | grep -v -E '^\./([^:]*/)?(Tools|[^/:]*Tests)/' || true)" ]; then uses_defaults=1; fi
python3 - "$uses_defaults" $m <<'PY'
import plistlib, sys
uses_defaults = sys.argv[1] == "1"
ok = False
for path in sys.argv[2:]:
    try:
        with open(path, "rb") as f:
            d = plistlib.load(f)
    except Exception as e:
        print(f"{path}: not a property list ({e})")
        continue
    if d.get("NSPrivacyTracking") is not False:
        print(f"{path}: NSPrivacyTracking is not false")
        continue
    if d.get("NSPrivacyTrackingDomains"):
        print(f"{path}: lists tracking domains")
        continue
    if uses_defaults:
        reasons = [r for t in d.get("NSPrivacyAccessedAPITypes", [])
                   if t.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
                   for r in t.get("NSPrivacyAccessedAPITypeReasons", [])]
        if not set(reasons) & {"CA92.1", "1C8F.1"}:
            print(f"{path}: the app uses UserDefaults but the manifest gives no reason for it")
            continue
    ok = True
sys.exit(0 if ok else 1)
PY
```

```sh check launches
launch_ok
```

## Checklist

Also check, on the simulator: summarize a note. The model fails there, so the app must still show a summary, labelled as not from AI, with a way to try again. The pane says which summaries come from AI, and has Stop while one is being written. The note's text goes in the prompt, never in the session's instructions.

- **R2**: start a summary, then press Open and Closed in Device Hub while it is written (a stand-in stream is fine). It keeps going with no restart; the note's text and the finished summary stay.
- **R3**: closed and open, the note and the summary fit their windows; no fixed widths.
- **R4**: partly folded, held wide and in tabletop: the note and the summary are on either side of the fold, and none of the summary's buttons sits on it.
- **R10**: closed, the summary's headline, the full summary and its buttons are reachable.
