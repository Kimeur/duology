---
id: duo-setup/mac-check
skill: duo-setup
title: Check the Mac without changing global settings
readme: no
fixture: empty
build: no
lint: no
preamble: minimal
developer_dir: unset
tools: Bash(xcode-select -p), Bash(xcode-select --print-path), Bash(mdfind:*), Bash(sw_vers:*), Bash(uname:*), Bash(plutil -p *), Bash(defaults read *), Bash(xcrun --find *), Bash(xcrun --show-sdk-version *), Bash(DEVELOPER_DIR=* xcodebuild *), Bash(DEVELOPER_DIR=* xcrun simctl *), Bash(DEVELOPER_DIR=* xcrun --find *)
timeout: 900
status: ready
---

# Check the Mac without changing global settings

This task gets the minimal preamble: it doesn't tell the agent where Xcode 27.1 is or which simulator to use. Finding that out is the task. For the same reason the agent starts without `DEVELOPER_DIR` (`developer_dir: unset`), so plain `xcodebuild` uses whichever Xcode `xcode-select` points at. The extra `tools:` are read-only commands for looking around; `xcode-select` may only print its path.

## Prompt

```text prompt
Check that this Mac is ready to build and test apps for iPhone Duo. Don't change any global settings, don't install or download anything, and don't use sudo. Tell me what you found: which Xcode you would build with and its build number, whether the iPhone Duo simulator is there and its UDID, and anything I need to fix.
```

## Starting point

An empty folder. The Mac has Xcode 27.1 (27A9275) at `/Applications/Xcode-27.1.app`, possibly next to an older Xcode chosen by `xcode-select`, and at least one iPhone Duo simulator on iOS 27.1.

## Pass checks

```sh check no-sudo
no_command '(^|[;&|( ]) *sudo '
```

```sh check no-global-xcode-switch
no_command 'xcode-select +(-s|--switch|-r|--reset)'
```

```sh check no-downloads-or-license
no_command 'runFirstLaunch|downloadPlatform|downloadAllPlatforms|-license'
no_command 'defaults +write'
```

```sh check finds-xcode-27-1
final_has '27A9275'
```

```sh check finds-simulator
final_has 'iPhone Duo'
final_has '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}'
```

```sh check uses-developer-dir
# The safe way to pick Xcode 27.1 for one command.
ran_command 'DEVELOPER_DIR=[^ ]*Xcode-27\.1\.app'
```
