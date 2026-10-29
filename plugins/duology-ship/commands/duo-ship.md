---
name: duo-ship
description: "App Store checklist for iPhone Duo before a submission: checks the build rules that start in April 2027 (iOS 27 SDK or later, iOS 15 or later, the scene life cycle), runs duo-lint, builds and launches the app on the iPhone Duo simulator, runs it in every pose with duo-pose-matrix and has the duo-pose-tester agent report each failure, captures App Store screenshots of both displays at the listed sizes without alpha, checks the privacy manifest against the code, and drafts the App Review notes. Reports Ready, Fix or Check for each item, with the evidence. Never uploads or submits anything."
argument-hint: "[app-folder] [--shot NAME=POSE[:ARGS] ...] [--no-poses] [--no-shots] [--static] [-- launch args]"
allowed-tools:
  - Bash(duo-doctor *)
  - Bash(duo-lint *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint" *)
  - Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint.py *)
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint.py" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose-matrix *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose-matrix" *)
  - Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo_pose.py *)
  - Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo_pose_matrix.py *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/duo-app-store/scripts/duo-shots *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/duo-app-store/scripts/duo-shots" *)
  - Bash(plutil -p *)
  - Bash(mktemp -d *)
  - Bash(printenv HOME)
  - Read
  - Glob
  - Grep
  - Agent
---

# /duo-ship

Check an app against what App Store Connect and App Review ask of an iPhone Duo app, collect the screenshots, and draft the notes. This command reports and prepares. It doesn't change the app's code, upload, or submit. Offer fixes at the end.

Arguments as typed: `$ARGUMENTS`

| Argument | Meaning | Default |
|---|---|---|
| `app-folder` | The app's folder, with its `.xcodeproj` or `.xcworkspace` | The current folder |
| `--shot NAME=POSE[:ARGS]` | One store screenshot: a file name, a pose (`closed`, `open`, `book`, `tabletop`) and launch arguments for that screen. Repeat it. | `01-open=open`, `02-closed=closed`, `03-tabletop=tabletop` |
| `--no-poses` | Skip the pose test (step 5) | Off |
| `--no-shots` | Skip the store screenshots (step 6) | Off |
| `--static` | Read and lint only: no build, no simulator (skips steps 4 to 6) | Off |
| `-- args` | Launch arguments for every launch, for example `-- -screenshots` | None |

Load these skills from this plugin for the detail behind each step: `duo-app-store` (sizes, screenshots, metadata, review notes, privacy), `duo-migrate` (SDK, scenes, deployment target), `duo-lint`, `duo-pose-matrix`. Write `${CLAUDE_PLUGIN_ROOT}` paths out in full in every command. If a duo-pose-matrix script can't be executed, run it with `python3`: `duo_pose.py` for `duo-pose`, `duo_pose_matrix.py` for `duo-pose-matrix`.

Rules:

- Use the existing iPhone Duo simulator by UDID. Never create, clone, erase or delete a simulator, and never use `booted`.
- Never run `sudo` or `xcode-select`. Prefix Xcode commands with the developer folder from `duo-doctor --developer-dir`.
- Never change a macOS privacy setting. If Accessibility isn't allowed, say how to allow it and use the manual route.
- Keep build output and screenshots out of the user's repo, in one scratch folder `OUT` from `mktemp -d "${TMPDIR:-/tmp}/duo-ship.XXXXXX"`. Tell the user where it is.
- Real screens only. Never draw, upscale or stretch a screenshot, and never fill a missing display with another one.
- Never mark an item Ready that you didn't check. Mark it Check and say what would settle it.

## 1. Where the app stands

Read these, and keep each one with its file and line for the report:

| Item | Where to look | Ready when |
|---|---|---|
| Xcode the app ships with | The CI pin first (`.xcode-version`, a workflow's `xcode-version` or `DEVELOPER_DIR`, fastlane), then the default Xcode | Xcode 27.1. Xcode 27.0 meets the April 2027 rule, but the app stays clear of the inner display's right edge (`duo-migrate`): **Fix** |
| Deployment target | `IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj` | iOS 15 or later |
| Life cycle | A SwiftUI `App`; or `UIApplicationSceneManifest` in the Info.plist (or `INFOPLIST_KEY_UIApplicationSceneManifest_Generation`) plus a scene delegate | Scenes. A UIKit app without them stops at launch when built with the iOS 27.1 SDK (`duo-migrate`, Step 2) |
| Bundle identifier, version, build | `PRODUCT_BUNDLE_IDENTIFIER`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | Found |
| App icon | The `AppIcon` set in the asset catalog | A 1024 × 1024 image in it ([Configuring your app icon](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)). An empty slot is a **Fix** |

From April 2027, uploads must be built with the iOS 27 SDK or later and target iOS 15 or later, and need iPhone Duo screenshots ([Submitting](https://developer.apple.com/app-store/submitting/), `duo-app-store`). A CI that archives with an older Xcode is a **Fix** even when the local build passes. Xcode Cloud picks its Xcode in the workflow settings, not in the repo: mark it Check.

## 2. duo-lint

```bash
duo-lint <app-folder>
```

If `duo-lint` isn't on the PATH, run `"${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint" <app-folder>`. Each `error` is a **Fix**. Warnings go in the report as they are; `/duo-audit` ranks them against screenshots.

## 3. Privacy manifest

Find every `PrivacyInfo.xcprivacy` in the app's targets and read it with `plutil -p`. Then Grep the app's code (not tests) for the APIs that need a declared reason ([the API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)):

| Category in `NSPrivacyAccessedAPITypes` | Grep for |
|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `UserDefaults`, `@AppStorage` |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `creationDate`, `modificationDate`, `contentModificationDateKey`, `getattrlist`, `stat(`, `fstat(`, `lstat(` |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `systemUptime`, `mach_absolute_time` |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `volumeAvailableCapacity`, `volumeTotalCapacity`, `systemFreeSize`, `statfs`, `statvfs` |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `activeInputModes` |

- **Fix**: no manifest while the code uses one of these, a category used but not declared, or `NSPrivacyTracking` true with no `NSPrivacyTrackingDomains`.
- **Check**: a declared reason you can't match to the code from Apple's list, and every third-party SDK (from `Package.resolved` or `Podfile.lock`). Each SDK ships its own manifest; Xcode's privacy report (Organizer, Generate Privacy Report on the archive) shows them all together ([privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)).

## 4. Build and launch on the iPhone Duo

```bash
duo-doctor --developer-dir     # DEV
duo-doctor --simulator         # UDID
DEVELOPER_DIR=<DEV> xcrun simctl bootstatus <UDID> -b
DEVELOPER_DIR=<DEV> xcodebuild -quiet -project <App>.xcodeproj -scheme <Scheme> \
  -destination "platform=iOS Simulator,id=<UDID>" -derivedDataPath <OUT>/DerivedData build
DEVELOPER_DIR=<DEV> xcrun simctl install <UDID> <OUT>/DerivedData/Build/Products/Debug-iphonesimulator/<FULL_PRODUCT_NAME>
DEVELOPER_DIR=<DEV> xcrun simctl launch --terminate-running-process <UDID> <bundle-id> <launch args>
```

- Use `-workspace` when the app has one, and the main app scheme (`xcodebuild -list`; ask if there are several). Read `FULL_PRODUCT_NAME` from `xcodebuild -showBuildSettings` with the same arguments. If code signing stops a simulator build, add `CODE_SIGNING_ALLOWED=NO`.
- Read `DTSDKName` from the built app's `Info.plist` with `plutil -p`: it names the SDK the build used.
- A build that fails, or an app that isn't running 5 seconds after launch, is a **Fix**. Report the first error and skip steps 5 and 6: there is nothing to test or capture.

## 5. Every pose

First settle the store shots. Without `--shot`, the three default shots all show the screen the app opens on. Grep the app for the launch arguments it reads (`ProcessInfo.processInfo.arguments`, `UserDefaults` launch keys, `duo-testing`'s launch switches) and give each default shot the switch for a screen that shows what that pose does, such as the two-pane screen for `open`. Say which switches you picked. If the app has none, keep the defaults and say in the report that the frames all show the first screen.

Tell the user in one line that steps 5 and 6 change the simulator's pose for everything on it, and bring Device Hub forward when its window isn't on the current desktop.

Check that the poses can be set:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose" status --udid <UDID>
```

Note its "Pose now" line. Exit 0: go on. Exit 3 (Accessibility) or 4 (no Device Hub window): skip the runs below, mark "Every pose" **Check**, tell the user how `/duo-poses` captures the poses by hand, and use the manual route in step 6. Exit 5, 6 or 7: show the output and skip steps 5 and 6. Never pass `--force`.

Then run the app in every pose twice, one run after the other, each Bash call with a 10-minute timeout:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose-matrix" <bundle-id> --udid <UDID> --out <OUT>/Poses/launch <cases> -- <launch args>
"${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose-matrix" <bundle-id> --udid <UDID> --out <OUT>/Poses/folding --no-relaunch <cases> -- <launch args>
```

- `<cases>` is one `--case NAME=ARGS` per distinct screen in the `--shot` list, so the poses are tested on the screens you will put on the store. `ARGS` is the shot's launch arguments only; the pose is never a launch argument.
- The first run starts the app fresh in each pose. The second keeps it running while the phone folds, which shows a quit during a fold and state lost (R2).
- Exit 0 or 1 is a result: go on. "Stopped early: UI tests started": don't rerun; say which poses are missing.

Run `printenv HOME`, then launch the `duology-ship:duo-pose-tester` agent with the Agent tool. Give it the bundle identifier, the two folders, and the crash report folder `<HOME>/Library/Logs/DiagnosticReports`. It reads the runs and opens every screenshot; it runs nothing. Keep its report whole for step 8. Step 5 takes about 10 to 20 minutes in all.

- Every failure it reports is a **Fix**: a crash in a pose blocks the submission, and the rest is what App Review and buyers see.
- If the agent isn't available, read each run's `summary.md` and every screenshot yourself, as `/duo-poses` step 4 does (`${CLAUDE_PLUGIN_ROOT}/commands/duo-poses.md`), and report what they show.

## 6. Store screenshots

Follow `duo-app-store`, Steps 1 to 3. For each `--shot`, in order:

1. Set the pose: `"${CLAUDE_PLUGIN_ROOT}/skills/duo-pose-matrix/scripts/duo-pose" set <pose> --udid <UDID>`. When it exits 3 or 4, ask the user to press it in Device Hub (Closed; Open; Partially Open for book; Partially Open, then Rotate Right for tabletop) and wait for their answer.
2. Launch the screen: `simctl launch --terminate-running-process` with the shared and the shot's launch arguments, then wait 4 seconds for the first screen.
3. Capture: `UDID=<UDID> "${CLAUDE_PLUGIN_ROOT}/skills/duo-app-store/scripts/duo-shots" <OUT>/Store <NAME>`.

Before the first shot, clean the status bar with `simctl status_bar <UDID> override` as `duo-app-store` Step 3 shows. After the last one, run `simctl status_bar <UDID> clear` and put the simulator back in the pose `duo-pose status` reported in step 5, with `duo-pose set`.

Then read every JPEG in `<OUT>/Store` with the Read tool and look at it:

- **Ready**: at least one outer-display frame (1398 × 2034 or 2034 × 1398) and one inner-display frame (2853 × 2007 or 2007 × 2853), the app's real screen, sample data only, nothing cut off.
- **Fix**: a display has no frame, a frame shows a real person's data, a debug overlay, an error, or the problem the pose test found.
- `duo-shots` writes JPEGs without alpha and fails on a size App Store Connect doesn't list. Say which display a shot skipped as black: that display was off in that pose.

## 7. Draft the notes

Write two drafts into `OUT`, from what steps 5 and 6 showed, never from what the app might do:

- `review-notes.txt`: the template in `duo-app-store`'s `references/review-notes.md`, filled with the screens, poses and launch path you saw working. Leave sign-in as a `<placeholder>` for the user.
- `promotional-text.txt`: one or two sentences on what the open phone does, in the user's words ("the list and the map side by side"), as `duo-app-store` Step 6 describes.

## 8. Report

```markdown
## iPhone Duo ship check: <App> <version> (<build>)

<one line: n Ready, n Fix, n Check. Screenshots and drafts in <OUT>.>

| Item | Result | Evidence |
|---|---|---|
| Built with the iOS 27 SDK or later | Ready | DTSDKName iphonesimulator27.1 |
| CI and archive use Xcode 27.1 | Fix | .github/workflows/ci.yml:14 pins Xcode 26.4 |
| Deployment target iOS 15 or later | Ready | 16.0 (project.pbxproj:312) |
| Scene life cycle | Ready | SwiftUI App |
| App icon | Fix | AppIcon has no 1024 × 1024 image (Contents.json:3) |
| duo-lint | Fix | 1 error, 2 warnings in 2 files |
| Privacy manifest | Fix | UserDefaults used (Settings.swift:8), not declared |
| Third-party SDK manifests | Check | Organizer privacy report on the archive |
| Builds and launches on the iPhone Duo simulator | Ready | |
| Every pose (duo-pose-tester) | Fix | Quits in tabletop: <OUT>/Poses/launch/app-tabletop.png |
| Screenshots, outer display | Ready | 02-closed-outer.jpg, 1398 × 2034 |
| Screenshots, inner display | Ready | 01-open-inner.jpg, 2853 × 2007 |
| App Review notes | Draft | <OUT>/review-notes.txt |
| Promotional text | Draft | <OUT>/promotional-text.txt |

### Fix first
- <one line per Fix, most serious first: a crash or a failed launch, then the build rules, then the privacy manifest, then the screenshots, then the rest; each with its file and line or screenshot, and the skill that fixes it>

### Pose test
<the duo-pose-tester report, as it came>

### Only you can do
- Upload the screenshots under iPhone Duo in App Store Connect (API: `APP_IPHONE_DUO`), wait for each to finish processing, and check the product page with the preview tool.
- Archive with Xcode 27.1, read the privacy report, paste the review notes, and submit.
```

- A finding that needs a real iPhone Duo (hinge feel, the camera on both sides) is a Check, never Ready.
- Show the pose report unchanged; don't soften it.

End by asking which Fix to start with. Don't edit the app until the user answers.
