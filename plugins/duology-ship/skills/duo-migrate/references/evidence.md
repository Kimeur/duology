# Evidence

What we ran for `duo-migrate`, on 23 October 2026, with Xcode 27.1 (27A9275) and the iPhone Duo simulator on iOS 27.1. No real iPhone Duo.

## A UIKit app without scenes, built with the iOS 27.1 SDK

Two minimal UIKit apps, compiled with `swiftc` for `arm64-apple-ios27.1-simulator`, wrapped in an app bundle by hand, signed ad hoc, installed on the iPhone Duo simulator and launched with `xcrun simctl launch`:

| App | What it had | Result |
|---|---|---|
| No scenes | `@main` app delegate; the window made in `didFinishLaunchingWithOptions` with `UIWindow(frame: UIScreen.main.bounds)`; no `UIApplicationSceneManifest`; no `configurationForConnecting` | Launched, then gone within 5 s. A crash report: `EXC_BREAKPOINT` (`SIGTRAP`) on the main thread, 3.8 s after launch. The top frame is in UIKitCore, `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption_block_invoke`, called from `-[UIApplication workspace:didCreateScene:withTransitionContext:completion:]`. |
| Scenes | A `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes` and no configurations; `configurationForConnecting` returning a configuration with `delegateClass = SceneDelegate.self`; the window made in `scene(_:willConnectTo:options:)` with `UIWindow(windowScene:)` | Launched and still running 5 s later. |

This matches Apple's rule that, from iOS 27, an app built with the latest SDK fails to launch without the scene life cycle ([Apple's guide](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)). Both apps were uninstalled afterwards.

The eval fixture `Tally` (a UIKit expense app with an iOS 16.0 target and no scenes, in `evals/fixtures/`) did the same: it built with Xcode 27.1 and crashed at each of three launches, from `simctl launch`, a launch check and a UI test, with the same UIKit frame. With a scene delegate connected through `configurationForConnecting`, it launched.

Not measured: the variant that names the delegate only in the manifest, with no `configurationForConnecting`; storyboard-based apps; a real device.

## Compiler warnings depend on the deployment target

The same two lines, typechecked with Xcode 27.1 against the iOS 27.1 simulator SDK:

| Code | Deployment target iOS 16.0 | Deployment target iOS 27.1 |
|---|---|---|
| `UIScreen.main.bounds` | no warning | `'main' was deprecated in iOS 26.0`, pointing to the window scene's screen or a trait |
| `UIWindow(frame: UIScreen.main.bounds)` | not tried at 16.0 | `'init(frame:)' was deprecated in iOS 26.0: Use init(windowScene:) instead` |

So an app that targets an older iOS builds quietly with these calls. duo-lint flags them at any target.

## Old SDKs

This Mac has only Xcode 27.1, so we could not build with the iOS 26 SDK or Xcode 27.0. What those builds look like on iPhone Duo comes from Apple ([prepare page](https://developer.apple.com/iphone-duo/prepare/), [Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)), not from us.

## How to repeat the scene check

```bash
DEV=/Applications/Xcode-27.1.app/Contents/Developer
DEVELOPER_DIR=$DEV xcrun -sdk iphonesimulator swiftc -parse-as-library \
  -target arm64-apple-ios27.1-simulator -o Probe.app/Probe AppDelegate.swift
# Probe.app/Info.plist: CFBundleIdentifier, CFBundleExecutable = Probe, MinimumOSVersion = 27.1,
# UILaunchScreen; add or leave out UIApplicationSceneManifest.
codesign -s - --force Probe.app
DEVELOPER_DIR=$DEV xcrun simctl install <UDID> Probe.app
DEVELOPER_DIR=$DEV xcrun simctl launch <UDID> <bundle id>
# A crash shows up in ~/Library/Logs/DiagnosticReports as Probe-<date>.ips.
```

Use the iPhone Duo simulator you already have, by UDID. Never create one for this.
