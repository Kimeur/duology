---
id: duo-app-intents/open-note-from-siri
skill: duo-app-intents
also: duo-scenes, duo-continuity, duo-navigation
title: Siri opens the right note in the right place
readme: no
fixture: Notes
project: Notes.xcodeproj
scheme: Notes
build: yes
lint: yes
checklist: R2 R10 R11
timeout: 2400
status: ready
---

# Siri opens the right note in the right place

App Intents describe an app's actions and content to Siri, Shortcuts and Spotlight ([App Intents](https://developer.apple.com/documentation/appintents)). On iPhone Duo an intent can arrive while the phone is closed in a pocket, while the list and a note are both on screen, or while two windows of the app share the inner display. Apple's routing guide sends an intent that opens content to a scene through `TargetContentProvidingIntent` and `onAppIntentExecution`, and lets a window say which content it prefers with `handlesExternalEvents` ([Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)). An intent that only answers can run without bringing the app forward ([Configuring the runtime behavior of your app intents](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents)).

## Prompt

```text prompt
Add Siri and Shortcuts actions to this notes app. One action opens a note the person picks: on the open phone the note must show beside the list, in the window that is already open, never in a new one, and on the closed phone it opens the note on the outer display. A second action reads out a note's text without opening the app, so it works while the phone is closed in a pocket. Keep everything that works today.
```

## Starting point

Fixture [`Notes`](../../fixtures/Notes): a notes list that pushes an editor (`NavigationStack`), with Duplicate and Delete in each row's context menu. iOS 26 target, Swift 6, main-actor isolation by default. One `NoteStore` is created in the `App` and passed down with `.environment`. `Info.plist` turns multiple scenes off. duo-lint finds nothing.

There are no intents, no entity for a note, and nothing shows the list beside a note.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check note-entity
# Siri and Shortcuts can name a note: an entity and a query that finds it.
has_src 'AppEntity'
has_src 'EntityQuery|EntityStringQuery|EntityPropertyQuery|EnumerableEntityQuery|UniqueAppEntityQuery'
```

```sh check note-is-a-parameter
# Each action takes the note it acts on, instead of reading whatever is selected:
# open, two notes can be on screen at once.
has_src '@Parameter'
```

```sh check opens-the-chosen-note
# The opening action reaches the app: an OpenIntent or a target-content intent that a
# scene handles, or an intent that opens the app and hands the note to its model.
has_src 'OpenIntent|TargetContentProvidingIntent|onAppIntentExecution|openAppWhenRun|supportedModes'
```

```sh check answers-without-opening
# The second action answers in words or with a value, so it needs no screen.
has_src 'ProvidesDialog|ReturnsValue|IntentDialog|\.result\((value|dialog):'
```

```sh check no-new-window
# Opening a note never asks for another window.
no_src 'openWindow|requestSceneSessionActivation|activateSceneSession|UISceneSessionActivationRequest'
```

```sh check list-beside-note
# On the open phone the note shows beside the list.
has_src 'NavigationSplitView|UISplitViewController|ArrangementView|UIArrangementViewController'
```

```sh check launches
launch_ok
```

## Checklist

Siri can't be tested in the simulator, and the iOS 27.1 simulator runtime has no Shortcuts app (its `Applications` folder holds only `ShortcutsUI.app`, checked 20 October 2026). Run each action from a UI test with AppIntentsTesting, which duo-app-intents measured working on the Duo simulator, once closed and once open.

- **R2**: open a note through the action, then press Closed and Open in Device Hub. The same note stays open, and the list keeps its scroll position.
- **R10**: closed, the opening action shows the note on the outer display, and the answering action reads the text without bringing the app forward.
- **R11**: open, the opening action shows the note beside the list in the existing window; no second window appears.
