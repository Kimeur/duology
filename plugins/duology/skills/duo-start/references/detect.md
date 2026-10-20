# Detect the stack, the app's state and the SDK

Run this before routing. It is read-only: it lists files, greps and asks `xcodebuild` for settings. It never builds, edits or switches Xcode.

## The script

Save it outside the app's repo (for example in `$TMPDIR`) and run it from the repo's root folder. It looks for the Xcode project up to three levels down, so an app in `ios/`, `App/` or `apps/ios/` is found. The first run lists the schemes. Run it again with `SCHEME=` to add the build settings.

```bash
#!/bin/bash
# duo-start detection. Read-only. Run it from the repo's root folder:
#   bash duo-detect.sh                 # first run lists the schemes
#   SCHEME=MyApp bash duo-detect.sh    # second run adds build settings
DEV=${DUO_XCODE:-/Applications/Xcode-27.1.app/Contents/Developer}

files() {  # find source files, skipping dependency and build folders
  find . \( -name .git -o -name Pods -o -name Carthage -o -name .build -o -name build \
    -o -name DerivedData -o -name node_modules -o -name SourcePackages \) -prune \
    -o -type f \( "$@" \) -print0
}
count() { local pattern=$1; shift; files "$@" | xargs -0 grep -lE "$pattern" 2>/dev/null | wc -l | tr -d ' '; }
SRC=(-name '*.swift' -o -name '*.m' -o -name '*.mm')

echo "== Project"
# Look up to three levels down: many repos keep the app in ios/, App/ or apps/ios/.
FOUND=$(find . -maxdepth 3 \( -name .git -o -name Pods -o -name Carthage -o -name .build -o -name build \
    -o -name DerivedData -o -name node_modules -o -name SourcePackages \) -prune \
  -o \( -name '*.xcworkspace' -o -name '*.xcodeproj' \) -print -prune \
  -o -type f \( -name Package.swift -o -name project.yml -o -name Project.swift \) -print)
# The app's container: the shallowest one; a workspace wins over a project at the same depth.
CONTAINER_PATH=$(printf '%s\n' "$FOUND" | grep -E '\.(xcworkspace|xcodeproj)$' \
  | awk -F/ '{ print NF, (/\.xcworkspace$/ ? 0 : 1), $0 }' | sort -n -k1,1 -k2,2 | head -1 | cut -d' ' -f3-)
OTHER=$(ls -d pubspec.yaml capacitor.config.* ProjectSettings/ProjectVersion.txt 2>/dev/null; grep -l '"react-native"' package.json 2>/dev/null)
SOURCES=$(files "${SRC[@]}" | tr -cd '\0' | wc -c | tr -d ' ')
[ -n "$FOUND" ] && printf '%s\n' "$FOUND" | head -10
echo "source files (Swift, Objective-C): $SOURCES"
if [ -n "$OTHER" ]; then
  echo "NOT NATIVE: $(echo $OTHER) (Duology covers native SwiftUI and UIKit only)"
elif [ -n "$CONTAINER_PATH" ]; then
  echo "EXISTING app: $CONTAINER_PATH"
  DIR=$(dirname "$CONTAINER_PATH")
  [ "$DIR" != . ] && echo "run the first pass from $DIR (cd there), or pass the path with -workspace or -project"
elif [ -n "$FOUND" ]; then
  echo "EXISTING code, no .xcodeproj or .xcworkspace: a Swift package or a generated project. Ask how the app is built."
elif [ "$SOURCES" -gt 0 ]; then
  echo "EXISTING code, no Xcode project within three levels: ask the user where the project is"
else
  echo "no Xcode project and no source files: treat as a NEW app"
fi

echo "== UI framework"
echo "files importing SwiftUI:   $(count '^[[:space:]]*import SwiftUI' -name '*.swift')"
echo "files importing UIKit:     $(count '^[[:space:]]*import UIKit' -name '*.swift')"
echo "SwiftUI App entry point:   $(count '[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*App([[:space:]]*[{,]|[[:space:]]*$)' -name '*.swift')"
echo "UIKit app delegate:        $(count 'UIApplicationDelegate|UIApplicationMain' "${SRC[@]}")"
echo "scene delegate:            $(count 'UIWindowSceneDelegate' "${SRC[@]}")"
echo "configurationForConnecting: $(count 'configurationForConnecting' "${SRC[@]}")"
echo "Info.plist with UISceneConfigurations: $(count 'UISceneConfigurations' -name 'Info.plist')"
echo "UIHostingController uses:  $(count 'UIHostingController' -name '*.swift')"
echo "Representable uses:        $(count 'UI(ViewController|View)Representable' -name '*.swift')"
echo "storyboards and xibs:      $(files -name '*.storyboard' -o -name '*.xib' | tr -cd '\0' | wc -c | tr -d ' ')"

echo "== Xcode on this Mac"
echo "default shell Xcode: $(xcodebuild -version 2>/dev/null | paste -sd' ' -)"
echo "Xcode 27.1:          $(DEVELOPER_DIR=$DEV xcodebuild -version 2>/dev/null | paste -sd' ' -)"
[ -f .xcode-version ] && echo ".xcode-version: $(cat .xcode-version)"
echo "== Xcode pinned by CI (nothing below = nothing found)"
grep -rnE 'xcode-version|DEVELOPER_DIR|xcode-select|xcodes |xcversion|Xcode[_-][0-9]' \
  .github .gitlab-ci.yml .circleci bitrise.yml codemagic.yaml fastlane ci_scripts Makefile 2>/dev/null | head -10

echo "== Build settings (Xcode 27.1)"
CONTAINER=()
case $CONTAINER_PATH in
  *.xcworkspace) CONTAINER=(-workspace "$CONTAINER_PATH") ;;
  *.xcodeproj) CONTAINER=(-project "$CONTAINER_PATH") ;;
esac
if [ ${#CONTAINER[@]} -eq 0 ]; then echo "skipped: no project"
elif [ -z "$SCHEME" ]; then
  echo "rerun with SCHEME=<name>. Schemes:"
  DEVELOPER_DIR=$DEV xcodebuild "${CONTAINER[@]}" -list 2>/dev/null | sed -n '/Schemes:/,$p' | tail -n +2
else
  DEVELOPER_DIR=$DEV xcodebuild "${CONTAINER[@]}" -scheme "$SCHEME" \
    -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null \
  | grep -E '^ *(SDK_VERSION|IPHONEOS_DEPLOYMENT_TARGET|SWIFT_VERSION|SWIFT_DEFAULT_ACTOR_ISOLATION|TARGETED_DEVICE_FAMILY|SUPPORTS_MACCATALYST|PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_KEY_UIRequiresFullScreen) = ' \
  | sort -u
fi
echo "== UIRequiresFullScreen in Info.plist files"
files -name 'Info.plist' | xargs -0 grep -l 'UIRequiresFullScreen' 2>/dev/null
exit 0
```

We ran it on 16 Oct 2026 against two scratch projects: a SwiftUI app (iOS 17.0 target, Swift 6, MainActor default isolation) and a UIKit app with an app delegate, no scene delegate, a storyboard, `UIRequiresFullScreen` and a CI file that pins Xcode 26.4. It reported both correctly. On 17 Oct 2026 we ran it again from the folder above each project: it still found the project and the stack. The CI and `.xcode-version` checks only read the folder you run it in, which is one more reason to start at the repo root. We also ran it on empty, Swift-only, Swift package, Flutter, CocoaPods (`ios/` with `Pods/`), nested-example and three-levels-deep layouts. It picks the shallowest container, and a workspace over a project at the same depth. So a CocoaPods workspace wins over its project, and an example app deeper down doesn't win over the main one.

## Read the output

### New or existing

| Output | Meaning |
|---|---|
| `EXISTING app: <path>` | Existing app. Use that container for every build. |
| `run the first pass from <folder>` | The project sits below the repo root. `cd` to that folder before the first pass, or pass the path with `-workspace` or `-project`. |
| `EXISTING code, no .xcodeproj or .xcworkspace` | A Swift package, or a project that XcodeGen or Tuist generates. Ask the user how they build the app. |
| `EXISTING code, no Xcode project within three levels` | Source files but no project nearby. Ask the user where it is. Don't treat it as new. |
| `treat as a NEW app` | No project and no source files. Go to the New app section of `SKILL.md`. |
| `EXISTING app`, but the source count is small and the views are template code | Treat it as new. Confirm with the user. |
| `project.yml` or `Project.swift` | The project is generated (XcodeGen or Tuist). Change settings in that file, not in the `.xcodeproj`. |
| `NOT NATIVE: pubspec.yaml`, `package.json` (React Native), `capacitor.config.*` | Not native, even though `ios/` holds an Xcode project. Point to [mirzaaghazadeh/iphone-duo-skills](https://github.com/mirzaaghazadeh/iphone-duo-skills). |
| `NOT NATIVE: ProjectSettings/ProjectVersion.txt` | A Unity project. Load `duo-games` (plugin `duology-features`) for the game rules (fill every pose, touch controls off the fold), and `duo-layout` for the native shell, if any. |

### SwiftUI, UIKit or mixed

| Output | Verdict |
|---|---|
| `SwiftUI App entry point` ≥ 1 | SwiftUI app life cycle. Scenes come for free. |
| ... and `Representable uses` > 0 | SwiftUI with UIKit parts. Check those parts with the UIKit notes in each skill. |
| `UIKit app delegate` ≥ 1 and `SwiftUI App entry point` = 0 | UIKit app. |
| ... and `UIHostingController uses` > 0 | UIKit shell with SwiftUI screens. |
| UIKit app, `scene delegate` = 0, `configurationForConnecting` = 0, no `UISceneConfigurations` | **No scene life cycle. Blocker.** |
| `storyboards and xibs` > 0 | Interface Builder layouts. Check their constraints for fixed widths and heights. |

**Why the scene check matters.** Apple's [scene life cycle article](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle) says an app built with the latest SDK must use scenes from iOS 27 on, or it fails to launch. The article names two signs that an app still needs to migrate: no `UIApplicationSceneManifest` with configurations in the Info.plist, and no `application(_:configurationForConnecting:options:)` in the app delegate. A generated Info.plist (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`) can hide the manifest from a grep, so also look for a class that adopts `UIWindowSceneDelegate`. Hand the migration to Apple's App Resizability skill, which converts apps to the scene life cycle ([WWDC26 session 278](https://developer.apple.com/videos/play/wwdc2026/278/)).

### The SDK the app ships with

The SDK on this Mac is not always the SDK the app ships with. Check in this order and stop at the first clear answer:

1. **CI pin.** The script greps `.xcode-version`, GitHub Actions, GitLab, CircleCI, Bitrise, Codemagic, fastlane and Xcode Cloud `ci_scripts`. Xcode Cloud picks its Xcode in the workflow settings, not in the repo, so ask the user if the app uses it.
2. **The last build.** Read the SDK baked into a built app or an archive:

   ```bash
   plutil -p <App>.app/Info.plist | grep -E 'DTSDKName|DTPlatformVersion|DTXcode|DTXcodeBuild|MinimumOSVersion'
   ```

   *Measured* on an app built with Xcode 27.1 for the simulator: `DTSDKName` = `iphonesimulator27.1`, `DTPlatformVersion` = `27.1`, `DTXcode` = `2710`, `DTXcodeBuild` = `27A9275`. A device build should say `iphoneos` instead of `iphonesimulator` (we didn't build for a device). In an archive, the app sits in `<Name>.xcarchive/Products/Applications/`.
3. **The default Xcode.** `default shell Xcode` is what a plain `xcodebuild` uses on this Mac. If it differs from the 27.1 line, the team may still ship with the older one. Ask.

Then map the SDK to what people see on iPhone Duo ([prepare page](https://developer.apple.com/iphone-duo/prepare/)):

| `SDK_VERSION` / `DTSDKName` | Behaviour on iPhone Duo | What to tell the user |
|---|---|---|
| 26.x or lower | Open: a familiar iPhone-sized window in the middle, empty space around it. Closed: content left of the status bar and camera. | The app runs but looks unoptimized. Building with Xcode 27.1 is the first win. |
| 27.0 | Open: fills most of the inner display but stays clear of the status bar on the right. | Better, not full. Move to Xcode 27.1. |
| 27.1 or later | Edge to edge on both displays; bars can lay out vertically. | Full experience. Apple asks you to check that content copes with vertical bars before you ship. |

Moving from 26 or 27.0 to 27.1 changes the layout with no code change. Toolbars and tab bars can turn vertical. That is why the first pass builds with 27.1 before anything else.

### Deployment target

| `IPHONEOS_DEPLOYMENT_TARGET` | What to do |
|---|---|
| 27.1 or later | Use Duo APIs directly. |
| Lower | Wrap iOS 27.1 APIs in `if #available(iOS 27.1, *)`. The fallback is today's layout; iPhone Duo always has iOS 27.1 or later. Some APIs Duology uses are iOS 27.0 (for example `defaultTabBarPlacement(_:)`); check each one in the [API index](https://github.com/Kimeur/duology/blob/main/reference/api-index.md). |
| Below 15.0 | From April 2027 the App Store wants iOS 15 or later ([Submitting](https://developer.apple.com/app-store/submitting/)). Flag it. |

### Other settings worth a line in the report

- `SUPPORTS_MACCATALYST = YES`: iOS 27.1-only APIs break the Catalyst build. Wrap them in `#if !targetEnvironment(macCatalyst)`. A target of iOS 27.1 also hides the Catalyst run destination until you add a Mac Catalyst 27.0 minimum deployment ([Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)).
- `TARGETED_DEVICE_FAMILY = 1` (iPhone only): the app still gets regular width and regular height on the inner display (*measured* with an iPhone-only test app, fully open). Code that treats regular width as iPad will run its iPad layout there ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).
- `SWIFT_VERSION` and `SWIFT_DEFAULT_ACTOR_ISOLATION`: copy snippets with care into Swift 6 targets that default to the main actor. The snippets in duo-start typecheck in Swift 5, Swift 6 and Swift 6 with MainActor default isolation.
- `UIRequiresFullScreen`: Tech Talk [111461](https://developer.apple.com/videos/play/tech-talks/111461/) says Duo still honours the key, but the app still resizes when the phone opens or closes. Apple deprecated it in iOS 26 ([TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)). Don't rely on it to avoid resizing work.
