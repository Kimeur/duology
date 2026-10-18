---
id: duo-scenes/open-in-new-window
skill: duo-scenes
also: duo-continuity
title: Open a note in a new window, safely
readme: no
fixture: Notes
project: Notes.xcodeproj
scheme: Notes
build: yes
lint: yes
checklist: R10 R11
timeout: 1800
status: ready
---

# Open a note in a new window, safely

iPhone Duo is the first iPhone that can show several windows of one app. Apple says only the inner display can create a new window and that requests on the outer display fail, so apps must handle the error; the window action in UIKit hides itself where a new window isn't possible ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=228)). An app also needs `UIApplicationSupportsMultipleScenes` in its scene manifest to get more than one window ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/uiapplicationscenemanifest/uiapplicationsupportsmultiplescenes)).

## Prompt

```text prompt
On iPhone Duo people want to open a note in its own window. Add an "Open in New Window" action to each note in the list. Opening a note in the current window must keep working, nothing may be lost when a new window can't open (for example on the closed phone), and every window must show the same, up-to-date notes.
```

## Starting point

Fixture [`Notes`](../../fixtures/Notes): a notes list that pushes an editor, with Duplicate and Delete in each row's context menu. iOS 26 target, Swift 6, main-actor isolation by default. One `NoteStore` is created in the `App` and passed down with `.environment`. duo-lint finds nothing.

- `Info.plist` sets `UIApplicationSupportsMultipleScenes` to `false`, and the target doesn't generate a scene manifest, so the app gets one window.
- There is only one `WindowGroup` and no way to open a window.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check multiple-scenes-not-off
# No plist in the project turns multiple scenes off.
for plist in $(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -name '*.plist' -print); do
  value="$(/usr/bin/plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw -o - "$plist" 2>/dev/null || true)"
  if [ "$value" = false ]; then
    echo "$plist still sets UIApplicationSupportsMultipleScenes to false"
    exit 1
  fi
done
```

```sh check multiple-scenes-on-in-the-app
# The built app's Info.plist turns multiple scenes on.
skip_if_light "reads the app built by the build gate"
app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'Notes.app' 2>/dev/null | awk 'NR == 1')"
[ -n "$app" ] || { echo "no built Notes.app under $DERIVED_DATA (did the build gate pass?)"; exit 1; }
value="$(/usr/bin/plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw -o - "$app/Info.plist" 2>/dev/null || true)"
[ "$value" = true ] || { echo "UIApplicationSupportsMultipleScenes in the built app is '$value', not true"; exit 1; }
```

```sh check opens-a-window
has_src 'WindowGroup\([^)]*for:|openWindow|UISceneSessionActivationRequest|activateSceneSession|ActivationAction'
```

```sh check opens-in-place-too
# The same note still opens inside the current window.
has_src 'NavigationLink|navigationDestination'
```

```sh check handles-no-window
# The action hides where windows aren't supported, or the request has a fallback.
has_src 'supportsMultipleWindows|supportsMultipleScenes|alternate:|errorHandler'
```

```sh check activation-action-has-alternate
# UIWindowScene.ActivationAction written as a bare trailing closure compiles with a
# warning and throws "Initializer is unavailable" at run time (measured by
# Duology). If the app uses it, each use names alternate: or returns its configuration.
if [ -n "$(src_grep 'ActivationAction\(')" ]; then
  if [ -n "$(src_grep 'ActivationAction\(' | grep -v 'alternate:')" ]; then
    has_src 'return +(UIWindowScene\.)?ActivationConfiguration|return +config'
  fi
fi
```

```sh check one-store-for-every-window
# One NoteStore for the whole app, so every window shows the same notes.
pycheck single_owner.py 'NoteStore\('
```

```sh check launches
launch_ok
```

## Checklist

- **R11**: Open (inner display): long-press a note, choose Open in New Window; the note opens in a window, and the first window is still reachable. Edit the note in one window and check the other shows the change. Closed: the action is hidden or opens the note in place; nothing is lost.
- **R10**: closed, every note opens and can be edited; nothing needs the open phone.
