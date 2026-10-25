---
id: recipe-kids-learning/new-kids-app
skill: recipe-kids-learning
also: duo-postures, duo-continuity, duo-accessibility, duo-app-store, duo-testing
title: Build a learning app for young children, with a parental gate and nothing tracked
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R3 R4 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*), Bash(plutil -lint:*)
timeout: 3000
status: ready
---

# Build a learning app for young children, with a parental gate and nothing tracked

The agent starts from an empty folder and must produce a whole Xcode project. Apple's rules for apps made for kids keep links out of the app and purchases behind a parental gate, and keep third-party analytics and advertising out ([App Review Guidelines 1.3 and 5.1.4](https://developer.apple.com/app-store/review/guidelines/)); Apple describes the gate as an adult-level task, such as a math question ([kids apps](https://developer.apple.com/app-store/kids-apps/)). An app that stores progress in `UserDefaults` declares why in its privacy manifest ([privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)). On iPhone Duo, the tabletop pose lets the phone rest on a table, so small hands tap the half that doesn't move (`duo-postures`).

## Prompt

```text prompt
Create a new iPhone Duo learning app for young children (5 and under) in this folder: counting and first letters, one question at a time, with big answer buttons and a button that reads the question aloud. Closed, the picture sits above the answers. Open, the question is on one side of the fold and the answers on the other. Half folded and resting on a table, the picture is above the fold and the answers below. The stars a child earns survive folding, unfolding and relaunching, and never leave the device. Put a grown-ups area (reset progress, a link to the privacy policy) behind a parental gate that asks an adult-level question. No ads, no analytics, no network, nothing tracked, and a privacy manifest that says so. Use sample content. Put the gate and the progress logic in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs them. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-kids-learning` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

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

```sh check nothing-tracked
# No networking, advertising identifiers or tracking APIs in the app's code. Test code
# (Tools/, *Tests/) is left out: a test may name these APIs to scan for them.
hits="$(src_grep 'URLSession|NWConnection|ATTrackingManager|ASIdentifierManager|advertisingIdentifier|identifierForVendor|^ *import +(Network|AdSupport|AppTrackingTransparency)\b' | grep -v -E '^\./([^:]*/)?(Tools|[^/:]*Tests)/' || true)"
if [ -n "$hits" ]; then
  echo "networking or tracking in the app:"
  echo "$hits" | head -10
  exit 1
fi
```

```sh check parental-gate
# A gate exists in the code. Whether it asks an adult-level question and guards the
# links and settings is judged in the checklist.
has_src '[Pp]arental ?[Gg]ate|[Gg]rown-?[Uu]ps?|struct +[A-Za-z]*Gate\b|class +[A-Za-z]*Gate\b'
```

```sh check launches
launch_ok
```

## Checklist

Also check, on the simulator: the gate asks a question a young child can't answer (an adult-level task), a wrong answer closes it, and the privacy policy link and the progress reset are reachable only after the gate. No ads, no purchases, no other link out.

- **R2**: earn a star, then press Closed and Open in Device Hub. The star count and the current question stay.
- **R3**: closed and open, the picture, the question and the answers fit their windows; no fixed widths.
- **R4**: partly folded, held wide and in tabletop: no answer button sits on the fold, and in tabletop the answers are on the bottom half.
- **R10**: closed, every activity, the read-aloud button and the grown-ups area are reachable.
