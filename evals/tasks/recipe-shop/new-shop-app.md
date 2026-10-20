---
id: recipe-shop/new-shop-app
skill: recipe-shop
also: duo-patterns, duo-design-system, duo-continuity, duo-testing
title: Build a shop for digital packs with StoreKit
readme: no
fixture: empty
build: yes
lint: yes
checklist: R2 R3 R4 R5 R10
tools: Bash(Tools/*), Bash(./Tools/*), Bash(bash Tools/*), Bash(chmod +x *), Bash(xcrun -sdk macosx swiftc:*), Bash(xcrun --sdk macosx swiftc:*), Bash(swift test:*), Bash(swift build:*)
timeout: 3000
status: ready
---

# Build a shop for digital packs with StoreKit

The agent starts from an empty folder and must produce a whole Xcode project. A product grid on iPhone Duo reflows from the outer to the inner display; open, the fold should fall between columns, so the column count is even ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=456)), and the product page can sit beside the grid. The basket is the state people care about most, so it must outlive every fold (`duo-continuity`). Digital goods sell through in-app purchase, and in Xcode StoreKit purchases can run against a local StoreKit configuration file instead of App Store servers, before the app exists in App Store Connect ([Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)).

## Prompt

```text prompt
Create a new iPhone Duo shop app in this folder that sells digital sound packs: a grid of packs, a pack page, a basket and a checkout. Closed, a pack opens on its own screen. Open, the grid and the pack page sit side by side, and no card straddles the fold. The basket must survive folding and unfolding. Sell each pack, and a subscription that unlocks every pack, with StoreKit, tested with a local StoreKit configuration file: no real products and no network. Use sample packs. Put the basket maths (what is in it, what the person already owns, the total) in plain Swift with tests that run on the Mac without a simulator, and add a script under Tools/ that runs those tests. Build it for the iPhone Duo simulator.
```

## Starting point

An empty folder (`fixture: empty`). With Duology, the `recipe-shop` skill and `/duo-new` can create the project from a template. Without it, the agent has to write the Xcode project itself.

The run with Duology should also get the recipe's own `new-project.sh`, by its exact path in the plugin copy; that needs the script added to `PLUGIN_SCRIPTS` in [`lib/evalkit.py`](../../lib/evalkit.py).

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
# Prices and totals are stored as Decimal or whole cents, never Double or Float.
no_src '(var|let) +[A-Za-z_]*([Aa]mount|[Tt]otal|[Pp]rice|[Ss]ubtotal|[Cc]ost)[A-Za-z_]* *: *(Double|Float|CGFloat)\b'
```

```sh check local-storekit
# Purchases run against a local StoreKit configuration file.
has_src '^ *import +StoreKit'
n="$(find . \( -name .git -o -name DerivedData -o -name build \) -prune -o -name '*.storekit' -type f -print | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || { echo "no .storekit configuration file"; exit 1; }
```

```sh check side-by-side-knows-the-fold
# Grid and product page side by side when open: a split view, an arrangement, or a
# layout that reads the .division reserved region.
has_src 'NavigationSplitView|UISplitViewController|ArrangementView|UIArrangementViewController|reservedRegions'
```

```sh check launches
launch_ok
```

## Checklist

- **R2**: add two packs to the basket, open a pack page, then press Closed and Open in Device Hub. The basket keeps both packs and the same pack stays open.
- **R3**: closed and open, the grid and the pack page fit their windows; no fixed column widths.
- **R4**: partly folded, held wide: no button, price or card sits on the fold.
- **R5**: open, the grid has an even number of columns, so the fold falls between cards.
- **R10**: closed, the basket, checkout and the subscription offer are all reachable.
