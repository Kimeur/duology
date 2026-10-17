# Scoring rubric

How a trial is scored. A *trial* is one run of one task in one arm (with Duology or without it). [run.sh](run.sh) scores the automatic parts; a person scores the checklist.

The checklist is the 15-point list from the `duo-design-review` skill ([checklist.md](../plugins/duology-design/skills/duo-design-review/references/checklist.md)). The lint gate is the `duo-lint` skill's linter ([rules.md](../plugins/duology-ship/skills/duo-lint/references/rules.md)). This page doesn't restate their rules; it says how each one turns into a verdict.

## The four parts

| Part | Who scores it | Pass when | Applies to |
|---|---|---|---|
| Build | run.sh | `xcodebuild build` succeeds for the iPhone Duo simulator (iOS 27.1) with Xcode 27.1 | tasks with `build: yes` |
| Lint | run.sh | `duo-lint --json` on the whole work folder reports 0 findings, and every `duo-lint:disable` comment gives a reason after `--` | tasks with `lint: yes` |
| Task checks | run.sh | every `check` block in the task file exits 0 | every task |
| Checklist | a person | every rule the task lists is `pass` or `n/a` | tasks with a `checklist:` line |

A trial **passes** when every part that applies to it passes. Until a person fills in the checklist, a trial whose automatic parts all pass is **pending review**. A trial that fails any automatic part fails at once; nobody needs to review it. A trial run with `--no-score` is **unscored**, never a pass.

The four README tasks use all four parts. Narrower tasks turn off what they don't test. For example, `duo-layout/controls-off-fold` skips lint, because the fixture's other lint findings are not that task's job.

## Build

- The scheme and project come from the task's front matter, or from the first `.xcodeproj` in the work folder.
- Destination: `platform=iOS Simulator,id=<iPhone Duo UDID>`, with `CODE_SIGNING_ALLOWED=NO`.
- Warnings don't fail the build. Deprecation warnings that matter on Duo are duo-lint's job.

## Lint

duo-lint findings and the checklist rule each one breaks:

| duo-lint rule | Severity in duo-lint | Catches | Checklist rule |
|---|---|---|---|
| DUO001 | error | `UIScreen.main`, `UIScreen.screens` | R3 |
| DUO002 | warning | device orientation | R3 |
| DUO003 | error | deprecated interface orientation | R3 |
| DUO004 | warning | layout by `userInterfaceIdiom` | R3 |
| DUO005 | warning | regular width treated as iPad | R3 |
| DUO006 | warning | hard-coded device sizes | R3 |
| DUO007 | warning | fixed widths of 320 pt or more | R3 |
| DUO008 | warning | `UIRequiresFullScreen` | R1, R3 |
| DUO009 | warning | `GeometryReader` size compared to a device size | R3 |

- Errors and warnings count the same: the gate needs 0 findings.
- A silenced line passes only with a reason: `// duo-lint:disable-next-line DUO001 -- crash reports need the device scale`. A silence without `--` fails the gate, even though duo-lint itself accepts it.
- The reviewer reads every silenced line. Silencing layout code to get a clean run is a **fail** for R3.

## Task checks

Each task file has `check` blocks: short shell scripts that look at the work folder after the agent's run. They test outcomes, not the words Duology uses:

- Source checks: a pattern must or must not appear in the code (`no_src 'userInterfaceIdiom'`). `//` comments don't count, so a fix that explains "not `userInterfaceIdiom`, because ..." in a comment still passes, and a comment alone can't satisfy a check.
- Ownership checks: a piece of state, such as the video player or the search text, has one owner that a fold can't rebuild ([single_owner.py](lib/checks/single_owner.py)).
- Behaviour checks: UI tests on the simulator, an app that must still launch, logic tests that must fail when the code is broken on purpose, a hidden oracle test copied in after the run.
- Report checks: for review tasks, each planted problem must be named in the same paragraph as its cause (`para_has`).
- Safety checks: commands the agent must not run (`sudo`, `xcode-select -s`).

Every task must fail on its untouched fixture. `run.sh --selftest` proves that.

## Checklist

The reviewer runs the app on the iPhone Duo simulator, sets each pose in Device Hub, and judges only the rules the task lists. The pose can't be changed from the command line in Xcode 27.1, so this part can't be automated yet.

### Verdicts

| Verdict | When |
|---|---|
| `pass` | No Blocker or Major finding for this rule. Minor findings go in `notes`. |
| `fail` | At least one Blocker or Major finding for this rule. |
| `n/a` | The rule can't apply to this app. Say why in `notes`. |
| `pending` | Not reviewed yet. |

Severities follow `duo-design-review`: Blocker, Major, Minor. Its checklist gives the default severity of each rule. In short:

| Rule | Fails the rule (Blocker or Major) | Note only (Minor) |
|---|---|---|
| R1 No letterboxing | the app or a game is letterboxed | a cropped hero image |
| R2 State survives fold and unfold | typed text, playback, scroll, selection or navigation lost | none |
| R3 No size from the main screen | content sized for the other display, clipped, or a fixed column with dead space | none |
| R4 Nothing interactive in the fold | any control touches the fold band when partly folded, or sits under a camera | none |
| R5 Even grids | tiles cut by the fold in a folded frame | odd count in a flat frame only |
| R6 Side controls, symbols and titles | custom horizontal bar closed, content under the bar, items with no title | item order, too many text buttons |
| R7 Tabletop and book layouts | a pose drops a control or splits a page across the fold | no tabletop layout in an app that could use one |
| R8 Split View and PiP work | the app breaks or clips in a half, or a video app has no PiP | none |
| R9 Camera preview upright | preview or photo sideways, wrong mirroring, controls under a camera | none |
| R10 Same features on the outer display | any feature missing closed | none |
| R11 Multiple windows | a window command that loses the person's place | no multi-window support in a document app |
| R12 Smooth transitions | a reload, blank frame or lost place | a jumpy but continuous change |
| R13 Touch targets of 44 pt | a primary or frequent control under 44 pt | a rare control between 28 and 44 pt |
| R14 Hardware keyboard | a focused field hidden by the keyboard; missing shortcuts in a text-heavy app | missing shortcuts elsewhere |
| R15 Drag and drop | no drag in an app whose main job is moving content | no drag elsewhere |

"Book" and "tabletop" are Duology's shorthand for Apple's descriptions "partially folded, like a book" and "seated on a table like a laptop". Apple has no posture API.

### Frames to look at

For every rule the task lists, look at the frames that can show it. Set poses with the Closed, Partially Open and Open buttons under the bezel in Device Hub.

| Frame | Rules it shows |
|---|---|
| Closed, upright and sideways | R1, R3, R6, R10, R13 |
| Open, flat, held wide and held tall | R1, R3, R5, R6 |
| Partly folded, held wide (book) | R4, R5, R7 |
| Partly folded, held tall, on a table (tabletop) | R4, R7 |
| Split View, left and right half | R8 |
| The same moment closed, then open, then closed | R2, R10, R12 |

For R2, build up state first: scroll halfway, search, select an item, start playback, type into a field. Then change the pose and compare.

### Recording a review

Each trial folder has `checklist.json`:

```json
{
  "reviewer": "your name",
  "frames": ["closed upright", "closed sideways", "open wide", "partly folded wide"],
  "rules": { "R2": "pass", "R4": "fail", "R10": "pass" },
  "notes": "R4: the + button overlaps the fold band by about 10 pt when partly folded."
}
```

Then rebuild the run's summary with `evals/run.sh --summarize evals/results/runs/<run-id>`.

Review blind when you can: look at `final-tree/` and the running app, not at the arm name in the path, until you have set every verdict.

## What else is recorded

These numbers don't change the verdict, but the summary keeps them:

- cost in US dollars, turns and wall-clock time, from the agent's `result` event;
- the skills the agent loaded (`Skill` tool calls), which shows whether a Duology skill fired;
- tool calls the allow list refused (`permission_denials`). Both arms get the same allow list apart from the plugin's own scripts, so many refusals in both arms point at a task's `tools:` line, not at the agent;
- `contamination`: signs that the run *without* Duology saw Duology anyway (a Duology skill, plugin or file path in its transcript). A contaminated trial is thrown out and rerun.

## Comparing the two arms

- Run at least 3 trials per arm before you publish a number. Agents vary from run to run.
- Report passes out of trials for each arm, per task, for example "1/3 pass" against "3/3 pass".
- Report trials still pending review separately. Never count them as passes.
- Use the same model, Claude Code version, Xcode build, simulator and Duology commit for both arms. The run's `run.json` records all five.
