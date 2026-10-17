---
id: recipe-two-player-game/new-game
skill: recipe-two-player-game
also: duo-shared-screen, duo-layout, duo-testing
title: Build a two-player game on one phone
readme: yes
fixture: empty
build: yes
lint: yes
checklist: R1 R3 R4 R13
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 3000
status: ready
---

# Build a two-player game on one phone

A README task. The agent starts from an empty folder and must produce a whole Xcode project.

## Prompt

```text prompt
Create a new iPhone Duo game app in this folder: a two-player tap race. Each player gets half of the screen, on the outer display and on the inner display, in every orientation, and the first to 30 taps wins, with a rematch button. Put the game rules in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs those tests. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-two-player-game` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

The extra `tools:` let the agent run scripts under `Tools/` and compile Swift for the Mac. The run with Duology also gets the recipe's own `new-project.sh`, by its exact path in the plugin copy.

## Pass checks

Gates: an Xcode project in the folder builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check one-project
n="$(find . \( -name .git -o -name DerivedData \) -prune -o -name '*.xcodeproj' -type d -print | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "no Xcode project"; exit 1; }
```

```sh check logic-tests-pass
# At least one test script under Tools/ runs without the simulator, and every such
# script passes. Scripts that drive the simulator (UI test runners, which a project
# may also have) are skipped here; the build gate and `launches` cover the app.
found=0
for s in $(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -path '*/Tools/*' -name '*test*.sh' -print); do
  if grep -qE 'simctl|xcodebuild +test|-destination' "$s"; then
    echo "skipping $s: it drives the simulator"
    continue
  fi
  found=1
  bash "$s" || { echo "$s failed"; exit 1; }
done
[ "$found" = 1 ] || { echo "no test script under Tools/ that runs without the simulator"; exit 1; }
```

```sh check halves-not-arrangement
# A split ArrangementView hides one half on the closed phone held sideways
# (measured by Duology; see duo-layout).
no_src 'ArrangementView'
```

```sh check goal-is-30
has_src '\b30\b'
```

```sh check launches
launch_ok
```

## Checklist

- **R1**: the game fills both displays edge to edge; no letterboxing.
- **R3**: closed upright, closed sideways, open wide and open tall: both halves show and fill their share.
- **R4**: partly folded, no tap target or score crosses the fold.
- **R13**: the rematch button is at least 44 pt; each half is one big tap target.
