# Reading the results against duo-design-review

The matrix proves that each screenshot shows the pose it claims. It does not judge the design. That is the job of the `duo-design-review` checklist ([SKILL.md on GitHub](https://github.com/Kimeur/duology/blob/main/plugins/duology-design/skills/duo-design-review/SKILL.md)). This page says how to go from `summary.md` to findings.

## 1. Trust the frames first

Read `summary.md` from top to bottom before you look at any design.

- **`failed` rows.** Fix the capture before you review. "the inner display should be active" means the pose didn't take: look at Device Hub, raise `--wait` or `--timeout`, and rerun that pose. "was not running" means the app quit in that pose: that is a finding in itself (a crash on fold), not a capture problem. Reproduce it in Xcode with the debugger attached.
- **`check` rows.** Another app started during the capture. Open the PNG. If it shows another app, rerun the pose.
- **Fold "not checked".** The picture is open or book, and the tool can't say which. Look for the fold in the image (an overlay helps), or rerun with a readout (see [pose-readout.md](pose-readout.md)). Until then, don't mark a book-only rule (R4, R7) as Pass from that frame.
- **"Pose at the end".** It should match "Pose at the start", or the restore note should explain why not. Tell the user if the simulator was left in another pose.

## 2. Know what each frame is

| File ends in | Display | Size (px) | Points (÷ 3) | Fold in the frame |
|---|---|---|---|---|
| `-closed.png` | outer, portrait | 1398 x 2034 | 466 x 678 | none |
| `-open.png` | inner, held wide, flat | 2853 x 2007 | 951 x 669 | a top-to-bottom line, inactive |
| `-book.png` | inner, held wide, partly folded | 2853 x 2007 | 951 x 669 | top to bottom, active |
| `-tabletop.png` | inner, held tall, partly folded | 2007 x 2853 | 669 x 951 | side to side, active |

Where the fold sits, measured in Duology's gallery when the app fills the display (duo-design-review step 2): x 455 to 495 pt (1365 to 1485 px) in book, y 455 to 495 pt (1365 to 1485 px) in tabletop. Draw that band on the frame before you judge R4. In Split View or a smaller window the band moves; the matrix doesn't capture those.

## 3. Apply the rules each pose can prove

| Pose | Rule | What to look for in this frame |
|---|---|---|
| closed | R1 No letterboxing | Content reaches the edges; no iPhone-sized window with bands; no strip down the trailing edge. |
| closed | R6 Side controls, symbols and titles | Toolbar and tab bar in one vertical bar on the trailing edge; titles next to symbols; nothing hidden under the bar. |
| closed | R10 Same features on the outer display | Every action you see in the open frame is reachable here, at most one level deeper. Compare with `-open.png`. |
| closed, open | R13 Touch targets of 44 pt | Hit areas at least 132 x 132 px in the screenshot. |
| open | R1, R3 No size from the main screen | The layout uses the wide window: no fixed-width column with dead space, nothing sized for the outer display. |
| open, book | R5 Even grids | A grid the fold crosses has an even column count, so the fold lands in a gutter. Count columns on each side of the band. |
| open | R6 | Vertical bar on the side when held wide. |
| book, tabletop | R4 Nothing interactive in the fold | No button, field, slider or handle touches the fold band. Scrolling text may cross it. |
| book | R7 book layout | Two panes or two pages, split at the fold. |
| tabletop | R7 tabletop layout | Things to look at above the fold, controls below, and the same controls as in other poses. |

With `--no-relaunch`, compare each case's frames in order for **R2 State survives fold and unfold**: same screen, same selection, same scroll position, same typed text. With a fresh launch per pose (the default), R2 can't be judged; say so.

## 4. Mark what the matrix can't show

Mark these **Check** in the review and name what would settle them:

| Rule or frame | What settles it |
|---|---|
| R8 Split View and PiP | Frames of each half in Split View, and under a pinned PiP video, set by hand |
| R12 Smooth transitions | A recording: `xcrun simctl io <UDID> recordVideo --display=primary-1 fold.mov` while someone folds |
| Closed, turned sideways | A screenshot after Rotate Right on the closed phone |
| Open, held tall, flat | A screenshot after Open and one Rotate Right |
| R9 Camera preview upright | The capture screen in each pose, on a real device for the cameras |
| R14, R15 Keyboard and drag and drop | Interaction, not a still frame |

## 5. Write findings

Use the duo-design-review format, and point at the file:

```markdown
### Blocker · R4 Nothing interactive in the fold: the Record button sits on the fold
- **Where:** book pose, `memos-book.png`. The Record button spans x 1350-1530 px (450-510 pt); the fold band is 1365-1485 px.
- **Code:** Sources/Memos/RecordBar.swift:31 (if you have the code)
- **Fix:** Move the control group off the fold with `reservedRegions(kind: .division)`. Load `duo-layout`.
- **Source:** HIG, Designing for iPhone Duo
```

Then add a coverage table that lists the matrix's frames as reviewed and the frames from step 4 as missing. With `/duo-audit`, pass the output folder as `--frames <out>` so the audit reviews these screenshots instead of taking its own.
