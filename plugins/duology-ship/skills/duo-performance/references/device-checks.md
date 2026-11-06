# Device checks

Nothing in `duo-performance` has run on a real iPhone Duo. Run these on one, and update the skill with what you find.

| Check | How | What we expect | What would change this skill |
|---|---|---|---|
| Folds at 120 Hz | Instruments, Animation Hitches template, attached to a Release build; press Open and Close by hand, five times each | Hitches only where `duo-fold-cost` showed long stretches on the simulator | Hitches where the simulator showed none: the simulator numbers would need a device factor, or would rank causes wrongly |
| How simulator numbers map to the device | The same build: `duo-fold-cost` on the Mac, the Hangs and Time Profiler instruments on the phone, for the same folds | A different scale, the same order between causes | If the order changes, Step 3's table needs device numbers |
| The SwiftUI instrument | Instruments, SwiftUI template, on the device | Long view body updates in the `body` properties this skill names | Other causes on top: add them to Step 3 |
| `XCTHitchMetric` | A UI test that scrolls a long list closed and open (the pose set by hand before each run) | Hitch time ratio per run | A metric worth adding to Step 4 |
| The first fold after launch | Five folds right after launch, with the Hitches instrument | The first costs the most, as on the simulator | If not, drop that note |
| MetricKit per pose | The `FoldMetrics` code in [field.md](field.md), a day of use, then the report's `stateEntries` | One entry per pose with hitch time, and `Fold` signpost intervals with hitch time | If no state entries come, or the pose labels are missing, fix field.md |
| Fold intervals from MetricKit's log handle | Instruments, os_signpost, on the device | `Fold` intervals around each fold | On the simulator they didn't appear |
| Low Power Mode and heat | Repeat the 120 Hz check with Low Power Mode on | Lower rates, and the same causes | — |
| Images during a fold | A gallery decoding at view size, then with [the ImageIO fix](fixes.md#images-decode-once-for-the-largest-display) | Fewer and shorter stretches with the fix | If no difference, drop that row from Step 3 |

Record the device, iOS build, Xcode build and date with each result, as in [evidence.md](evidence.md).
