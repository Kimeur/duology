---
id: duo-testing/ui-test-launch-args
skill: duo-testing
title: A UI test that jumps to a screen with a launch argument
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
timeout: 2400
status: ready
---

# A UI test that jumps to a screen with a launch argument

## Prompt

```text prompt
Add a UI test to PlacesUITests that launches the app straight into the detail screen for "Glass Lake" using a launch argument, and checks that the place's name and its summary, "Clear water and a flat loop trail.", are on screen. The argument must have no effect in normal launches. Run the UI tests on the iPhone Duo simulator and make sure they all pass.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `PlacesUITests` has one test that launches the app and looks for the "Places" title. The app reads no launch arguments.

## Pass checks

Gate: the app builds for the iPhone Duo simulator.

```sh check test-uses-launch-argument
grep -rqE 'launchArguments' PlacesUITests || { echo "no launchArguments in PlacesUITests"; exit 1; }
grep -rq 'Glass Lake' PlacesUITests || { echo "the test doesn't look for Glass Lake"; exit 1; }
```

```sh check app-reads-argument
grep -rqE 'ProcessInfo\.processInfo\.arguments|CommandLine\.arguments|UserDefaults\.standard|ProcessInfo\.processInfo\.environment' Places \
  || { echo "the app reads no launch argument"; exit 1; }
```

```sh check more-than-one-test
n="$(grep -rhoE 'func test[A-Za-z0-9_]*' PlacesUITests | sort -u | wc -l | tr -d ' ')"
[ "$n" -ge 2 ] || { echo "expected at least 2 UI tests, found $n"; exit 1; }
```

```sh check ui-tests-pass
xcb_test -only-testing:PlacesUITests
```
