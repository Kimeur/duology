#!/bin/bash
# Runs the UI tests on the iPhone Duo simulator, on the simulator named in $DEVICE,
# or on any xcodebuild destination in $DESTINATION.
#   Tools/run-ui-tests.sh
#   DEVICE="My Duo" Tools/run-ui-tests.sh -only-testing:__APP_NAME__UITests/__APP_NAME__UITests/testPickingAPackShowsItsDetail
#   DESTINATION="id=<simulator UDID>" Tools/run-ui-tests.sh    # needed for an older iOS runtime
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"
DEVICE="${DEVICE:-iPhone Duo}"
# A name alone picks the latest iOS runtime, so pass an id for a simulator on an older one.
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=$DEVICE}"

# The result bundle goes to build/, which .gitignore leaves out.
RESULT="build/UITests-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p build

# No parallel testing: it would clone the simulator, and a fresh Duo clone can take
# minutes to boot. The tests run on the simulator you named, one after another.
# No test diagnostics: on a failure xcodebuild otherwise collects a system diagnosis,
# which kept a failing run going for about ten more minutes here. Turn it on to report a bug.
xcodebuild test \
  -project __APP_NAME__.xcodeproj -scheme __APP_NAME__ \
  -destination "$DESTINATION" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  "$@"
echo "Results: $RESULT"
