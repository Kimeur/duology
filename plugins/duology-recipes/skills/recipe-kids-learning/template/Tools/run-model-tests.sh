#!/bin/bash
# Builds the model (__APP_NAME__/Model, Foundation and CoreGraphics only) with a small test
# program and runs it on this Mac: the parental gate, the activities, progress, the layouts,
# and the privacy checks on the app's sources and privacy manifest. No simulator, a few seconds.
#   Tools/run-model-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/__APP_NAME__-model.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT

# Same language mode and default isolation as the app target, so the model's
# `nonisolated` types are checked the way the app compiles them.
xcrun --sdk macosx swiftc -swift-version 6 -default-isolation MainActor \
  -o "$OUT_DIR/model-tests" \
  __APP_NAME__/Model/*.swift Tools/ModelTests/main.swift

# The privacy checks read __APP_NAME__/ and the project file, from the project folder.
"$OUT_DIR/model-tests"
