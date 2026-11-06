---
id: duo-performance/cheap-fold
skill: duo-performance
also: duo-transitions, duo-layout, duo-continuity
title: Make opening and closing the phone cheap
readme: no
fixture: Ledger
project: Ledger.xcodeproj
scheme: Ledger
build: yes
lint: yes
checklist: R2 R10 R12
timeout: 1800
status: ready
---

# Make opening and closing the phone cheap

Opening iPhone Duo changes the app's layout size in several steps: `duo-transitions` measured a full-width view going 382 → 466 → 951 → 867 pt on the simulator, and every view that reads the size runs its `body` again at each step. At 120 Hz a frame lasts 8.3 ms ([Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)), so whatever a `body` does, a fold does several times while the person watches.

## Prompt

```text prompt
Our ledger screen freezes for a second or more every time someone opens or closes the phone, and the list jumps back to the top. Make opening and closing smooth. Keep what the screen shows: the total, the list newest first with the payee, date and amount, and the totals by category beside the list when the phone is open.
```

## Starting point

Fixture [`Ledger`](../../fixtures/Ledger): a ledger of 2,000 entries with a total, the list and, on the open phone, totals by category. iOS 17 target, Swift 5. duo-lint finds nothing: every problem is work a fold redoes.

- The screen reads the size with a `GeometryReader` and, in the same `body`, sorts the 2,000 entries and adds them up.
- An `if` on the width builds the list once in each branch, and `.id(proxy.size.width)` makes a new screen at every resize step: the scroll position and the selection reset.
- The list is a plain `VStack` in a `ScrollView`: all 2,000 rows are laid out at every step.
- Each row has its own `GeometryReader`, and creates a `DateFormatter` and a `NumberFormatter` in `body`.
- The totals by category are grouped, summed and sorted in `body`; the total's `NumberFormatter` too.

*Measured* on the iPhone Duo simulator (6 November 2026, Release build, `duo-fold-cost`, 3 cycles): opening took a median longest main-thread stretch of 2,913 ms (4,370 ms busy), closing 1,645 ms. A hand-fixed copy (a model that sorts and formats once, the size read once as one Boolean, `AnyLayout`, `LazyVStack`, plain rows, no `.id`) took 86 ms and 15 ms, and passes every check below. The fold cost itself isn't a check: the eval account can't run `duo-pose`.

## Pass checks

Gates: builds for the iPhone Duo simulator; duo-lint reports nothing.

```sh check shows-the-same
for id in '"ledger.total"' '"ledger.list"' '"entry\.'; do
  has_src "$id"
done
```

```sh check body-stays-cheap
# Nothing a fold would redo at each resize step: no formatter made, nothing sorted,
# grouped or summed over the entries inside a body.
pycheck body_work.py 'DateFormatter\(' 'NumberFormatter\(' '\.sorted *[({]' 'Dictionary\(grouping' '\.reduce\('
```

```sh check rows-are-lazy
# Only the rows on screen are laid out.
has_src 'LazyVStack|LazyVGrid|\bList *[({]'
```

```sh check identity-kept
# No new identity at each size, and the size is read in one place at most.
no_src '\.id\([^)]*(width|height|size|proxy|[Ww]ide|[Nn]arrow|columns|[Ss]izeClass)'
geo="$(count_src 'GeometryReader')"
if [ "$geo" -gt 1 ]; then
  echo "GeometryReader in $geo places: read the size once, high up"
  src_grep 'GeometryReader'
  exit 1
fi
```

```sh check list-built-once
# The entry list is built in one place, so the fold keeps it (and its scroll position).
# Renamed: the check says so and passes, and R2 decides.
# Previews, comments and strings don't count.
n="$(pycheck body_work.py --count '(^|[^A-Za-z0-9_.])EntryList *\(')"
if [ "$n" -gt 1 ]; then
  echo "EntryList is built in $n places"
  exit 1
fi
[ "$n" -eq 1 ] || echo "note: EntryList was renamed or replaced, so the checklist decides"
```

```sh check launches
launch_ok
```

## Checklist

The reviewer scrolls the list a little, taps a row, then presses Open, Closed and Open in Device Hub. Optionally, `duo-fold-cost run com.example.ledger` with the plugin installed:

- **R12**: no freeze, blank frame or jump when the phone opens or closes.
- **R2**: the scroll position and the selected row are the same after each change.
- **R10**: the total and the list show closed; the totals by category show open.
