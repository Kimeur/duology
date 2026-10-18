# Two-page

Content that comes in pages: books, documents, slides, comics, a photo album, an onboarding flow. Closed, one page at a time. Open and held wide, two pages, one on each side of the fold, like a book.

Prior art: Microsoft's [two-page pattern](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/two-page) for Surface Duo. Apple explains why nothing should straddle the fold with a photo printed across a book's spine in [talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=89).

## Use it when

- The content is already split into pages, or can be.
- Seeing two pages at once helps: facing pages, a slide and the next one, two steps of a tutorial.

Don't use it for a continuous article or feed. Those scroll, and scrolling content can cross the fold ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)). Don't stretch one page across both halves to fill space; Microsoft's guidance is to show a placeholder on the second side instead.

## How it behaves

| State | What shows |
|---|---|
| Closed (outer display) | One page. Page turns move one page. |
| Open, flat, held wide | Two pages. The gap between them sits on the fold line. Page turns move two pages. |
| Open, partly folded like a book | Two pages, each in its own region. The gap is the fold's whole reserved frame. |
| Open, flat, held tall | One tall page. The fold runs across the screen, so a top and bottom "spread" would not read like a book. |
| Open, partly folded across (tabletop) | The gallery shows one page above the fold and a contents list below it, so no line of text sits in the fold. The recipe keeps one tall page that scrolls. That is allowed: scrolling content may cross the fold. |
| Split View, or a narrow window | One page. |

The reader keeps its place in every change. A spread always starts on an even page, so pages don't jump sides when you fold.

## Apple APIs

There is no page or spread API for this. Build it from these:

| Need | API | Availability |
|---|---|---|
| Where the fold is, even when flat | [`reservedRegions(kind:options:layoutDirectionBehavior:)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:)) with `.division` and [`.includeInactive`](https://developer.apple.com/documentation/swiftui/reservedregion/queryoptions/includeinactive), wrapped in `FoldGeometry` (SKILL.md) | iOS 27.1 |
| Re-read it when it changes | [`onGeometryChange(for:of:action:)`](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) | iOS 16 |
| Page turn controls | [`ToolbarItemGroup(placement: .bottomBar)`](https://developer.apple.com/documentation/swiftui/toolbaritemgroup) | iOS 14 |
| The current page after a relaunch | [`@SceneStorage`](https://developer.apple.com/documentation/swiftui/scenestorage) | iOS 14 |
| UIKit | [`reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)) on `UIView` | iOS 27.1 |

You could put the left page in an `ArrangementView` primary and the right page in its secondary. But nothing reports whether the secondary is on screen (see [supporting-pane.md](supporting-pane.md#what-we-measured)), and the reader must know whether a page turn moves one page or two. A custom split that reads the fold directly knows.

## Rules

1. Split at the fold, not at the middle of the view. Bars on the side make the view off-centre on the open phone, so its middle is not the fold.
2. Ask for inactive regions too. Apple says the default query returns only active regions ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=470)), and we measured the same: flat, the default query returned nothing. With `.includeInactive` it returned the fold.
3. Choose two pages only when the fold runs top to bottom (its frame is taller than wide). If no fold crosses the view, fall back to "regular width and wider than tall", so iPad and Mac get spreads too.
4. Keep the left page the same view in both layouts. Add the right page with an `if`, so the left one keeps its identity and scroll position.
5. Put page turns in the system toolbar. System toolbar items move to the side bar and off the fold on their own ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=568)). Swipes are fine too, but keep buttons for VoiceOver and Switch Control.
6. If a page has nothing to face (the last page), leave the right side calm: an end mark, a blank page, or the cover. Don't stretch the last page.

## What we measured

iOS 27.1 iPhone Duo simulator, open, flat, held wide (951 × 669 pt window):

- `reservedRegions(kind: .division)` returned no regions.
- With `.includeInactive` it returned one inactive division: a 40 pt wide frame across the full height, centred on the window, with 20 pt margins on each side. So the fold line itself has zero width, and the 40 pt is the margin Apple adds for interactive content.
- On the first `onAppear` the query returned nothing at all; the values came with the next geometry update. Read regions with `onGeometryChange`, not once in `onAppear`.

In every pose, 18 October 2026, on the gallery's two-page screen. We read the frames with the gallery's region overlay (launch argument `-showsRegions YES`):

| Pose | `.division` region |
|---|---|
| Open, flat, held wide | Inactive, 40 × 669 pt at (455, 17) |
| Partly folded like a book | Active, 40 × 669 pt at (455, 17) |
| Partly folded across (tabletop) | Active, 669 × 40 pt at (0, 455) |

- Folding changes `isActive`, not the frame. Read the frame with `.includeInactive` and the spread lands in the same place flat and folded.
- The page gap matches it. In the [book screenshot](https://github.com/Kimeur/duology/blob/main/docs/assets/gallery/twoPage-book.png) each page card has 12 pt of padding: the left card ends at x = 443 and the right card starts at x = 507.
- The overlay draws in the window's space, which read 951 × 686 pt in book pose. So y = 17 is in that space. The band covers the display from top to bottom.

## Recipe

Needs `FoldGeometry` from SKILL.md. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import SwiftUI

// requires: FoldGeometry (SKILL.md)

@available(iOS 27.1, *)
struct TwoPageReader: View {
    let pages: [String]

    // The first page on screen. Scene storage brings it back after a relaunch.
    @SceneStorage("reader.page") private var page = 0
    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @Environment(\.horizontalSizeClass) private var widthClass

    /// Two pages when a top-to-bottom fold crosses the view, or on a wide, regular-width view.
    private var showsSpread: Bool {
        if fold.frame != nil { return fold.isVertical }
        return widthClass == .regular && size.width > size.height
    }

    /// A spread always starts on an even page, so pages don't shuffle sides.
    private var firstIndex: Int { showsSpread ? page - page % 2 : page }

    var body: some View {
        GeometryReader { proxy in
            let spine = spineFrame(in: proxy.size)
            HStack(spacing: 0) {
                // Same view in both layouts: it keeps its identity when the spread appears.
                PageView(text: text(at: firstIndex))
                    .frame(width: showsSpread ? spine.minX : proxy.size.width)
                if showsSpread {
                    Color.clear.frame(width: spine.width)
                    PageView(text: text(at: firstIndex + 1))
                        .frame(width: proxy.size.width - spine.maxX)
                }
            }
        }
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .toolbar {
            // System toolbar items avoid the fold and move to the side bar on their own.
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Previous Page", systemImage: "chevron.backward") { turn(by: -1) }
                    .disabled(firstIndex == 0)
                Spacer()
                Button("Next Page", systemImage: "chevron.forward") { turn(by: 1) }
                    .disabled(firstIndex + (showsSpread ? 2 : 1) >= pages.count)
            }
        }
    }

    /// The gap between the two pages: the fold itself when there is one, else a centred gutter.
    private func spineFrame(in size: CGSize) -> CGRect {
        if fold.isVertical, let frame = fold.frame { return frame }
        let gutter: CGFloat = 32
        return CGRect(x: (size.width - gutter) / 2, y: 0, width: gutter, height: size.height)
    }

    private func turn(by direction: Int) {
        let step = showsSpread ? 2 : 1
        page = min(max(firstIndex + direction * step, 0), max(pages.count - 1, 0))
    }

    private func text(at index: Int) -> String {
        pages.indices.contains(index) ? pages[index] : ""
    }
}

struct PageView: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
```

Put `TwoPageReader` inside a `NavigationStack` so the bottom bar has a toolbar to live in.

## Pitfalls

- **Splitting at `width / 2`.** On the open phone the content area is not centred on the fold. With no bars on screen, a full-screen view measured 867 pt wide in the 951 pt window, and the screenshot showed the status bar in an 84 pt column down the trailing edge. The fold sits at the window's centre, not the content's.
- **Only the default query.** It returns nothing while the phone is flat, so the reader shows one stretched page until someone folds it.
- **Odd spreads.** If page 3 is on the left when open, closing and reopening can show 3 and 4, then 2 and 3. Snap spreads to even pages.
- **Spreads in the tall layout.** Held tall, the fold runs across. Two pages stacked top and bottom don't read like a book.
- **Rebuilding pages on every fold.** `if showsSpread { SpreadView() } else { PageView() }` makes a new view tree and resets each page's scroll position.

## Test it

1. Closed: one page; Next moves one page.
2. Open, held wide: two pages, gap on the fold line; Next moves two.
3. Partially Open: no text or button in the fold.
4. Go to page 5 open (pages 4 and 5 show), close (page 4 shows), open again (4 and 5).
5. Open, held tall: one page.
6. Partially Open, then Rotate Right once (tabletop): no button sits in the fold.
7. Run in a right-to-left language: the first page should sit on the right and the gap should stay on the fold. SwiftUI mirrors region frames by default ([`ReservedRegion`](https://developer.apple.com/documentation/swiftui/reservedregion)); we have not tested this screen in right-to-left. (unverified)

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/TwoPageView.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/TwoPageView.swift)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (hub), D4 (Device Hub poses), V3 (talk 111463), V6 (talk 111466), P1d (Microsoft two-page).
