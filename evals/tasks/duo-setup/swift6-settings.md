---
id: duo-setup/swift6-settings
skill: duo-setup
title: Move a project to Swift 6 settings
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
timeout: 2400
status: ready
---

# Move a project to Swift 6 settings

## Prompt

```text prompt
Move this project to Swift 6 language mode, with main-actor isolation by default and approachable concurrency, for the app and its UI tests. Keep it building for the iPhone Duo simulator, with its UI tests, and keep the iOS 17 deployment target.
```

## Starting point

Fixture [`Places`](../../fixtures/Places): `SWIFT_VERSION = 5.0`, no default actor isolation, iOS 17.0 target, one UI test target.

## Pass checks

Gate: builds for the iPhone Duo simulator.

```sh check swift-6
build_setting_is SWIFT_VERSION 6.0
```

```sh check main-actor-default
build_setting_is SWIFT_DEFAULT_ACTOR_ISOLATION MainActor
```

```sh check approachable-concurrency
build_setting_is SWIFT_APPROACHABLE_CONCURRENCY YES
```

```sh check deployment-target-kept
build_setting_is IPHONEOS_DEPLOYMENT_TARGET 17.0
```

```sh check ui-tests-build
xcb_build_for_testing
```

```sh check ui-tests-swift-6
grep -qE 'SWIFT_VERSION = 6' Places.xcodeproj/project.pbxproj
[ "$(grep -cE 'SWIFT_VERSION = 5' Places.xcodeproj/project.pbxproj)" = 0 ] || { echo "a target is still on Swift 5"; exit 1; }
```
