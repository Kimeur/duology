# Xcode 27.1 next to an older Xcode

Many Macs keep an older Xcode for shipping work and add Xcode 27.1 for iPhone Duo. This page shows how to use 27.1 for Duo work without changing the Mac-wide default.

Checked on 16 October 2026 on a Mac with Xcode 26.5 (17F42) at `/Applications/Xcode.app` and Xcode 27.1 (27A9275) at `/Applications/Xcode-27.1.app`, macOS 27.0.1.

## How the Mac picks an Xcode

`xcrun` and `xcodebuild` look for a developer directory in this order:

1. The `DEVELOPER_DIR` environment variable, if it is set.
2. The path saved by `xcode-select --switch`, which is Mac-wide.

So `DEVELOPER_DIR` wins for one command or one shell, and touches nothing else (`man xcrun`, `man xcode-select`). We confirmed that `xcode-select -p` itself prints `DEVELOPER_DIR` when the variable is set:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcode-select -p
# /Applications/Xcode.app/Contents/Developer
env -u DEVELOPER_DIR xcode-select -p
# the Mac-wide default, even when your shell exports DEVELOPER_DIR
```

So plain `xcode-select -p` can't tell you the Mac-wide default while the variable is set. Use the `env -u DEVELOPER_DIR` form for that.

## Three ways to use Xcode 27.1

One command:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild -version
```

One shell session:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
xcodebuild -version
xcrun --show-sdk-version --sdk iphonesimulator
```

Agent shells often reset between calls. In that case, prefix every call. Don't rely on an `export` from an earlier call.

A build or test script. Put this guard at the top. It keeps a `DEVELOPER_DIR` the caller already set, falls back to the 27.1 path, and stops unless it finds a working Xcode 27.1 or later:

```sh
#!/bin/sh
# Put this at the top of any build or test script.
set -eu
: "${DEVELOPER_DIR:=/Applications/Xcode-27.1.app/Contents/Developer}"
export DEVELOPER_DIR

# Fail closed: a wrong path or the Command Line Tools give no version.
if ! out=$(xcodebuild -version 2>/dev/null); then
  echo "No usable Xcode at $DEVELOPER_DIR" >&2
  exit 1
fi
version=$(echo "$out" | awk 'NR == 1 { print $2 }')
case $version in
  [0-9]*.[0-9]*) ;;
  *) echo "Can't read the Xcode version at $DEVELOPER_DIR" >&2; exit 1 ;;
esac
major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)

if [ "$major" -lt 27 ] || { [ "$major" -eq 27 ] && [ "$minor" -lt 1 ]; }; then
  echo "Need Xcode 27.1 or later; $DEVELOPER_DIR is Xcode $version." >&2
  exit 1
fi
echo "Using Xcode $version at $DEVELOPER_DIR"
```

We ran it with `sh`, `bash`, `zsh` and `dash`, five ways each. With no variable it passed, because the script's own default is the 27.1 path; the Mac default is never read. Set to Xcode 27.1, it passed. Set to Xcode 26.5, to a mistyped path, or to `/Library/Developer/CommandLineTools`, it stopped with exit 1. A wrong path is the usual CI mistake, for example a runner that installs Xcode at `/Applications/Xcode_27.1.app`.

In CI, set `DEVELOPER_DIR` in the job's environment to the path where the runner installs Xcode 27.1.

## `xcode-select --switch` is the user's call

`sudo xcode-select --switch <path>` changes the default for every terminal, every script and every tool that runs `xcrun`, including Xcode's MCP bridge. It also needs an admin password. Only the user should decide to run it. If they do, `xcode-select -p` shows the result, and the same command with the other path switches back.

## Open the project in the right Xcode

Double-clicking a project opens it in whichever Xcode macOS picks. To be sure, the user opens it from Xcode 27.1, or runs:

```bash
open -a /Applications/Xcode-27.1.app MyApp.xcodeproj
```

We didn't run this one here, because it launches Xcode on the user's screen.

## What is shared between the two Xcodes

- **Simulators and runtimes are shared.** Xcode 26.5's `simctl` lists the same "iPhone Duo" device and the same iOS 26.2 to 27.1 runtimes as Xcode 27.1's. So a simulator list doesn't tell you which Xcode is active. `xcodebuild -version` does.
- **The SDK is not shared.** Xcode 26.5 builds with the iOS 26.5 SDK. On iPhone Duo, an app built with the iOS 26 SDK sits at a familiar iPhone size in the middle of the inner display ([Apple: Three steps](https://developer.apple.com/iphone-duo/prepare/)).
- **Each Xcode has its own tools.** Xcode 27.1 ships `DeviceHub.app` in `Contents/Applications` and no `Simulator.app`. Xcode 26.5 still ships `Simulator.app` in `Contents/Developer/Applications`. Both ship `mcpbridge`.

## First launch and components

Check whether Xcode 27.1 still needs its first-launch setup. Exit code 0 means nothing is pending:

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild -checkFirstLaunchStatus; echo $?
```

If it is pending, ask the user to open Xcode 27.1 once, or to approve `xcodebuild -runFirstLaunch`. Its help says it installs packages *and agrees to the license*, so an agent must not run it on its own.

Missing the iOS 27.1 simulator runtime: the user installs it in Xcode > Settings > Components, or approves this download ([Apple: installing components](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components)):

```bash
DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer xcodebuild -downloadPlatform iOS
```

We confirmed the option in `xcodebuild -help` but did not run it, because it downloads several gigabytes. Apple's page uses `xcode-select -s` before such commands; `DEVELOPER_DIR` selects the Xcode for that one call instead.

## Versions to expect

| Check | Xcode 27.1 on our Mac |
|---|---|
| `xcodebuild -version` | `Xcode 27.1`, `Build version 27A9275` |
| `xcrun --show-sdk-version --sdk iphonesimulator` | `27.1` |
| `xcrun swift --version` | Apple Swift version 6.4 |
| `xcrun simctl list runtimes` | `iOS 27.1 (27.1 - 24A94425)` |
| macOS needed | Tahoe 26.6 or later ([release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)) |

Apple's [Software Releases](https://developer.apple.com/news/releases/) page lists Xcode 27.1 (27A9275) on 15 October 2026. Check the build number, not a page's wording.
