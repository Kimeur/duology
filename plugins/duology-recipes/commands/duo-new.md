---
name: duo-new
description: "Create a new iPhone Duo app from a Duology recipe, build it with Xcode 27.1 and run it on the iPhone Duo simulator. In v0.1 the one recipe is recipe-two-player-game."
argument-hint: "<recipe> <AppName> [bundle-id] [folder]"
allowed-tools:
  - Bash(duo-doctor *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh" *)
  - Read
  - Glob
---

# /duo-new

Create an app from a recipe, build it and show it running on the iPhone Duo simulator. Work through the steps in order. Stop at a step that fails and tell the user why.

Arguments as typed: `$ARGUMENTS`

## 1. Read the arguments

| Position | Meaning | If missing |
|---|---|---|
| 1 | Recipe name | List the recipes below and ask which one. |
| 2 | App name | Ask. If the user described the app, suggest a name from it. |
| 3 | Bundle ID | Use `com.example.<appname in lowercase>`. Tell the user to change it before shipping. |
| 4 | Folder | `./<AppName>` under the current folder. |

Text after the arguments, or on the next lines, describes the app. Keep it for step 6.

The app name becomes the Xcode target, the scheme and a Swift type. It must start with a letter and use only letters and digits, 40 at most. If the user typed `Duel Tap` or `duel-tap`, propose `DuelTap` and go on.

### Recipes

| Recipe | Status | Script |
|---|---|---|
| `recipe-two-player-game` | Ready in v0.1 | `${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh` |
| `recipe-finance-dashboard`, `recipe-media-player`, `recipe-reader`, `recipe-shop` | Planned for v0.3 | none yet |
| `recipe-notes-ai`, `recipe-camera-studio`, `recipe-kids-learning` | Planned for v1.0 | none yet |

Accept the short form without `recipe-`, such as `two-player-game`.

For a planned recipe, say it isn't released yet and link https://github.com/Kimeur/duology/blob/main/ROADMAP.md. Offer two options: start from `recipe-two-player-game`, or build the app from scratch with the Duology skills (`duo-layout`, `duo-navigation`, `duo-continuity`, `duo-patterns`). Don't create anything until the user picks one.

## 2. Find Xcode 27.1 and a Duo simulator

```bash
duo-doctor --developer-dir
duo-doctor --simulator
```

The first prints the Xcode 27.1 developer folder. Call it `DEV`. The second prints the UDID of the iPhone Duo simulator to use. Call it `UDID`. `duo-doctor` comes from the `duology` plugin, which this plugin depends on.

If either command fails, run `duo-doctor` with no options, show the user the failed lines and their fixes, and stop.

If `duo-doctor` isn't on your PATH, find them by hand:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild -version   # needs Xcode 27.1 or later
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun simctl list devices available | grep "iPhone Duo"
```

Put `DEVELOPER_DIR=<DEV>` in front of every `xcrun` and `xcodebuild` call below. Never run `sudo` or `xcode-select`.

## 3. Create the project

The folder must not exist yet, or must be empty. If it has files, stop and ask for another folder. Never delete or overwrite the user's files.

For `recipe-two-player-game`:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh" <AppName> <bundle-id> <folder>
```

The script copies the template, renames it and checks that no placeholder is left. It prints `Created <AppName> ...` and the next steps. A non-zero exit means nothing usable was made: show its error and stop.

Use full paths from here on. `<folder>` is the absolute path of the new project.

## 4. Test the game rules on the Mac

```bash
DEVELOPER_DIR=<DEV> <folder>/Tools/run-engine-tests.sh
```

It compiles the engine with `swiftc` and runs its checks in seconds, without a simulator. If it fails, show the failures and stop: the template is broken, so report it as a Duology bug.

## 5. Build and run on the iPhone Duo simulator

Start the boot first, in the background. A first boot can take several minutes, and it can run while you build:

```bash
DEVELOPER_DIR=<DEV> xcrun simctl bootstatus <UDID> -b
```

Build for the simulator you picked. `-quiet` keeps the log short; errors still show.

```bash
DEVELOPER_DIR=<DEV> xcodebuild -quiet -project <folder>/<AppName>.xcodeproj -scheme <AppName> \
  -destination "platform=iOS Simulator,id=<UDID>" \
  -derivedDataPath <folder>/build/DerivedData build
```

If the build fails, read the first error. Fix it only when the cause is clear and inside the new project, then build again. Otherwise show the error and stop.

Wait for `bootstatus` to finish. Then show the simulator, install the app and launch it:

```bash
open "<DEV>/../Applications/DeviceHub.app"
DEVELOPER_DIR=<DEV> xcrun simctl install <UDID> <folder>/build/DerivedData/Build/Products/Debug-iphonesimulator/<AppName>.app
DEVELOPER_DIR=<DEV> xcrun simctl launch --terminate-running-process <UDID> <bundle-id>
```

- Use the UDID, never `booted`: several simulators may be booted.
- Device Hub is Xcode 27.1's simulator window. It has the Closed, Partially Open and Open pose buttons.

Prove it runs. Save both displays and look at them with the Read tool:

```bash
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary <folder>/build/duo-new-outer.png
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary-1 <folder>/build/duo-new-inner.png
```

The display that is off comes out black. In our runs a freshly booted simulator started closed, so the app showed on the outer display. Pass when the display in use shows the app's start screen. If both are black, or one shows the iOS Home Screen instead of the app, launch again and take new screenshots before you report. `build/` is in the project's `.gitignore`.

## 6. Report

Tell the user, in a few lines:

- What you created: app name, bundle ID, full folder path.
- That the engine tests passed and the app runs on the simulator, naming the simulator. Mention the screenshot of the display in use.
- How to run it again: `open <AppName>.xcodeproj`, pick the iPhone Duo simulator, Run. Or `Tools/run-ui-tests.sh` for the UI tests. That script uses the simulator named `iPhone Duo`; set `DEVICE="<name>"` for another one.
- How to check each pose: click Closed, Partially Open and Open in Device Hub. Both halves must show in every pose, with nothing on the fold.
- Where to change things. For `recipe-two-player-game`: the rules in `<AppName>/Engine/Duel.swift`, the look in `<AppName>/Duel/`.
- If the bundle ID starts with `com.example.`, change it before shipping.

If the user described the app in step 1, load the recipe's skill (for example `recipe-two-player-game` in this plugin) and offer to adapt the project to that description. Don't start the changes until the user agrees.

Don't run `git init`, commit or push unless the user asks.
