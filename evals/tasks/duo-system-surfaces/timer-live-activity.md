---
id: duo-system-surfaces/timer-live-activity
skill: duo-system-surfaces
also: duo-continuity
title: A cooking timer Live Activity for the narrow Dynamic Island
readme: no
fixture: Steps
project: Steps.xcodeproj
scheme: Steps
build: yes
lint: no
timeout: 3000
status: ready
---

# A cooking timer Live Activity for the narrow Dynamic Island

On iPhone Duo the Dynamic Island sits in the side column of both displays and grows down it as Live Activities arrive ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=98)). The system draws compact and minimal Live Activity views narrower there, and iOS 27 tells the view with the `isDynamicIslandLimitedInWidth` environment value (WidgetKit, iOS 27.1 SDK; [doc](https://developer.apple.com/documentation/swiftui/environmentvalues/isdynamicislandlimitedinwidth)). The HIG asks a limited-width compact or minimal view to fit a 28 pt circle ([HIG: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)). A Live Activity needs a widget extension with an `ActivityConfiguration`, attributes the app and extension share, and `NSSupportsLiveActivities` in the app's Info.plist ([Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)).

## Prompt

```text prompt
Add a Live Activity for the cooking timer: while a step's timer runs, the time left shows on the Lock Screen and in the Dynamic Island, and the activity ends when the timer finishes or the cook leaves the step. It must look right on iPhone Duo, closed and open. Keep the cook screen's buttons and their accessibility identifiers.
```

## Starting point

Fixture [`Steps`](../../fixtures/Steps): a recipe step, a timer panel (`cook.timer`) and Previous and Next buttons (`cook.previous`, `cook.next`). Each step's countdown runs in a `CookTimer` owned by the timer panel. iOS 17 target, Swift 5, a generated Info.plist, one app target and no extension. `isDynamicIslandLimitedInWidth` is iOS 27.0, so the build gate also checks the availability gating in the extension.

The fixture's one duo-lint finding (`UIScreen.main` in the cook screen) belongs to `duo-postures/book-two-regions`, so this task turns the lint gate off.

## Pass checks

Gates: builds for the iPhone Duo simulator (the app scheme, with the extension it embeds).

```sh check widget-extension-target
# The project has a second target for the widget extension.
pbx="$(find . -name project.pbxproj -not -path './.git/*' 2>/dev/null | awk 'NR == 1')"
[ -n "$pbx" ] || { echo "no project.pbxproj"; exit 1; }
grep -q 'com.apple.product-type.app-extension' "$pbx" || { echo "no app extension target in $pbx"; exit 1; }
```

```sh check live-activity
has_src 'ActivityAttributes'
has_src 'ActivityConfiguration'
has_src 'DynamicIsland'
has_src 'Activity(<[^>]*>)?\.request\('
```

```sh check narrow-island
# The compact and minimal views adapt when iOS 27 draws them narrower, as it does on
# iPhone Duo.
has_src 'isDynamicIslandLimitedInWidth'
```

```sh check extension-embedded
# The built app carries the extension, and declares Live Activities.
skip_if_light "reads the app built by the build gate"
app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'Steps.app' 2>/dev/null | awk 'NR == 1' || true)"
[ -n "$app" ] || { echo "no built Steps.app under $DERIVED_DATA (did the build gate pass?)"; exit 1; }
appex="$(find "$app/PlugIns" -maxdepth 1 -name '*.appex' 2>/dev/null | awk 'NR == 1' || true)"
[ -n "$appex" ] || { echo "Steps.app has no extension in PlugIns/"; exit 1; }
value="$(/usr/bin/plutil -extract NSSupportsLiveActivities raw -o - "$app/Info.plist" 2>/dev/null || true)"
[ "$value" = true ] || { echo "NSSupportsLiveActivities in the built app is '$value', not true"; exit 1; }
```

```sh check controls-kept
for id in cook.timer cook.previous cook.next; do
  has_src "\"$id\""
done
```

```sh check launches
launch_ok
```

## Checklist

None. Xcode 27.1's release notes say most app extensions can't run in the iPhone Duo simulator, and duo-system-surfaces measured that the island's content never showed in a simulator screenshot. So how the activity looks in the side column needs a device. On a device, if there is one: start a timer, leave the app, and check the compact, minimal and expanded views closed and open, and the Lock Screen view.
