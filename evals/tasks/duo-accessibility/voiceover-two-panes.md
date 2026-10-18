---
id: duo-accessibility/voiceover-two-panes
skill: duo-accessibility
also: duo-continuity
title: VoiceOver reads one pane at a time and keeps its place
readme: no
fixture: Inbox
project: Inbox.xcodeproj
scheme: Inbox
build: yes
lint: yes
checklist: R2
timeout: 1800
status: ready
---

# VoiceOver reads one pane at a time and keeps its place

VoiceOver reads top to bottom, then leading to trailing ([HIG, VoiceOver](https://developer.apple.com/design/human-interface-guidelines/voiceover#Navigation)). Two custom panes side by side on the open inner display are read row by row, mixing both, unless each pane is its own container ([`accessibilityElement(children: .contain)`](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain)). A fold rebuilds the layout, so VoiceOver can also lose its place. `duo-accessibility` measured both on the iPhone Duo simulator, and found that a focus move made at the moment the size class changes is lost, while one made after the new layout settles lands.

## Prompt

```text prompt
VoiceOver users report two problems with the inbox on iPhone Duo. On the open phone, VoiceOver reads the message list and the open message mixed together, line by line, instead of one pane and then the other. And when they close the phone while reading a message, VoiceOver jumps to the top of the screen and they lose their place. Fix both without changing how the screen looks. Keep the accessibility identifiers and the InboxUITests target.
```

## Starting point

Fixture [`Inbox`](../../fixtures/Inbox): open, a custom `HStack` with the message list and the message pane; closed, a `NavigationStack` that pushes the selected message. The selection survives a fold, so the message is still on screen after closing, but nothing tells VoiceOver where to go. iOS 17 target, Swift 5. duo-lint finds nothing.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check panes-are-containers
# Each pane is one VoiceOver container, or the layout is a NavigationSplitView,
# which already reads the sidebar, then the detail.
has_src 'accessibilityElement\(children: *\.contain\)|NavigationSplitView'
```

```sh check focus-is-moved
# Something puts VoiceOver focus back after the layout changes.
has_src 'AccessibilityFocusState|UIAccessibility\.post|AccessibilityNotification'
```

```sh check focus-waits-for-the-layout
# A focus move through @AccessibilityFocusState made at the moment the size class
# changes was lost in Duology's test; the same move made 0.3 s later landed. So an
# @AccessibilityFocusState fix needs a wait. A posted layout-changed or
# screen-changed notification is accepted on its own.
if [ -z "$(src_grep 'UIAccessibility\.post|AccessibilityNotification')" ]; then
  has_src 'Task\.sleep|asyncAfter'
fi
```

```sh check launches
launch_ok
```

## Checklist

The reviewer turns on VoiceOver in the simulator (Accessibility Inspector works too) and checks:

- **Reading order**: Open, held wide, swiping right from the first element reads the whole message list before the message pane (or the reverse), never one row of each.
- **R2**: Open, select a message and put VoiceOver on its subject; press Closed in Device Hub. VoiceOver lands on the message (its subject or body), not on Back or the top of the screen.
- The screen looks the same as before, closed and open. Turn VoiceOver off afterwards.
