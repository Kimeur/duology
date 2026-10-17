---
name: duo-audit
description: "Audit an app for iPhone Duo: run duo-lint on the code, run the 15-point duo-design-review checklist on screenshots of the app on the Duo simulator, and list what to fix, most serious first."
argument-hint: "[app-folder] [--frames <screenshot-folder>] [--code-only]"
allowed-tools:
  - Bash(duo-doctor *)
  - Bash(duo-lint *)
  - Bash(${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint *)
  - Bash("${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint" *)
  - Bash(python3 ${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint.py *)
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint.py" *)
  - Read
  - Glob
  - Grep
---

# /duo-audit

Audit an app for iPhone Duo and report what to fix, most serious first. This command finds and ranks problems. It doesn't change the app. Offer fixes at the end.

Arguments as typed: `$ARGUMENTS`

| Argument | Meaning | Default |
|---|---|---|
| `app-folder` | The app's folder, with its `.xcodeproj`, `.xcworkspace` or `Package.swift` | The current folder |
| `--frames <folder>` | PNG screenshots or Figma exports to review instead of capturing new ones | Capture from the simulator |
| `--code-only` | Run duo-lint only; skip the build and the checklist | Off |

## 1. Run duo-lint

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint" --json <app-folder>
```

`duo-lint --json <app-folder>` does the same: this plugin puts `duo-lint` on the Bash tool's PATH. If the file can't run, use `python3 "${CLAUDE_PLUGIN_ROOT}/skills/duo-lint/scripts/duo-lint.py" --json <app-folder>`. Add `--objc` when the app has `.m` or `.mm` files.

- Exit code 1 means it found errors. That is a result, not a failure. Exit code 2 means a bad path or option.
- It skips `build/`, `DerivedData/`, `Pods/`, `Carthage/`, `.build/`, `SourcePackages/`, `.claude/`, `.agents/` and its own test fixtures on its own.
- Each JSON finding has `path`, `line`, `rule`, `severity`, `snippet`, `message`, `fix` and `source` (an Apple link).
- Group repeated findings: one finding per rule, with the count and up to five `path:line` places.
- A finding in test code, a preview or a debug-only file is usually harmless. Say so instead of ranking it.

Load the `duo-lint` skill from this plugin when you need a rule's details or how to silence a false positive.

If the user passed `--code-only`, skip to step 4.

## 2. Get the frames

The checklist reviews pictures, not code. With `--frames`, use those files and skip to step 3.

Otherwise capture the app on the iPhone Duo simulator:

```bash
duo-doctor --developer-dir     # prints the Xcode 27.1 developer folder: DEV
duo-doctor --simulator         # prints the Duo simulator's UDID: UDID
```

If either fails, show the user the output of `duo-doctor`, then go on with duo-lint findings only and mark every checklist rule **Check**.

Keep build output and screenshots out of the user's repo. Use one scratch folder, `OUT`, for both:

```bash
mktemp -d "${TMPDIR:-/tmp}/duo-audit.XXXXXX"     # prints OUT
```

Start the boot in the background; a first boot can take minutes. Then build with Xcode 27.1. Use `-workspace` instead of `-project` when the app has one. Pick the main app scheme (`xcodebuild -list` shows them; ask if there are several):

```bash
DEVELOPER_DIR=<DEV> xcrun simctl bootstatus <UDID> -b
DEVELOPER_DIR=<DEV> xcodebuild -quiet -project <app-folder>/<App>.xcodeproj -scheme <Scheme> \
  -destination "platform=iOS Simulator,id=<UDID>" -derivedDataPath <OUT>/DerivedData build
```

When `bootstatus` has finished, install, launch and capture both displays:

```bash
DEVELOPER_DIR=<DEV> xcrun simctl install <UDID> <OUT>/DerivedData/Build/Products/Debug-iphonesimulator/<FULL_PRODUCT_NAME>
DEVELOPER_DIR=<DEV> xcrun simctl launch --terminate-running-process <UDID> <bundle-id>
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary   <OUT>/outer.png
DEVELOPER_DIR=<DEV> xcrun simctl io <UDID> screenshot --display=primary-1 <OUT>/inner.png
```

- Read `FULL_PRODUCT_NAME` (for example `Places.app`; it already ends in `.app`) and `PRODUCT_BUNDLE_IDENTIFIER` (the `<bundle-id>`) from `xcodebuild -showBuildSettings` with the same project, scheme and destination.
- The display that is off comes out black. Keep the one that shows the app.
- If code signing stops a simulator build, add `CODE_SIGNING_ALLOWED=NO` to the build command.
- If the build still fails, don't fix the app. Report the first build error as a Blocker, then go on with duo-lint findings only.
- Use the UDID, never `booted`. Never run `sudo` or `xcode-select`.
- Tell the user where `OUT` is, so they can open the screenshots.

You can capture only the pose the simulator is in. `simctl` has no pose command. List the frames you are missing (step 1 of `duo-design-review` lists the full set) and ask the user once whether to capture more. If they agree, ask them to click Closed, Partially Open or Open in Device Hub, then take new screenshots. If they don't, mark the rules those frames would prove as **Check**.

## 3. Run the checklist

Load the `duo-design-review` skill from the `duology-design` plugin. Follow its steps 1 to 4 on the frames: tell the frames apart by pixel size, mark the fold and camera regions, check rules R1 to R15, and write findings with severity, rule, where and fix.

Use the code as evidence for rules a still frame can't prove. For example, look for `@SceneStorage` or state restoration for R2, and for tab or tool bars built from plain stacks for R6. Name the file and line.

If `duo-design-review` isn't available, tell the user the checklist needs the `duology-design` plugin (`/plugin install duology-design@duology`), mark R1 to R15 **Check**, and go on.

## 4. Rank and merge

Put duo-lint findings and checklist findings in one list. Order by severity, then by evidence:

1. **Blocker**: from the checklist, plus a build that fails.
2. **Major**: checklist Majors, and every duo-lint `error`. Also a duo-lint `warning` that a frame confirms (the screen is the wrong size, clipped or letterboxed), or that picks the layout of a whole screen.
3. **Minor**: checklist Minors and the other duo-lint warnings.
4. **Check**: what you couldn't see. Name the frame or recording that would settle it.

Inside one level, put findings with both a frame and a code location first. When a lint finding explains a checklist finding (for example `UIScreen.main.bounds` behind a clipped screen), merge them into one finding that names both.

## 5. Report

Write the report in this shape:

```markdown
## iPhone Duo audit: <App>

<one sentence: how many Blockers, Majors, Minors and Checks; which frames you reviewed>

### Blocker · R4 Nothing interactive in the fold: the Play button sits on the fold
- **Where:** Inner display, partly folded, Home screen. Play button at x 450–500 pt.
- **Code:** Sources/Home/HomeView.swift:42 (if any)
- **Fix:** Move the button off the fold with a reserved region query (`reservedRegions(kind: .division)`). Load `duo-layout`.
- **Source:** <Apple link from the checklist or the duo-lint finding>

...one heading per finding, most serious first...

### Coverage
| Check | Result |
|---|---|
| duo-lint | <n> errors, <n> warnings in <n> files |
| R1 to R15 | Pass, Fail, Check or N/A for each |
| Frames reviewed | <list> |
| Frames missing | <list> |
```

Rules for the report:

- Every finding has a severity, a rule (`R1`–`R15` or a `DUO0xx` id), a place and a fix.
- Every fix names the skill that does the work, such as `duo-layout`, `duo-navigation`, `duo-continuity`, `duo-patterns`, `duo-shared-screen` or `duo-lint`.
- Fixes never use device sizes, hinge angles, `UIScreen.main`, `userInterfaceIdiom` or orientation checks.
- Never mark a rule Pass that you couldn't see. Mark it Check.
- Say which findings need a real iPhone Duo to confirm, such as hinge feel or camera handover.

End by asking which findings to fix first. Don't edit the app until the user answers.
