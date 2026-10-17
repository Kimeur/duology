#!/bin/bash
# Builds the game engine (__APP_NAME__/Engine, Foundation only) with a small test
# program and runs it on this Mac. No simulator, no Xcode project, a few seconds.
#   Tools/run-engine-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}"

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/__APP_NAME__-engine.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT

# Same language mode and default isolation as the app target, so the engine's
# `nonisolated` types are checked the way the app compiles them.
xcrun --sdk macosx swiftc -swift-version 6 -default-isolation MainActor \
  -o "$OUT_DIR/engine-tests" \
  __APP_NAME__/Engine/*.swift Tools/EngineTests/main.swift

"$OUT_DIR/engine-tests"
