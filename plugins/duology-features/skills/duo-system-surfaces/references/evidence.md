# Evidence: what we ran for duo-system-surfaces

What we could check on 20 October 2026 with Xcode 27.1 (27A9275) and the shared iPhone Duo simulator (iOS 27.1), and what we could not. Nothing here ran on a real iPhone Duo.

## The simulator's limits

Apple's Xcode 27.1 release notes list, among the iPhone Duo simulator's known issues, that StandBy is unavailable and that running and debugging most app extensions is unavailable ([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)). Widgets, Live Activity views and controls all run in an app extension. So we measured what the system around them does, not the views themselves.

## The probe

A SwiftUI app with a widget extension. The extension holds a `StaticConfiguration` widget that supports every system and accessory family, and an `ActivityConfiguration` whose compact leading view reads `isDynamicIslandLimitedInWidth`. The app starts and ends the activity with `Activity.request(attributes:content:pushType:)` and `end(_:dismissalPolicy:)`. Poses were set with `duo-pose` from `duo-pose-matrix`; screenshots came from `xcrun simctl io <device> screenshot`, `--display=primary` for the outer display and `--display=primary-1` for the inner.

## Starting a Live Activity

- `ActivityAuthorizationInfo().areActivitiesEnabled` was `true` on the closed phone.
- `Activity.request` returned an activity whose `activityState` was `.active`.

## The island in the side column

We measured where the status bar's clock sat, as the top of its text in points from the top of the screenshot (pixels ÷ 3), with Settings in front, before and after the probe started one activity.

| Display | No activity | One activity | Room the island took |
|---|---|---|---|
| Outer, closed | 87 pt | 171 pt | about 84 pt |
| Inner, open, held wide | 34 pt | 128 pt | about 94 pt |

- The island's own content (the compact or minimal views) never appeared in any screenshot. The space above the clock stayed empty. We read this as the extension not running in the simulator, which matches the release notes, but that is our reading.
- With the probe app itself in front and its activity running, the clock stayed at 87 pt, closed: the app's own activity took no room while the app was in front.
- Open with no activity, the clock sat near the very top (34 pt). The inner front camera is under the display, so nothing above the clock claims room until an activity does.

## Home Screen

- Closed, the outer Home Screen showed the Dock (one app) and a round search button in the side column, under the status bar, and page dots for two pages at the bottom.
- In edit mode, Done and Edit buttons sat in the side column. Edit opened a menu with Add Widget, Customize, Edit Wallpaper and Edit Pages.
- Add Widget opened the widget gallery as a sheet on the outer display, with a search field. The gallery listed the probe app among the apps that offer widgets, and a search for its name found it.

We tried to open the probe's page in the gallery to see which families it offers on each display. The UI test reached the gallery in one of six runs. In the others the long press didn't enter edit mode, the menu closed before the tap, or another tool on the shared simulator had brought its own app to the front. We stopped there, so which families the gallery offers on each display, the new tall family included, is *unverified*.

## Code checks

Every Swift snippet in this skill typechecks with Xcode 27.1 at an iOS 27.1 target in Swift 6 with MainActor default isolation, at an iOS 27.1 target in Swift 5, and at an older target (iOS 17.0 for the Live Activity views and previews; iOS 18.0 for the widgets, the control and the app's router, which uses the iOS 18 `Tab` API). One finding from that check: in a MainActor-default target, a control's shared state needs `nonisolated` (or its own isolation), or Swift 6 reports "main actor-isolated static property 'isRunning' can not be mutated from a nonisolated context" in the intent's `perform()`.

## What we could not check

- The vertical island's compact, minimal and expanded views, and several activities at once.
- `isDynamicIslandLimitedInWidth` at run time on Duo. Apple's doc says it is `true` there.
- Widget sizes on either display, and which families each Home Screen and Today View offer.
- StandBy on either display.
- Controls in Control Center and on the Lock Screen.
- How a running activity changes the room in another app's vertical bar. Our probe could not run its own bars next to an activity, because its own activity hides while it is in front.
