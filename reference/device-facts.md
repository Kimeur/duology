# iPhone Duo device facts

What an agent needs to know about the hardware before it writes layout code. Every line names its source. Tags in brackets link to [`sources.md`](sources.md), where each source has its full title, URL and check date.

- **Checked:** 16 October 2026, against Xcode 27.1 (27A9275) and the iPhone Duo simulator on iOS 27.1.
- **Labels:** *measured* means we ran code on the iPhone Duo simulator. *Derived* means arithmetic on Apple's numbers. *Unverified* means we could not confirm it. Everything else comes straight from an Apple page.
- **Secondary sources:** none needed. The pixel counts first reported by press sites are now on Apple's own specs page [[A2]].

> [!WARNING]
> Never hard-code any number on this page into an app. Apple tells you to size from the view, window or scene, and to pick layouts by size class [[D1]][[A4]]. These numbers are here so you can reason about layouts and check screenshots, not so you can branch on them.

## Displays

| | Outer display | Inner display | Source |
|---|---|---|---|
| Diagonal (marketing) | 5.4 in | 7.6 in | [[A1]][[A2]] |
| Diagonal (as a plain rectangle) | 5.36 in | 7.58 in | [[A1]][[A2]] |
| Panel resolution | 1398 × 2034 px at 460 ppi | 1878 × 2670 px at 430 ppi | [[A2]] |
| App Store screenshot size | 1398 × 2034 px (or 2034 × 1398) | 2007 × 2853 px (or 2853 × 2007) | [[S1]] |
| Simulator framebuffer | 1398 × 2034 px, scale 3 | 2007 × 2853 px, scale 3 | *measured*: `xcrun simctl io booted enumerate` and the simulator's device profile |
| Window size in points | 466 × 678 pt in portrait (*derived*: 1398 × 2034 px ÷ 3; not yet measured in a window) | 951 × 669 pt, fully open, held wide (*measured*: probe app, scale 3.0, hinge `fullyOpen` at 180°) | see [How we measured](#how-we-measured) |
| Size classes | Portrait: compact width, regular height. Landscape: compact width, compact height. | Regular width, regular height. *Measured* fully open and held wide. | [[V1]] |
| Supported orientations | Honoured, like any iPhone | Not honoured; the app is scaled to fit, Split View included | [[V1]] |
| Toolbars and tab bars | Vertical, on the side, in both orientations | Vertical on the side in landscape; horizontal in portrait | [[D2]][[V2]][[V6]] |
| Front camera | In a corner, in line with the side bars; always visible and always an occlusion | Under the display, hidden until active; an occlusion only while active | [[D1]][[D2]][[V3]] |
| Fold | None | A division region, active only when partially folded; zero width when flat | [[D1]][[V3]] |

Both displays:

- Same aspect ratio, per Apple. Apple gives no number [[A1]].
- *Derived:* the panel pixel counts give about 1.45 (outer) and 1.42 (inner), long side over short side. Close, not equal. Don't publish a ratio such as "4:3" and don't scale one layout by a fixed factor [[A2]].
- ProMotion with adaptive refresh up to 120 Hz, Always-On, Dynamic Island on each display [[A2]]. Apple's press release says ProMotion but gives no rate [[A1]].
- *Measured:* the simulator reports `maximumFramesPerSecond` = 60. Test 120 Hz behaviour on a real device.
- The outer display is wider and shorter than other iPhone displays. That is why bars move to the side [[D2]][[V6]].
- Bars stay on the same hardware edge in right-to-left languages. In Split View, each app puts its bars on its outer edge, so the left app has bars on the left [[D2]].

Physical size [[A2]]:

| | Width | Height | Depth | Weight |
|---|---|---|---|---|
| Open | 164.6 mm | 117.8 mm | 5.2 mm | 254 g |
| Closed | 84.1 mm | 117.8 mm | 11.3 mm | 254 g |

### Two inner-display resolutions

Apple publishes two pixel sizes for the inner display:

- The specs page says 1878 × 2670 [[A2]].
- The App Store screenshot spec and the simulator use 2007 × 2853 [[S1]].
- The app preview spec calls 2853 × 2007 the "device resolution" and labels both Duo sizes 19.5:9. Neither number is 19.5:9, so treat that label as an error on Apple's page [[S2]].

*Derived:* the two sizes share one aspect ratio, and 2007 × 2853 at 430 ppi would make an 8.1 in diagonal, not 7.58 in. *Unverified inference:* iOS renders the inner display at 2007 × 2853 (3x) and the panel shows a scaled copy. In practice:

- submit inner-display screenshots at 2007 × 2853;
- simulator screenshots already come out at that size;
- quote 1878 × 2670 only when you talk about the physical panel.

## Poses

### Names that exist in the SDK and tools

Only these are real identifiers. Use them in code and tests.

| Name | Where | Source |
|---|---|---|
| `closed`, `partiallyOpen`, `fullyOpen` | SwiftUI `DeviceHinge.Status`, read with `onHingeChange(isEnabled:_:)` | iOS 27.1 SDK (SwiftUICore interface); [[V4]] |
| `unknown`, `closed`, `partiallyOpen`, `fullyOpen` | UIKit `UIHinge.Status`, read with `UIHingeInteraction` | iOS 27.1 SDK (`UIHinge.h`); [[V4]] |
| Closed, Partially Open, Open | The three pose buttons under the bezel in Device Hub | [[D4]] |
| `division`, `occlusion` | Kinds of `ReservedRegion` (SwiftUI) and `UIView.ReservedRegion` (UIKit): `division` is the fold, `occlusion` is a camera | iOS 27.1 SDK; [[D1]][[V3]] |

The hinge also reports an angle: `Angle` in SwiftUI, radians in UIKit (iOS 27.1 SDK). Apple presents the hinge as a source of effects and interactions. Layout comes from size classes, reserved regions and arrangement views [[V4]][[D1]].

### Phrases Apple uses only to describe

Apple describes ways to hold the phone with everyday comparisons. None of them is an API, an enum case or a Device Hub control.

| Phrase | Where Apple uses it |
|---|---|
| "partially folded, like a book" | [[D2]][[V3]][[V6]] |
| "folded like a tent", "set the phone down like a tent" | [[D1]] (image description), [[V1]], [[A4]] (image description) |
| "seated on a table like a laptop", "folded like a laptop" | [[V6]], [[D1]] (image description) |
| "propped on a surface / on a table", "placed down on a surface" | [[D2]][[V3]][[A1]] |
| "standing on its edges" | [[D2]][[V6]] |
| "open in a wide layout", "open in a tall layout" | [[D1]] (image description) |
| "open, turned around", "flip the device" (rear camera faces you) | [[D7]][[V5]] |

The HIG calls these "device poses" and shows six of them [[D2]]. The hub shows six as well: closed, tent, open wide, partially folded, open tall, laptop [[D1]].

### Words Apple does not use

Apple's iPhone Duo pages and talks never say "tabletop", "posture", "book posture", "tent mode" or "flex mode". We searched the Newsroom release, the specs and marketing pages, the developer iPhone Duo pages, the hub, the HIG page, the Device Hub and camera articles, the release notes and all six Tech Talk transcripts. Those words come from Android, Samsung and Microsoft [[P2]][[P3]][[P1]]. If Duology uses "book" or "tabletop" as shorthand, say once that these are Duology's words for Apple's descriptions.

### What Apple says to do about poses

- Don't design one layout per pose. Design a compact-width layout for the outer display and a regular-width layout for the inner display, and let the layout grow [[D2]][[V6]].
- One optional special case: the phone sitting on a table. Media can go in the top half, controls in the bottom half. Keep the same controls and hierarchy as in the other poses [[V6]][[V3]].
- Partially folded, system alerts, sheets, menus and toolbar buttons move off the fold on their own. Scrolling content does not need to avoid the fold [[V6]][[D2]].
- Partially folded and held like a book, alerts move to the trailing side, near where they appear once the phone closes [[V3]].

## Cameras that apps can use

| Camera | Hardware | What apps get | Source |
|---|---|---|---|
| Rear | 48MP Fusion Main (26 mm, f/1.6, with a 12MP optical-quality 2x at 52 mm). 48MP Fusion Ultra Wide (13 mm, f/2.2, 120°). | `position` is `.back`, as on any iPhone. Open and turned around, a rear camera faces the user. | [[A2]][[V5]][[D7]] |
| Outer front | 12MP Center Stage camera, f/2.2, square sensor | `builtInOuterUltraWideCamera`. Specs list 4K up to 60 fps and 1080p slo-mo at 120 fps. The talk says "up to 4K and 120 fps". | [[A2]][[V5]], iOS 27.1 SDK (`AVCaptureDevice.h`) |
| Inner front | Under-display FaceTime camera, f/1.8, square sensor | `builtInInnerUltraWideCamera`. 1080p at 30 or 60 fps. | [[A2]][[V5]], iOS 27.1 SDK |
| Virtual front camera | Not a separate camera | Asking for `.front` with `builtInWideAngleCamera` or `builtInUltraWideCamera` returns it. It switches between the two front cameras as the phone opens and closes. Limits: features both share, max 1080p at 60 fps, no depth. `isVirtualDevice` is `true`; `activePrimaryConstituent` tells you which camera streams. | [[D7]][[V5]] |

- Both front cameras report `position == .front`. That says where a camera sits, not which way it faces. Use `AVCaptureDeviceDirectionCoordinator` to learn which way it faces. It lives in **AVKit**, not AVFoundation [[D7]], iOS 27.1 SDK (`AVKit/AVCaptureDeviceDirectionCoordinator.h`).
- Fully open with the rear camera running, an app can show extra content on the outer display through a camera capture accessory (`CameraCaptureAccessory` in SwiftUI). The system decides when to show it. It needs the app full screen on the inner display with an active capture session [[D1]][[D8]][[V4]].
- *Simulator caveat:* in the Duo simulator, an app using `CameraCaptureAccessory` can use both displays with no capture session running [[A11]].

## Release dates and versions

| Event | Date | Source |
|---|---|---|
| iPhone Duo announced | 9 Sep 2026 | [[A1]] |
| HIG page "Designing for iPhone Duo" published | 9 Sep 2026 | [[D2]] (change log) |
| Six iPhone Duo Tech Talks published | 9 Sep 2026 | [[V1]]–[[V6]] |
| Xcode 27 (27A266a) | 14 Sep 2026 | [[A10]] |
| Xcode 27.1 beta (27A9269), the first Xcode with Duo support | 18 Sep 2026 | [[A10]][[A6]][[A7]] |
| "Prepare and submit your apps for iPhone Duo" news; Duo screenshots accepted | 5 Oct 2026 | [[A5]] |
| iOS 27.2 beta 4 (24B5110a) | 13 Oct 2026 | [[A10]] |
| Xcode 27.1 (27A9275), final | 15 Oct 2026 | [[A10]][[A11]] |
| Pre-orders, 5 a.m. PT, more than 70 countries and regions | Fri 16 Oct 2026 | [[A1]] |
| In stores | Fri 23 Oct 2026 | [[A1]][[A5]] |
| 28 more countries and regions | Fri 30 Oct 2026 | [[A1]] |
| Apple Pencil (USB-C) support | "later this year" (2026) | [[A1]][[A2]] |
| App Store: uploads must use the iOS 27 SDK or later | April 2027 | [[A9]][[S4]] |
| App Store: iPhone Duo screenshots required | April 2027 | [[A5]][[S1]] |

- iPhone Duo ships with iOS 27.1 [[A1]][[A7]].
- US price starts at $1,999, in 256GB, 512GB, 1TB and 2TB [[A1]].
- Xcode 27.1 contains the iOS 27.1 SDK and needs macOS Tahoe 26.6 or later [[A11]].
- As of 16 Oct, Apple's Releases page has no separate iOS 27.1 entry [[A10]].
- Apple's iPhone Duo developer page still labels Xcode 27.1 "Release Candidate", although the final build shipped on 15 Oct [[A3]][[A10]].

## Which SDK gives which behaviour

| Built with | Open (inner display) | Closed (outer display) | Source |
|---|---|---|---|
| iOS 26 SDK or earlier (Xcode 26) | Runs at a familiar iPhone size, centred, with empty space around it | Content sits to the left of the status bar and camera | [[A4]][[V1]][[D1]] |
| iOS 27 SDK (Xcode 27.0) | Resizes to fill most of the display, but still stays clear of the status bar on the right edge | Apple doesn't say | [[A4]][[V1]] |
| iOS 27.1 SDK or later (Xcode 27.1) | Edge to edge. Toolbars and tab bars go vertical under the status bar where the pose calls for it. | Edge to edge, bars vertical | [[A4]][[V1]] |

- Before you ship a 27.1 build, check that your content copes with vertical bars [[A4]].
- `UIRequiresFullScreen` is still honoured, but the app still resizes when the phone opens or closes [[V1]].
- All apps take part in Split View on the inner display. Two apps share it 50/50 [[V4]][[V6]].
- Only the inner display can open a new window. Requests on the outer display fail, so handle the error [[V4]].
- From April 2027, uploads must be built with the iOS 27 SDK or later and target iOS 15 or later [[A9]][[S4]]. *Derived from the table above:* that floor gives you the iOS 27 behaviour, not the full 27.1 layout.

## App Store screenshots

- Duo sizes: 1398 × 2034 (outer) and 2007 × 2853 (inner), portrait or landscape [[S1]].
- Submitting Duo screenshots adds a badge to the product page saying the app is optimized for iPhone Duo [[A5]][[S1]][[A4]].
- Apple states the April 2027 rule two ways:
  - the 5 Oct news says *every* app or game submitted from April 2027 needs iPhone Duo screenshots [[A5]];
  - the screenshot spec page says the rule covers apps *using the iOS 27.1 SDK or later* [[S1]].
- *Unverified:* which wording App Store Connect will enforce. Plan for the stricter one.
- Device Hub screenshots come out at the device's full resolution and land on the Mac's Desktop [[D5]].

## The iPhone Duo simulator (Xcode 27.1)

- Device type "iPhone Duo" (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`). It needs the iOS 27.1 runtime or later. *Measured:* `xcrun simctl list devicetypes` and the device profile under `/Library/Developer/CoreSimulator/Profiles/DeviceTypes/`.
- Xcode 27.1 adds Duo development support and a simulator that covers the new poses and orientations [[A7]][[A5]].
- Pick it as the run destination in Xcode. Your app opens in Device Hub [[V1]][[D3]].
- Poses: three buttons under the bezel (Closed, Partially Open, Open), next to the rotate buttons. Hold Option and drag the slider below the bezel to set any angle [[D4]].
- Split View test: on the inner display, drag the app by its home indicator to one side, then to the other [[V1]].
- *Measured:* `simctl` in Xcode 27.1 has no command to change the pose. Poses change only in Device Hub. Plan scripted pose checks around that.
- *Measured:* `xcrun simctl io booted screenshot --display=primary` saves the outer display (2034 × 1398 here). `--display=primary-1` saves the inner display (2853 × 2007 here). Orientation follows the current device orientation.
- Previews: the canvas overrides picker has a Display group for previewing on the device's other display [[A11]].
- Known issues in 27.1 [[A11]]:
  - the first launch can take several minutes;
  - StandBy is unavailable;
  - most app extensions can't run or be debugged;
  - camera capture accessories show without a capture session.
- Device Hub can't send two-finger touches (Xcode 27 known issue). Test pinch and rotate gestures on hardware [[A12]].
- Apple also suggests testing resizing in the resizable iOS simulator in Device Hub and in iPhone Mirroring on macOS 27. It calls the Duo simulator the best way to test the full native experience [[A4]].

## How we measured

We built a tiny SwiftUI app and ran it on the booted iPhone Duo simulator (iOS 27.1). It was fully open, held wide. The core of it is below; it typechecks against the iOS 27.1 SDK. To fill the gaps listed under [Not yet verified](#not-yet-verified), run it, switch poses in Device Hub, and read the console.

```swift
import SwiftUI

struct SizeProbe: View {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.verticalSizeClass) private var height
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { proxy in
            let line = "\(Int(proxy.size.width))x\(Int(proxy.size.height)) pt, "
                + "w=\(String(describing: width)) h=\(String(describing: height)) @\(scale)x"
            Text(line)
                .onAppear { print("SIZE", line) }
                .onChange(of: line) { _, new in print("SIZE", new) }
        }
        .ignoresSafeArea()
        .onHingeChange { _, context in
            if let hinge = context.hinge {
                print("HINGE", hinge.status, Int(hinge.angle.degrees))
            }
        }
    }
}
```

Result, fully open and held wide: 951 × 669 pt, regular width, regular height, scale 3.0, hinge `fullyOpen` at 180°. The window scene's screen reported native bounds of 2007 × 2853 px.

## Not yet verified

- Window size in points when closed. 466 × 678 pt is derived, not measured.
- Window sizes partially open, in the tall layout, and in Split View.
- How wide the fold's division region is at different angles.
- Size classes partially open and in Split View. Apple says the inner display is regular/regular. We measured it only fully open.
- Real-device behaviour: 120 Hz during the open and close animation, how the hinge feels, and how the front cameras hand over.
- Whether the inner panel really shows a scaled 2007 × 2853 render (see [Two inner-display resolutions](#two-inner-display-resolutions)).

[A1]: sources.md#a1
[A2]: sources.md#a2
[A3]: sources.md#a3
[A4]: sources.md#a4
[A5]: sources.md#a5
[A6]: sources.md#a6
[A7]: sources.md#a7
[A9]: sources.md#a9
[A10]: sources.md#a10
[A11]: sources.md#a11
[A12]: sources.md#a12
[D1]: sources.md#d1
[D2]: sources.md#d2
[D3]: sources.md#d3
[D4]: sources.md#d4
[D5]: sources.md#d5
[D7]: sources.md#d7
[D8]: sources.md#d8
[S1]: sources.md#s1
[S2]: sources.md#s2
[S4]: sources.md#s4
[V1]: sources.md#v1
[V2]: sources.md#v2
[V3]: sources.md#v3
[V4]: sources.md#v4
[V5]: sources.md#v5
[V6]: sources.md#v6
[P1]: sources.md#p1
[P2]: sources.md#p2
[P3]: sources.md#p3
