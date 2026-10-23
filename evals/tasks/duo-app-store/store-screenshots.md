---
id: duo-app-store/store-screenshots
skill: duo-app-store
also: duo-pose-matrix, duo-testing
title: App Store screenshots and submission for iPhone Duo
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
checklist: R1
tools: Bash(sips:*), Bash(mkdir:*), Bash(plutil -lint:*)
timeout: 2400
status: ready
---

# App Store screenshots and submission for iPhone Duo

App Store Connect has its own screenshot sizes for iPhone Duo: 1398 × 2034 or 2034 × 1398 pixels for the outer display, 2007 × 2853 or 2853 × 2007 for the inner display, up to 10 per size, in JPEG or PNG, and "Images can't include alpha channels or transparencies" ([Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)). The same page says that a product page with iPhone Duo screenshots shows a badge saying the app is optimized for iPhone Duo, and that from April 2027 apps built with the iOS 27.1 SDK or later need them. Raw simulator screenshots aren't ready to upload: by default `simctl io screenshot` saves PNGs with an alpha channel, and the display that is off in the current pose saves at full size with every pixel black (measured, see [Starting point](#starting-point)).

The same submission is checked for a privacy manifest. An app that uses a required-reason API, such as `UserDefaults`, declares it in `PrivacyInfo.xcprivacy` with an approved reason, and "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect" ([Apple: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)).

This task is `planned` until the harness can change the simulator's pose, for the reason in `depends:` and in [`duo-pose-matrix/every-pose-screenshots`](../duo-pose-matrix/every-pose-screenshots.md). Name it on the command line to run it anyway.

## Prompt

```text prompt
We're submitting this app to the App Store next week, and we want its page to show that it's made for the new iPhone Duo. Make our App Store screenshots for iPhone Duo, of the closed phone and of the open phone. Put only the finished screenshots, ready to upload, in a folder named Store at the top of the project, and write our notes for App Review in Store/review-notes.md. Then check that nothing else in the submission will get it rejected, and fix what you find.
```

## Starting point

Fixture [`Places`](../../fixtures/Places), unchanged: three tabs (Places, Gallery, Settings), iOS 17 target, Swift 5 mode. It builds for the iPhone Duo simulator and launches. There is no `Store` folder and no `PrivacyInfo.xcprivacy`.

- **Required-reason API:** `Settings/SettingsScreen.swift` keeps two toggles in `@AppStorage`, which reads and writes `UserDefaults`. That is the category `NSPrivacyAccessedAPICategoryUserDefaults`, and the reason that fits an app keeping its own settings is `CA92.1`. Apple also lists `1C8F.1` (App Group), `C56D.1` (third-party SDKs only) and `AC6B.1` (managed app configuration from MDM) ([NSPrivacyAccessedAPIType](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)). The fixture uses no other required-reason API: no file timestamps, system boot time, disk space or active keyboards.
- **Simulator:** measured on 23 October 2026 with Xcode 27.1 on the iPhone Duo simulator (iOS 27.1), closed: `simctl io screenshot --display=primary` saved the outer display at 1398 × 2034 and `--display=primary-1` saved the inner display at 2007 × 2853, both PNGs with an alpha channel, the inner one all black (mean colour 0). With `--type=jpeg`, both came out as JPEGs at the same sizes, without alpha. `simctl` has no pose command, so a run can capture only the display that the current pose turns on.
- duo-lint's findings on Places (10) are other tasks' job, so there is no lint gate.

## Pass checks

Gates: the app builds for the iPhone Duo simulator.

```sh check duo-screenshots
# Every image under Store/ (any depth) is an App Store screenshot for iPhone Duo, ready to
# upload: a size App Store Connect lists for it (outer display 1398 x 2034 or 2034 x 1398,
# inner display 2007 x 2853 or 2853 x 2007), no alpha channel, and not black. At least one
# usable screenshot: the eval account can't change the simulator's pose, so whether both
# displays are covered is judged in the checklist. A frame counts as black when its mean colour, read from the image
# shrunk to one pixel, is under 3 of 255, the test the skill's capture script uses: a
# display that is off in the current pose saves at full size with every pixel black.
[ -d Store ] || { echo "no Store folder"; exit 1; }
tmp="$(mktemp -d "${TMPDIR:-/tmp}/duo-shots.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
list="$(find Store -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort)"
[ -n "$list" ] || { echo "no PNG or JPEG files under Store"; exit 1; }
outer=0; inner=0; bad=""
while IFS= read -r f; do
  info="$(/usr/bin/sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" 2>/dev/null || true)"
  w="$(awk '/pixelWidth:/ { print $2 }' <<< "$info")"
  h="$(awk '/pixelHeight:/ { print $2 }' <<< "$info")"
  alpha="$(awk '/hasAlpha:/ { print $2 }' <<< "$info")"
  case "${w}x${h}" in
    1398x2034|2034x1398) kind=outer ;;
    2007x2853|2853x2007) kind=inner ;;
    *) bad="$bad
$f: ${w:-?} x ${h:-?} px is not an iPhone Duo screenshot size"; continue ;;
  esac
  if [ "$alpha" != no ]; then
    bad="$bad
$f: has an alpha channel (hasAlpha: ${alpha:-unknown}), which App Store Connect doesn't accept"
    continue
  fi
  rm -f "$tmp/px.png"
  /usr/bin/sips -s format png -z 1 1 "$f" --out "$tmp/px.png" >/dev/null 2>&1 || true
  mean="$(python3 -I - "$tmp/px.png" <<'PY'
import struct, sys, zlib
try:
    data = open(sys.argv[1], "rb").read()
except OSError:
    print(-1)
    sys.exit(0)
pos, idat, depth, ctype, palette = 8, b"", 8, 2, b""
while pos + 8 <= len(data):
    n, kind = struct.unpack(">I4s", data[pos:pos + 8])
    body = data[pos + 8:pos + 8 + n]
    if kind == b"IHDR":
        depth, ctype = body[8], body[9]
    elif kind == b"PLTE":
        palette = body
    elif kind == b"IDAT":
        idat += body
    pos += 12 + n
try:
    row = zlib.decompress(idat)
except zlib.error:
    print(-1)
    sys.exit(0)
# One pixel in one row: a filter byte, then the pixel. With nothing to its left or above,
# every PNG filter leaves that first pixel as it is.
step = 2 if depth == 16 else 1
channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype, 3)
samples = [row[1 + i * step] for i in range(channels)]
if depth < 8:
    samples = [(row[1] >> (8 - depth)) * 255 // ((1 << depth) - 1)]
if ctype == 3:
    px = list(palette[samples[0] * 3:samples[0] * 3 + 3]) or [0, 0, 0]
elif ctype in (0, 4):
    px = samples[:1] * 3
else:
    px = samples[:3]
print(sum(px) // 3)
PY
)"
  case "$mean" in ''|*[!0-9-]*) mean=-1 ;; esac
  if [ "$mean" -lt 0 ]; then
    bad="$bad
$f: could not read its mean colour"
  elif [ "$mean" -lt 3 ]; then
    bad="$bad
$f: black (mean colour $mean of 255): that display was off, or the app wasn't on it"
  elif [ "$kind" = outer ]; then
    outer=$((outer + 1))
  else
    inner=$((inner + 1))
  fi
done <<< "$list"
echo "usable screenshots under Store: outer display $outer, inner display $inner"
if [ -n "$bad" ]; then
  echo "not ready to upload:$bad"
  exit 1
fi
[ $((outer + inner)) -ge 1 ] || { echo "no usable iPhone Duo screenshot under Store"; exit 1; }
```

```sh check review-notes
# A notes file for App Review under Store/ (.md or .txt; the prompt asks for
# Store/review-notes.md) that names iPhone Duo and tells the reviewer about both the
# closed phone and the open phone. "Open the app" doesn't count as the open phone; the
# inner display, unfolding, book or tabletop do.
python3 -I - <<'PY'
import os, re, sys
files = []
for folder, dirs, names in os.walk("Store"):
    files += [os.path.join(folder, n) for n in names if n.lower().endswith((".md", ".txt"))]
if not files:
    print("no .md or .txt file under Store with notes for App Review")
    sys.exit(1)
duo = re.compile(r"\biPhone\s*Duo\b", re.I)
closed = re.compile(r"\bclosed\b|\b(outer|cover|front) (display|screen)\b|\bfolded (shut|closed|up)\b"
                    r"|\bfully folded\b|\bclose (it|the phone|the device|the iphone duo)\b", re.I)
opened = re.compile(r"\bunfold(s|ed|ing)?\b|\binner (display|screen)\b|\bbook\b|\btabletop\b"
                    r"|\bpartially open\b|\bhalf[- ]?(fold|folded|open)\b|\bfully open(ed)?\b"
                    r"|\bopen (phone|pose|position|state)\b"
                    r"|\b(phone|device|duo)( is| stays| held)?( fully)? open(s|ed)?\b|\bit(?:'s| is) (fully )?open\b"
                    r"|\bopen(ed|ing)? (it|the phone|the device|the iphone duo)\b"
                    r"|\bopen\s*[(:,;/]|\bopen\.(\s|$)|\bopen (and|or) (closed|folded)\b"
                    r"|\b(closed|folded) (and|or|to|then) open\b", re.I)
problems = []
for path in sorted(files):
    text = open(path, encoding="utf-8", errors="replace").read()
    missing = [name for name, pat in (("iPhone Duo", duo), ("the closed phone", closed),
                                      ("the open phone", opened)) if not pat.search(text)]
    words = len(re.findall(r"\w+", text))
    if not missing and words >= 20:
        print("App Review notes: %s (%d words)" % (path, words))
        sys.exit(0)
    if words < 20:
        missing.append("at least 20 words (it has %d)" % words)
    problems.append("%s: missing %s" % (path, ", ".join(missing)))
print("no notes file under Store covers iPhone Duo, the closed phone and the open phone:")
print("\n".join(problems))
sys.exit(1)
PY
```

```sh check privacy-manifest
# Places keeps its settings in @AppStorage, which is UserDefaults, a required-reason API.
# The app's source folder (Places/, which Xcode syncs into the app target) has a
# PrivacyInfo.xcprivacy that is a valid property list and declares
# NSPrivacyAccessedAPICategoryUserDefaults with a reason that fits an app reading its own
# settings: CA92.1, or 1C8F.1 when they live in an App Group. When the build gate has
# built the app, the manifest must be inside it too.
manifests="$(find Places -type f -name PrivacyInfo.xcprivacy 2>/dev/null | sort)"
[ -n "$manifests" ] || { echo "no PrivacyInfo.xcprivacy in the app's source folder (Places/)"; exit 1; }
while IFS= read -r m; do
  /usr/bin/plutil -lint "$m" || { echo "$m is not a valid property list"; exit 1; }
done <<< "$manifests"
python3 -I - <<'PY'
import glob, os, plistlib, sys
FITS = {"CA92.1", "1C8F.1"}
paths = sorted(os.path.join(folder, "PrivacyInfo.xcprivacy") for folder, dirs, names in os.walk("Places")
               if "PrivacyInfo.xcprivacy" in names)
ok = []
for path in paths:
    try:
        with open(path, "rb") as fh:
            data = plistlib.load(fh)
    except Exception as e:
        print("%s: can't read it as a property list (%s)" % (path, e))
        continue
    types = data.get("NSPrivacyAccessedAPITypes") if isinstance(data, dict) else None
    for entry in types if isinstance(types, list) else []:
        if not isinstance(entry, dict):
            continue
        if entry.get("NSPrivacyAccessedAPIType") != "NSPrivacyAccessedAPICategoryUserDefaults":
            continue
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
        reasons = [r for r in reasons if isinstance(r, str)] if isinstance(reasons, list) else []
        if FITS & set(reasons):
            ok.append(path)
        else:
            print("%s declares UserDefaults with reasons %s; an app keeping its own settings needs "
                  "CA92.1 (or 1C8F.1 for an App Group)" % (path, reasons or "none"))
if not ok:
    print("no PrivacyInfo.xcprivacy under Places/ declares NSPrivacyAccessedAPICategoryUserDefaults "
          "with a fitting reason")
    sys.exit(1)
print("UserDefaults declared in " + ", ".join(ok))
built = sorted(glob.glob(os.path.join(os.environ.get("DERIVED_DATA", "DerivedData"),
                                      "Build", "Products", "*", "Places.app")))
if built:
    if not os.path.isfile(os.path.join(built[0], "PrivacyInfo.xcprivacy")):
        print("the built app %s has no PrivacyInfo.xcprivacy: is the file in the app target?" % built[0])
        sys.exit(1)
    print("the built app carries it: " + built[0])
PY
```

```sh check launches
# A guard: the manifest and any screenshot switch the agent added didn't stop the app
# from launching. It passes on the untouched fixture, which launches.
launch_ok
```

## Checklist

Open every image under `Store/` before judging. Each must be the Places app as it runs on the iPhone Duo simulator, with sample data: not drawn, not an iPhone screenshot stretched or scaled up to an iPhone Duo size, and the inner-display frame must show the open phone. A frame that isn't the real app fails the trial; say which in `notes`. Both displays: the run can't change the simulator's pose, so it may only reach the display that is on. If `Store/` holds only one display, the run's final message or the notes must say which display is missing and why; a run that claims both displays without the files fails. Read `Store/review-notes.md` too: it should say which screens change when the phone opens and how to reach them, with no claims the app doesn't back up.

- **R1**: in every screenshot, and on the simulator closed and open, the app fills the display it is on: no black bars and no small box in the middle of the inner display.
