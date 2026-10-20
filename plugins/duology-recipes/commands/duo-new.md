---
name: duo-new
description: "Create a new iPhone Duo app from a Duology recipe (a two-player game, a finance dashboard, a media player, a reader or a shop), build it with Xcode 27.1 and run it on the iPhone Duo simulator."
argument-hint: "<recipe> <AppName> [bundle-id] [folder]"
allowed-tools:
  - Bash(duo-doctor *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-two-player-game/scripts/new-project.sh" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-finance-dashboard/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-finance-dashboard/scripts/new-project.sh" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-media-player/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-media-player/scripts/new-project.sh" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-reader/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-reader/scripts/new-project.sh" *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/recipe-shop/scripts/new-project.sh *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/recipe-shop/scripts/new-project.sh" *)
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

Every recipe's script is `${CLAUDE_PLUGIN_ROOT}/skills/<recipe>/scripts/new-project.sh`, and every recipe has a skill of the same name in this plugin.

| Recipe | What it makes |
|---|---|
| `recipe-two-player-game` | A two-player race on one phone. Each player gets half the screen in every pose. |
| `recipe-finance-dashboard` | A personal finance dashboard. Closed: the balance and recent spending. Open: the balance, a spending chart and the transactions side by side, with a detail for each transaction. |
| `recipe-media-player` | A video podcast player: a library, and a player that keeps playing through every fold, with the video above the fold and the controls below in tabletop, Picture in Picture and an up next card. |
| `recipe-reader` | An e-book reader: one page closed, two facing pages open and in book pose, and the reader's place kept through every fold. |
| `recipe-shop` | A shop for digital packs: the grid and a pack's page side by side when open, a basket, and StoreKit purchases and a subscription, tested with a local StoreKit configuration file. |
| `recipe-notes-ai`, `recipe-camera-studio`, `recipe-kids-learning` | Planned for v1.0. No script yet. |

Accept the short form without `recipe-`, such as `media-player`. If the user describes an app instead of naming a recipe, propose the closest one and say why in one line. If none fits, say so.

For a planned recipe, say it isn't released yet and link https://github.com/Kimeur/duology/blob/main/ROADMAP.md. Offer two options: start from the closest ready recipe, or build the app from scratch with the Duology skills (`duo-layout`, `duo-navigation`, `duo-continuity`, `duo-patterns`). Don't create anything until the user picks one.

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

Run the recipe's script, with the recipe name from step 1:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/<recipe>/scripts/new-project.sh" <AppName> <bundle-id> <folder>
```

For example, for a media player:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/recipe-media-player/scripts/new-project.sh" FieldCast com.example.fieldcast ~/Developer/FieldCast
```

Each script copies its template, renames it and checks that no placeholder is left. It prints `Created <AppName> ...`, then the next steps, then where to change things. Keep that output for steps 4 and 6. A non-zero exit means nothing usable was made: show its error and stop. Exit 65 means a bad or clashing app name or bundle ID, and exit 73 a folder that isn't empty; both refuse before anything is created.

Use full paths from here on. `<folder>` is the absolute path of the new project.

## 4. Test the rules on the Mac

Every recipe keeps its rules in plain Swift and has one script under `Tools/` that tests them on the Mac. `new-project.sh` names it under "Next steps", right after the `cd` line. Run it:

```bash
DEVELOPER_DIR=<DEV> <folder>/Tools/<the test script>
```

That is `Tools/run-engine-tests.sh` for `recipe-two-player-game` and `Tools/run-model-tests.sh` for the other recipes. Don't run `Tools/run-ui-tests.sh` here: it needs the simulator (step 6 says how to offer it).

The script compiles the rules with `swiftc` and runs their checks in seconds, without a simulator. Expect `0 failed`. If it fails, show the failures and stop: the template is broken, so report it as a Duology bug.

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
- Launch with no switches, so the app opens on its first screen. Some recipes have launch switches that open a deeper screen (see the recipe's skill); use them only when the user asks.

Prove it runs. Save both displays and look at them with the Read tool:

```bash
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary <folder>/build/duo-new-outer.png
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary-1 <folder>/build/duo-new-inner.png
```

The display that is off comes out black. In our runs a freshly booted simulator started closed, so the app showed on the outer display. Pass when the display in use shows the app's first screen. If both are black, or one shows the iOS Home Screen instead of the app, launch again and take new screenshots before you report. `build/` is in the project's `.gitignore`.

## 6. Report

Tell the user, in a few lines:

- What you created: recipe, app name, bundle ID, full folder path.
- That the Mac tests passed and the app runs on the simulator, naming the simulator. Mention the screenshot of the display in use.
- How to run it again: `open <AppName>.xcodeproj`, pick the iPhone Duo simulator, Run. Or `Tools/run-ui-tests.sh` for the UI tests. That script uses the simulator named `iPhone Duo`; set `DEVICE="<name>"` or `DESTINATION="id=<UDID>"` for another one. A UI test run brings the app to the front of that simulator, so say so if other work shares it.
- How to check each pose: click Closed, Partially Open and Open in Device Hub, and look for what the recipe's skill promises in each pose. Nothing interactive may sit on the fold.
- Where to change things: repeat the last line the script printed in step 3. For example, for `recipe-two-player-game`, the rules in `<AppName>/Engine/Duel.swift` and the look in `<AppName>/Duel/`.
- For `recipe-media-player`: Picture in Picture doesn't run on the iPhone Duo simulator (the recipe measured `isPictureInPictureSupported()` as `false`), so check it on a device.
- For `recipe-shop`: after the plain `simctl launch` in step 5, every price reads "–", because no StoreKit test session has run yet. Running the app from Xcode (the scheme names `StoreKit/Shop.storekit`) or running `Tools/run-ui-tests.sh` opens one, and after that the prices show. The recipe's skill explains it.
- If the bundle ID starts with `com.example.`, change it before shipping.

If the user described the app in step 1, load the recipe's skill (the skill with the recipe's name, in this plugin) and offer to adapt the project to that description. Don't start the changes until the user agrees.

Don't run `git init`, commit or push unless the user asks.
