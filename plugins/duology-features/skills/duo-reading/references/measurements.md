# What we measured

Every *measured* line in this skill comes from the runs below.

## Method

- **Probe app.** A small SwiftUI app built with `swiftc` against the iOS 27.1 simulator SDK (Xcode 27.1, 27A9275), no Xcode project. It runs the skill's code as published (`Paginator`, `PageTextView`, `PagedReader`, `ReaderWithNotes`, `PDFSpread`, `FoldGeometry`), plus log lines. The reader sits in a `NavigationStack`, as `BookScreen` shows.
- **Text.** One generated chapter of 120 paragraphs, 44,516 characters, at the Large text size unless a run says otherwise. The place starts at character 20,000.
- **Device.** The shared "iPhone Duo" simulator, iOS 27.1, 20 October 2026.
- **Poses.** `duo-pose` from `duo-pose-matrix` pressed Device Hub's buttons: Closed, Open, Partially Open (book), then Rotate Right (tabletop). Going from tabletop back to closed passes through Rotate Right three more times, so the log shows wide and tall sizes in a row there.
- **Evidence.** A log line each time the reader paginates, and one for every size the reader is given, plus a screenshot of the display in use after each pose.
- **Touch.** UI tests (XCUITest, `xcodebuild test-without-building`) in an Xcode project that runs the same code, one run per pose.
- **Caveats.** Other probes shared the simulator. We kept only steps where the log shows the expected size and fold.

## Pages in each pose

Log lines from one run, timestamps removed. `first` is the zero-based index of the first page on screen; `firstRange` is that page's characters.

```text
reader size=(382.0, 620.0) fold=nil active=false mode=single page=(342.0, 580.0) pages=48 offset=20000 first=21 firstRange=19515..<20417
reader size=(867.0, 611.0) fold=Optional((455.5, -24.0, 40.0, 669.0)) active=false mode=spread page=(331.5, 571.0) pages=50 offset=20000 first=22 firstRange=19515..<20409
reader size=(669.0, 835.0) fold=Optional((0.0, 373.5, 669.0, 40.0)) active=true mode=tabletop page=(629.0, 333.5) pages=48 offset=20000 first=21 firstRange=19620..<20575
reader size=(867.0, 611.0) fold=Optional((455.5, -24.0, 40.0, 669.0)) active=true mode=spread page=(331.5, 571.0) pages=50 offset=20000 first=22 firstRange=19515..<20409
reader size=(382.0, 620.0) fold=nil active=false mode=single page=(342.0, 580.0) pages=48 offset=20000 first=21 firstRange=19515..<20417
```

Open, flat and held tall, from an earlier run of the same code:

```text
reader size=(669.0, 787.0) fold=Optional((0.0, 373.5, 669.0, 40.0)) active=false mode=single page=(629.0, 747.0) pages=21 offset=20000 first=9 firstRange=18994..<21194
```

- Every pose showed the page that holds character 20,000.
- Flat (`active=false`) and book (`active=true`) gave the same 50 pages and the same spread. Folding into book didn't paginate again.
- In the book screenshot the text of the leading page ran from x = 62 to 393 pt and the trailing page from x = 516 to 846 pt. The fold frame (455.5 to 495.5 pt) was empty, and the page turn buttons sat in the vertical bar on the trailing edge.

## Sizes during a change

`PagedReader` logs every size it is given (`reader raw size`) and every pagination. Opening the phone, from closed:

```text
reader raw size=(382.0, 562.0)
reader raw size=(382.0, 514.0)
reader raw size=(466.0, 514.0)
reader raw size=(466.0, 505.0)
reader raw size=(951.0, 505.0)
reader raw size=(867.0, 505.0)
reader raw size=(867.0, 611.0)
reader size=(867.0, 611.0) ... mode=spread ... pages=50
```

Seven sizes in 0.2 s, then one pagination 0.26 s after the last size. Rotating from book into tabletop sent six sizes, then one pagination. The 200 ms wait turns each burst into one pagination.

## Timing

| Text | Pages | Time on the simulator |
|---|---|---|
| The 44,516-character chapter, 342 × 580 pt pages | 48 | 0.044 s and 0.151 s in two runs |
| 558,134 characters (1,500 paragraphs), 415 × 560 pt pages | 521 | 1.1 s, 2.7 s, 2.9 s and 3.1 s in four runs |

The simulator runs on the Mac's CPU, and other work shared it during the slower runs. Device speed is unverified.

## Accessibility text size

Launched with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`. The reader logged `type=accessibility5`. Other probes moved the pose during this run, so the poses came in an odd order; each line is still one pose.

```text
reader size=(669.0, 787.0) fold=Optional((0.0, 373.5, 669.0, 40.0)) active=false mode=single page=(629.0, 747.0) type=accessibility5 pages=165 offset=20000 first=74 firstRange=19975..<20234
reader size=(669.0, 835.0) fold=Optional((0.0, 373.5, 669.0, 40.0)) active=true mode=tabletop page=(629.0, 333.5) type=accessibility5 pages=391 offset=20000 first=176 firstRange=19967..<20054
reader size=(867.0, 611.0) fold=Optional((455.5, -24.0, 40.0, 669.0)) active=true mode=spread page=(331.5, 571.0) type=accessibility5 pages=444 offset=20000 first=198 firstRange=19808..<19915
reader size=(382.0, 620.0) fold=nil active=false mode=single page=(342.0, 580.0) type=accessibility5 pages=430 offset=20000 first=193 firstRange=19975..<20077
```

- The place held in every pose. In book, character 20,000 was on the trailing page: the spread starts on an even page, and the leading page ended at 19,915.
- A closed page held about 100 characters at this size, against about 900 at Large.

## Notes beside the page

Launched closed with the notes open (`ReaderWithNotes`, `-showNotes YES`):

```text
reader size=(382.0, 620.0) fold=nil active=false mode=single page=(342.0, 580.0) pages=48 offset=20000 first=21 firstRange=19515..<20417
reader size=(455.5, 611.0) fold=nil active=false mode=single page=(415.5, 571.0) pages=41 offset=20000 first=18 firstRange=19641..<20783
reader size=(382.0, 620.0) fold=nil active=false mode=single page=(342.0, 580.0) pages=48 offset=20000 first=21 firstRange=19515..<20417
```

- Closed: the notes showed as a sheet over the page, with Done.
- Open: the sheet went away and the notes sat on the trailing side, after the fold. The reader took the leading region (455.5 pt wide) and showed one page. The fold reads `nil` there because it lies on the reader's trailing edge, not inside it.
- Closed again: one page at 382 × 620 pt, and the sheet came back.
- An earlier version put `.navigationTitle("Notes")` on the editor. Open, its large title sat over the reader, which measured 455.5 × 553 pt.

## The frame pitfall, reproduced

The same reader with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)`, without `minWidth: 0` and `minHeight: 0`:

```text
reader size=(382.0, 620.0) ... mode=single page=(342.0, 580.0)
reader size=(951.0, 620.0) fold=Optional((497.5, -19.5, 40.0, 669.0)) active=false mode=spread page=(373.5, 580.0)
reader size=(951.0, 835.0) fold=Optional((141.0, 373.5, 669.0, 40.0)) active=true mode=tabletop page=(911.0, 333.5)
reader size=(951.0, 620.0) fold=nil active=false mode=single page=(911.0, 580.0)
```

Once the reader had measured 951 pt, it never shrank: 951 pt wide in tabletop's 669 pt window, and 951 pt on the closed phone, whose reader space is 382 pt. Held wide it took 951 pt of an 867 pt space, centred, so 42 pt hung off each side and the fold read at x = 497.5 instead of 455.5. Pages were cut off on both sides.

## PDF

`PDFSpread` with an eight-page generated PDF, opened at page 3:

```text
pdf update twoUp=true mode=2 frame=(0.0, 0.0, 783.0, 635.0) page=2
pdf update twoUp=false mode=1 frame=(0.0, 0.0, 669.0, 835.0) page=1
```

Modes are `PDFDisplayMode` raw values: 1 is `.singlePageContinuous`, 2 is `.twoUp`. Pages are zero-based. Screenshots: held wide and in book, the two pages met at x = 471 to 480 pt, around the fold's centre (475.5). With `displaysAsBook = true`, page 1 sat alone in the middle, across the fold.

## Add to Notes, by UI test

A UI test (XCUITest) launched the reader with `ReaderWithNotes`, held a finger on the first page for 1.2 s, tapped Add to Notes in the edit menu, then read the notes editor.

| Pose | First page (text view frame) | Notes after Add to Notes |
|---|---|---|
| Closed | (20, 44), 342 × 580 pt | in the sheet, with the quoted word |
| Book | (62, 44), 331.7 × 571 pt | beside the page, at x = 523.7 pt, after the fold |
| Tabletop | (20, 102), 629 × 333.7 pt: above the fold at 455.5 | in the sheet |

With the action appended after the system's eight suggestions, the menu's first page listed only Copy, Look Up, Translate and Search Web, and the test couldn't find Add to Notes. With the action first, it passed in all three poses.

## Drag and selection defaults

```text
launch probe=notes dragDefault=true textViewDrag=true
```

`UIDragInteraction.isEnabledByDefault` and a new `UITextView`'s `textDragInteraction?.isEnabled` were both `true`, in every launch.
