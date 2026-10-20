# AGENTS.md

Instructions for AI coding agents other than Claude Code: Codex, Cursor, GitHub Copilot, Gemini CLI and the rest. Claude Code users install the plugins instead; see the [README](README.md#quick-start).

This file has two parts. [Use Duology in an app](#use-duology-in-an-app) is for agents building an iPhone Duo app. [Work on this repo](#work-on-this-repo) is for agents changing Duology itself.

## Use Duology in an app

### Get the skills

Install them with the skills CLI, which puts them where your agent looks:

```bash
npx skills add Kimeur/duology                      # every skill
npx skills add Kimeur/duology --skill duo-layout   # one skill
```

If your agent has no skill support, read the files straight from this repo. A skill is a folder: `SKILL.md` holds the instructions, `references/` holds the detail, and some skills have `scripts/`. Read `SKILL.md` first and open a reference file only when `SKILL.md` sends you there.

### Start with duo-start

Read [`plugins/duology/skills/duo-start/SKILL.md`](plugins/duology/skills/duo-start/SKILL.md) before any other skill. It works out whether the app is SwiftUI or UIKit, new or existing, and which SDK it builds with, runs a short first pass, and tells you which skill to load next. Load a skill only when the task needs it.

| Skill | Path | Load it when |
|---|---|---|
| `duo-start` | [`plugins/duology/skills/duo-start/`](plugins/duology/skills/duo-start/) | Always first. |
| `duo-setup` | [`plugins/duology/skills/duo-setup/`](plugins/duology/skills/duo-setup/) | Xcode 27.1, the iPhone Duo simulator or project settings aren't ready. |
| `duo-layout` | [`plugins/duology/skills/duo-layout/`](plugins/duology/skills/duo-layout/) | Content lands in the fold, or a screen breaks on one display. |
| `duo-navigation` | [`plugins/duology/skills/duo-navigation/`](plugins/duology/skills/duo-navigation/) | Toolbars, tab bars, split views or sheets look wrong. |
| `duo-continuity` | [`plugins/duology/skills/duo-continuity/`](plugins/duology/skills/duo-continuity/) | Something resets when the phone folds, unfolds or rotates. |
| `duo-scenes` | [`plugins/duology/skills/duo-scenes/`](plugins/duology/skills/duo-scenes/) | The app opens a second window, runs in Split View, or shows content on the outer display while the camera runs. |
| `duo-patterns` | [`plugins/duology-design/skills/duo-patterns/`](plugins/duology-design/skills/duo-patterns/) | Choosing a layout for the outer and inner display. |
| `duo-design-system` | [`plugins/duology-design/skills/duo-design-system/`](plugins/duology-design/skills/duo-design-system/) | Spacing, grids, type, Liquid Glass, corners, colours and touch targets for both displays. |
| `duo-postures` | [`plugins/duology-design/skills/duo-postures/`](plugins/duology-design/skills/duo-postures/) | A screen must work half folded (book, tabletop), or you add a hinge effect. |
| `duo-transitions` | [`plugins/duology-design/skills/duo-transitions/`](plugins/duology-design/skills/duo-transitions/) | Opening or closing the phone flashes, reloads or moves controls. |
| `duo-ergonomics` | [`plugins/duology-design/skills/duo-ergonomics/`](plugins/duology-design/skills/duo-ergonomics/) | Placing primary actions and floating controls within reach. |
| `duo-accessibility` | [`plugins/duology-design/skills/duo-accessibility/`](plugins/duology-design/skills/duo-accessibility/) | VoiceOver, Dynamic Type, Reduce Motion, keyboard and contrast on both displays. |
| `duo-shared-screen` | [`plugins/duology-design/skills/duo-shared-screen/`](plugins/duology-design/skills/duo-shared-screen/) | Two people use the phone at the same time. |
| `duo-design-review` | [`plugins/duology-design/skills/duo-design-review/`](plugins/duology-design/skills/duo-design-review/) | Reviewing screenshots or Figma frames. |
| `duo-testing` | [`plugins/duology-ship/skills/duo-testing/`](plugins/duology-ship/skills/duo-testing/) | Writing logic tests or UI tests for the Duo simulator. |
| `duo-pose-matrix` | [`plugins/duology-ship/skills/duo-pose-matrix/`](plugins/duology-ship/skills/duo-pose-matrix/) | Screenshots of the app closed, open, in book pose and in tabletop. |
| `duo-lint` | [`plugins/duology-ship/skills/duo-lint/`](plugins/duology-ship/skills/duo-lint/) | Checking code before review, release or CI. |
| `recipe-two-player-game` | [`plugins/duology-recipes/skills/recipe-two-player-game/`](plugins/duology-recipes/skills/recipe-two-player-game/) | Starting a new two-player game. |
| `duo-camera` | [`plugins/duology-features/skills/duo-camera/`](plugins/duology-features/skills/duo-camera/) | The app takes photos or video, runs a video call or shows a camera preview, on either display or in tabletop. |
| `duo-media` | [`plugins/duology-features/skills/duo-media/`](plugins/duology-features/skills/duo-media/) | The app plays video or audio and playback must survive fold and unfold, with a tabletop player and Picture in Picture. |
| `duo-intelligence` | [`plugins/duology-features/skills/duo-intelligence/`](plugins/duology-features/skills/duo-intelligence/) | The app uses Foundation Models: an AI pane when open, a short summary when closed. |
| `duo-app-intents` | [`plugins/duology-features/skills/duo-app-intents/`](plugins/duology-features/skills/duo-app-intents/) | The app exposes actions to Siri, Shortcuts or the Action button, and they must open the right pane or window. |
| `duo-swiftui-27` | [`plugins/duology-features/skills/duo-swiftui-27/`](plugins/duology-features/skills/duo-swiftui-27/) | The app adopts the iOS 27 SwiftUI changes (reordering, swipe actions, the @State macro, new toolbar and tab APIs) and needs them to work on both displays. |
| `duo-system-surfaces` | [`plugins/duology-features/skills/duo-system-surfaces/`](plugins/duology-features/skills/duo-system-surfaces/) | The app has widgets, Live Activities, StandBy or Control Center controls that must look right on both displays. |
| `duo-reading` | [`plugins/duology-features/skills/duo-reading/`](plugins/duology-features/skills/duo-reading/) | The app shows books, articles or documents and should read like a book when open, keeping the reader's place through a fold. |
| `duo-games` | [`plugins/duology-features/skills/duo-games/`](plugins/duology-features/skills/duo-games/) | The project is a game (SpriteKit, Metal, or a native shell around an engine) and must fill every pose with touch controls off the fold. |

### Commands, without Claude Code

`/duo-doctor`, `/duo-audit`, `/duo-new`, `/duo-poses` and `/duo-review` are Claude Code commands. Any agent can do the same work with the scripts or skills they use. Paths are relative to this repo.

| Claude Code | Any agent |
|---|---|
| `/duo-doctor` | Run `plugins/duology/bin/duo-doctor --skip-claude`. It only reads, and it explains each failure. |
| `/duo-audit` | Run `python3 plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py <app-folder>`, then follow the checklist in `duo-design-review`. |
| `/duo-new` | Follow `recipe-two-player-game/SKILL.md`. It runs `scripts/new-project.sh <AppName> <bundle-id> <folder>` from that skill. |
| `/duo-poses` | Run `plugins/duology-ship/skills/duo-pose-matrix/scripts/duo-pose status`, then `duo-pose-matrix <bundle-id>` from the same folder. Read `duo-pose-matrix/SKILL.md` first: it changes the pose of the whole simulator and needs the user's Accessibility permission. |
| `/duo-review` | Read the frames yourself and follow `duo-design-review/SKILL.md`, with the `duo-postures`, `duo-patterns`, `duo-ergonomics` and `duo-accessibility` rules. The `duo-design-reviewer` agent in `plugins/duology-design/agents/` describes the output. Don't edit files. |

### Rules that apply everywhere

- Build with Xcode 27.1 through `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`. Never run `sudo` or `xcode-select`.
- Run the app on the "iPhone Duo" simulator.
- Poses change only in Device Hub. `simctl` and `devicectl` have no pose command. A small Mac program can press Device Hub's buttons through the macOS Accessibility API: find the `AXButton` whose description is `Closed`, `Partially Open`, `Open` or `Rotate Right`, then call `AXUIElementPerformAction` with `kAXPressAction`. It works only after the user gives Accessibility permission to the app that runs you, and only the user can give it; never change that setting. It drives Device Hub's window, so Device Hub must be open on the iPhone Duo, and an Xcode update can break it. The pose applies to everything running on that simulator. `duo-pose-matrix` ships `duo-pose` and `duo-pose-matrix`, which do this and refuse while UI tests share the simulator. Ask the user to press the pose in Device Hub unless they ask you to script it. Details: `duo-setup`'s [`references/simulator-and-device-hub.md`](plugins/duology/skills/duo-setup/references/simulator-and-device-hub.md#script-the-pose-buttons).
- Pick layouts by size class and the space the view has. Never by `UIScreen.main`, device model, `userInterfaceIdiom` or orientation.
- Keep buttons and text out of the fold. Scrolling content may cross it.
- Before you use an iPhone Duo API, find it in [`reference/api-index.md`](reference/api-index.md). Its [Not in the SDK](reference/api-index.md#not-in-the-sdk) section lists names that sound right but don't exist in the SDK.

## Work on this repo

### Layout

| Path | What's there |
|---|---|
| `plugins/<plugin>/skills/<skill>/` | One skill: `SKILL.md`, `references/`, sometimes `scripts/` and `template/` |
| `plugins/<plugin>/commands/` | Claude Code commands |
| `plugins/<plugin>/agents/` | Claude Code agents (`duo-design-reviewer`) |
| `plugins/<plugin>/.claude-plugin/plugin.json` | Plugin manifest |
| `.claude-plugin/marketplace.json` | The marketplace that lists the plugins |
| `reference/` | API index, device facts and sources, shared by every skill |
| `samples/DuologyGallery/` | Gallery app with a screen for each layout pattern |
| `evals/` | Test tasks and fixture apps |
| `scripts/` | Repo checks, with tests in `scripts/tests/` |

### Rules

1. **Verify every API name** in the iOS 27.1 SDK (the SwiftUI and SwiftUICore `.swiftinterface` files and the UIKit, AVFoundation and AVKit headers) or on Apple's documentation. If you can't, leave it out or mark it "(unverified)". Never invent an API.
2. **Typecheck every Swift snippet** you add:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
   xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios27.1-simulator <file>.swift
   ```
3. **Explain Apple's guidance in your own words** and link the source. Add new sources to `reference/sources.md`. Don't copy text from Apple or from other repos.
4. **Write skills for agents.** `SKILL.md` is imperative and concrete, with code. Keep it to 300 lines and move depth into `references/`. Use short sentences, plain words and active voice. No emoji.
5. **Keep `metadata.verified` honest**, for example `"Xcode 27.1 (27A9275), iOS 27.1 simulator, device: no"`. Change `device` to `yes` only after testing on a real iPhone Duo.
6. **Quote YAML values that contain `: ` or ` #`.** Unquoted, the first breaks the front matter and the second cuts the description short.
7. **Keep relative links inside the skill folder.** `npx skills add --skill <name>` copies only that skill's folder, and `/plugin install` copies only `plugins/<plugin>/`. So a relative link to `reference/`, to another skill or to another plugin breaks for users. Use the GitHub URL instead, for example `https://github.com/Kimeur/duology/blob/main/reference/api-index.md`. `validate-skills.py` fails on links that leave the plugin and prints the URL to use; `--portable --strict` (what CI runs) also fails on links that leave the skill.
8. **Add a test task** in `evals/` for a new skill.

### Before you finish

Run these. All but the last need only Python 3; the last one needs network.

```bash
python3 scripts/validate-skills.py --portable --strict
python3 scripts/check-manifests.py
python3 -m unittest discover plugins/duology-ship/skills/duo-lint/tests
python3 -m unittest discover plugins/duology-ship/skills/duo-pose-matrix/tests
python3 -m unittest discover -s scripts/tests
python3 scripts/check-sources.py
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for how pull requests are reviewed.
