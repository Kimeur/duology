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
| `duo-patterns` | [`plugins/duology-design/skills/duo-patterns/`](plugins/duology-design/skills/duo-patterns/) | Choosing a layout for the outer and inner display. |
| `duo-shared-screen` | [`plugins/duology-design/skills/duo-shared-screen/`](plugins/duology-design/skills/duo-shared-screen/) | Two people use the phone at the same time. |
| `duo-design-review` | [`plugins/duology-design/skills/duo-design-review/`](plugins/duology-design/skills/duo-design-review/) | Reviewing screenshots or Figma frames. |
| `duo-testing` | [`plugins/duology-ship/skills/duo-testing/`](plugins/duology-ship/skills/duo-testing/) | Writing logic tests or UI tests for the Duo simulator. |
| `duo-lint` | [`plugins/duology-ship/skills/duo-lint/`](plugins/duology-ship/skills/duo-lint/) | Checking code before review, release or CI. |
| `recipe-two-player-game` | [`plugins/duology-recipes/skills/recipe-two-player-game/`](plugins/duology-recipes/skills/recipe-two-player-game/) | Starting a new two-player game. |

### Commands, without Claude Code

`/duo-doctor`, `/duo-audit` and `/duo-new` are Claude Code commands. Any agent can do the same work with the scripts they call. Paths are relative to this repo.

| Claude Code | Any agent |
|---|---|
| `/duo-doctor` | Run `plugins/duology/bin/duo-doctor --skip-claude`. It only reads, and it explains each failure. |
| `/duo-audit` | Run `python3 plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py <app-folder>`, then follow the checklist in `duo-design-review`. |
| `/duo-new` | Follow `recipe-two-player-game/SKILL.md`. It runs `scripts/new-project.sh <AppName> <bundle-id> <folder>` from that skill. |

### Rules that apply everywhere

- Build with Xcode 27.1 through `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`. Never run `sudo` or `xcode-select`.
- Run the app on the "iPhone Duo" simulator. You can't change its pose from the command line; ask the user to press Closed, Partially Open or Open in Device Hub.
- Pick layouts by size class and the space the view has. Never by `UIScreen.main`, device model, `userInterfaceIdiom` or orientation.
- Keep buttons and text out of the fold. Scrolling content may cross it.
- Before you use an iPhone Duo API, find it in [`reference/api-index.md`](reference/api-index.md). Its [Not in the SDK](reference/api-index.md#not-in-the-sdk) section lists names that sound right but don't exist in the SDK.

## Work on this repo

### Layout

| Path | What's there |
|---|---|
| `plugins/<plugin>/skills/<skill>/` | One skill: `SKILL.md`, `references/`, sometimes `scripts/` and `template/` |
| `plugins/<plugin>/commands/` | Claude Code commands |
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
7. **Keep relative links inside the plugin folder.** `/plugin install` copies only `plugins/<plugin>/`, so a relative link to `reference/` or to another plugin breaks for users. Use the GitHub URL instead, for example `https://github.com/Kimeur/duology/blob/main/reference/api-index.md`. `validate-skills.py` fails on these links and prints the URL to use.
8. **Add a test task** in `evals/` for a new skill.

### Before you finish

Run these. All but the last need only Python 3; the last one needs network.

```bash
python3 scripts/validate-skills.py
python3 scripts/check-manifests.py
python3 -m unittest discover plugins/duology-ship/skills/duo-lint/tests
python3 -m unittest discover -s scripts/tests
python3 scripts/check-sources.py
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for how pull requests are reviewed.
