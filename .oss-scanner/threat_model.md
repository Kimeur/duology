# Threat model: Duology

## What this project does and where untrusted input enters

Duology is a Claude Code plugin pack: Markdown skills that an AI coding agent reads, plus a few Python and shell tools that run on the developer's Mac. Users install it into Claude Code. The tools run with the user's permissions, so they are the attack surface. Untrusted input enters here:

- **`duo-lint`** (`plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py`, wrapper `plugins/duology-ship/bin/duo-lint`): reads Swift, Objective-C and `Info.plist` files from any project the user points it at, including third-party or attacker-supplied code. Output is text, JSON or GitHub annotations.
- **The lint hook** (`plugins/duology-ship/hooks/hooks.json`, `hooks/lint-hook.sh`): opt-in (`DUOLOGY_LINT_HOOK=1`). Claude Code calls it after every Edit/Write with a JSON payload on stdin; the file path in that payload comes from the agent's edit and may be shaped by untrusted repository content.
- **`new-project.sh`** (`plugins/duology-recipes/skills/recipe-two-player-game/scripts/`): copies a template and renames placeholders using an app name, a bundle id and a destination folder taken from the user's (or the agent's) arguments.
- **`duo-pose` / `duo-pose-matrix`** (`plugins/duology-ship/skills/duo-pose-matrix/scripts/`): take a bundle id, launch arguments and an output folder; they drive the iOS simulator and press Device Hub buttons through the macOS Accessibility API. They must never change macOS privacy or Accessibility permissions.
- **`duo-doctor`** (`plugins/duology/bin/duo-doctor`): reads the environment and runs `xcrun`/`xcodebuild` queries.
- **Eval harness** (`evals/run.sh`, `evals/lib/evalkit.py`): runs Claude Code headless on copied fixtures with a scoped tool allowlist and `env -i`; task files and fixtures are repo content.
- **Repo validators** (`scripts/validate-skills.py`, `scripts/check-manifests.py`, `scripts/check-sources.py`): read repo files and, for check-sources, fetch URLs listed in the repo.
- **CI** (`.github/workflows/claude-review.yml`): reviews pull requests with Claude; pull request titles, bodies and files are untrusted and must not lead to a merge, secret exposure or command injection.

## Components that matter most / least

- Most: `duo-lint` (parses untrusted source files), the hook (runs automatically), `new-project.sh` and the pose tools (path and argument handling, `rm`, quoting, shell injection), and `claude-review.yml` (prompt injection, auto-merge).
- Less: the validators and eval harness (developer-only tools).
- Out of scope: the Swift sample apps (`samples/`, the recipe `template/`), Markdown skill content, images. They are examples, not tools that process input.

## How to exercise it

- `python3 -m unittest discover plugins/duology-ship/skills/duo-lint/tests` (fixtures in `tests/fixtures/`).
- `python3 plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py <dir>` on any folder of Swift files.
- `python3 -m unittest discover plugins/duology-ship/skills/duo-pose-matrix/tests` (no simulator needed).
- `bash plugins/duology-recipes/skills/recipe-two-player-game/scripts/new-project.sh <AppName> <bundle.id> <dest>`.
- `echo '<json>' | DUOLOGY_LINT_HOOK=1 CLAUDE_PLUGIN_ROOT=plugins/duology-ship bash plugins/duology-ship/hooks/lint-hook.sh`.
- macOS-only paths (`xcrun`, Accessibility) can't run in this image; review them by reading the code.

## How we rate severity

- Critical: arbitrary command execution from file contents, hook payloads, PR content or tool arguments; anything that lets a pull request merge itself or read repository secrets.
- High: writing or deleting files outside the intended folder (path traversal, unsafe `rm`), changing macOS permissions, leaking environment secrets into output.
- Medium: denial of service on crafted input (hangs, runaway memory) in duo-lint or the hook; wrong exit codes that would hide errors in CI.
- Low: lint false positives or negatives, cosmetic output issues.

## Anything to leave alone

- Lint rule accuracy (false positives/negatives) is a correctness issue, not a security one; report it only if it can be abused.
- The sample apps and recipe template are demo code.
