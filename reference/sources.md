# Sources

Duology's rules and device facts come from the pages on this list. We link to these pages and explain them in our own words. We never copy their text.

- **Checked:** 16 October 2026. On that day every URL below returned HTTP 200, unless the row says otherwise.
- **IDs:** each source has an ID (A1, D2, V3...). [`device-facts.md`](device-facts.md) and the skills cite sources by ID.
- **API pages:** for every Duo API and its doc link, see [`api-index.md`](api-index.md).

> [!TIP]
> Apple's documentation pages need JavaScript. Agents can read the same content as JSON. Swap `https://developer.apple.com/documentation/<path>` for `https://developer.apple.com/tutorials/data/documentation/<path>.json`. HIG pages work the same way under `tutorials/data/design/human-interface-guidelines/<page>.json`.

## Apple: announcements, product pages and news

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="a1"></a>A1 | Apple unveils iPhone Duo (Newsroom, 9 Sep 2026) | https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/ | The announcement: display sizes, same aspect ratio, cameras, iOS 27 on Duo, Split View, StandBy, price, pre-order and release dates, ships with iOS 27.1, Apple Pencil later in 2026. | 16 Oct 2026 |
| <a id="a2"></a>A2 | iPhone Duo – Technical Specifications | https://www.apple.com/iphone-duo/specs/ | Size and weight open and closed, panel resolution and ppi for each display, ProMotion up to 120 Hz, the full camera list (rear, outer front, under-display inner front). | 16 Oct 2026 |
| <a id="a3"></a>A3 | Get ready for iPhone Duo (developer page) | https://developer.apple.com/iphone-duo/ | Apple's hub for developers: the six Tech Talks, Group Labs, workshops, forum Q&As, tools and App Store asset links. Still labels Xcode 27.1 "Release Candidate". | 16 Oct 2026 |
| <a id="a4"></a>A4 | Three steps to make your app shine on iPhone Duo | https://developer.apple.com/iphone-duo/prepare/ | What an app looks like with the iOS 26, 27 and 27.1 SDKs, the resizability skill, the code patterns to remove (main screen, orientation, idiom, fixed sizes), test tools, the App Store badge. | 16 Oct 2026 |
| <a id="a5"></a>A5 | Prepare and submit your apps for iPhone Duo (news, 5 Oct 2026) | https://developer.apple.com/news/?id=kkphp5qo | Rebuild with Xcode 27.1, Device Hub for poses, new screenshot and preview specs, the badge, Duo screenshots needed from April 2027. | 16 Oct 2026 |
| <a id="a6"></a>A6 | Build for iPhone Duo with new resources (news, 18 Sep 2026) | https://developer.apple.com/news/?id=nyuppv9r | Xcode 27.1 beta, Duo design kits in Apple Design Resources, workshops. | 16 Oct 2026 |
| <a id="a7"></a>A7 | Get ready with the latest beta releases (news, 16 Sep 2026) | https://developer.apple.com/news/?id=rfb1rooi | A note that iPhone Duo runs iOS 27.1 and that Xcode 27.1 brings Duo SDKs and a simulator with the new poses. | 16 Oct 2026 |
| <a id="a8"></a>A8 | Get ready for iPhone Duo (news, 9 Sep 2026) | https://developer.apple.com/news/?id=vn8abkxx | Launch of the developer videos, Group Labs and forum Q&As. | 16 Oct 2026 |
| <a id="a9"></a>A9 | App Store submissions now open for the latest OS releases (news, 9 Sep 2026) | https://developer.apple.com/news/?id=k1mtkt1k | From April 2027, uploads must be built with the iOS 27 SDK or later. | 16 Oct 2026 |
| <a id="a10"></a>A10 | Software Releases | https://developer.apple.com/news/releases/ | Build numbers and dates: Xcode 27 (27A266a, 14 Sep), Xcode 27.1 beta (27A9269, 18 Sep), Xcode 27.1 (27A9275, 15 Oct), iOS 27.2 beta 4 (24B5110a, 13 Oct). | 16 Oct 2026 |
| <a id="a11"></a>A11 | Xcode 27.1 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes | SDKs included, macOS requirement, the Previews Display group, iPhone Duo simulator known issues (StandBy, extensions, camera accessory). | 16 Oct 2026 |
| <a id="a12"></a>A12 | Xcode 27 Release Notes | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes | Device Hub changes and known issues (for example, no two-finger touch), Apple-built agent specialists. | 16 Oct 2026 |

## Apple: documentation and design guidance

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="d1"></a>D1 | Preparing your app for iPhone Duo | https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo | The developer hub: resizing, size classes, vertical bars, arrangement views, reserved regions (division and occlusion), camera handling. Shows six poses. | 16 Oct 2026 |
| <a id="d2"></a>D2 | Designing for iPhone Duo (Human Interface Guidelines) | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | Anatomy, device poses, best practices, dynamic layouts, reserved regions, split and arrangement views, vertical controls. New page on 9 Sep 2026. | 16 Oct 2026 |
| <a id="d3"></a>D3 | Device Hub | https://developer.apple.com/documentation/xcode/device-hub | What Device Hub is and the articles under it. | 16 Oct 2026 |
| <a id="d4"></a>D4 | Interacting with your app in Device Hub | https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub | The Closed, Partially Open and Open pose buttons, and Option-drag for any hinge angle. | 16 Oct 2026 |
| <a id="d5"></a>D5 | Capturing screenshots and videos from devices | https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices | Screenshots at full device resolution, saved to the Desktop; screen recording. | 16 Oct 2026 |
| <a id="d6"></a>D6 | Running your app on simulated or physical devices | https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices | Running on a simulator or a device. The hub links it as the first test step. | 16 Oct 2026 |
| <a id="d14"></a>D14 | Managing your simulated and physical devices in Device Hub | https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub | Adding simulators and pairing devices. | 16 Oct 2026 |
| <a id="d7"></a>D7 | Choosing a camera by the direction it faces | https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces | The virtual front camera, the two physical front cameras, the direction coordinator (AVKit). | 16 Oct 2026 |
| <a id="d8"></a>D8 | Registering a camera capture accessory on iPhone Duo | https://developer.apple.com/documentation/avfoundation/registering-a-camera-capture-accessory-on-iphone-duo | Showing content on the outer display while the camera UI runs on the inner display. | 16 Oct 2026 |
| <a id="d9"></a>D9 | Supporting device rotation in your camera app (sample code) | https://developer.apple.com/documentation/avfoundation/supporting-device-rotation-in-your-camera-app | The rotation coordinator, which the camera talk says to adopt on Duo. | 16 Oct 2026 |
| <a id="d10"></a>D10 | TN3210: Optimizing your app for iPhone Mirroring | https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring | Resizable iPhone apps. The hub says apps that already resize for iPhone Mirroring are well on the way to Duo. | 16 Oct 2026 |
| <a id="d11"></a>D11 | Giving external agents access to Xcode | https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode | Turning on external agents in Xcode's Intelligence settings and connecting them with `xcrun mcpbridge`. | 16 Oct 2026 |
| <a id="d12"></a>D12 | Adapting your app when traits change | https://developer.apple.com/documentation/uikit/adapting-your-app-when-traits-change | Trait tracking for size classes in UIKit. | 16 Oct 2026 |
| <a id="d13"></a>D13 | Apple Design Resources | https://developer.apple.com/design/resources/ | iOS and iPadOS 27 design kits and the iPhone Duo device bezels. | 16 Oct 2026 |

## Apple: videos

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="v1"></a>V1 | Prepare your app for iPhone Duo (Tech Talk 111461, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111461/ | Behaviour by SDK, size classes for each display, orientation, main screen, safe areas, reserved regions, the App Resizability skill. | 16 Oct 2026 |
| <a id="v2"></a>V2 | Raise the bar with iPhone Duo (Tech Talk 111462, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111462/ | Vertical toolbars and tab bars: when they go vertical, item order, symbols and titles, overflow. | 16 Oct 2026 |
| <a id="v3"></a>V3 | Strike a pose with adaptive layouts on iPhone Duo (Tech Talk 111463, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111463/ | Displacement patterns, reserved regions (division, occlusion), arrangement views. | 16 Oct 2026 |
| <a id="v4"></a>V4 | Leverage multiple displays and scenes on iPhone Duo (Tech Talk 111464, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111464/ | The hinge APIs, Split View, multiple windows (inner display only), scene accessories and the camera capture accessory. | 16 Oct 2026 |
| <a id="v5"></a>V5 | Build a great camera experience for iPhone Duo (Tech Talk 111465, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111465/ | The two front cameras, the virtual front camera and its limits, the direction coordinator, preview tips. | 16 Oct 2026 |
| <a id="v6"></a>V6 | Design for iPhone Duo (Tech Talk 111466, 9 Sep 2026) | https://developer.apple.com/videos/play/tech-talks/111466/ | Design principles, poses, Split View, Picture in Picture, controls on the side, sheets, fold avoidance. | 16 Oct 2026 |
| <a id="v7"></a>V7 | Modernize your UIKit app (WWDC26 session 278) | https://developer.apple.com/videos/play/wwdc2026/278/ | Flexible layout for resizable iPhone apps; the modernization skill that Xcode 27.1 renames App Resizability. | 16 Oct 2026 |
| <a id="v8"></a>V8 | Make your UIKit app more flexible (WWDC25 session 282) | https://developer.apple.com/videos/play/wwdc2025/282/ | Earlier flexible-layout guidance that the hub links to. | 16 Oct 2026 |
| <a id="v9"></a>V9 | What's new in SwiftUI (WWDC26 session 269) | https://developer.apple.com/videos/play/wwdc2026/269/ | iOS 27 SwiftUI changes. | 16 Oct 2026 |
| <a id="v10"></a>V10 | Migrate to Swift Testing (WWDC26 session 267) | https://developer.apple.com/videos/play/wwdc2026/267/ | Moving XCTest suites to Swift Testing. | 16 Oct 2026 |
| <a id="v11"></a>V11 | Support the Center Stage front camera in your iOS app (WWDC26 session 341) | https://developer.apple.com/videos/play/wwdc2026/341/ | The square front sensor; the camera talk points here. | 16 Oct 2026 |
| <a id="v12"></a>V12 | Get to know the new design system (WWDC25 session 356) | https://developer.apple.com/videos/play/wwdc2025/356/ | The 2025 visual design system and core components; the bars talk points here. | 16 Oct 2026 |
| <a id="v13"></a>V13 | iPhone Duo Group Lab, day 1 and day 2 (Meet with Apple 285, 286) | https://developer.apple.com/videos/play/meet-with-apple/285/ and https://developer.apple.com/videos/play/meet-with-apple/286/ | Recorded Q&A sessions. The pages resolve; we have not watched them yet. | 16 Oct 2026 |

## Apple: App Store

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="s1"></a>S1 | Screenshot specifications | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications | iPhone Duo sizes: 1398 × 2034 (outer) and 2007 × 2853 (inner). Screenshots required from April 2027 for apps using the iOS 27.1 SDK or later. The badge. | 16 Oct 2026 |
| <a id="s2"></a>S2 | App preview specifications | https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications | Duo preview resolutions. Its "19.5:9" label for Duo doesn't match its own pixel numbers. | 16 Oct 2026 |
| <a id="s3"></a>S3 | App Store asset best practices and resources | https://developer.apple.com/app-store/asset-best-practices/ | Templates and guidance for screenshots, previews and the new product page assets. | 16 Oct 2026 |
| <a id="s4"></a>S4 | Submitting | https://developer.apple.com/app-store/submitting/ | From April 2027: iOS 27 SDK or later and a deployment target of iOS 15 or later. | 16 Oct 2026 |

## Apple: forums (not opened)

Apple's iPhone Duo page links these Q&A threads. On 16 Oct 2026 each one sent us to a human-verification page, so we have not read them. Don't cite them until someone has.

| Title | URL |
|---|---|
| Photos & Camera Q&A | https://developer.apple.com/forums/activities/1659080 |
| SwiftUI Q&A | https://developer.apple.com/forums/activities/1664080 |
| UIKit Q&A | https://developer.apple.com/forums/activities/1670080 |
| Popular iPhone Duo questions (short link to a forum thread) | https://apple.co/iPhoneDuo-QA01 |

## Apple: tools we checked on this Mac

These are not web pages. They are local checks we ran with Xcode 27.1 (27A9275), using `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`.

| What | How we checked | Result |
|---|---|---|
| iOS 27.1 SDK interfaces | SwiftUI and SwiftUICore `.swiftinterface`, UIKit, AVFoundation and AVKit headers inside `iPhoneSimulator.sdk` | Every Swift and Objective-C API name in `device-facts.md` was found there. (`UIRequiresFullScreen` is an Info.plist key; its source is V1.) |
| iPhone Duo simulator | `xcrun simctl list devicetypes`, `xcrun simctl io booted enumerate`, the device profile in `/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype` | Two built-in displays, 1398 × 2034 and 2007 × 2853 px at scale 3; iOS 27.1 runtime or later |
| Probe app on the simulator | A small SwiftUI app (code in `device-facts.md`) | 951 × 669 pt, regular/regular, hinge fully open at 180° |
| Xcode's agent skills export | `xcrun agent skills export -h` | Takes `--output-dir <path>` and `--replace-existing` |

## Prior art outside Apple

These shaped Duology's design patterns. They describe other devices, so treat them as ideas to test, not as rules for iPhone Duo.

### Microsoft Surface Duo

Microsoft moved its dual-screen docs to "previous versions". The old `learn.microsoft.com/en-us/dual-screen/` URLs redirect there.

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="p1"></a>P1 | Introduction to dual-screen devices | https://learn.microsoft.com/en-us/previous-versions/dual-screen/introduction | Overview of dual-screen design on Surface Duo. | 16 Oct 2026 |
| P1a | Surface Duo device modes | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/postures | How Surface Duo names the ways it's held. | 16 Oct 2026 |
| P1b | Extended canvas pattern | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/extended-canvas | One canvas spread across both screens (maps, drawing). | 16 Oct 2026 |
| P1c | List-detail pattern | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/list-detail | List on one side, detail on the other. | 16 Oct 2026 |
| P1d | Two-page pattern | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/two-page | Book-like reading, one page per side. | 16 Oct 2026 |
| P1e | Dual view pattern | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/dual-view | Two versions of the same kind of content side by side, to compare them. | 16 Oct 2026 |
| P1f | Companion pane pattern | https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/companion-pane | Second-level surfaces shown beside the main content when the app spans both screens. | 16 Oct 2026 |

### Android (Google)

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="p2"></a>P2 | Canonical layouts | https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts | List-detail, supporting pane and feed. The old `guide/topics/large-screens/large-screen-canonical-layouts` URL redirects here. | 16 Oct 2026 |
| P2a | Learn about foldables | https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/learn-about-foldables | Android's tabletop and book postures, and the fold as a hinge feature. | 16 Oct 2026 |
| P2b | Make your app fold aware | https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware | Reading fold state and features to adapt layouts, including for tabletop and book postures. | 16 Oct 2026 |
| P2c | Support foldable display modes | https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/support-foldable-display-modes | Rear display mode and dual-screen mode on Android foldables. | 16 Oct 2026 |
| P2d | Use window size classes | https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes | Android's counterpart to size classes. | 16 Oct 2026 |
| P2e | Adaptive app quality guidelines | https://developer.android.com/docs/quality-guidelines/adaptive-app-quality | Three tiers: Tier 3 adaptive ready, Tier 2 adaptive optimized, Tier 1 adaptive differentiated. Tier 3 includes tests such as T-Config_State and T-Config_Combinations. The old `large-screen-app-quality` URL redirects here. | 16 Oct 2026 |

### Samsung

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="p3"></a>P3 | Flex mode | https://developer.samsung.com/galaxy-z/flex-mode.html | Galaxy Z behaviour when partly folded: content on the top half, controls on the bottom half, phone resting on a table. | 16 Oct 2026 |
| P3a | Galaxy Z developer overview | https://developer.samsung.com/galaxy-z/overview.html | Samsung's foldable developer hub. | 16 Oct 2026 |

## Community projects to credit

The README's acknowledgements credit the first four. expo/skills is a reference for plugin layout. We link to all of them and don't copy their text.

| Project | URL | License | What it is | Checked |
|---|---|---|---|---|
| mirzaaghazadeh/iphone-duo-skills | https://github.com/mirzaaghazadeh/iphone-duo-skills | MIT (LICENSE file; GitHub's API reports "NOASSERTION") | 11 iPhone Duo agent skills, including Flutter, React Native and Capacitor. Point cross-platform users here. | 16 Oct 2026 |
| AvdLee/SwiftUI-Agent-Skill | https://github.com/AvdLee/SwiftUI-Agent-Skill | MIT | SwiftUI best-practice skill in the Agent Skills format. | 16 Oct 2026 |
| twostraws/Swift-Agent-Skills | https://github.com/twostraws/Swift-Agent-Skills | MIT | Curated directory of Swift and Apple-platform agent skills. Submit Duology here to get listed. | 16 Oct 2026 |
| Dimillian/Skills | https://github.com/Dimillian/Skills | MIT | Reusable Codex skills, many for Apple platforms (debugging iOS apps, SwiftUI, App Store release notes). Last push March 2026. | 16 Oct 2026 |
| expo/skills | https://github.com/expo/skills | MIT | Expo's agent skills; a reference for plugin and skill layout. | 16 Oct 2026 |
| Xcode 27 agent skills (Apple) | Shipped with Xcode; see [A4] and [V1] | Apple software | Apple's own skills, including App Resizability. Export them with `xcrun agent skills export --output-dir <path>`. Link to them; never copy them into this repo. | 16 Oct 2026 |

## How to re-check

Run this before a release. It prints the status code for each Apple doc page as JSON, so a moved or deleted page shows up as a 404.

```bash
for p in technologyoverviews/preparing-your-app-for-iphone-duo \
         xcode/interacting-with-your-app-in-device-hub \
         avkit/choosing-a-camera-by-the-direction-it-faces \
         avfoundation/registering-a-camera-capture-accessory-on-iphone-duo \
         xcode-release-notes/xcode-27_1-release-notes; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' \
    "https://developer.apple.com/tutorials/data/documentation/$p.json")" "$p"
done
```

[A4]: #a4
[V1]: #v1
