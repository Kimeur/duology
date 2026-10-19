# Frames, sizes and where the fold is

What to ask for, how to tell frames apart, and where the fold and cameras sit on each one. Labels: *measured* means we ran code on the iPhone Duo simulator (Xcode 27.1, iOS 27.1). *Derived* means arithmetic on measured or Apple numbers. *Unverified* means nobody has checked it yet.

Use these numbers to read pictures. Never put them in app code: Apple tells you to size from the view, window or scene ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

## Names for the ways people hold the phone

Apple has no pose API and no pose names in code. The hinge reports only `closed`, `partiallyOpen` and `fullyOpen` ([`DeviceHinge.Status`](https://developer.apple.com/documentation/swiftui/devicehinge/status-swift.struct)). Device Hub's buttons say Closed, Partially Open and Open ([Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). Use these labels in a report:

| Label in the report | Apple's description | Display | Fold |
|---|---|---|---|
| Closed, portrait / landscape | closed | Outer | None |
| Open, held wide | "open in a wide layout" | Inner, landscape | Top to bottom, flat |
| Open, held tall | "open in a tall layout" | Inner, portrait | Side to side, flat |
| Partly folded like a book (Duology: "book") | "partially folded, like a book" | Inner, held wide | Top to bottom, active |
| Propped on a table like a laptop (Duology: "tabletop") | "seated on a table like a laptop" | Inner, held tall | Side to side, active |
| Folded like a tent | "folded like a tent" | Outer, landscape (talk 111461 suggests supporting landscape for it) | None on the display in use |
| Open, turned around | "flip the device" | Outer, with the rear camera facing the person | None |
| Split View, left / right | "50/50 split" | Inner | As the pose |

Sources: [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Device-poses), [hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/?time=166), [talk 111465](https://developer.apple.com/videos/play/tech-talks/111465/?time=166), [talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=28). The full list of Apple's phrases is in [`reference/device-facts.md`](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#poses).

## Sizes

| Frame | Screenshot px | Points | Size classes | Bars |
|---|---|---|---|---|
| Closed, portrait | 1398 × 2034 | 466 × 678 (*measured*: window) | compact width, regular height | Vertical, trailing edge |
| Closed, landscape | 2034 × 1398 | 678 × 466 (*derived*) | compact, compact | Vertical, on the side |
| Open, held wide | 2853 × 2007 | 951 × 669 (*measured*) | regular, regular | Vertical, on the side |
| Open, held tall | 2007 × 2853 | 669 × 951 (*measured* in tabletop, gallery overlay) | regular, regular | Horizontal |

- Screenshot sizes match Apple's App Store sizes ([screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)). Apple's specs page gives 1878 × 2670 for the inner panel; screenshots and the simulator still come out at 2007 × 2853. See [`device-facts.md`](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#two-inner-display-resolutions).
- Size classes per display: [talk 111461, 2:59](https://developer.apple.com/videos/play/tech-talks/111461/?time=179). Bars: [HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls).
- Not measured yet: Split View halves, the space under a pinned PiP video, and the window while folded like a book. Don't quote a number for them. The gallery's region overlay reads 951 × 686 pt held wide, but that is its own view, 17 pt taller than the display, not the window (see [Partly folded](#partly-folded)).

## Where the fold and cameras are

### Closed, portrait (outer display)

*Measured* with the debug overlay in SKILL.md, app built with the iOS 27.1 SDK, fresh simulator (it boots closed):

| Item | Points | Pixels |
|---|---|---|
| Window | 466 × 678 | 1398 × 2034 |
| Safe area | 382 × 644; insets trailing 84, bottom 34, top and leading 0 | |
| Occlusion: outer camera | x 399.7–436.7, y 29.3–66.3 (37 × 37) | x 1199–1310, y 88–199 |
| Occlusion: top of the trailing column | x 382–466, y 0–174 | x 1146–1398, y 0–522 |
| Fold | none, even with `.includeInactive` | |

The trailing 84 pt column holds the status bar and Dynamic Island at the top and the app's vertical bar below. Apple doesn't label the 84 × 174 region; our reading is that it covers the status bar. A toolbar's Close and Done items drew in the column just below it, and the bottom group at the bottom.

### Open, held wide, flat (inner display)

*Measured* by `duo-layout`'s probe ([reserved regions](https://github.com/Kimeur/duology/blob/main/plugins/duology/skills/duo-layout/references/reserved-regions.md)), fully open at 180°:

| Item | Points | Pixels |
|---|---|---|
| Window | 951 × 669 | 2853 × 2007 |
| Fold line | x 475.5 | x 1426.5 |
| Fold region (inactive, flat) | x 455–495, full height (the line plus 20 pt margins) | x 1365–1485 |
| Occlusion, active: status bar corner | x 867–951, y 0–124 | x 2601–2853, y 0–372 |
| Occlusion, inactive: likely the inner camera | x 677–735, y 21–58 | x 2031–2205, y 63–174 |

### Partly folded

*Measured* with the gallery's region overlay, 18 October 2026, and checked against where it drew the regions in the screenshots ([`duo-patterns` two-page](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-patterns/references/two-page.md#what-we-measured)). Folding changed only `isActive`, never the frame.

| Item | Points | Pixels |
|---|---|---|
| Book: fold region (active) | x 455–495, full height | x 1365–1485 |
| Book: occlusions | same as open, held wide | |
| Tabletop: fold region (active) | y 455–495, full width | y 1365–1485 |
| Tabletop, occlusion, active: status bar corner | x 525–669, y 0–82 | x 1575–2007, y 0–246 |
| Tabletop, occlusion, inactive: likely the inner camera | x 611–648, y 677–735 | x 1833–1944, y 2031–2205 |

Held wide, the overlay adds 17 to every y: its own view reads 951 × 686 pt and starts 17 pt above the display. The table gives display points, which match the flat probe above (status bar corner at y 0, camera at y 21). Why its view is taller is *unverified*.

Flag any control inside the fold band. Content above the tabletop band is the part to look at when the phone sits on a table; below it is the part to touch.

### Open, held tall

*Derived*, not measured: the same band as tabletop, y 455–495 pt (1365–1485 px), inactive. Held wide, folding changed only `isActive`.

## Recognise the SDK an app was built with

| What you see | Built with | Source |
|---|---|---|
| Inner display: an iPhone-sized window in the middle, empty space around it. Outer display: content stops left of the status bar and camera. | iOS 26 SDK or earlier | [prepare page](https://developer.apple.com/iphone-duo/prepare/) |
| Inner display: fills most of it, but a strip stays clear by the status bar on the right edge. | iOS 27 SDK | same |
| Edge to edge on both displays; toolbars and tab bars vertical under the status bar. | iOS 27.1 SDK or later | same |

If the screenshots show the first two rows, the main finding is R1: rebuild with Xcode 27.1. Review the layout again after that; many other rules change.

## Capture

- Simulator screenshots: `xcrun simctl io <device> screenshot --display=primary` saves the outer display, `--display=primary-1` the inner display (*measured*). The display that's off comes out black. See `duo-setup` for the full set of commands.
- Device Hub's own screenshot button saves at full resolution to the Desktop ([capturing screenshots](https://developer.apple.com/documentation/xcode/capturing-screenshots-and-videos-from-devices)).
- Poses: only the Closed, Partially Open and Open buttons under the bezel, or Option-drag on the slider for any angle. `simctl` has no pose command ([Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub)). Ask the person to set each pose, or run [`duo-pose-matrix`](https://github.com/Kimeur/duology/blob/main/plugins/duology-ship/skills/duo-pose-matrix/SKILL.md) if they have given Accessibility permission.
- Split View: on the inner display, drag the app by its home indicator to one side, then the other ([talk 111461, 7:30](https://developer.apple.com/videos/play/tech-talks/111461/?time=450)).
- Recordings: `xcrun simctl io <device> recordVideo --display=primary-1 --force out.mov`, stopped with Ctrl-C. The simulator runs at 60 frames per second, so judge continuity, not smoothness.

## Figma and other design files

- Start from Apple's iPhone Duo device bezels and iOS 27 kits in [Apple Design Resources](https://developer.apple.com/design/resources/).
- Frame sizes at 1x: 466 × 678 and 678 × 466 for the outer display, 951 × 669 and 669 × 951 for the inner display.
- Ask for exports at 3x if you will measure in pixels, so the numbers above apply directly. At 1x, Figma pixels are points.
- A frame that isn't one of these sizes is a concept. Review it, but say which display you assumed.
- Look for constraints, auto layout and safe-area guides in the file. Absolute positions and fixed widths are an R3 finding even when the frame looks right.
- Figma can't fold. Ask for a partly folded frame drawn with the fold band marked, or review the flat frame against the band and mark R4 and R7 as Check.
