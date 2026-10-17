---
id: duo-start/first-pass
skill: duo-start
title: Size up an existing app before changing it
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: no
lint: no
timeout: 1500
status: ready
---

# Size up an existing app before changing it

## Prompt

```text prompt
I want this app to work well on the new iPhone Duo. Before you change anything, look at the project and tell me where it stands and what to fix first. Don't edit any files yet.
```

## Starting point

Fixture [`Places`](../../fixtures/Places): SwiftUI, iOS 17 target, Swift 5 mode. Its planted mistakes are listed in [fixtures/README.md](../../fixtures/README.md#places).

## Pass checks

No build or lint gate: the answer is a report. The checks read the agent's final message.

```sh check no-edits
unchanged
```

```sh check built-with-xcode-27-1
# A first pass builds the app with Xcode 27.1 for the iPhone Duo simulator.
ran_command 'xcodebuild'
final_has 'Xcode 27\.1|iOS 27\.1'
```

```sh check names-the-stack
final_has 'SwiftUI'
```

```sh check finds-main-screen
final_has 'UIScreen\.main'
```

```sh check finds-device-checks
final_has 'userInterfaceIdiom|idiom'
final_has 'iPad'
```

```sh check finds-fixed-width
final_has '390|fixed width|frame\(width'
```

```sh check finds-state-loss
final_has '(los[et]|reset|drop|throw[sn]? away|wipe)[^.]{0,120}(search|selection|scroll|state)|(search|selection|scroll|state)[^.]{0,120}(los[et]|reset|drop|thrown away|wipe)'
```
