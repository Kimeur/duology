---
id: duo-testing/logic-tests
skill: duo-testing
title: Logic tests that run on the Mac in seconds
readme: no
fixture: Places
project: Places.xcodeproj
scheme: Places
build: yes
lint: no
tools: Bash(Tools/run-logic-tests.sh:*), Bash(./Tools/run-logic-tests.sh:*), Bash(bash Tools/run-logic-tests.sh:*), Bash(chmod +x Tools/run-logic-tests.sh), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 1800
status: ready
---

# Logic tests that run on the Mac in seconds

The extra `tools:` let the agent compile Swift for the Mac and run the script it is asked to write.

## Prompt

```text prompt
Add tests for the search and sort rules in Places/List/PlaceFilter.swift. They must run on the Mac in seconds, without the simulator. Add a script, Tools/run-logic-tests.sh, that runs them and exits with a non-zero code when a test fails. Don't change PlaceFilter.swift or Place.swift.
```

## Starting point

Fixture [`Places`](../../fixtures/Places). `PlaceFilter` is plain Swift (Foundation only): `filter(_:query:)` matches every word of the query against name, region and summary, ignoring case and accents; `sort(_:by:)` sorts by name, rating or region. The project has no unit test target.

## Pass checks

Gate: the app still builds for the iPhone Duo simulator.

```sh check rules-unchanged
unchanged Places/List/PlaceFilter.swift Places/List/Place.swift
```

```sh check tests-pass
[ -f Tools/run-logic-tests.sh ] || { echo "Tools/run-logic-tests.sh is missing"; exit 1; }
bash Tools/run-logic-tests.sh
```

```sh check no-simulator
[ -f Tools/run-logic-tests.sh ] || { echo "Tools/run-logic-tests.sh is missing"; exit 1; }
if grep -nE 'simctl|xcodebuild +test|-destination|iphonesimulator' Tools/run-logic-tests.sh; then
  echo "the logic tests must not need the simulator"
  exit 1
fi
```

```sh check catches-filter-bug
# Break the filter (every query matches everything); the tests must fail.
[ -f Tools/run-logic-tests.sh ] || { echo "Tools/run-logic-tests.sh is missing"; exit 1; }
f=Places/List/PlaceFilter.swift
cp "$f" "$TRIAL/PlaceFilter.swift.orig"
trap 'cp "$TRIAL/PlaceFilter.swift.orig" "$f"' EXIT
python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "guard !words.isEmpty else { return places }"
assert old in s, "PlaceFilter.swift changed; can't apply the mutation"
open(p, "w").write(s.replace(old, "return places"))
PY
if bash Tools/run-logic-tests.sh > "$TRIAL/mutant-filter.log" 2>&1; then
  echo "the tests still pass when filter() ignores the query"
  exit 1
fi
```

```sh check catches-sort-bug
# Reverse the rating order; the tests must fail.
[ -f Tools/run-logic-tests.sh ] || { echo "Tools/run-logic-tests.sh is missing"; exit 1; }
f=Places/List/PlaceFilter.swift
cp "$f" "$TRIAL/PlaceFilter.swift.orig2"
trap 'cp "$TRIAL/PlaceFilter.swift.orig2" "$f"' EXIT
python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "? $0.rating > $1.rating"
assert old in s, "PlaceFilter.swift changed; can't apply the mutation"
open(p, "w").write(s.replace(old, "? $0.rating < $1.rating"))
PY
if bash Tools/run-logic-tests.sh > "$TRIAL/mutant-sort.log" 2>&1; then
  echo "the tests still pass when rating sort is reversed"
  exit 1
fi
```
