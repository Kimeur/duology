---
id: duo-intelligence/ai-pane-through-fold
skill: duo-intelligence
also: duo-continuity, duo-layout, duo-navigation
title: An on-device AI pane that survives a fold
readme: no
fixture: Notes
project: Notes.xcodeproj
scheme: Notes
build: yes
lint: yes
checklist: R2 R4 R10
timeout: 2400
status: ready
---

# An on-device AI pane that survives a fold

Foundation Models gives an app Apple's on-device language model through `LanguageModelSession` and `SystemLanguageModel` ([Foundation Models](https://developer.apple.com/documentation/foundationmodels)). On iPhone Duo the hard parts are where the answer goes and what happens when the phone folds while it is still being written. A fold resizes the window and can change its size class, so a request owned by a view below a layout switch starts again from nothing (`duo-continuity`). Apple's Duo guidance asks for the same features on both displays, with more detail on the open phone ([HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). The model can also be missing: the device may not support it, or Apple Intelligence may be off, so the app checks `availability` and keeps a non-AI path ([SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)).

## Prompt

```text prompt
Add an AI summary to this notes app, made with Apple's on-device language model. When the phone is open, show the summary of the open note in a panel beside the note while it is being written out. When the phone is closed, show a one-line summary above the note that opens the full summary. If the phone is folded or unfolded while the summary is still being written, it must carry on, not start again. Nothing may leave the phone, and the app must keep working on devices where the model isn't available.
```

## Starting point

Fixture [`Notes`](../../fixtures/Notes): a notes list that pushes an editor (`NavigationStack`), with Duplicate and Delete in each row's context menu. iOS 26 target, Swift 6, main-actor isolation by default. One `NoteStore` is created in the `App` and passed down with `.environment`. duo-lint finds nothing. Foundation Models is iOS 26.0, so the target needs no availability checks for `SystemLanguageModel` and `LanguageModelSession`.

The easy fix puts the request in the panel's view and swaps an `HStack` for a `VStack` by size class. Then the panel is built in two places, and every fold throws the half-written answer away.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check on-device-model
has_src '^ *import +FoundationModels'
has_src 'LanguageModelSession'
```

```sh check stays-on-device
# The prompt says nothing may leave the phone, so no Private Cloud Compute model.
no_src 'PrivateCloudComputeLanguageModel'
```

```sh check checks-availability
# The app asks whether the model can run before it relies on it.
has_src '\.availability|\.isAvailable'
```

```sh check request-outlives-the-fold
# The session is created in one place that a fold can't rebuild: a model kept in
# @State or a static. single_owner.py reads a `let session = ...` inside a view, even in
# its .task, as the view's own property and fails it: views are what a fold rebuilds.
pycheck single_owner.py 'LanguageModelSession\('
```

```sh check launches
launch_ok
```

## Checklist

duo-intelligence measured on 20 October 2026 that the simulator reports the on-device model as available while every request fails. So in the simulator the reviewer sees the app's fallback, not a streamed answer. Streaming through a fold needs a device.

- **R2**: open a note, ask for the summary, then press Closed, Open and Partially Open in Device Hub. The open note, the panel's state (or the fallback message) and the typed text stay; nothing starts over.
- **R4**: partly folded, no button of the panel (Stop, Retry, a disclosure) sits on the fold.
- **R10**: closed, the one-line summary is there and opens the full one; the feature isn't missing on the outer display.
