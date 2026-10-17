# Writing findings

Every review ends in the same shape, so people can compare reviews and track fixes.

## Severity

| Severity | Use it when | Ship? |
|---|---|---|
| **Blocker** | Someone can't finish a task, loses work or state, or can't reach a primary control in a common pose | No |
| **Major** | The design breaks an Apple iPhone Duo rule or looks broken, but people can work around it | Fix in this release |
| **Minor** | Polish; nothing is blocked | When convenient |
| **Check** | You can't judge it from what you have | Get the frame or recording, then judge |

Start from the rule's default severity in [checklist.md](checklist.md). Raise it when the element is the screen's main action. Lower it when the element is rare. Say why when you change it.

## One finding

```markdown
### <Severity> · <Rule ID> <Rule name>: <the problem in a few words>
- **Where:** <display>, <pose>, <screen>. <element> at <position in pt>. <what is wrong there>
- **Fix:** <one or two sentences: the system component or API, and the skill that builds it>
- **Source:** <Apple link, with a timestamp for talks>
```

**Where** always names:

- the display: outer or inner;
- the pose, with the labels in [frames.md](frames.md#names-for-the-ways-people-hold-the-phone): "closed, portrait", "open, held wide", "partly folded like a book" and so on;
- the screen, by its title or purpose;
- the element, by its visible label;
- its position in points (x from the leading edge of the frame, y from the top), when position is the problem.

**Fix** names real APIs only and points to the skill or reference that builds it. It never contains device sizes, hinge angles, `UIScreen.main`, idiom or orientation checks.

**Source** links the Apple page behind the rule. For R13 to R15, link the general HIG page. For anything Apple doesn't say, write "Duology rule".

Group repeats. If the same problem shows on six screens, write one finding and list the screens under **Where**.

## The whole review

```markdown
# iPhone Duo design review: <app or file name>

**Reviewed:** <date>. <n> frames: <list, each with display, pose and size>.
**Missing:** <frames you asked for and didn't get, and the rules they would settle>.
**Verdict:** <Not ready | Ready after fixes | Ready>. <n> Blockers, <n> Majors, <n> Minors, <n> Checks.

## Findings

<Blockers first, then Majors, Minors and Checks. One block per finding.>

## Rule coverage

| Rule | Result |
|---|---|
| R1 No letterboxing | Pass / Fail (finding) / Check / N/A |
| R2 State survives fold and unfold | |
| R3 No size from the main screen | |
| R4 Nothing interactive in the fold | |
| R5 Even grids | |
| R6 Side controls, symbols and titles | |
| R7 Tabletop and book layouts | |
| R8 Split View and PiP work | |
| R9 Camera preview upright | |
| R10 Same features on the outer display | |
| R11 Multiple windows | |
| R12 Smooth transitions | |
| R13 Touch targets of 44 pt | |
| R14 Hardware keyboard | |
| R15 Drag and drop | |

## Not verified

<What needs a real device or a recording: 120 Hz, the feel of the hinge, camera handover, the fold's width while folded.>
```

**Verdict:**

- Any Blocker: **Not ready**.
- Majors but no Blockers: **Ready after fixes**.
- Only Minors and Checks: **Ready**, with the open Checks listed.

Use N/A only when a rule can't apply: R9 for an app with no camera, R5 for a screen with no grid. Never use N/A for a rule you couldn't see; that's Check.

## Worked example

An invented review of an invented recipe app, to show the format. It is not output from a real project.

```markdown
# iPhone Duo design review: recipe app, Figma file "Duo v2"

**Reviewed:** 16 Oct 2026. 6 frames: closed portrait (466 × 678), closed landscape (678 × 466), open held wide (951 × 669), open held tall (669 × 951), partly folded like a book (951 × 669, fold band drawn), propped on a table (669 × 951, fold band drawn).
**Missing:** Split View halves (R8), a closed/open pair of the same moment (R2), a fold recording (R12).
**Verdict:** Not ready. 1 Blocker, 3 Majors, 1 Minor, 3 Checks.

## Findings

### Blocker · R10 Same features on the outer display: no shopping list when closed
- **Where:** Outer display, closed, portrait, Recipe screen. The "Shopping list" pane exists only in the open frames. No closed frame reaches it.
- **Fix:** Add a toolbar item with a title and a symbol that opens the list as a sheet when the width is compact. Pattern: `duo-patterns`, supporting pane.
- **Source:** [HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices).

### Major · R4 Nothing interactive in the fold: the timer button sits on the fold
- **Where:** Inner display, partly folded like a book, Cooking mode. "Start timer" button at x 430–520, y 560–604 pt, across the fold band (x 455–495).
- **Fix:** Place the button in the trailing part while a `.division` region is active; see fixes.md, R4.
- **Source:** [talk 111466, 9:28](https://developer.apple.com/videos/play/tech-talks/111466/?time=568).

### Major · R5 Even grids: three columns on the inner display
- **Where:** Inner display, open held wide and partly folded, Browse screen. 3-column card grid; the fold runs through the middle column.
- **Fix:** Round the column count down to an even number whenever a fold crosses the grid, active or not. Recipe: `duo-patterns`, feed reflow.
- **Source:** [HIG, Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions).

### Major · R6 Side controls, symbols and titles: custom tab bar along the bottom when closed
- **Where:** Outer display, closed, portrait and landscape, all tabs. A custom bottom tab bar, 64 pt tall, plus a top bar with Back and Share.
- **Fix:** Use `TabView` and the toolbar of a `NavigationStack` so the system builds one vertical bar on the trailing edge. Give Share a title. See `duo-navigation`.
- **Source:** [HIG, Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls).

### Minor · R13 Touch targets of 44 pt: small favourite buttons
- **Where:** All displays, Browse screen. Heart buttons on cards are 28 × 28 pt.
- **Fix:** Keep the glyph; grow the hit region to 44 × 44 pt with a frame and a content shape; see fixes.md, R13.
- **Source:** [HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).

### Check · R2, R8, R12: frames missing
- **Where:** Not in the file.
- **Fix:** Send a closed and an open frame of Cooking mode at the same step, both Split View halves, and a recording of a fold.
- **Source:** [checklist.md](checklist.md).

## Rule coverage

| Rule | Result |
|---|---|
| R1 No letterboxing | Pass |
| R2 State survives fold and unfold | Check |
| R3 No size from the main screen | Pass |
| R4 Nothing interactive in the fold | Fail (timer button) |
| R5 Even grids | Fail (Browse grid) |
| R6 Side controls, symbols and titles | Fail (custom tab bar) |
| R7 Tabletop and book layouts | Pass (video on top, steps and timer below, same controls) |
| R8 Split View and PiP work | Check |
| R9 Camera preview upright | N/A |
| R10 Same features on the outer display | Fail (shopping list) |
| R11 Multiple windows | N/A (one window by design) |
| R12 Smooth transitions | Check |
| R13 Touch targets of 44 pt | Fail (favourite buttons) |
| R14 Hardware keyboard | Pass (Command-F opens search in the spec) |
| R15 Drag and drop | Pass (ingredients drag to the shopping list) |

## Not verified

The fold's width while folded, and every behaviour on a real device.
```
