# What we measured

Every *measured* claim in this skill comes from one probe app and its UI tests, run on the shared iPhone Duo simulator on 18 October 2026.

## Setup

- Xcode 27.1 (27A9275), iOS 27.1 simulator runtime (24A94425), the "iPhone Duo" device type, macOS 27.0.1.
- A SwiftUI probe app with one screen per question, picked by launch argument, and an XCUITest target. VoiceOver was driven with `XCUIDevice.shared.voiceOverService`; audits with `performAccessibilityAudit(for:_:)`.
- Closed means the outer display, portrait. Open means the inner display, fully open, held wide. The window was 466 × 678 pt closed (`app.windows.firstMatch.frame`).
- For the real fold, the test logged `READY` and the Closed button in Device Hub was then pressed through the macOS Accessibility API, as `duo-setup` describes.
- Not covered: real hardware, partial fold, Split View, unfold with VoiceOver, the inner display with a keyboard. In the afternoon run Device Hub had no open window, so no pose could be pressed.

## VoiceOver order

Two panes, each a heading and three lines ("Left 1" to "Left 3", "Right 1" to "Right 3"). VoiceOver output, one step per `|`:

| Layout | Display | Output |
|---|---|---|
| `HStack`, plain panes | closed | `Inbox, Heading \| Message, Heading \| Left 1 \| Right 1 \| Left 2 \| Right 2 \| Left 3 \| Right 3` |
| `HStack`, plain panes | open | `Port on left \| Message, Heading \| Left 1 \| Right 1 \| …` (`Inbox, Heading` was not spoken) |
| Right pane 20 pt lower | closed | same interleaving as plain |
| Both panes `.contain` with a label | closed and open | `Inbox, Heading \| Left 1 \| Left 2 \| Left 3 \| Message pane, Message, Heading \| Right 1 \| Right 2 \| Right 3` |
| Same, right pane priority 1 | closed | `Message, Heading \| Right 1 \| Right 2 \| Right 3 \| Inbox pane, Inbox, Heading \| Left 1 \| Left 2 \| Left 3` |
| `ArrangementView`, `.split.axes(.horizontal)` | closed | primary only: `Inbox, Heading \| Left 1 \| Left 2 \| Left 3` |
| `ArrangementView`, `.split.axes(.horizontal)` | open | same interleaving as plain |
| `NavigationSplitView`, `columnVisibility` `.all` | closed | sidebar only: `Inbox, Heading \| Left 1 \| Left 2 \| Left 3` |
| `NavigationSplitView`, `columnVisibility` `.all` | open | `Hide Sidebar, Button \| Sidebar, Left 1 \| Left 2 \| Left 3 \| Message, Heading \| Right 1 \| Right 2 \| Right 3` |

On the open split view, `app.staticTexts` listed `Inbox, Message, Right 1, Right 2, Right 3, Left 1, Left 2, Left 3`: a different order from VoiceOver.

## Focus after a fold

Open: a list ("Row 1" to "Row 4") and a message ("Back" button, "Lunch on Friday" heading, two body lines). Closed: the message only. VoiceOver was on "Row 2". Values read with `currentSpeech()` 4 s (real fold) or 2 s (forced) after the layout changed.

| Code in `onChange(of: horizontalSizeClass)` | Real fold (Device Hub, Closed) | Size class forced in the environment, no resize |
|---|---|---|
| Nothing | `Back, Button` | `Back, Button` |
| `AccessibilityNotification.LayoutChanged().post()` | not run | `Back, Button` |
| Set `AccessibilityFocusState` at once | `Back, Button` | `Lunch on Friday, Heading` |
| Set it after 0.3 s | `Lunch on Friday, Heading` | `Lunch on Friday, Heading` |

In the 0.3 s run, a `moveForward()` right after also returned the heading, so we read the result as "VoiceOver spoke the heading" and recommend checking with `moveForward()` and `moveBackward()` in your own test. In an earlier run of the forced case, all three rows gave the heading. We report the later run, and we trust only the real fold for advice.

## Dynamic Type

| Row | Size | Row frame (closed) | Audit (`.dynamicType`, `.textClipped`) |
|---|---|---|---|
| `AnyLayout` HStack, VStack at accessibility sizes | Large | 348 × 42 pt | none |
| same | AX5 (launch argument) | 297 × 370 pt | none |
| `lineLimit(1)`, `frame(height: 30)` | Large | n/a | 2 × "Text clipped" |
| same | AX5 | n/a | 2 × "Text clipped" |

- The launch argument `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` gave `dynamicTypeSize == .accessibility5`, `isAccessibilitySize == true`.
- With Increase Contrast on and an accessibility text size set on the simulator, the app read `colorSchemeContrast == .increased` and `dynamicTypeSize == .accessibility3`. With defaults: `.standard`, `.large`, Reduce Motion `false`, cross-fade `false`.

## Audits

Closed display, `performAccessibilityAudit(for: .all)`:

| Element | Issue |
|---|---|
| `Image(systemName: "trash")`, 20 × 20 pt, tap gesture | "Hit area is too small" (label "Trash" from the symbol) |
| Plain button, 16 × 16 pt star icon | "Hit area is too small" |
| `Color(white: 0.85)` text | "Contrast failed" |
| `.system(size: 13)` text | "Dynamic Type font sizes are unsupported" |
| Icon-only button, `.frame(minWidth: 44, minHeight: 44)` outside the label | "Hit area is too small" |
| `.secondary` text; a tinted button title | "Contrast nearly passed" |

## Modifiers and .position

Each case sat in its own `GeometryReader` band, 382 pt wide. Frames from XCUITest:

| Case | Frame |
|---|---|
| Circle 60 pt, accessibility element, then `.position` | 60 × 60 pt |
| Circle 60 pt, `.position`, then accessibility element | 60 × 60 pt |
| `Button`, `.position`, then label | 51 × 20 pt |
| Circle, `.position`, then `contentShape(Rectangle())`, tap, accessibility | 382 × 103 pt; a tap 5 % from the band's left edge counted |
| Circle, `contentShape(Circle())`, tap, accessibility, then `.position` | 60 × 60 pt |
| Circle with its element before `.position`, in a container with `contentShape(Rectangle())`, a tap and `.contain` | child 382 × 104 pt, the container's frame |

So `.position` alone did not break the element in our runs; `contentShape` and gestures after it did, and so did a content shape on the container. The rule "modifiers before `.position`" covers all of these.

## Keyboard (closed display, UI tests)

| Check | Morning run | Afternoon run |
|---|---|---|
| `UIFocusSystem.focusSystem(for:)` from a view in the window | nil | nil |
| Command-N before any tap | ignored | ran |
| Tab with nothing focused | nothing | focused the first text field |
| Tab again | nothing | focused the second text field |
| Space on a `focusable()` view with `onKeyPress(.space)` | never fired | never fired |
| Two Command-N presses after tapping a label | counted once | counted once |
| `typeText("hello")` into a tapped field | typed | typed |
| `typeKey("a")` into a focused field | typed nothing | not run |
| Tab inside a focused text field | stayed in the field | not run |

## Shared simulator notes

- Another session's UI tests and apps ran on the same simulator during the day. Our runs started only when no test runner was active.
- One of our test processes was stopped before its teardown, and VoiceOver stayed on. `xcrun devicectl device settings voiceover -d <UDID> --disable` turned it off; `devicectl device info voiceover` confirmed it.
- The probe app was uninstalled afterwards and the simulator left closed, with default text size, contrast and appearance.
