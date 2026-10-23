# Sources

Duology's rules and device facts come from the pages on this list. We link to these pages and explain them in our own words. We never copy their text.

- **Checked:** 16 October 2026, 19 October 2026 for the rows added with v0.2, 20 October 2026 for the rows added with v0.3, and 23 October 2026 for M1, whose URL changed. On those days every URL below returned HTTP 200, unless the row says otherwise. Apple documentation and HIG pages were checked through their documentation JSON.
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
| <a id="a13"></a>A13 | Apple Pencil | https://www.apple.com/apple-pencil/ | The model comparison. Apple Pencil (USB-C) has tilt and hover, and no pressure sensitivity, double tap, squeeze or barrel roll. Used by `duo-reading`. | 20 Oct 2026 |

## Apple: documentation and design guidance

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="d1"></a>D1 | Preparing your app for iPhone Duo | https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo | The developer hub: resizing, size classes, vertical bars, arrangement views, reserved regions (division and occlusion), camera handling. Shows six poses. | 16 Oct 2026 |
| <a id="d2"></a>D2 | Designing for iPhone Duo (Human Interface Guidelines) | https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo | Anatomy, device poses, best practices, dynamic layouts, reserved regions, split and arrangement views, vertical controls. New page on 9 Sep 2026. | 16 Oct 2026 |
| <a id="d3"></a>D3 | Device Hub | https://developer.apple.com/documentation/xcode/device-hub | What Device Hub is and the articles under it. | 16 Oct 2026 |
| <a id="d4"></a>D4 | Interacting with your app in Device Hub | https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub | The Closed, Partially Open and Open pose buttons, Option-drag for any hinge angle, and Device > Slow Animations (used by `duo-transitions`). | 16 Oct 2026 |
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
| <a id="d15"></a>D15 | HIG: Materials | https://developer.apple.com/design/human-interface-guidelines/materials | Liquid Glass: for the controls layer, used sparingly; regular and clear variants; dimming behind clear glass over bright media. Used by `duo-design-system`. | 19 Oct 2026 |
| <a id="d16"></a>D16 | HIG: Color | https://developer.apple.com/design/human-interface-guidelines/color | Light, dark and increased-contrast variants; system colours instead of hard-coded values; tinting Liquid Glass for the primary action. | 19 Oct 2026 |
| <a id="d17"></a>D17 | HIG: Typography | https://developer.apple.com/design/human-interface-guidelines/typography | Default and minimum text sizes, Dynamic Type sizes, fewer columns and stacked layouts at large sizes, custom fonts. | 19 Oct 2026 |
| <a id="d18"></a>D18 | HIG: Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | Contrast ratios, text that grows to at least twice its size, control sizes and padding (Mobility), Reduce Motion guidance (Cognitive), Voice Control labels. | 19 Oct 2026 |
| <a id="d19"></a>D19 | HIG: Buttons | https://developer.apple.com/design/human-interface-guidelines/buttons | A hit region of at least 44 x 44 pt on iOS; one or two prominent buttons per view. | 19 Oct 2026 |
| <a id="d20"></a>D20 | HIG: Dark Mode | https://developer.apple.com/design/human-interface-guidelines/dark-mode | Contrast for custom colours; testing with Increase Contrast and Reduce Transparency; no app-only appearance switch. | 19 Oct 2026 |
| <a id="d21"></a>D21 | HIG: Layout | https://developer.apple.com/design/human-interface-guidelines/layout | Controls versus content, and layouts that adapt to the space they get. | 19 Oct 2026 |
| <a id="d22"></a>D22 | HIG: Designing for iOS | https://developer.apple.com/design/human-interface-guidelines/designing-for-ios | People hold an iPhone in one or both hands; controls in the middle or lower part of the screen are easier to reach. Used by `duo-ergonomics`. | 19 Oct 2026 |
| <a id="d23"></a>D23 | HIG: Right to left | https://developer.apple.com/design/human-interface-guidelines/right-to-left | Which controls flip in right-to-left languages (progress, back and next) and which keep a real direction. | 19 Oct 2026 |
| <a id="d24"></a>D24 | HIG: Motion | https://developer.apple.com/design/human-interface-guidelines/motion | Motion that supports the task, stays brief and isn't added to actions people repeat often. Used by `duo-transitions` and `duo-postures`. | 19 Oct 2026 |
| <a id="d25"></a>D25 | HIG: VoiceOver | https://developer.apple.com/design/human-interface-guidelines/voiceover | Reading order, grouping, telling VoiceOver when the layout changes, rotors. | 19 Oct 2026 |
| <a id="d26"></a>D26 | HIG: Focus and selection | https://developer.apple.com/design/human-interface-guidelines/focus-and-selection | Don't move focus on people, except to a nearby item when the focused one disappears. | 19 Oct 2026 |
| <a id="d27"></a>D27 | HIG: Keyboards | https://developer.apple.com/design/human-interface-guidelines/keyboards | Full Keyboard Access, standard shortcuts and custom shortcuts. | 19 Oct 2026 |
| <a id="d28"></a>D28 | Applying Liquid Glass to custom views (SwiftUI) | https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views | `glassEffect(_:in:)`, `GlassEffectContainer` and how glass shapes merge. | 19 Oct 2026 |
| <a id="d29"></a>D29 | Applying custom fonts to text (SwiftUI) | https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text | Custom fonts that still scale with Dynamic Type (`relativeTo:`). | 19 Oct 2026 |
| <a id="d30"></a>D30 | Managing your app's life cycle (UIKit) | https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle | Scene states, and that UIKit can disconnect background scenes to reclaim resources. Used by `duo-scenes`. | 19 Oct 2026 |
| <a id="d31"></a>D31 | Optimizing iPhone and iPad apps to support ProMotion displays | https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays | Refresh rates on iPhone, `CADisableMinimumFrameDurationOnPhone`, `targetTimestamp`, lower rates in Low Power Mode and when hot. | 19 Oct 2026 |
| <a id="d32"></a>D32 | Understanding hitches in your app | https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app | The frame budget at 120 Hz and how Xcode reports hitches. | 19 Oct 2026 |
| <a id="d33"></a>D33 | Accessibility Inspector | https://developer.apple.com/documentation/accessibility/accessibility-inspector | The Mac tool for checking a running app's accessibility, including on a simulator. | 19 Oct 2026 |
| <a id="d34"></a>D34 | Inspecting the accessibility of the screens in your app | https://developer.apple.com/documentation/accessibility/inspecting-the-accessibility-of-screens | Targeting a simulator in Accessibility Inspector and playing back the navigation order. | 19 Oct 2026 |
| <a id="d35"></a>D35 | Performing accessibility audits for your app | https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app | Audit types, the audit report, and audits inside UI tests. | 19 Oct 2026 |
| <a id="d36"></a>D36 | Testing system accessibility features in your app | https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app | Turning on Reduce Motion, Increase Contrast, Full Keyboard Access and Bold Text from Accessibility Inspector. | 19 Oct 2026 |
| <a id="d37"></a>D37 | Switch Control | https://developer.apple.com/documentation/accessibility/switch-control | How Switch Control moves through an app and what it needs from it. | 19 Oct 2026 |
| <a id="d38"></a>D38 | Foundation Models (framework) | https://developer.apple.com/documentation/foundationmodels | The on-device model, sessions, guided generation and tools; from iOS 27, Private Cloud Compute and image input. Used by `duo-intelligence`. | 20 Oct 2026 |
| <a id="d39"></a>D39 | Generating content and performing tasks with Foundation Models | https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models | Prompting the on-device model, and checking that it is available first. | 20 Oct 2026 |
| <a id="d40"></a>D40 | Generating Swift data structures with guided generation | https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation | `@Generable` and `@Guide`: asking for typed output instead of text. | 20 Oct 2026 |
| <a id="d41"></a>D41 | Expanding generation with tool calling | https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling | Tools the model can call to reach the app's own data. | 20 Oct 2026 |
| <a id="d42"></a>D42 | Improving the safety of generative model output | https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output | Guardrails and handling sensitive input. | 20 Oct 2026 |
| <a id="d43"></a>D43 | Managing the context window | https://developer.apple.com/documentation/foundationmodels/managing-the-context-window | Token budgets, the context size and counting tokens. | 20 Oct 2026 |
| <a id="d44"></a>D44 | Analyzing images with multimodal prompting | https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting | Image attachments in a prompt (iOS 27). | 20 Oct 2026 |
| <a id="d45"></a>D45 | Adding server-side intelligence with Private Cloud Compute | https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute | The Private Cloud Compute model, its entitlement, the daily quota, and the scheme option that simulates availability and quota. Its option labels differ from WWDC26 session 319; `duo-intelligence` quotes this guide. | 20 Oct 2026 |
| <a id="d46"></a>D46 | Private Cloud Compute entitlement | https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.private-cloud-compute | The Boolean entitlement an app needs to use Private Cloud Compute. | 20 Oct 2026 |
| <a id="d47"></a>D47 | Private Cloud Compute (developer page) | https://developer.apple.com/private-cloud-compute/ | Apple's overview of Private Cloud Compute for developers. | 20 Oct 2026 |
| <a id="d48"></a>D48 | HIG: Generative AI | https://developer.apple.com/design/human-interface-guidelines/generative-ai | Designing features that use generative models. | 20 Oct 2026 |
| <a id="d49"></a>D49 | App Intents (framework) | https://developer.apple.com/documentation/appintents | Intents, entities and queries for Siri, Shortcuts, Spotlight and widgets. Used by `duo-app-intents`. | 20 Oct 2026 |
| <a id="d50"></a>D50 | Directing app intents to your app's scenes | https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes | Routing an intent to a SwiftUI or UIKit scene with `TargetContentProvidingIntent`, `onAppIntentExecution(_:perform:)` and `UISceneAppIntent`. | 20 Oct 2026 |
| <a id="d51"></a>D51 | Configuring the runtime behavior of your app intents | https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents | Running an intent in the foreground, in the background or in an extension (`supportedModes`, `allowedExecutionTargets`). | 20 Oct 2026 |
| <a id="d52"></a>D52 | Providing contextual cues to Apple Intelligence and Siri | https://developer.apple.com/documentation/appintents/providing-contextual-cues-to-apple-intelligence-and-siri | Annotating views with app entities so Siri knows what is on screen. | 20 Oct 2026 |
| <a id="d53"></a>D53 | Testing your App Intents code | https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code | AppIntentsTesting: running intents and reading view annotations from tests (iOS 27). | 20 Oct 2026 |
| <a id="d54"></a>D54 | HIG: App Shortcuts | https://developer.apple.com/design/human-interface-guidelines/app-shortcuts | Phrases, titles and symbols for App Shortcuts. | 20 Oct 2026 |
| <a id="d55"></a>D55 | Updating views automatically with observation tracking in UIKit | https://developer.apple.com/documentation/uikit/updating-views-automatically-with-observation-tracking-in-uikit | `updateProperties()` and observation tracking in UIKit. | 20 Oct 2026 |
| <a id="d56"></a>D56 | TN3211: Resolving SwiftUI source incompatibilities for State and ContentBuilder | https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder | The `@State` macro and `ContentBuilder` changes in Xcode 27, and the build errors they cause. Used by `duo-swiftui-27`. | 20 Oct 2026 |
| <a id="d57"></a>D57 | Displaying live data with Live Activities | https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities | Starting, updating and ending a Live Activity, and its Dynamic Island and Lock Screen views. Used by `duo-system-surfaces`. | 20 Oct 2026 |
| <a id="d58"></a>D58 | HIG: Live Activities | https://developer.apple.com/design/human-interface-guidelines/live-activities | Live Activity layouts. Guidance for limited-width layouts was added on 13 Oct 2026. | 20 Oct 2026 |
| <a id="d59"></a>D59 | HIG: Widgets | https://developer.apple.com/design/human-interface-guidelines/widgets | Widget sizes, content and backgrounds. | 20 Oct 2026 |
| <a id="d60"></a>D60 | HIG: Controls | https://developer.apple.com/design/human-interface-guidelines/controls | Controls in Control Center, on the Lock Screen and on the Action button. | 20 Oct 2026 |
| <a id="d61"></a>D61 | WidgetKit updates and ActivityKit updates | https://developer.apple.com/documentation/updates/widgetkit and https://developer.apple.com/documentation/updates/activitykit | Apple's change logs. Their latest entries are from June 2025: nothing for iOS 27 or iPhone Duo yet. | 20 Oct 2026 |
| <a id="d62"></a>D62 | HIG: Designing for games | https://developer.apple.com/design/human-interface-guidelines/designing-for-games | Minimum text and button sizes, and alternatives to game controllers. Used by `duo-games`. | 20 Oct 2026 |
| <a id="d63"></a>D63 | HIG: Game controls | https://developer.apple.com/design/human-interface-guidelines/game-controls | Touch controls and physical controllers. | 20 Oct 2026 |
| <a id="d64"></a>D64 | HIG: Playing haptics | https://developer.apple.com/design/human-interface-guidelines/playing-haptics | When haptics help and when they get in the way. | 20 Oct 2026 |
| <a id="d65"></a>D65 | Touch Controller (framework) | https://developer.apple.com/documentation/touchcontroller | On-screen touch controls for Metal games (iOS 26). | 20 Oct 2026 |
| <a id="d66"></a>D66 | Configuring your app for media playback | https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback | The `.playback` audio category, and the background mode that also enables AirPlay and Picture in Picture. Used by `duo-media` and `recipe-media-player`. | 20 Oct 2026 |
| <a id="d67"></a>D67 | Adopting Picture in Picture in a standard player | https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player | Picture in Picture with `AVPlayerViewController`. | 20 Oct 2026 |
| <a id="d68"></a>D68 | Adopting Picture in Picture in a custom player | https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player | Picture in Picture with `AVPictureInPictureController` and your own controls. | 20 Oct 2026 |
| <a id="d69"></a>D69 | Accessing the camera while multitasking on iPad | https://developer.apple.com/documentation/avkit/accessing-the-camera-while-multitasking-on-ipad | Using the camera in Split View and the other multitasking modes. `duo-camera` applies it to iPhone Duo. | 20 Oct 2026 |
| <a id="d70"></a>D70 | Handling audio interruptions | https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions | Observing audio session notifications so playback reacts to interruptions. | 20 Oct 2026 |
| <a id="d71"></a>D71 | Responding to audio route changes | https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes | Reacting when headphones or other outputs come and go. | 20 Oct 2026 |
| <a id="d72"></a>D72 | HIG: Playing video | https://developer.apple.com/design/human-interface-guidelines/playing-video | Video playback, full screen and Picture in Picture. | 20 Oct 2026 |
| <a id="d73"></a>D73 | HIG: Playing audio | https://developer.apple.com/design/human-interface-guidelines/playing-audio | Audio that adapts when the context changes, and Now Playing. | 20 Oct 2026 |
| <a id="d74"></a>D74 | Setting up StoreKit Testing in Xcode | https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode | A local StoreKit configuration file and the scheme option that uses it. Used by `recipe-shop`. | 20 Oct 2026 |
| <a id="d75"></a>D75 | Testing in-app purchases with StoreKit transaction manager in Xcode | https://developer.apple.com/documentation/xcode/testing-in-app-purchases-with-storekit-transaction-manager-in-code | The transaction manager (Debug > StoreKit > Manage Transactions). | 20 Oct 2026 |
| <a id="d76"></a>D76 | StoreKit (framework) | https://developer.apple.com/documentation/storekit | Products, purchases, transactions and subscriptions (StoreKit 2). | 20 Oct 2026 |
| <a id="d77"></a>D77 | Swift Charts (framework) | https://developer.apple.com/documentation/charts | Marks, scales, axes and legends. Used by `recipe-finance-dashboard`. | 20 Oct 2026 |
| <a id="d78"></a>D78 | Transitioning to the UIKit scene-based life cycle | https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle | From iOS 27, UIKit apps built with the latest SDK fail to launch without scenes; the signs, the manifest, moving the window and the life-cycle methods. Used by `duo-migrate`. | 23 Oct 2026 |
| <a id="d79"></a>D79 | TN3192: Migrating your app from the deprecated UIRequiresFullScreen key | https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key | The key is deprecated in iOS 26; how to make the app resize instead. Used by `duo-migrate`. | 23 Oct 2026 |
| <a id="d80"></a>D80 | Uploading assets to App Store Connect | https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect | Reserve, upload and commit an asset such as a screenshot. Used by `duo-app-store`. | 23 Oct 2026 |
| <a id="d81"></a>D81 | ScreenshotDisplayType (App Store Connect API) | https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype | The display types for screenshot sets. On 23 Oct 2026 it listed 33 values and none for iPhone Duo; the API itself accepted `APP_IPHONE_DUO`. | 23 Oct 2026 |
| <a id="d82"></a>D82 | Privacy manifest files | https://developer.apple.com/documentation/bundleresources/privacy-manifest-files | What an app or SDK declares in `PrivacyInfo.xcprivacy`. Used by `duo-app-store`. | 23 Oct 2026 |
| <a id="d83"></a>D83 | App Review | https://developer.apple.com/distribute/app-review/ | Submitting for review and what to tell App Review. Used by `duo-app-store`. | 23 Oct 2026 |

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
| <a id="v14"></a>V14 | Meet Liquid Glass (WWDC25 session 219) | https://developer.apple.com/videos/play/wwdc2025/219/ | What Liquid Glass is and where it belongs in an interface. | 19 Oct 2026 |
| <a id="v15"></a>V15 | Build a SwiftUI app with the new design (WWDC25 session 323) | https://developer.apple.com/videos/play/wwdc2025/323/ | Adopting the iOS 26 design in SwiftUI: glass effects, toolbars, scroll edge effects. | 19 Oct 2026 |
| <a id="v16"></a>V16 | Explore SwiftUI animation (WWDC23 session 10156) | https://developer.apple.com/videos/play/wwdc2023/10156/ | How SwiftUI animates changes, transactions and animatable values. | 19 Oct 2026 |
| <a id="v17"></a>V17 | Animate with springs (WWDC23 session 10158) | https://developer.apple.com/videos/play/wwdc2023/10158/ | Springs keep their velocity when a new change retargets them. | 19 Oct 2026 |
| <a id="v18"></a>V18 | Demystify SwiftUI (WWDC21 session 10022) | https://developer.apple.com/videos/play/wwdc2021/10022/ | View identity and lifetime: why a changed identity resets state. | 19 Oct 2026 |
| <a id="v19"></a>V19 | Optimize for variable refresh rate displays (WWDC21 session 10147) | https://developer.apple.com/videos/play/wwdc2021/10147/ | ProMotion frame pacing and choosing a frame rate range. | 19 Oct 2026 |
| <a id="v20"></a>V20 | What's new in the Foundation Models framework (WWDC26 session 241) | https://developer.apple.com/videos/play/wwdc2026/241/ | Third-party models, Keychain and OAuth tokens, and what an image costs in tokens. | 20 Oct 2026 |
| <a id="v21"></a>V21 | Build with the new Apple Foundation Model on Private Cloud Compute (WWDC26 session 319) | https://developer.apple.com/videos/play/wwdc2026/319/ | Privacy, no token cost to the developer, a daily limit per person (higher with iCloud+), and apps with fewer than 2 million downloads. | 20 Oct 2026 |
| <a id="v22"></a>V22 | Validate your App Intents adoption with AppIntentsTesting (WWDC26 session 295) | https://developer.apple.com/videos/play/wwdc2026/295/ | Testing intents, entities and view annotations. | 20 Oct 2026 |
| <a id="v23"></a>V23 | Explore advanced App Intents features for Siri and Apple Intelligence (WWDC26 session 343) | https://developer.apple.com/videos/play/wwdc2026/343/ | Full and supporting dialog, indexed entities, onscreen awareness, and annotating collections versus rows. | 20 Oct 2026 |
| <a id="v24"></a>V24 | Discover new capabilities in the App Intents framework (WWDC26 session 345) | https://developer.apple.com/videos/play/wwdc2026/345/ | Long-running intents shown as a Live Activity with a stop button, and cancellable intents. | 20 Oct 2026 |
| <a id="v25"></a>V25 | Code-along: Build powerful drag and drop in SwiftUI (WWDC26 session 271) | https://developer.apple.com/videos/play/wwdc2026/271/ | Reordering with `reorderable()` and `reorderContainer`. Used by `duo-swiftui-27`. | 20 Oct 2026 |
| <a id="v26"></a>V26 | Live Activities essentials (WWDC26 session 223) | https://developer.apple.com/videos/play/wwdc2026/223/ | Building and updating Live Activities. | 20 Oct 2026 |
| <a id="v27"></a>V27 | WidgetKit foundations (WWDC26 session 277) | https://developer.apple.com/videos/play/wwdc2026/277/ | Widget families, timelines and backgrounds. | 20 Oct 2026 |

## Apple: App Store

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="s1"></a>S1 | Screenshot specifications | https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications | iPhone Duo sizes: 1398 × 2034 (outer) and 2007 × 2853 (inner). Screenshots required from April 2027 for apps using the iOS 27.1 SDK or later. The badge. | 16 Oct 2026 |
| <a id="s2"></a>S2 | App preview specifications | https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications | Duo preview resolutions. Its "19.5:9" label for Duo doesn't match its own pixel numbers. | 16 Oct 2026 |
| <a id="s3"></a>S3 | App Store asset best practices and resources | https://developer.apple.com/app-store/asset-best-practices/ | Templates and guidance for screenshots, previews and the new product page assets. | 16 Oct 2026 |
| <a id="s4"></a>S4 | Submitting | https://developer.apple.com/app-store/submitting/ | From April 2027: iOS 27 SDK or later and a deployment target of iOS 15 or later. | 16 Oct 2026 |
| <a id="s5"></a>S5 | App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ | In-app purchase (3.1.1), what to tell people before they subscribe (3.1.2(c)) and goods or services used outside the app (3.1.3(e)). Used by `recipe-shop`. | 20 Oct 2026 |

## Apple: support pages

From GitHub's runners, support.apple.com sometimes answers HTTP 404 with an empty body for a page that exists. `scripts/check-sources.py` reports that answer as blocked, not broken.

| ID | Title | URL | What it covers | Checked |
|---|---|---|---|---|
| <a id="m1"></a>M1 | Allow accessibility apps to access your Mac (Mac User Guide) | https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac | Where the user grants Accessibility permission: System Settings > Privacy & Security > Accessibility. `duo-pose-matrix` needs it to press Device Hub's pose buttons; only the user can grant it. | 23 Oct 2026 |

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
| Device Hub's pose buttons | The macOS Accessibility API from a small tool (`duo-pose-matrix`), with the user's Accessibility permission; notes in `duo-pose-matrix` references/how-it-works.md | `Closed`, `Partially Open`, `Open` and `Rotate Right` can be pressed; `simctl` and `devicectl` have no pose command |
| Probe apps for the v0.2 skills | Small SwiftUI and UIKit apps on the shared iPhone Duo simulator, 17 to 19 Oct 2026; the code and logs are in each skill's evidence or measurement file (for example `duo-scenes` references/evidence.md, `duo-postures` references/measurements.md) | Window sizes per pose, scene and focus behaviour through fold and unfold. Each skill marks what it measured and what is still unverified |
| iOS 27.1 SDK, v0.3 frameworks | The `.swiftinterface` files and headers of FoundationModels, AppIntents, WidgetKit, ActivityKit, StoreKit, StoreKitTest, Charts, AVFoundation, AVKit, AVFAudio, MediaPlayer, SpriteKit, MetalKit, GameController, TouchController, PDFKit and PencilKit, plus AppIntentsTesting in the iPhone Simulator platform | Every name in `api-index.md`'s v0.3 sections was found there and typechecks at an iOS 27.1 target |
| Xcode 27.1 build settings | `CoreBuildSystem.xcspec` inside Xcode 27.1 | `INFOPLIST_KEY_NSSupportsLiveActivities` exists; there is no `INFOPLIST_KEY_UIBackgroundModes`, so background audio needs an Info.plist file |
| iOS 27.1 simulator runtime | Its `Applications` folder, read by `duo-app-intents` on 20 Oct 2026 | `ShortcutsUI.app` is there, but no Shortcuts app, so Shortcuts runs can't be tested in the simulator |
| Probe apps for the v0.3 skills and recipes | Small apps and the recipe templates on the shared iPhone Duo simulator, 20 Oct 2026; logs in each skill's evidence, measurements or testing file | Behaviour through fold and unfold for each feature. Each skill marks what it measured and what needs a device |

## Tools outside Apple

| Title | URL | What it covers | Checked |
|---|---|---|---|
| FFmpeg filters documentation | https://ffmpeg.org/ffmpeg-filters.html | The `gradients` source and `drawtext` filter behind `recipe-media-player`'s sample clips, and the `testsrc` source behind the `Reel` eval fixture. Both are made on the Mac; nothing is downloaded. | 20 Oct 2026 |

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
