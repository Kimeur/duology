---
id: recipe-camera-studio/new-camera-studio
skill: recipe-camera-studio
also: duo-camera, duo-scenes, duo-postures, duo-continuity, duo-testing
title: Build a camera studio whose subject sees themselves on the outer display
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R3 R4 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*), Bash(plutil -lint:*)
timeout: 3000
status: ready
---

# Build a camera studio whose subject sees themselves on the outer display

The agent starts from an empty folder and must produce a whole Xcode project. On iPhone Duo, while the phone is open and the rear camera runs, an app can show a view on the outer display, which faces the person being filmed: a camera capture accessory ([Apple's guide](https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo), `duo-scenes`). The simulator has no camera (`duo-camera` measured it), so an app that assumes one crashes there or shows nothing; the layout in each pose still has to be checked. In tabletop, Apple puts what people watch in the top region and what they tap in the bottom one ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=283)).

## Prompt

```text prompt
Create a new iPhone Duo camera app in this folder: photos and videos with the rear camera, a self-timer, and a gallery of what you took that stays in the app until you share it. While the phone is open, the person in front of the camera sees themselves on the outer display, with the countdown. Folded like a book, the preview is on one side of the fold and the controls on the other; half folded and resting on a table, the preview is above the fold and the controls below. No control ever sits on the fold. The simulator has no camera, so make the app usable there with a stand-in picture, and keep a countdown or a recording going through folding and unfolding. Nothing leaves the device and nothing is tracked, with a privacy manifest that says so. Put the layout and timer rules in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs them. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-camera-studio` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

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

```sh check subject-view
# The outer display's view is registered: SwiftUI's CameraCaptureAccessory, or UIKit's
# camera capture scene accessory.
has_src 'CameraCaptureAccessory|\.cameraCapture\(' || { echo "no camera capture accessory"; exit 1; }
```

```sh check usage-strings
# Without a camera usage string the app crashes the first time it asks. Generated Info.plist
# keys in the project, or an Info.plist file, both count.
if ! grep -rqs 'NSCameraUsageDescription' --include='*.pbxproj' --include='*.plist' . ; then
  echo "no NSCameraUsageDescription"
  exit 1
fi
```

```sh check nothing-leaves
# No networking, tracking or cloud sync in the app's code. Test code (Tools/, *Tests/) is
# left out: a test may name these APIs to scan for them.
hits="$(src_grep 'URLSession|NWConnection|ATTrackingManager|ASIdentifierManager|advertisingIdentifier|NSUbiquitousKeyValueStore|^ *import +(Network|CloudKit|AdSupport|AppTrackingTransparency)\b' | grep -v -E '^\./([^:]*/)?(Tools|[^/:]*Tests)/' || true)"
if [ -n "$hits" ]; then
  echo "photos or videos could leave the device:"
  echo "$hits" | head -10
  exit 1
fi
```

```sh check privacy-manifest
# A privacy manifest that says nothing is tracked.
m="$(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -name 'PrivacyInfo.xcprivacy' -type f -print)"
[ -n "$m" ] || { echo "no PrivacyInfo.xcprivacy"; exit 1; }
python3 - $m <<'PY'
import plistlib, sys
ok = False
for path in sys.argv[1:]:
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
    ok = True
sys.exit(0 if ok else 1)
PY
```

```sh check launches
launch_ok
```

## Checklist

Also check, on the simulator: the app starts with no camera and shows something in the preview's place; the shutter, the self-timer, recording and the gallery work there; open, with the self-timer running, the outer display shows the countdown (`xcrun simctl io <UDID> screenshot --display=primary`).

- **R2**: start a 10-second countdown, or a recording, then press Closed and Open in Device Hub. It carries on.
- **R3**: closed and open, the preview and the controls fit their windows; no fixed widths.
- **R4**: partly folded, held wide and in tabletop: no control sits on the fold, and in tabletop the controls are on the bottom half.
- **R10**: closed, the shutter, the timer, the mode, the gallery and the camera switch are reachable.
