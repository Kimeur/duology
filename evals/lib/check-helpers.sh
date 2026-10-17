# Helpers for the ```sh check blocks in evals/tasks/**.md.
#
# run.sh sources this file, turns on `set -e -o pipefail`, then runs the check
# from the trial's work folder (a copy of the fixture after the agent's run).
# A check passes when it exits 0. Print a short reason before failing.
#
# With pipefail on, never pipe a long output into a reader that stops early
# (grep -q, head, awk '{...; exit}'): the writer gets SIGPIPE and the whole
# pipeline fails even when the match was found. Capture the output first and
# read it from a here-string, as the helpers below do.
#
# Variables set by run.sh:
#   WORK          the work folder (also the current folder)
#   TRIAL         the trial's results folder
#   TRANSCRIPT    the agent's stream-json transcript (may be missing)
#   FINAL         the agent's final message, as text (may be empty)
#   EVALS         the evals/ folder
#   DUO_LINT      path to duo-lint.py
#   SIM_UDID      the iPhone Duo simulator used for builds and tests
#   DERIVED_DATA  DerivedData folder for this trial
#   PROJECT       the .xcodeproj that was built (may be empty)
#   SCHEME        its scheme (may be empty)
#   DEVELOPER_DIR Xcode 27.1
#   EVALS_SKIP_HEAVY  1 during `run.sh --selftest` without --with-build: helpers that
#                 build, test or launch exit 3 ("skipped") instead of running
#
# Checks run under `env -i` with a throwaway HOME and PATH=/usr/bin:/bin:/usr/sbin:/sbin,
# because they run code the agent wrote (build phases, test scripts). Use only
# tools from those folders.

# Exits the check with code 3 ("skipped") when heavy steps are turned off.
skip_if_light() {
  if [ "${EVALS_SKIP_HEAVY:-0}" = 1 ]; then
    echo "skipped: $1 (selftest without --with-build)"
    exit 3
  fi
}

# Swift files in the work folder, without build output.
swift_files() {
  find . \( -name .git -o -name DerivedData -o -name build -o -name .build \
            -o -name '*.xcresult' -o -name Pods \) -prune -o \
         -type f -name '*.swift' -print
}

# grep -E over the code of every Swift file, with // comments removed first, so a
# comment that names an API ("not ArrangementView, because ...") neither fails a
# no_src check nor satisfies a has_src check. Prints matches as path:line:code.
# (Block comments are not removed. "//" inside a string literal cuts the line short.)
src_grep() {
  swift_files | while IFS= read -r f; do
    sed -e 's#//.*$##' "$f" | grep -nE -- "$1" | awk -v f="$f" '{ print f ":" $0 }' || true
  done
}

# Passes when PATTERN appears in some Swift file.
has_src() {
  if [ -n "$(src_grep "$1")" ]; then
    return 0
  fi
  echo "not found in Swift sources: $1"
  return 1
}

# Passes when PATTERN appears in no Swift file. Prints the offending lines.
no_src() {
  local hits
  hits="$(src_grep "$1")"
  if [ -z "$hits" ]; then
    return 0
  fi
  echo "still in Swift sources: $1"
  echo "$hits" | head -20
  return 1
}

# Number of Swift lines matching PATTERN.
count_src() {
  src_grep "$1" | grep -c . || true
}

# Passes when the agent's final message matches PATTERN (case-insensitive, -E).
final_has() {
  if [ -s "$FINAL" ] && grep -qiE -- "$1" "$FINAL"; then
    return 0
  fi
  echo "final message does not match: $1"
  return 1
}

# Every Bash command the agent ran, one per line (multi-line commands stay whole).
agent_commands() {
  if [ -f "$TRANSCRIPT" ]; then
    python3 "$EVALS/lib/evalkit.py" transcript "$TRANSCRIPT" bash
  fi
}

# Passes when no Bash command the agent ran matches PATTERN (-E).
no_command() {
  local hits
  hits="$(agent_commands | grep -E -- "$1" || true)"
  if [ -z "$hits" ]; then
    return 0
  fi
  echo "the agent ran a forbidden command: $1"
  echo "$hits" | head -5
  return 1
}

# Passes when some Bash command the agent ran matches PATTERN (-E).
ran_command() {
  local cmds
  cmds="$(agent_commands)"
  if grep -qE -- "$1" <<< "$cmds"; then
    return 0
  fi
  echo "the agent never ran a command matching: $1"
  return 1
}

# Passes when the agent changed no tracked file under the given paths
# (default: the whole work folder). New untracked files count as changes too.
unchanged() {
  local changes
  changes="$(git status --porcelain -- "${@:-.}" 2>/dev/null || true)"
  if [ -z "$changes" ]; then
    return 0
  fi
  echo "files changed:"
  echo "$changes" | head -20
  return 1
}

# The first .xcodeproj in the work folder, or $PROJECT.
project_path() {
  if [ -n "${PROJECT:-}" ]; then
    echo "$PROJECT"
    return 0
  fi
  find . \( -name .git -o -name DerivedData -o -name build \) -prune -o \
       -name '*.xcodeproj' -type d -print | sort | awk 'NR == 1'
}

# Runs xcodebuild test on the iPhone Duo simulator. Extra arguments are passed on,
# for example: xcb_test -only-testing:NaiveListUITests
xcb_test() {
  skip_if_light xcb_test
  local proj scheme
  proj="$(project_path)"
  scheme="${SCHEME:-$(basename "$proj" .xcodeproj)}"
  xcodebuild test -project "$proj" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath "$DERIVED_DATA" -collect-test-diagnostics never \
    CODE_SIGNING_ALLOWED=NO "$@" 2>&1 | tail -40
}

# Passes when the build settings of the app target contain KEY = VALUE.
build_setting_is() {
  skip_if_light build_setting_is
  local proj settings value
  proj="$(project_path)"
  settings="$(xcodebuild -showBuildSettings -project "$proj" -scheme "${SCHEME:-$(basename "$proj" .xcodeproj)}" \
            -destination "generic/platform=iOS Simulator" 2>/dev/null || true)"
  value="$(awk -F' = ' -v k="$1" '$1 ~ "^ *"k"$" && !found {print $2; found = 1}' <<< "$settings")"
  if [ "$value" = "$2" ]; then
    return 0
  fi
  echo "build setting $1 is '$value', expected '$2'"
  return 1
}

# Runs xcodebuild build-for-testing on the iPhone Duo simulator (app and test targets).
xcb_build_for_testing() {
  skip_if_light xcb_build_for_testing
  local proj scheme
  proj="$(project_path)"
  scheme="${SCHEME:-$(basename "$proj" .xcodeproj)}"
  xcodebuild build-for-testing -project "$proj" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO "$@" 2>&1 | tail -20
}

# Passes when some paragraph or list item of FILE matches every pattern
# (case-insensitive, Python regular expressions). Use it to check that a review
# names a problem and its cause together: para_has review.md 'start cooking' 'fold|hinge'
para_has() {
  python3 - "$@" <<'PY'
import re, sys
path, pats = sys.argv[1], sys.argv[2:]
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    print("missing file: " + path)
    sys.exit(1)
chunks, cur = [], []
for line in text.splitlines():
    starts_item = re.match(r"\s*([-*+]|\d+[.)]|#{1,6}|\|)\s", line)
    if not line.strip() or (starts_item and not line.startswith("    ")):
        if cur:
            chunks.append(" ".join(cur))
        cur = [line] if line.strip() else []
    else:
        cur.append(line)
if cur:
    chunks.append(" ".join(cur))
# A finding often spans a heading and the lines under it: also try each chunk
# joined with the next one.
pairs = chunks + [a + " " + b for a, b in zip(chunks, chunks[1:])]
for c in pairs:
    if all(re.search(p, c, re.IGNORECASE) for p in pats):
        sys.exit(0)
print("no paragraph of %s matches all of: %s" % (path, " + ".join(pats)))
sys.exit(1)
PY
}

# Offset of the first match of PATTERN in FILE (case-insensitive), or a large number.
first_offset() {
  python3 - "$1" "$2" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(sys.argv[2], text, re.IGNORECASE)
print(m.start() if m else 10**9)
PY
}

# Installs the app built by the build gate on the iPhone Duo simulator, launches it,
# waits, and passes if it is still running. Boots the simulator if needed.
launch_ok() {
  skip_if_light launch_ok
  local app bundle procs
  app="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name '*.app' -not -name '*-Runner.app' 2>/dev/null \
         | sort | awk 'NR == 1')"
  if [ -z "$app" ]; then
    echo "no built app under $DERIVED_DATA (did the build gate pass?)"
    return 1
  fi
  bundle="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null
  xcrun simctl install "$SIM_UDID" "$app"
  xcrun simctl launch --terminate-running-process "$SIM_UDID" "$bundle" >/dev/null
  sleep "${LAUNCH_WAIT:-8}"
  procs="$(xcrun simctl spawn "$SIM_UDID" launchctl list 2>/dev/null || true)"
  xcrun simctl terminate "$SIM_UDID" "$bundle" >/dev/null 2>&1 || true
  case "$procs" in
    *"UIKitApplication:$bundle["*) return 0 ;;
  esac
  echo "$bundle is not running ${LAUNCH_WAIT:-8} s after launch (crash?)"
  return 1
}

# Runs a Python check from evals/lib/checks on the work folder.
pycheck() {
  local name="$1"; shift
  python3 "$EVALS/lib/checks/$name" "$@"
}
