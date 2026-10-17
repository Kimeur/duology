#!/bin/bash
# Duology evals: run a task with Claude Code twice, with the Duology plugins and
# without them, each in a fresh throwaway copy of the task's fixture, then score
# both runs the same way.
#
# Read evals/README.md first. A real run calls the Claude API, costs money, and
# lets an agent run Xcode's build tools as your macOS user. Run real evals in a
# separate macOS user account or a VM, never in your everyday account.
# Start with --dry-run.
#
# Usage: evals/run.sh [options] [TASK ...]
#
# TASK is a task id (duo-layout/existing-list-app), a skill folder (duo-layout,
# meaning all of its tasks) or a path to a task file.
#
# Choose tasks:
#   --all                every task with "status: ready"
#   --readme             the four tasks in the main README table
#   --list               print the tasks and exit
#   --validate           check every task file and its tool rules, then exit
#
# Run:
#   --arms LIST          with,without (default) or one of them
#   --trials N           runs per arm (default 1)
#   --model NAME         passed to claude --model (default: Claude Code's default)
#   --budget USD         claude --max-budget-usd per run (default 5)
#   --timeout SEC        wall-clock limit per run (default: the task's timeout, else 1800)
#   --run-id ID          results folder name (default: YYYY-MM-DD_HHMMSS). The agent's
#                        current folder includes it, so don't put a task or arm name in it
#   --plugins DIR        folder that holds the Duology plugins (default: <repo>/plugins)
#   --lint-hook          turn on the duology-ship lint hook in the run with Duology
#   --bare               add --bare to both arms (signs in with ANTHROPIC_API_KEY only;
#                        also skips plugin hooks, so --lint-hook has no effect)
#   --no-score           run the agent but skip scoring
#   --clean-work         delete each throwaway trial folder after scoring (default: keep it)
#
# No agent:
#   --dry-run            validate, copy fixtures and plugins, write the exact commands,
#                        check that claude starts in the clean environment; no API calls
#   --selftest           score every untouched fixture; each task must fail (proves the checks bite)
#   --with-build         with --selftest: build the fixtures too
#   --score-dir DIR      score DIR as the result of one TASK (for example a hand-made fix)
#   --summarize RUN_DIR  rebuild summary.json and summary.md after a checklist review
#
# Environment:
#   CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY
#                        how the agent signs in. run.sh passes exactly one of them to
#                        the agent (the token first); no other variable of yours reaches it
#   DEVELOPER_DIR        Xcode to use (default /Applications/Xcode-27.1.app/Contents/Developer)
#   DUO_SIM_UDID         iPhone Duo simulator to build and test on (default: picked from simctl)
#   EVALS_WORK_ROOT      where throwaway trial folders go (default: $TMPDIR/evals-work)
#   CLAUDE_BIN           the claude executable (default: claude on PATH)

set -u -o pipefail

EVALS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$EVALS/.." && pwd)"
KIT="$EVALS/lib/evalkit.py"
HELPERS="$EVALS/lib/check-helpers.sh"
DUO_LINT="$REPO/plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
TMP_BASE="${TMPDIR:-/tmp}"
WORK_ROOT="${EVALS_WORK_ROOT:-${TMP_BASE%/}/evals-work}"
WORK_ROOT="${WORK_ROOT%/}"
README_TASKS="duo-layout/existing-list-app duo-continuity/video-through-fold recipe-two-player-game/new-game duo-postures/tabletop-video-call"
# The only PATH an agent or a check gets.
MIN_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

ARMS="with,without"
TRIALS=1
MODEL=""
BUDGET=5
TIMEOUT=""
RUN_ID=""
PLUGINS="$REPO/plugins"
LINT_HOOK=0
BARE=0
SCORE=1
CLEAN_WORK=0
MODE="run"
WITH_BUILD=0
SCORE_DIR=""
SUMMARIZE_DIR=""
SELECT_ALL=0
SELECT_README=0
TASK_ARGS=""

die() { echo "run.sh: $*" >&2; exit 2; }
note() { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }

usage() { sed -n '2,53p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --all) SELECT_ALL=1 ;;
    --readme) SELECT_README=1 ;;
    --list) MODE="list" ;;
    --validate) MODE="validate" ;;
    --arms) shift; ARMS="${1:?--arms needs a value}" ;;
    --trials) shift; TRIALS="${1:?--trials needs a value}" ;;
    --model) shift; MODEL="${1:?--model needs a value}" ;;
    --budget) shift; BUDGET="${1:?--budget needs a value}" ;;
    --timeout) shift; TIMEOUT="${1:?--timeout needs a value}" ;;
    --run-id) shift; RUN_ID="${1:?--run-id needs a value}" ;;
    --plugins) shift; PLUGINS="${1:?--plugins needs a value}" ;;
    --lint-hook) LINT_HOOK=1 ;;
    --bare) BARE=1 ;;
    --no-score) SCORE=0 ;;
    --clean-work) CLEAN_WORK=1 ;;
    --dry-run) MODE="dry-run" ;;
    --selftest) MODE="selftest" ;;
    --with-build) WITH_BUILD=1 ;;
    --score-dir) shift; MODE="score-dir"; SCORE_DIR="${1:?--score-dir needs a folder}" ;;
    --summarize) shift; MODE="summarize"; SUMMARIZE_DIR="${1:?--summarize needs a run folder}" ;;
    --permission-mode|--allow-contaminated|--dangerously-skip-permissions)
      die "$1 is not supported: every run uses --permission-mode manual and --permission-prompts none, so anything off the allow list is refused" ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) TASK_ARGS="$TASK_ARGS $1" ;;
  esac
  shift
done

case "$TRIALS" in ''|*[!0-9]*|0) die "--trials must be a positive whole number" ;; esac
case "$TIMEOUT" in *[!0-9]*) die "--timeout must be a whole number of seconds" ;; esac
case "$BUDGET" in ''|*[!0-9.]*) die "--budget must be a number" ;; esac
case ",$ARMS," in *,with,*|*,without,*) ;; *) die "--arms must name with, without or both" ;; esac
for arm in $(echo "$ARMS" | tr ',' ' '); do
  case "$arm" in with|without) ;; *) die "unknown arm: $arm" ;; esac
done
case "$RUN_ID" in *[!A-Za-z0-9._-]*) die "--run-id may use only letters, digits, dot, dash and underscore" ;; esac

command -v python3 >/dev/null 2>&1 || die "python3 is required"

# Trial folders are deleted with rm -rf, so the root must be a real, deep path
# outside the repo, with no spaces (spaces would also break the tool rules).
case "$WORK_ROOT" in /*/*) ;; *) die "EVALS_WORK_ROOT must be an absolute path at least two folders deep: $WORK_ROOT" ;; esac
case "$WORK_ROOT" in *[[:space:]]*) die "EVALS_WORK_ROOT must not contain spaces: $WORK_ROOT" ;; esac
case "$WORK_ROOT/" in "$REPO"/*) die "EVALS_WORK_ROOT must be outside the repo" ;; esac

# ------------------------------------------------------------------ task list

all_tasks() { python3 "$KIT" list "$EVALS/tasks"; }

task_field() { python3 "$KIT" field "$1" "$2" "${3:-}"; }

resolve_task() {  # id, skill folder or path -> task file paths
  local t="$1"
  if [ -f "$t" ]; then
    (cd "$(dirname "$t")" && echo "$(pwd)/$(basename "$t")")
  elif [ -f "$EVALS/tasks/$t.md" ]; then
    echo "$EVALS/tasks/$t.md"
  elif [ -d "$EVALS/tasks/$t" ]; then
    python3 "$KIT" list "$EVALS/tasks/$t"
  else
    die "no task called '$t' (try --list)"
  fi
}

selected_tasks() {
  local t
  if [ "$SELECT_ALL" = 1 ]; then
    for t in $(all_tasks); do
      [ "$(task_field "$t" status)" = "ready" ] && echo "$t"
    done
  fi
  if [ "$SELECT_README" = 1 ]; then
    for t in $README_TASKS; do resolve_task "$t"; done
  fi
  for t in $TASK_ARGS; do resolve_task "$t"; done
}

if [ "$MODE" = "list" ]; then
  for t in $(all_tasks); do
    printf '%-48s %-8s %s\n' "$(task_field "$t" id)" "$(task_field "$t" status)" "$(task_field "$t" title)"
  done
  exit 0
fi

if [ "$MODE" = "validate" ]; then
  # shellcheck disable=SC2046
  if python3 "$KIT" validate $(all_tasks); then
    echo "all $(all_tasks | wc -l | tr -d ' ') task files are valid"
    exit 0
  fi
  exit 1
fi

if [ "$MODE" = "summarize" ]; then
  [ -d "$SUMMARIZE_DIR" ] || die "no such run folder: $SUMMARIZE_DIR"
  python3 "$KIT" summarize "$SUMMARIZE_DIR" >/dev/null || die "summary failed"
  cat "$SUMMARIZE_DIR/summary.md"
  exit 0
fi

TASKS="$(selected_tasks | awk '!seen[$0]++')"
if [ -z "$TASKS" ]; then
  if [ "$MODE" = "selftest" ]; then
    TASKS="$(for t in $(all_tasks); do [ "$(task_field "$t" status)" = "ready" ] && echo "$t"; done)"
  else
    die "no tasks selected. Name one, or use --all or --readme (see --list)"
  fi
fi
# shellcheck disable=SC2086
python3 "$KIT" validate $TASKS || die "fix the task files above first"

# --------------------------------------------------------------- environment

[ -f "$DUO_LINT" ] || die "duo-lint not found at $DUO_LINT"

SIM_UDID="${DUO_SIM_UDID:-}"
if [ -z "$SIM_UDID" ]; then
  SIM_UDID="$(python3 "$KIT" pick-sim 2>/dev/null || true)"
fi
if [ -z "$SIM_UDID" ]; then
  if [ "$MODE" = "run" ] || [ "$MODE" = "score-dir" ] || [ "$WITH_BUILD" = 1 ]; then
    die "no iPhone Duo simulator found. Install Xcode 27.1 and the iOS 27.1 runtime, or set DUO_SIM_UDID"
  fi
  SIM_UDID="SIMULATOR-NOT-FOUND"
  warn "no iPhone Duo simulator found; fine for $MODE"
fi
DESTINATION="platform=iOS Simulator,id=$SIM_UDID"

# The agent starts from an empty environment (env -i), so find claude by its full
# path now. A Node install of Claude Code is a script that needs node on PATH.
CLAUDE_ABS=""
if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  CLAUDE_ABS="$(command -v "$CLAUDE_BIN")"
  case "$CLAUDE_ABS" in
    /*) ;;
    *) CLAUDE_ABS="$(cd "$(dirname "$CLAUDE_ABS")" && pwd)/$(basename "$CLAUDE_ABS")" ;;
  esac
fi
AGENT_PATH="$MIN_PATH"
if [ -n "$CLAUDE_ABS" ] && [ "$(head -c 2 "$CLAUDE_ABS" 2>/dev/null)" = "#!" ]; then
  NODE_BIN="$(command -v node 2>/dev/null || true)"
  if [ -n "$NODE_BIN" ]; then AGENT_PATH="$(dirname "$NODE_BIN"):$AGENT_PATH"; fi
fi

# Sign-in: exactly one variable is passed to the agent.
AUTH_VAR=""
if [ "$BARE" = 1 ]; then
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then AUTH_VAR="ANTHROPIC_API_KEY"; fi
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  AUTH_VAR="CLAUDE_CODE_OAUTH_TOKEN"
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  AUTH_VAR="ANTHROPIC_API_KEY"
fi

if [ "$MODE" = "run" ]; then
  [ -n "$CLAUDE_ABS" ] || die "claude not found; install Claude Code or set CLAUDE_BIN"
  [ -d "$DEVELOPER_DIR" ] || die "Xcode not found at $DEVELOPER_DIR"
  if [ -z "$AUTH_VAR" ]; then
    if [ "$BARE" = 1 ]; then
      die "--bare signs in with ANTHROPIC_API_KEY only; set it"
    fi
    die "the agent runs with an empty HOME, so it can't use your saved login.
Set CLAUDE_CODE_OAUTH_TOKEN (make one with: claude setup-token) or ANTHROPIC_API_KEY"
  fi
fi
if [ "$MODE" = "dry-run" ]; then
  [ -n "$CLAUDE_ABS" ] || { warn "claude not found; the commands below say 'claude'"; CLAUDE_ABS="claude"; }
  [ -n "$AUTH_VAR" ] || warn "neither CLAUDE_CODE_OAUTH_TOKEN nor ANTHROPIC_API_KEY is set; a real run would stop here"
fi
if [ "$MODE" = "run" ] || [ "$MODE" = "dry-run" ]; then
  case ",$ARMS," in
    *,with,*) [ -d "$PLUGINS" ] || die "plugins folder not found: $PLUGINS" ;;
  esac
  if [ "$LINT_HOOK" = 1 ] && [ "$BARE" = 1 ]; then
    warn "--bare skips plugin hooks, so --lint-hook does nothing"
  fi
fi

DENIED_TOOLS=()
while IFS= read -r line; do
  [ -n "$line" ] && DENIED_TOOLS+=("$line")
done < <(python3 "$KIT" denied-tools)

# ----------------------------------------------------------------- run folder

[ -n "$RUN_ID" ] || RUN_ID="$(date +%Y-%m-%d_%H%M%S)"
case "$MODE" in
  dry-run) RUN_ID="$RUN_ID-dry-run" ;;
  selftest) RUN_ID="$RUN_ID-selftest" ;;
  score-dir) RUN_ID="$RUN_ID-score" ;;
esac
RUN_DIR="$EVALS/results/runs/$RUN_ID"
mkdir -p "$RUN_DIR" || die "cannot create $RUN_DIR"

CLAUDE_VERSION=""
if [ -n "$CLAUDE_ABS" ] && [ "$CLAUDE_ABS" != "claude" ]; then
  CLAUDE_VERSION="$("$CLAUDE_ABS" --version 2>/dev/null | head -1 || true)"
fi
XCODE_VERSION="$(xcodebuild -version 2>/dev/null | tr '\n' ' ' | sed 's/ *$//' || true)"
# The Mac-wide default Xcode, read only. Tasks that start without DEVELOPER_DIR
# (duo-setup/mac-check) behave differently when it is not Xcode 27.1.
XCODE_SELECT="$(env -u DEVELOPER_DIR xcode-select -p 2>/dev/null || true)"
DUOLOGY_COMMIT="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$REPO" status --porcelain -- plugins 2>/dev/null)" ]; then
  DUOLOGY_COMMIT="$DUOLOGY_COMMIT+dirty"
fi

RUN_ID="$RUN_ID" MODE="$MODE" CLAUDE_VERSION="$CLAUDE_VERSION" XCODE_VERSION="$XCODE_VERSION" \
XCODE_SELECT="$XCODE_SELECT" DUOLOGY_COMMIT="$DUOLOGY_COMMIT" MODEL="$MODEL" SIM_UDID="$SIM_UDID" ARMS="$ARMS" TRIALS="$TRIALS" \
BUDGET="$BUDGET" TASKS="$TASKS" KIT="$KIT" RUN_JSON="$RUN_DIR/run.json" AUTH_VAR="$AUTH_VAR" \
AGENT_PATH="$AGENT_PATH" BARE="$BARE" LINT_HOOK="$LINT_HOOK" python3 - <<'PY'
import datetime, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.environ["KIT"]))
import evalkit
tasks = {}
for path in os.environ["TASKS"].split():
    meta, _, _ = evalkit.parse_task(path)
    tasks[meta.get("id")] = {"title": meta.get("title"), "readme": meta.get("readme") == "yes",
                             "skill": meta.get("skill"), "fixture": meta.get("fixture"),
                             "extra_tools": evalkit.task_tools(meta)}
meta = {
    "run_id": os.environ["RUN_ID"],
    "created": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "mode": os.environ["MODE"],
    "dry_run": os.environ["MODE"] == "dry-run",
    "claude_version": os.environ["CLAUDE_VERSION"],
    "model": os.environ["MODEL"] or None,
    "xcode": os.environ["XCODE_VERSION"],
    "xcode_select": os.environ["XCODE_SELECT"] or None,
    "simulator": os.environ["SIM_UDID"],
    "duology_commit": os.environ["DUOLOGY_COMMIT"],
    "arms": os.environ["ARMS"].split(","),
    "trials": int(os.environ["TRIALS"]),
    "budget_usd_per_trial": float(os.environ["BUDGET"]),
    "isolation": {
        "environment": "env -i: HOME, PATH, DEVELOPER_DIR, TMPDIR, SHELL and one sign-in variable",
        "path": os.environ["AGENT_PATH"],
        "sign_in_variable": os.environ["AUTH_VAR"] or None,
        "permission_mode": "manual",
        "permission_prompts": "none",
        "base_allowed_tools": evalkit.BASE_TOOLS,
        "denied_tools": evalkit.DENIED_TOOLS,
        "bare": os.environ["BARE"] == "1",
        "lint_hook": os.environ["LINT_HOOK"] == "1",
    },
    "tasks": tasks,
}
with open(os.environ["RUN_JSON"], "w") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

# ------------------------------------------------------------------ helpers

# Writes meta.json for a trial. Extra KEY=VALUE pairs (strings, numbers, true/false).
write_meta() {
  local out="$1"; shift
  python3 - "$out" "$@" <<'PY'
import json, os, sys
out = sys.argv[1]
try:
    with open(out) as f:
        meta = json.load(f)
except (OSError, ValueError):
    meta = {}
for kv in sys.argv[2:]:
    k, v = kv.split("=", 1)
    if v in ("true", "false"):
        v = v == "true"
    elif k == "check_ids":
        v = [x for x in v.split(",") if x]
    else:
        try:
            v = int(v)
        except ValueError:
            pass
    meta[k] = v
with open(out, "w") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY
}

# Deletes a throwaway folder, and refuses anything outside WORK_ROOT.
safe_rm() {
  case "$1" in
    "$WORK_ROOT"/?*) rm -rf "$1" ;;
    *) die "refusing to delete $1: it is not inside $WORK_ROOT" ;;
  esac
}

# Copies a folder without build output, caches or Finder files.
copy_tree() {  # src dest
  mkdir -p "$2" || return 1
  (cd "$1" && tar -cf - --exclude './.git' --exclude './build' --exclude 'DerivedData' \
     --exclude 'xcuserdata' --exclude '*.xcresult' --exclude '.DS_Store' --exclude '__pycache__' .) \
    | (cd "$2" && tar -xf -)
}

# Sets CLEAN_ENV to an `env -i` prefix with a minimal environment. Scoring uses
# it for everything that runs code from the work folder: xcodebuild (build
# phases), test scripts the agent wrote, git (the agent could edit .git/config).
clean_env() {  # HOME TMPDIR
  CLEAN_ENV=(/usr/bin/env -i "HOME=$1" "PATH=$MIN_PATH" "DEVELOPER_DIR=$DEVELOPER_DIR"
    "TMPDIR=$2/" "SHELL=/bin/bash")
}

# A new, unused trial folder path with an opaque name: $WORK_ROOT/$RUN_ID/t-<random>.
# The agent's current folder, HOME and TMPDIR sit inside it, and Claude Code shows
# the current folder to the model. So the name must not say which task, skill or
# arm this is. meta.json (work_dir, trial_root) maps it back.
new_trial_root() {
  local r
  while :; do
    r="$WORK_ROOT/$RUN_ID/t-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    [ -e "$r" ] || { echo "$r"; return 0; }
  done
}

# One throwaway folder per trial, outside the repo:
#   <root>/work        the copy of the fixture; the agent's current folder
#   <root>/home        the agent's HOME, empty at the start
#   <root>/tmp         the agent's TMPDIR
#   <root>/plugins     a copy of the Duology plugins (run with Duology only)
#   <root>/score-home  HOME for scoring, separate from anything the agent touched
#   <root>/score-tmp   TMPDIR for scoring
prepare_trial() {  # fixture root arm
  local fixture="$1" root="$2" arm="$3"
  safe_rm "$root"
  mkdir -p "$root/work" "$root/home" "$root/tmp" "$root/score-home" "$root/score-tmp" || return 1
  if [ "$fixture" != "empty" ]; then
    copy_tree "$EVALS/fixtures/$fixture" "$root/work" || return 1
  fi
  if [ "$arm" = "with" ]; then
    copy_tree "$PLUGINS" "$root/plugins" || return 1
  fi
  init_git "$root"
}

# Commits the work folder to a throwaway git repo, so the agent's changes show up
# as a git diff. Runs in the clean environment: no user gitconfig, hooks or signing.
init_git() {  # root
  clean_env "$1/score-home" "$1/score-tmp"
  (
    cd "$1/work" || exit 1
    "${CLEAN_ENV[@]}" git init -q . || exit 1
    printf 'DerivedData/\nbuild/\n*.xcresult\nxcuserdata/\n.DS_Store\n' >> .git/info/exclude
    "${CLEAN_ENV[@]}" git add -A || exit 1
    "${CLEAN_ENV[@]}" git -c user.name="evals" -c user.email="evals@localhost" -c commit.gpgsign=false \
      commit -q --allow-empty -m "initial commit" || exit 1
  )
}

# Runs a command with a wall-clock limit. Exit 142 means the limit was hit.
# The command runs in its own process group, and the whole group is stopped at
# the limit (or on Ctrl-C), so a hung xcodebuild or simctl under it goes too.
#
# When EVALS_AUTH_VAR names the sign-in variable and the command starts with
# `/usr/bin/env -i`, the variable is added to env's list at the last moment, in
# the child. So the secret never sits in a long-lived process's argument list,
# where `ps` would show it for the whole run.
with_timeout() {
  local secs="$1"; shift
  perl -e '
    my $secs = shift @ARGV;
    my $pid = fork();
    die "fork: $!\n" unless defined $pid;
    if ($pid == 0) {
      setpgrp(0, 0);
      my $var = $ENV{EVALS_AUTH_VAR} // "";
      if ($var =~ /^(ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN)$/ && defined $ENV{$var}
          && @ARGV > 2 && $ARGV[0] eq "/usr/bin/env" && $ARGV[1] eq "-i") {
        splice(@ARGV, 2, 0, "$var=$ENV{$var}");
      }
      exec { $ARGV[0] } @ARGV or die "exec: $!\n";
    }
    my $stop = sub { my $code = shift; kill "TERM", -$pid; sleep 3; kill "KILL", -$pid; exit $code; };
    $SIG{ALRM} = sub { $stop->(142) };
    $SIG{INT} = sub { $stop->(130) };
    $SIG{TERM} = sub { $stop->(143) };
    alarm $secs;
    waitpid($pid, 0);
    my $st = $?;
    exit($st & 127 ? 128 + ($st & 127) : $st >> 8);
  ' "$secs" "$@"
}

find_project() {  # $1 work dir, $2 project from the task (may be empty)
  if [ -n "$2" ] && [ -d "$1/$2" ]; then echo "$2"; return 0; fi
  (cd "$1" && find . \( -name .git -o -name DerivedData -o -name build -o -name Pods \) -prune -o \
     -name '*.xcodeproj' -type d -print | sed 's|^\./||' | sort | head -1)
}

find_scheme() {  # $1 work dir, $2 project, $3 scheme from the task (may be empty); needs CLEAN_ENV
  if [ -n "$3" ]; then echo "$3"; return 0; fi
  (cd "$1" && with_timeout 300 "${CLEAN_ENV[@]}" xcodebuild -list -json -project "$2" 2>/dev/null) | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
schemes = data.get("project", {}).get("schemes", [])
name = data.get("project", {}).get("name", "")
print(name if name in schemes else (schemes[0] if schemes else ""))'
}

# Scores one work folder: build, duo-lint, task checks, checklist template.
# Everything that can run code from the work folder runs in the clean environment.
score_work() {
  local task="$1" root="$2" trial="$3" do_build="$4"
  local work="$root/work" build lint project scheme dd ids id code passed
  local extra=()
  build="$(task_field "$task" build no)"
  lint="$(task_field "$task" lint no)"
  dd="$work/DerivedData"
  clean_env "$root/score-home" "$root/score-tmp"
  project="$(find_project "$work" "$(task_field "$task" project)")"
  scheme=""

  if [ "$build" = "yes" ]; then
    if [ "$do_build" != 1 ]; then
      echo '{"passed": false, "skipped": true}' > "$trial/build.json"
    elif [ -z "$project" ]; then
      echo "no .xcodeproj in the work folder" > "$trial/build.log"
      echo '{"passed": false, "reason": "no Xcode project"}' > "$trial/build.json"
    else
      scheme="$(find_scheme "$work" "$project" "$(task_field "$task" scheme)")"
      note "build $project ($scheme) for $DESTINATION"
      (cd "$work" && with_timeout 1800 "${CLEAN_ENV[@]}" xcodebuild build -project "$project" \
          -scheme "$scheme" -destination "$DESTINATION" -derivedDataPath "$dd" CODE_SIGNING_ALLOWED=NO) \
          > "$trial/build.log" 2>&1
      code=$?
      passed=false; [ "$code" = 0 ] && passed=true
      printf '{"passed": %s, "exit": %s, "project": "%s", "scheme": "%s", "destination": "%s"}\n' \
        "$passed" "$code" "$project" "$scheme" "$DESTINATION" > "$trial/build.json"
    fi
  fi

  if [ "$lint" = "yes" ]; then
    "${CLEAN_ENV[@]}" python3 "$DUO_LINT" --json "$work" > "$trial/lint.json" 2> "$trial/lint.stderr"
    python3 "$KIT" lint-summary "$trial/lint.json" "$work" > "$trial/lint-summary.json"
  fi

  if [ "$MODE" = "selftest" ] && [ "$WITH_BUILD" != 1 ]; then extra+=("EVALS_SKIP_HEAVY=1"); fi
  if [ -n "${LAUNCH_WAIT:-}" ]; then extra+=("LAUNCH_WAIT=$LAUNCH_WAIT"); fi

  mkdir -p "$trial/checks"
  ids="$(python3 "$KIT" checks "$task" "$trial/checks")"
  for id in $ids; do
    (
      cd "$work" || exit 1
      with_timeout 1800 "${CLEAN_ENV[@]}" \
        "WORK=$work" "TRIAL=$trial" "TRANSCRIPT=$trial/transcript.jsonl" "FINAL=$trial/final.md" \
        "EVALS=$EVALS" "DUO_LINT=$DUO_LINT" "SIM_UDID=$SIM_UDID" "DERIVED_DATA=$dd" \
        "PROJECT=$project" "SCHEME=$scheme" ${extra[@]+"${extra[@]}"} \
        /bin/bash -c 'source "$1"; set -e -o pipefail; source "$2"' _ "$HELPERS" "$trial/checks/$id.sh"
    ) > "$trial/checks/$id.log" 2>&1
    echo $? > "$trial/checks/$id.exit"
  done
  write_meta "$trial/meta.json" "check_ids=$(echo $ids | tr ' ' ',')" "build=$build" "lint=$lint" \
    "scored=true"

  if [ -n "$(task_field "$task" checklist)" ] && [ ! -f "$trial/checklist.json" ]; then
    python3 "$KIT" checklist "$task" "$trial/checklist.json"
  fi
}

save_tree() {  # copy the final work tree, without build output, into the trial folder
  copy_tree "$1" "$2"
}

preamble() {  # $1 = full | minimal, $2 = the shared Bash commands
  echo "You are running headless inside an automated evaluation. Nobody will answer questions, so make reasonable choices and finish the whole task. Work only inside the current folder."
  if [ "$1" = "full" ]; then
    echo "Xcode 27.1 is at /Applications/Xcode-27.1.app, and DEVELOPER_DIR already points at it in this environment, so plain xcodebuild and xcrun use it. Never run sudo or xcode-select."
    echo "An iPhone Duo simulator (iOS 27.1) has the UDID $SIM_UDID. Build for it with -destination 'platform=iOS Simulator,id=$SIM_UDID'. It may be shut down; xcodebuild boots it when needed."
    echo "The Bash tool runs only commands on an allow list, which includes: $2. Anything else is refused. Use the Read, Edit, Write, Glob and Grep tools for files instead of shell commands."
  else
    echo "The Bash tool runs only commands on an allow list; anything else is refused. Use the Read, Edit, Write, Glob and Grep tools for files instead of shell commands."
  fi
  echo "When you are done, reply with a short summary of what you changed and how you checked it."
}

# Sets AGENT_ENV: the env -i prefix the agent starts with. The sign-in variable is
# not in it; with_timeout adds it in the child (see above).
agent_env() {  # root arm task
  AGENT_ENV=(/usr/bin/env -i "HOME=$1/home" "PATH=$AGENT_PATH")
  if [ "$(task_field "$3" developer_dir set)" != "unset" ]; then
    AGENT_ENV+=("DEVELOPER_DIR=$DEVELOPER_DIR")
  fi
  AGENT_ENV+=("TMPDIR=$1/tmp/" "SHELL=/bin/bash")
  if [ "$2" = "with" ] && [ "$LINT_HOOK" = 1 ]; then AGENT_ENV+=("DUOLOGY_LINT_HOOK=1"); fi
}

# Sets ALLOWED_TOOLS from the trial's allowed-tools.txt.
read_allowed() {  # file
  ALLOWED_TOOLS=()
  while IFS= read -r line; do
    [ -n "$line" ] && ALLOWED_TOOLS+=("$line")
  done < "$1"
  [ "${#ALLOWED_TOOLS[@]}" -gt 0 ] || die "no allowed tools in $1"
}

# Builds the claude command line for one arm into CLAUDE_ARGS. Never adds
# bypassPermissions or --dangerously-skip-permissions: anything off the allow list
# is refused, because nobody answers permission prompts in a headless run.
claude_args() {  # arm preamble-text plugin-root
  CLAUDE_ARGS=("$CLAUDE_ABS" -p --output-format stream-json --verbose
    --permission-mode manual --permission-prompts none
    --allowedTools "${ALLOWED_TOOLS[@]}"
    --disallowedTools "${DENIED_TOOLS[@]}"
    --setting-sources "project,local" --strict-mcp-config --no-session-persistence
    --max-budget-usd "$BUDGET"
    --append-system-prompt "$2")
  if [ -n "$MODEL" ]; then CLAUDE_ARGS+=(--model "$MODEL"); fi
  if [ "$BARE" = 1 ]; then CLAUDE_ARGS+=(--bare); fi
  if [ "$1" = "with" ]; then CLAUDE_ARGS+=(--plugin-dir "$3"); fi
}

# Writes the exact command to command.txt, with the sign-in variable redacted.
write_command() {  # trial work
  {
    echo "# cd $2"
    printf '%q ' "${AGENT_ENV[@]:0:2}"
    if [ -n "$AUTH_VAR" ]; then printf '%s ' "$AUTH_VAR=<from your environment>"; fi
    printf '%q ' "${AGENT_ENV[@]:2}" "${CLAUDE_ARGS[@]}"
    printf '< %q\n' "$1/prompt.txt"
  } > "$1/command.txt"
}

# ------------------------------------------------------------------ selftest

if [ "$MODE" = "selftest" ]; then
  note "selftest: scoring untouched fixtures in $RUN_DIR (build: $([ "$WITH_BUILD" = 1 ] && echo on || echo off))"
  FAILED_TO_FAIL=""
  for task in $TASKS; do
    id="$(task_field "$task" id)"
    fixture="$(task_field "$task" fixture)"
    trial="$RUN_DIR/$id/fixture/trial-1"
    root="$(new_trial_root)"
    mkdir -p "$trial"
    prepare_trial "$fixture" "$root" fixture || die "could not copy fixture $fixture"
    write_meta "$trial/meta.json" "task=$id" "arm=fixture" "trial=1" "score_only=true" "work_dir=$root/work"
    : > "$trial/final.md"
    score_work "$task" "$root" "$trial" "$WITH_BUILD"
    python3 "$KIT" result "$trial" > "$trial/result.json"
    line="$(python3 - "$trial/result.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
failed = [c["id"] for c in r["checks"] if not c["passed"] and c["exit"] != 3]
skipped = [c["id"] for c in r["checks"] if c["exit"] == 3]
passed = [c["id"] for c in r["checks"] if c["passed"]]
lint = r["lint"]
parts = []
if r["build"]["required"]:
    b = r["build"]
    parts.append("build " + ("skipped" if b.get("skipped") else ("ok" if b.get("passed") else "FAIL")))
if lint["required"]:
    parts.append("lint %s finding(s)" % lint.get("findings"))
parts.append("checks failing: %s" % (",".join(failed) or "none"))
parts.append("passing: %s" % (",".join(passed) or "none"))
if skipped:
    parts.append("skipped: %s" % ",".join(skipped))
auto_fail = bool(failed) or (lint["required"] and not lint.get("passed"))
print(("ok   " if auto_fail else "BAD  ") + "; ".join(parts))
PY
)"
    printf '%-46s %s\n' "$id" "$line"
    case "$line" in BAD*) FAILED_TO_FAIL="$FAILED_TO_FAIL $id" ;; esac
    safe_rm "$root"
  done
  rmdir "$WORK_ROOT/$RUN_ID" 2>/dev/null
  if [ -n "$FAILED_TO_FAIL" ]; then
    echo "These tasks pass on the untouched fixture, so their checks prove nothing:$FAILED_TO_FAIL" >&2
    exit 1
  fi
  echo "selftest ok: every task fails on its untouched fixture"
  exit 0
fi

# ----------------------------------------------------------------- score-dir

if [ "$MODE" = "score-dir" ]; then
  [ -d "$SCORE_DIR" ] || die "no such folder: $SCORE_DIR"
  set -- $TASKS
  [ $# = 1 ] || die "--score-dir needs exactly one task"
  task="$1"
  id="$(task_field "$task" id)"
  trial="$RUN_DIR/$id/score/trial-1"
  root="$(new_trial_root)"
  mkdir -p "$trial"
  safe_rm "$root"
  mkdir -p "$root/work" "$root/score-home" "$root/score-tmp" || die "cannot create $root"
  copy_tree "$SCORE_DIR" "$root/work" || die "could not copy $SCORE_DIR"
  init_git "$root" || die "git init failed in $root/work"
  write_meta "$trial/meta.json" "task=$id" "arm=score" "trial=1" "score_only=true" "work_dir=$root/work"
  : > "$trial/final.md"
  score_work "$task" "$root" "$trial" 1
  python3 "$KIT" result "$trial" > "$trial/result.json"
  python3 - "$trial/result.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print("status:", r["status"])
if r["build"]["required"]:
    print("build:", "pass" if r["build"].get("passed") else "FAIL")
if r["lint"]["required"]:
    print("lint:", r["lint"].get("findings"), "finding(s);",
          "unexplained silences:", len(r["lint"].get("unexplained_silences", [])))
for c in r["checks"]:
    print("check %-28s %s" % (c["id"], "pass" if c["passed"] else "FAIL"))
PY
  echo "details: $trial"
  echo "work folder: $root/work"
  exit 0
fi

# -------------------------------------------------------------- run, dry-run

note "run $RUN_ID: $(echo $TASKS | wc -w | tr -d ' ') task(s), arms $ARMS, $TRIALS trial(s) each"
if [ "$MODE" = "dry-run" ]; then note "dry run: no API calls, no builds"; fi
PROBED=0

for task in $TASKS; do
  id="$(task_field "$task" id)"
  fixture="$(task_field "$task" fixture)"
  task_timeout="${TIMEOUT:-$(task_field "$task" timeout 1800)}"
  preamble_kind="$(task_field "$task" preamble full)"
  dev_arg="$DEVELOPER_DIR"
  [ "$(task_field "$task" developer_dir set)" = "unset" ] && dev_arg="-"
  shared="$(python3 "$KIT" allowed-tools --summary "$task" "$dev_arg")" \
    || die "the tool rules for $id are too broad (see above)"
  PREAMBLE="$(preamble "$preamble_kind" "$shared")"
  if [ "$(task_field "$task" status)" != "ready" ]; then
    warn "$id has status $(task_field "$task" status); running it anyway because you named it"
  fi
  for arm in $(echo "$ARMS" | tr ',' ' '); do
    n=1
    while [ "$n" -le "$TRIALS" ]; do
      trial="$RUN_DIR/$id/$arm/trial-$n"
      root="$(new_trial_root)"
      work="$root/work"
      plugin_root=""
      [ "$arm" = "with" ] && plugin_root="$root/plugins"
      mkdir -p "$trial"
      note "$id [$arm] trial $n"
      prepare_trial "$fixture" "$root" "$arm" || die "could not set up $root"
      python3 "$KIT" prompt "$task" > "$trial/prompt.txt"
      python3 "$KIT" allowed-tools "$task" "$dev_arg" $plugin_root > "$trial/allowed-tools.txt" \
        || die "the tool rules for $id [$arm] are too broad (see above)"
      read_allowed "$trial/allowed-tools.txt"
      agent_env "$root" "$arm" "$task"
      claude_args "$arm" "$PREAMBLE" "$plugin_root"
      write_command "$trial" "$work"
      write_meta "$trial/meta.json" "task=$id" "arm=$arm" "trial=$n" "fixture=$fixture" \
        "work_dir=$work" "trial_root=$root" "timeout=$task_timeout" \
        "dry_run=$([ "$MODE" = "dry-run" ] && echo true || echo false)"

      if [ "$MODE" = "dry-run" ]; then
        cat "$trial/command.txt"
        if [ "$PROBED" = 0 ] && [ "$CLAUDE_ABS" != "claude" ]; then
          # No API call: only checks that claude starts in the clean environment.
          if v="$(cd "$work" && "${AGENT_ENV[@]}" "$CLAUDE_ABS" --version 2>&1)"; then
            echo "   clean-environment probe: $v"
          else
            warn "claude did not start in the clean environment: $v"
          fi
          PROBED=1
        fi
        ids="$(python3 "$KIT" checks "$task" "$trial/checks" | tr '\n' ',')"
        write_meta "$trial/meta.json" "check_ids=$ids" \
          "build=$(task_field "$task" build no)" "lint=$(task_field "$task" lint no)"
        echo "   allowed tools: ${#ALLOWED_TOOLS[@]} rules (see $trial/allowed-tools.txt)"
        echo "   score: build=$(task_field "$task" build no) lint=$(task_field "$task" lint no) checks=${ids%,} checklist=$(task_field "$task" checklist)"
        safe_rm "$root"
        n=$((n + 1))
        continue
      fi

      started=$(date +%s)
      (
        cd "$work" || exit 1
        if [ -n "$AUTH_VAR" ]; then export EVALS_AUTH_VAR="$AUTH_VAR"; fi
        with_timeout "$task_timeout" "${AGENT_ENV[@]}" "${CLAUDE_ARGS[@]}" < "$trial/prompt.txt"
      ) > "$trial/transcript.jsonl" 2> "$trial/stderr.log"
      code=$?
      timed_out=false; [ "$code" = 142 ] && timed_out=true
      write_meta "$trial/meta.json" "agent_exit=$code" "timed_out=$timed_out" \
        "agent_seconds=$(( $(date +%s) - started ))"
      python3 "$KIT" transcript "$trial/transcript.jsonl" final > "$trial/final.md"
      clean_env "$root/score-home" "$root/score-tmp"
      (cd "$work" && "${CLEAN_ENV[@]}" git add -A \
         && "${CLEAN_ENV[@]}" git diff --cached --stat > "$trial/changed-files.txt" \
         && "${CLEAN_ENV[@]}" git diff --cached > "$trial/changes.diff") 2>/dev/null
      if [ "$SCORE" = 1 ]; then
        score_work "$task" "$root" "$trial" 1
      fi
      save_tree "$work" "$trial/final-tree"
      python3 "$KIT" result "$trial" > "$trial/result.json"
      note "$id [$arm] trial $n: $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$trial/result.json")"
      if [ "$CLEAN_WORK" = 1 ]; then safe_rm "$root"; fi
      n=$((n + 1))
    done
  done
done

rmdir "$WORK_ROOT/$RUN_ID" 2>/dev/null   # only when empty
python3 "$KIT" summarize "$RUN_DIR" > /dev/null || die "summary failed"
note "results: $RUN_DIR"
cat "$RUN_DIR/summary.md"
