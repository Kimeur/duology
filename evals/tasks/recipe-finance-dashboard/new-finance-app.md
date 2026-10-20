---
id: recipe-finance-dashboard/new-finance-app
skill: recipe-finance-dashboard
also: duo-patterns, duo-design-system, duo-continuity, duo-testing
title: Build a personal finance dashboard
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R3 R4 R5 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 3000
status: ready
---

# Build a personal finance dashboard

The agent starts from an empty folder and must produce a whole Xcode project. The open phone is where a dashboard earns its place: Apple's Duo guidance has the open phone show more of the same app, not a different one, with even columns where a fold crosses a grid and nothing interactive on the fold ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456), [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)). Money needs exact arithmetic: `Double` sums drift by fractions of a cent.

## Prompt

```text prompt
Create a new iPhone Duo personal finance app in this folder. Closed, it shows the balance and recent spending. Open, it shows the balance, a spending chart and the list of transactions side by side, and tapping a transaction shows its details. Use sample data. Put the money maths (balances, totals by category, this month's spending) in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs those tests. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-finance-dashboard` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

The extra `tools:` let the agent run scripts under `Tools/` and compile Swift for the Mac. The run with Duology also gets the recipe's own `new-project.sh`, by its exact path in the plugin copy (`PLUGIN_SCRIPTS` in [`lib/evalkit.py`](../../lib/evalkit.py)).

## Pass checks

Gates: an Xcode project in the folder builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check one-project
n="$(find . \( -name .git -o -name DerivedData \) -prune -o -name '*.xcodeproj' -type d -print | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "no Xcode project"; exit 1; }
```

```sh check logic-tests-pass
# At least one test script under Tools/ runs without the simulator, and every such
# script passes. Scripts that drive the simulator are skipped here.
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

```sh check money-is-exact
# Amounts, balances and totals are stored as Decimal or whole cents, never Double or Float.
no_src '(var|let) +[A-Za-z_]*([Aa]mount|[Bb]alance|[Tt]otal|[Ss]pent|[Pp]rice)[A-Za-z_]* *: *(Double|Float|CGFloat)\b'
```

```sh check open-layout-knows-the-fold
# Side by side when open, without a pane or a chart under the fold: a split view, an
# arrangement, or a layout that reads the .division reserved region.
has_src 'NavigationSplitView|UISplitViewController|ArrangementView|UIArrangementViewController|reservedRegions'
```

```sh check launches
launch_ok
```

## Checklist

- **R2**: open a transaction's details, then press Closed and Open in Device Hub. The same transaction stays selected, and the dashboard keeps its scroll position.
- **R3**: closed and open, every card fits its window; no column has a fixed width with dead space beside it.
- **R4**: partly folded, held wide: no button, row or chart sits on the fold.
- **R5**: open, cards sit in an even number of columns, so the fold falls between them.
- **R10**: closed, the details of a transaction are still reachable, and the chart is too, one tap away at most.
