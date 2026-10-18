# Duology evals

Does Duology make Claude Code better at iPhone Duo work? These evals answer that with a with/without comparison. Each task runs twice, once with the Duology plugins loaded and once without them. Both runs get the same starting project, the same prompt and the same permissions. Then both results are scored the same way.

- **Tasks:** 20 tasks, one to three for each of the 11 v0.1 skills. They include the four tasks in the main README's [Proof table](../README.md#proof-not-promises). One of those, the tabletop video call, is filed under `duo-postures` and needs v0.2 skills to show its full gap. Each task is one file in [`tasks/`](tasks).
- **Fixtures:** small Xcode projects with typical pre-Duo mistakes, in [`fixtures/`](fixtures). Each one builds for the iPhone Duo simulator.
- **Scoring:** [`rubric.md`](rubric.md). Build, duo-lint, task checks, and the 15-point checklist from `duo-design-review`.
- **Runner:** [`run.sh`](run.sh). It runs Claude Code headless (`claude -p`) in a fresh throwaway copy of the fixture, with an empty environment and a short list of allowed commands. It collects everything, scores it and writes a summary.

> [!WARNING]
> **Run real evals in a separate macOS user account or a VM, never in your everyday account.** The agent gets no blanket shell, but it can still run `xcodebuild`, and `xcodebuild` runs build phases the agent can write. Read, Edit and Write are not limited to the trial folder. Scoring then runs code the agent wrote (test scripts, build phases). Each trial also costs API money: two agent runs per task, each up to the budget you set (default 5 USD). Start with `--dry-run`, which makes no API calls.

## How the comparison works

For each task, each *arm* (`with`, `without`) and each trial:

1. **Fresh copy.** `run.sh` makes a new throwaway folder, `$TMPDIR/evals-work/<run-id>/t-<random>/`, outside the repo. It copies the task's fixture into `work/` and commits it to a new git repo, so the agent's changes show up as a diff. The `with` arm also gets a copy of the plugins in `plugins/`. The agent works in that copy and is never told where the Duology repo is. Claude Code puts the current folder in the model's system prompt, so the folder name is random: it never names the task, the skill under test or the arm. Each trial's `meta.json` maps the folder back (`work_dir`, `trial_root`).
2. **Empty environment.** The agent starts under `env -i`. It gets `HOME` set to a new empty `home/` inside the trial folder, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `DEVELOPER_DIR` for Xcode 27.1, `TMPDIR` inside the trial folder, `SHELL=/bin/bash`, and one sign-in variable. Nothing else of yours reaches it: not your shell variables, not your `~/.claude` settings or plugins, not your git config.
3. **Same agent call.** Both arms run this command (paths shortened):

   ```bash
   cd <trial>/work
   /usr/bin/env -i HOME=<trial>/home PATH=/usr/bin:/bin:/usr/sbin:/sbin \
     DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer \
     TMPDIR=<trial>/tmp/ SHELL=/bin/bash CLAUDE_CODE_OAUTH_TOKEN=<from your environment> \
     <path to claude> -p --output-format stream-json --verbose \
     --permission-mode manual --permission-prompts none \
     --allowedTools Read Edit Write Glob Grep Skill 'Bash(xcodebuild:*)' 'Bash(xcrun simctl:*)' \
       'Bash(git diff:*)' 'Bash(git status:*)' 'Bash(ls:*)' 'Bash(head:*)' 'Bash(tail:*)' 'Bash(cd:*)' ... \
     --disallowedTools Agent WebFetch WebSearch 'Edit(./.claude/**)' 'Write(./.claude/**)' ... \
     --setting-sources project,local --strict-mcp-config --no-session-persistence \
     --max-budget-usd 5 --append-system-prompt "<preamble>" < prompt.txt
   ```

   The `with` arm adds two things: `--plugin-dir <trial>/plugins`, which loads all four Duology plugins for that session, and allow rules for the plugins' own scripts (duo-lint, the recipe's `new-project.sh`, `duo-doctor`), each by its exact path in that copy, plus the bare `duo-doctor` and `duo-lint` commands that the plugins put on PATH. Every trial's exact command is in its `command.txt`, with the sign-in value redacted.
4. **Preamble.** Both arms get the same short system-prompt addition. It says to run headless without asking questions, that `DEVELOPER_DIR` already points at Xcode 27.1, which simulator UDID to build for (and to reuse it, not create or clone another), and which shell commands are allowed. Tasks marked `preamble: minimal` (the Mac check) leave out the Xcode facts, because finding them is the task.
5. **Score.** Build, duo-lint and the task's checks run on the work folder, under `env -i` with a fresh scoring `HOME`. A checklist template is written for the human review.

The prompt never mentions Duology or its skills. With the plugins loaded, Claude decides on its own whether a skill applies. The summary records which skills it loaded.

## Permissions and isolation

| What | How |
|---|---|
| Shell | No blanket `Bash`. The base list is `xcodebuild`, `xcrun simctl`, `git diff`, `git status`, `ls`, `head`, `tail` and `cd`, plus `DEVELOPER_DIR=<Xcode 27.1> xcodebuild` and `xcrun simctl`, the form skills write. A task can add rules in its `tools:` line. |
| Rule gate | `run.sh` refuses to start if any rule is too broad: blanket `Bash`, `Bash(*)`, an interpreter with a wildcard (`python3 *`), a wildcard path that doesn't start with a project folder (`Tools/*` is fine; `/bin/*`, `../*` and `./*` are not), `sudo`, `rm`, `curl`, `env`, commands that run another command (`find`, `nice`, `time`, `timeout`, `source`, `awk` and others), `xcrun` with anything but `simctl`, `swiftc` or its `--find`/`--show-sdk` options, `git` with anything but `diff`, `status`, `log` or `show` right after it, `xcode-select` with anything but printing, and more. See `rule_problem()` in [`lib/evalkit.py`](lib/evalkit.py). |
| Other tools | Read, Edit, Write, Glob, Grep and Skill. The Agent tool and the web tools are denied, so neither arm can start subagents or fetch Duology from GitHub. `xcrun simctl delete`, `erase`, `spawn`, `create` and `clone` are denied too: the first two could wipe simulators that aren't the eval's, `spawn` runs any program, and the last two add a simulator (about 4-6 GB of disk each) when the run already reuses one. |
| Prompts | `--permission-mode manual` with `--permission-prompts none`. Per `claude --help` (2.1.301), anything that would prompt is denied automatically. Nothing is ever auto-approved, and `run.sh` never passes `bypassPermissions` or `--dangerously-skip-permissions`. |
| Settings | `HOME` is empty, so no user settings, plugins or MCP servers load. `--strict-mcp-config` with no config starts no MCP servers. Deny rules keep the agent from writing `.claude/` settings mid-run. |
| Sign-in | Exactly one variable is passed: `CLAUDE_CODE_OAUTH_TOKEN` if set, else `ANTHROPIC_API_KEY`. The value is added to `env`'s argument list only at the moment `env` starts claude, so it never sits in a long-lived process's arguments, where `ps` would show it. |
| Scoring | `xcodebuild`, the task checks and `git` run under `env -i` with their own empty `HOME`, because they run code from the work folder. |
| Refused calls | Each `result.json` counts tool calls the allow list refused (`permission_denials`) and keeps up to 10 examples. The summary shows the totals. Many refusals mean a task's `tools:` list is too tight. |

What this does **not** stop: the agent runs as your macOS user. Read, Edit and Write work on any path. `xcodebuild` runs build phases, `xcrun simctl` can erase simulators, and the checks run the agent's test scripts. That is why real runs belong in a separate account or a VM.

### Set up a separate macOS user

1. In System Settings, open Users & Groups and add a Standard user, for example `evals`.
2. Log in as that user. Xcode 27.1 in `/Applications` is shared, but simulators are per user. Check for an iPhone Duo simulator, and create one only if none is listed. It takes about 4-6 GB of disk, so create exactly one: `run.sh` reuses it for every trial and never creates one itself.

   ```bash
   DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun simctl list devices available | grep "iPhone Duo"
   # none listed:
   DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcrun simctl create "iPhone Duo" \
     com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1
   ```

   When you stop running evals, delete that user's simulator with `xcrun simctl delete <UDID>` (as that user), or delete the user.

3. Install Claude Code, clone Duology, and make a sign-in token with `claude setup-token`. Export it as `CLAUDE_CODE_OAUTH_TOKEN`, or export `ANTHROPIC_API_KEY` instead.
4. Run `evals/run.sh --dry-run --all` first, then the real run.

A macOS VM works too if it can run the iOS Simulator. We haven't checked which VM setups can.

## What "pass" means

A trial passes when every part that applies to its task passes:

1. **It builds** for the iPhone Duo simulator (iOS 27.1) with Xcode 27.1.
2. **duo-lint is clean:** 0 findings in the whole work folder, and every `duo-lint:disable` comment gives a reason.
3. **Every task check passes:** source checks, ownership checks, UI tests on the simulator, logic tests that must catch planted bugs, hidden oracle tests.
4. **The checklist passes:** a person runs the app on the simulator, sets each pose in Device Hub, and marks each rule the task lists `pass` or `n/a`.

Each task's front matter says which parts apply. The four README tasks use all four. Until the checklist is filled in, a trial whose automatic parts pass shows as *pending review*, never as a pass. A trial run with `--no-score` shows as *unscored*. Details: [rubric.md](rubric.md).

## Requirements

- A Mac with Apple silicon, Xcode 27.1 (27A9275) at `/Applications/Xcode-27.1.app`, and an iPhone Duo simulator on iOS 27.1. Set `DEVELOPER_DIR` or `DUO_SIM_UDID` if yours differ.
- Claude Code. We wrote `run.sh` against the flags in `claude --help` of version 2.1.301; older versions may lack some of them.
- `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY`. The agent runs with an empty `HOME`, so it can't use the login saved in your account. `--bare` accepts only `ANTHROPIC_API_KEY`.
- Python 3.9 or later, Perl (for timeouts) and git. macOS and Xcode include all three. The checks run with Xcode's `python3` because their `PATH` is minimal.

`run.sh` works with the Bash 3.2 that ships with macOS.

## Run it

From the repo root:

```bash
evals/run.sh --list                         # every task, with its status
evals/run.sh --validate                     # check every task file and its tool rules
evals/run.sh --selftest                     # each task must fail on its untouched fixture
evals/run.sh --dry-run --all                # set up every trial and write the exact commands; no API calls

evals/run.sh duo-layout/existing-list-app   # one task, both arms, one trial each
evals/run.sh duo-continuity                 # every task of one skill
evals/run.sh --readme --trials 3            # the four README tasks, three trials per arm
evals/run.sh --all --arms with --model opus # every task, only the run with Duology
```

`--dry-run` copies the fixture and plugins, writes `prompt.txt`, `allowed-tools.txt` and `command.txt` for every trial, and starts `claude --version` once inside the empty environment, to show that claude can start there. Then it deletes the throwaway folders.

Options you will use most:

| Option | What it does |
|---|---|
| `--trials N` | Runs per arm. Use 3 or more before publishing. |
| `--model NAME` | Passed to `claude --model`. Both arms use the same model. |
| `--budget USD` | `--max-budget-usd` per agent run (default 5). |
| `--timeout SEC` | Wall-clock limit per agent run (default: the task's `timeout`, else 1800). |
| `--lint-hook` | Turns on the `duology-ship` lint hook in the `with` arm. Off by default, as it is for users. |
| `--bare` | Adds `--bare` to both arms. It skips plugin hooks, so `--lint-hook` then does nothing. |
| `--no-score` | Run the agents now and score later with `--score-dir`. These trials show as *unscored*. |
| `--score-dir DIR TASK` | Score any folder as the result of one task, with no agent. Use it to test a hand-made fix. |
| `--with-build` | With `--selftest`, also build the untouched fixtures and run the heavy checks. |
| `--summarize RUN_DIR` | Rebuild the summary after a checklist review. |

`evals/run.sh --help` lists every option.

## Results

Everything goes to `evals/results/runs/<run-id>/`, which git ignores. The default run id is the start time, `YYYY-MM-DD_HHMMSS`.

```text
evals/results/runs/2026-10-30_101500/
  run.json                 Claude Code, model, Xcode, xcode-select's default, simulator, Duology commit,
                           isolation settings, tasks
  summary.json             per task and arm: trials, passes, pending, failures, cost, refused calls
  summary.md               the same as a table, in the README's format
  duo-layout/existing-list-app/
    with/trial-1/
      prompt.txt  allowed-tools.txt  command.txt   what ran, exactly
      transcript.jsonl  stderr.log                 the agent's stream-json output
      final.md                                     its last message
      changes.diff  changed-files.txt
      build.log  build.json
      lint.json  lint-summary.json
      checks/<id>.sh  checks/<id>.log  checks/<id>.exit
      checklist.json                               fill this in during review
      final-tree/                                  the work folder after the run, without build output
      result.json                                  the verdict for this trial
    without/trial-1/ ...
```

The summary counts only folders shaped `<skill>/<task>/<arm>/trial-N` and never looks inside one, so a `meta.json` the agent left in its work folder (and so in `final-tree/`) can't add a trial. `summary.json` has one entry per task, with `arms.with` and `arms.without`. Each gives `trials`, `counts` (`pass`, `pending-review`, `fail`, `error`, `contaminated`, `unscored`), `automatic_passed`, `cost_usd` and `permission_denials`, plus run-wide `totals`. A `contaminated` trial is one where the run without Duology touched Duology anyway; rerun it. Each `result.json` adds the agent's turns, time, cost, the skills it loaded, refused tool calls and any contamination.

The throwaway folders stay in `$TMPDIR/evals-work/` so you can open the app in Xcode. Pass `--clean-work` to delete them after scoring.

## Review the checklist

1. Open the trial's work folder (its path is in `meta.json`) in Xcode 27.1, or install the built app from its `DerivedData`.
2. Run it on the iPhone Duo simulator. Set poses with the Closed, Partially Open and Open buttons under the bezel in Device Hub. `simctl` has no pose command in Xcode 27.1, so this step stays manual.
3. Judge only the rules listed in `checklist.json`, using [rubric.md](rubric.md#checklist). Record `pass`, `fail` or `n/a` for each, the frames you looked at, and notes.
4. Run `evals/run.sh --summarize evals/results/runs/<run-id>`.

Review both arms the same way, ideally without looking at the arm name first.

## Publish results in the main README

The main README's [Proof table](../README.md#proof-not-promises) shows the four README tasks. To update it after a release:

1. Run `evals/run.sh --readme --trials 3` on a clean checkout of the release tag, in the separate eval account. `run.json` records the commit. A `+dirty` suffix means the plugins had local changes, so don't publish that run.
2. Review every trial still pending.
3. Copy the rows of `summary.md` into the Proof table. Each cell reads like "1/3 pass".
4. Commit `summary.json` and `summary.md` as `evals/results/<version>/` (for example `evals/results/v0.1/`). Only `results/runs/` is ignored. Don't commit transcripts: they can hold paths from your Mac.
5. Under the table, say which model, Claude Code version and Xcode build the numbers come from.

Results for all 20 tasks go in `evals/results/<version>/` as well, linked from the README.

## Task files

Each task is `tasks/<skill>/<task>.md`. The front matter drives `run.sh`:

| Key | Meaning |
|---|---|
| `id` | `<skill>/<task>`; must match the file path |
| `skill` | the skill under test; `also:` lists others that may help |
| `title` | the row name in summaries |
| `readme` | `yes` for the four tasks in the main README |
| `fixture` | a folder in `fixtures/`, or `empty` |
| `project`, `scheme` | what to build; found automatically when left out |
| `build`, `lint` | `yes` or `no`: whether those gates apply |
| `checklist` | the rubric rules a person must review, such as `R2 R4` |
| `tools` | extra allow rules for this task, separated by commas, such as `Bash(swift test:*)`. Both arms get them. The rule gate checks them. |
| `developer_dir` | `set` (default) or `unset`. `unset` starts the agent without `DEVELOPER_DIR`; it needs `preamble: minimal` |
| `timeout` | seconds for the agent run |
| `preamble` | `full` (default) or `minimal` |
| `status` | `ready` or `planned`; `--all` runs only `ready` tasks |
| `depends` | skills from later releases that the task really needs |

The body has one prompt block and any number of check blocks:

````markdown
```text prompt
The exact words sent to Claude.
```

```sh check search-survives-fold
pycheck single_owner.py '\bvar +(query|searchText)\b'
```
````

Checks run with `bash`, `set -e` and `pipefail`, from the work folder, after [`lib/check-helpers.sh`](lib/check-helpers.sh) is loaded. They run under `env -i` with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, so use only tools from those folders. A check passes when it exits 0; print a reason before you fail. The helpers:

| Helper | Passes when |
|---|---|
| `has_src RE`, `no_src RE` | a line of Swift code matches, or none does (`grep -E`). `//` comments are ignored, so a comment that names an API neither fails nor passes a check |
| `count_src RE` | prints how many lines of Swift code match |
| `unchanged [PATH...]` | the agent changed none of these files |
| `final_has RE` | the agent's last message matches |
| `ran_command RE`, `no_command RE` | some Bash command the agent asked to run matches, or none does. Refused commands count: the check judges what the agent tried |
| `para_has FILE RE...` | one paragraph of FILE matches every pattern (for review reports) |
| `first_offset FILE RE` | prints where RE first matches, to check order |
| `pycheck single_owner.py RE` | the state declared or created on lines matching RE has one owner that a fold can't rebuild: a view's `@State`, a model object kept in `@State` or `@StateObject`, or a static. `@Binding` and `@Bindable` lines are skipped |
| `build_setting_is KEY VALUE` | the app target's build setting has this value |
| `xcb_test ARGS`, `xcb_build_for_testing` | `xcodebuild test` or `build-for-testing` on the iPhone Duo simulator succeeds. `xcb_test` turns parallel testing off, so xcodebuild doesn't clone the simulator. |
| `launch_ok` | the built app installs, launches and is still running 8 seconds later |

Oracle tests live in [`oracles/`](oracles), outside the fixtures, so the agent never sees them. A check copies one into the app's UI test folder after the run, then runs it.

### Add a task

1. Pick or add a fixture. Keep the app small, give it a neutral name, and make sure it builds (see [fixtures/README.md](fixtures/README.md)).
2. Write `tasks/<skill>/<task>.md`. Write the prompt the way a developer would; never name a Duology skill in it.
3. If the agent must run something beyond the base list, add a narrow `tools:` rule, such as `Bash(Tools/run-logic-tests.sh:*)`, not `Bash(bash *)`.
4. Write checks that test the outcome a user cares about, not the words Duology uses. Accept every correct fix you can think of, including what Duology's own templates produce.
5. Run `evals/run.sh --validate` and `evals/run.sh --selftest`. Every task must fail on its untouched fixture.
6. Make a correct fix by hand and run `evals/run.sh --score-dir <your-fix> <task-id>`. Every automatic check must pass.

To test the harness itself: `python3 -B evals/lib/test_evalkit.py` (rule gate, task files, transcripts, verdicts) and `python3 -B evals/lib/checks/test_single_owner.py --typecheck`.

## Known limits

- **Not yet run end to end with a real agent.** As of 17 October 2026 the harness has been checked with `bash -n`, `--validate`, `--dry-run`, `--selftest` (with and without builds), `--score-dir` on hand-made fixes, the unit tests, and a run with a stand-in `claude` script that recorded its environment. No paid agent run has happened yet. These parts are still unverified:
  - how Claude Code 2.1.301 matches the allow rules against what the agent types, for example a quoted plugin path, a `DEVELOPER_DIR=...` prefix or a `cd ... &&` chain;
  - whether the agent sees `${CLAUDE_PLUGIN_ROOT}` expanded in skill text, so that it calls plugin scripts by the paths the allow rules name;
  - the stream-json fields `run.sh` reads (`result`, `total_cost_usd`, `num_turns`, `permission_denials`, `Skill` tool calls);
  - that the deny rules for `.claude/` settings parse as intended.

  Run one trial per task first and read `permission_denial_samples` in each `result.json` before a full run.
- **Not a sandbox.** The scoped allow list prevents accidents, not a determined agent. See [Permissions and isolation](#permissions-and-isolation).
- **Poses are manual.** Xcode 27.1 can't fold the simulator from the command line or from XCTest, so the checklist needs a person. Oracle tests run in whatever pose the simulator is in. In our test, a newly created iPhone Duo simulator started closed, on the outer display.
- **Static checks are heuristics.** `single_owner.py` and the source helpers read Swift text, not a syntax tree. They skip `//` comments but not block comments. Read a check's message before you trust a failure.
- **Agents vary.** One trial per arm proves little. Publish only with three or more.
- **Another runner exists.** Claude Code 2.1.301 also has `claude plugin eval`. It runs a plugin's eval cases (`case.yaml`, or `prompt.md` plus `graders/*.md`) with and without the plugin, takes tool grants in the same `Tool(pattern:*)` form, and, per its help, confines shell tools in an OS sandbox. Our tasks need a fixture copy, an Xcode build and simulator tests, and we haven't checked whether `xcodebuild` and `simctl` work inside that sandbox, so we wrote `run.sh`. It may suit prompt-only tasks such as the design reviews. Our task files are named `<task>.md`, not `prompt.md`, so it shouldn't mistake them for its own cases.
