# Running tests from the command line

Every command here ran on 16 October 2026 with Xcode 27.1 (27A9275) and the iOS 27.1 runtime (24A94425), unless the text says otherwise. Flags come from `man xcodebuild` and `xcrun xcresulttool help` in Xcode 27.1.

Set this once per shell, or put it in front of each command:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
```

## Pick and boot the simulator

```bash
xcrun simctl list devices available | grep "iPhone Duo"
xcrun simctl bootstatus <UDID or name> -b
```

- *Measured:* a newly created iPhone Duo simulator made `xcodebuild test` fail with "Timed out trying to boot simulator after waiting 60.00s" and exit 65. `bootstatus -b` then booted it in about a minute, and the same tests ran. Boot first, in the background if you can't wait.
- Use `-destination "id=<UDID>"` when two simulators share a name, when other people or agents use the shared "iPhone Duo", or in CI. *Measured:* `-destination "platform=iOS Simulator,name=iPhone Duo"` resolved and built.
- A UI test brings the app to the front of that simulator, and each `launch()` ends any running copy first (XCUIAutomation header). Don't do that on a simulator someone else is watching or scripting. Create your own and delete it after:

```bash
UDID=$(xcrun simctl create "Tests Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1)
xcrun simctl bootstatus "$UDID" -b
# ... run tests with -destination "id=$UDID" ...
xcrun simctl shutdown "$UDID" && xcrun simctl delete "$UDID"
```

- *Measured:* a new Duo simulator boots closed (the hinge reported `closed`, window 466 × 678 pt). Poses change only in Device Hub.
- *Measured:* the iOS 27.1 runtime refused other iPhones: `simctl create` with iPhone 17, 17e, 17 Pro, Air, 18 Pro or 18 Pro Max failed with "Incompatible device". To run the same suite on another iPhone, use the iOS 27.0 runtime and a deployment target of 27.0 or lower (an iPhone 17 Pro on iOS 27.0 worked).

## Run the tests

```bash
rm -rf build/UITests.xcresult
xcodebuild test \
  -project App.xcodeproj -scheme App \
  -destination "platform=iOS Simulator,name=iPhone Duo" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/UITests.xcresult \
  -collect-test-diagnostics never
```

| Flag | Why |
|---|---|
| `-destination` | `platform=iOS Simulator,name=iPhone Duo`, or `id=<UDID>`. Add `,OS=27.1` to pin the runtime. |
| `-derivedDataPath build/DerivedData` | Keeps build products next to the project, so later commands can find the `.xctestrun` file. |
| `-resultBundlePath` | Writes an `.xcresult` bundle. The man page says xcodebuild exits with an error if the path already exists, so delete it first. |
| `-collect-test-diagnostics never` | Skips sysdiagnoses and log archives on failure. See "Sitting after the last test". |
| `-only-testing:Target/Class/method` | Runs one target, class or method. Repeat it for several. `-skip-testing:` does the reverse. |
| `-test-iterations N` with `-retry-tests-on-failure` or `-run-tests-until-failure` | Hunts flaky tests. |
| `-parallel-testing-enabled NO` | Overrides the scheme's parallel setting, so tests run one at a time. |
| `-enumerate-tests` | Lists the tests a run would execute, without running them. |

Test identifiers follow `TestTarget/TestClass/testMethod` ([Running tests and interpreting results](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)). *Measured:* `-only-testing:DuoSampleUITests/BoardUITests/testTapInsideAShape` worked without parentheses; the result bundle then names the test `BoardUITests/testTapInsideAShape()`, with them.

Exit codes, *measured*: 0 when all tests pass; 65 when a test fails, and also when the run can't start (the boot timeout above).

## Build once, test many times

```bash
xcodebuild build-for-testing -project App.xcodeproj -scheme App \
  -destination "platform=iOS Simulator,name=iPhone Duo" -derivedDataPath build/DerivedData

# Same scheme, no rebuild:
xcodebuild test-without-building -project App.xcodeproj -scheme App \
  -destination "id=<UDID>" -derivedDataPath build/DerivedData \
  -resultBundlePath build/Run2.xcresult -collect-test-diagnostics never

# Or point at the .xctestrun file that build-for-testing wrote (no -project then):
xcodebuild test-without-building \
  -xctestrun build/DerivedData/Build/Products/App_iphonesimulator27.1-arm64.xctestrun \
  -destination "id=<UDID>" -resultBundlePath build/Run3.xcresult \
  -only-testing:AppUITests/BoardUITests/testDragPieceIntoSlot
```

*Measured:* all three forms ran. The `.xctestrun` file name carries the SDK and the architectures built; list `build/DerivedData/Build/Products/` to find it. Building for `-destination "generic/platform=iOS Simulator"` named it `App_iphonesimulator27.1-arm64-x86_64.xctestrun`.

## Sitting after the last test

A shipped Duo app's notes said xcodebuild could sit for minutes after the last test while it saved results. We reproduced it and found the cause:

| Run | Last test ended | xcodebuild exited | Result bundle |
|---|---|---|---|
| 4 passing tests, default flags | 21:10:19 | 21:10:19 | 320 KB |
| 1 failing test, default flags | 21:10:57 | 21:20:57, right after the log line "Failure collecting diagnostics from simulator: Timed out after 600.0 seconds" | 50 MB |
| 1 failing test, `-collect-test-diagnostics never` | 21:22:18 | 21:22:18 | 1.1 MB |

So pass `-collect-test-diagnostics never` for agent and CI runs. Turn it back on (`on-failure`) only when you need a sysdiagnose to debug a crash. Each `Test Case ... passed` or `failed` line reaches the log before that wait (only `** TEST FAILED **` comes after it), so a script can read results without waiting for the process.

## Run in the background and poll

UI test runs take minutes. An agent should start the run in the background, write the log to a file, and check it:

```bash
( xcodebuild test ... -collect-test-diagnostics never > build/ui-tests.log 2>&1; echo "EXIT $?" >> build/ui-tests.log ) &
# later:
grep -E "^Test Case .*(passed|failed)|\*\* TEST|^EXIT" build/ui-tests.log
```

- `** TEST SUCCEEDED **` (or `** TEST EXECUTE SUCCEEDED **` for `test-without-building`) and `** TEST FAILED **` mark the end.
- Each test prints `Test Case '-[Target.Class testName]' passed (N seconds)` or `failed`.
- A failed assertion prints `path/File.swift:LINE: error: -[Target.Class testName] : message`.

## Read the result bundle

```bash
xcrun xcresulttool get test-results summary --path build/UITests.xcresult        # totals + every failure
xcrun xcresulttool get test-results tests --path build/UITests.xcresult          # the test tree with results
xcrun xcresulttool get test-results activities --path build/UITests.xcresult \
  --test-id "BoardUITests/testTapInsideAShape()"                                 # each tap, wait and query
xcrun xcresulttool export attachments --path build/UITests.xcresult --output-path build/attachments
```

- The summary is JSON. Its `result` is `Passed` or `Failed`; `testFailures` lists each failure with `testIdentifierString` and `failureText` (*measured*).
- `export attachments` writes the files plus a `manifest.json` naming each one. *Measured:* a failing UI test came with a screen recording (`.mp4`) and a "Synthesized Event" attachment without any code; screenshots added in `tearDown` were skipped by `--only-failures`.
- Open the bundle in Xcode to see the same report with screenshots ([Running tests and interpreting results](https://developer.apple.com/documentation/xcode/running-tests-and-interpreting-results)).
- `xcrun xcresulttool help` marks `get object` and `graph` as deprecated; use `get test-results`.

## A runner script

`Tools/run-ui-tests.sh`. *Measured:* on the iPhone Duo simulator it printed each test line, then `Passed | passed 2 | failed 0 | skipped 0` and exited 0; with a broken assertion it printed the `FAIL` line with the message and exited 65.

```bash
#!/bin/zsh
# Runs the UI tests on an iPhone Duo simulator, then prints the result summary.
#   Tools/run-ui-tests.sh                                   all UI tests
#   Tools/run-ui-tests.sh -only-testing:AppUITests/BoardUITests
# Settings: PROJECT, SCHEME, DEVICE_ID (a UDID; default: the first "iPhone Duo" on iOS 27.1).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"
PROJECT="${PROJECT:-App.xcodeproj}"
SCHEME="${SCHEME:-App}"
RESULT="build/UITests.xcresult"
LOG="build/ui-tests.log"

if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID=$(xcrun simctl list --json devices available | python3 -I -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next((d["udid"] for runtime, list in devices.items() if runtime.endswith("iOS-27-1")
            for d in list if d["name"] == "iPhone Duo"), ""))')
fi
[[ -n "$DEVICE_ID" ]] || { echo "No iPhone Duo simulator on iOS 27.1. See duo-setup."; exit 1; }

mkdir -p build
xcrun simctl bootstatus "$DEVICE_ID" -b > /dev/null   # xcodebuild gives a new simulator only 60 s to boot
rm -rf "$RESULT"                                       # xcodebuild refuses an existing result path

set +e
xcodebuild test \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "$RESULT" \
  -collect-test-diagnostics never \
  "$@" > "$LOG" 2>&1
STATUS=$?
set -e

grep -E "^Test Case .*(passed|failed)|: error: |\*\* TEST" "$LOG" || true
if [[ -d "$RESULT" ]]; then
  xcrun xcresulttool get test-results summary --path "$RESULT" --compact | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(d["result"], "| passed", d["passedTests"], "| failed", d["failedTests"], "| skipped", d["skippedTests"])
for f in d["testFailures"]:
    print("FAIL", f["testIdentifierString"], "-", f["failureText"])'
fi
exit $STATUS
```

Pass test settings through to the runner with `TEST_RUNNER_` variables: `TEST_RUNNER_DUO_MANUAL_FOLD=1 Tools/run-ui-tests.sh` sets `DUO_MANUAL_FOLD=1` inside the test process (`man xcodebuild`, Xcode 27.1).

## Logic tests

```bash
Tools/run-logic-tests.sh                 # swiftc script, see logic-tests.md
(cd AppCore && xcrun swift test)         # Swift package with Swift Testing
```

Both run on the Mac, need no simulator, and exit non-zero on failure.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Timed out trying to boot simulator after waiting 60.00s" | First boot of a new simulator is slow | `xcrun simctl bootstatus <UDID> -b` first |
| xcodebuild exits at once with an error about the result path | The `.xcresult` path exists | `rm -rf` it first, or use a new name per run |
| xcodebuild sits about 10 minutes after a failure | Diagnostics collection timing out | `-collect-test-diagnostics never` |
| "Incompatible device" from `simctl create` | The iOS 27.1 runtime took only the iPhone Duo in our tries | Use iOS 27.0 for other iPhones |
| A test passes alone and fails in the suite | State left by an earlier test | Launch every test with `-resetState` |
| `Unable to find a destination matching ...` | Wrong name, or no runtime for the deployment target | `xcodebuild -showdestinations -scheme App` |
| Taps or drags do nothing | Points computed from `app.frame` | Use element coordinates ([ui-tests.md](ui-tests.md)) |
| Rotation in a test does nothing on the Duo | `XCUIDevice.shared.orientation` didn't rotate the app (*measured*, closed) | Rotate in Device Hub |
| Wrong Xcode used | `DEVELOPER_DIR` missing | Export it; never `sudo xcode-select` (`duo-setup`) |
