---
id: duo-lint/lint-and-fix
skill: duo-lint
title: Find and fix code that breaks on two displays
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: yes
checklist: R3
timeout: 2400
status: ready
---

# Find and fix code that breaks on two displays

## Prompt

```text prompt
Find every line in this project that will break on iPhone Duo's two displays: sizing from the screen, device-type or orientation checks, hard-coded sizes and fixed widths, and old Info.plist settings. Fix them. If you leave a line because it isn't about layout, say why in a comment next to it. Keep every feature the app has today.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). duo-lint finds 10 problems in it: 3 errors and 7 warnings, covering DUO001, DUO002, DUO004, DUO005, DUO007, DUO008 (twice, Debug and Release) and DUO009. `Diagnostics.deviceSummary` reads `UIScreen.main.scale` for a bug-report string, which is not layout.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing, and every silenced line gives a reason after `--`.

```sh check full-screen-key-gone
if grep -nE 'UIRequiresFullScreen *= *(YES|1|true)' Places.xcodeproj/project.pbxproj; then
  echo "UIRequiresFullScreen is still set"
  exit 1
fi
```

```sh check features-kept
has_src 'deviceSummary'
has_src 'New place'
has_src 'Directions'
has_src 'LazyVGrid|Grid'
```

```sh check launches
xcb_test -only-testing:PlacesUITests
```

## Checklist

- **R3**: closed and open, the list, detail and gallery are sized from their containers.
