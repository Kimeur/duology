import SwiftUI

/// Two-page: a short book.
///
/// Closed, one page at a time. Open and held wide, two facing pages with the
/// gap on the fold line. Page turns move one page or two to match. The split
/// comes from the `.division` reserved region (iOS 27.1), read with
/// `.includeInactive` so a flat phone still reports where its fold is.
///
/// Pattern guide: `duo-patterns/references/two-page.md`.
struct TwoPageView: View {
    var body: some View {
        NavigationStack {
            BookReader(pages: BookPage.harbourYear)
                .navigationTitle("The Harbour Year")
                .navigationBarTitleDisplayMode(.inline)
                .galleryCloseButton()
        }
    }
}

private struct BookReader: View {
    let pages: [BookPage]

    // The first page on screen. Scene storage brings it back after a relaunch.
    @SceneStorage("book.page") private var page = 0
    @State private var fold = FoldGeometry()
    @State private var size = CGSize.zero
    @Environment(\.horizontalSizeClass) private var widthClass

    /// Two pages when a top-to-bottom fold crosses the view, or on a wide,
    /// regular-width view with no fold (iPad, Mac, earlier systems).
    private var showsSpread: Bool {
        if fold.frame != nil { return fold.isVertical }
        return widthClass == .regular && size.width > size.height
    }

    /// A spread always starts on an even page, so pages don't swap sides when you fold.
    private var firstIndex: Int { showsSpread ? page - page % 2 : page }
    private var step: Int { showsSpread ? 2 : 1 }

    var body: some View {
        GeometryReader { proxy in
            let spine = spineFrame(in: proxy.size)
            HStack(spacing: 0) {
                // The same view in both layouts, so it keeps its identity when the
                // second page appears.
                PageSheet(page: page(at: firstIndex), number: firstIndex, total: pages.count)
                    .frame(width: showsSpread ? spine.minX : proxy.size.width)
                if showsSpread {
                    Color.clear
                        .frame(width: spine.width)
                    PageSheet(page: page(at: firstIndex + 1), number: firstIndex + 1, total: pages.count)
                        .frame(width: max(0, proxy.size.width - spine.maxX))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onFoldChange { fold = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                turn(by: value.translation.width < 0 ? 1 : -1)
            }
        )
        .toolbar {
            // System toolbar items avoid the fold and move to the side bar on their own.
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Previous Page", systemImage: "chevron.backward") { turn(by: -1) }
                    .disabled(firstIndex == 0)
                Spacer()
                Button("Next Page", systemImage: "chevron.forward") { turn(by: 1) }
                    .disabled(firstIndex + step >= pages.count)
            }
        }
    }

    /// The gap between the pages: the fold's whole frame when there is one,
    /// else a centred gutter. Never `width / 2` alone: side bars and the status
    /// bar make the view off-centre on the open phone.
    private func spineFrame(in size: CGSize) -> CGRect {
        if fold.isVertical, let frame = fold.frame { return frame }
        let gutter: CGFloat = 32
        return CGRect(x: (size.width - gutter) / 2, y: 0, width: gutter, height: size.height)
    }

    private func turn(by direction: Int) {
        let target = firstIndex + direction * step
        guard target >= 0, target < pages.count else { return }
        page = target
    }

    private func page(at index: Int) -> BookPage {
        pages.indices.contains(index) ? pages[index] : .end
    }
}

/// One page of paper. It scrolls if the half it sits in is short.
private struct PageSheet: View {
    let page: BookPage
    let number: Int
    let total: Int

    var body: some View {
        ScrollView {
            PageContent(page: page)
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if case .end = page {
                EmptyView()
            } else {
                Text("\(number + 1) of \(total)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .padding(12)
    }
}

private struct PageContent: View {
    let page: BookPage

    var body: some View {
        switch page {
        case .title:
            VStack(spacing: 18) {
                Image(systemName: "water.waves")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(Color(hex: 0x0E7490))
                    .padding(.top, 40)
                Text("The Harbour Year")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Twelve short notes from a fishing town")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Isla Penrose")
                    .font(.subheadline.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }
            .frame(maxWidth: .infinity)
        case .month(let name, let symbol, let text):
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.system(.title, design: .serif).weight(.bold))
                    Spacer()
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(Color(hex: 0x0E7490))
                        .accessibilityHidden(true)
                }
                Rectangle()
                    .fill(Color(hex: 0x0E7490).opacity(0.5))
                    .frame(width: 40, height: 2)
                Text(text)
                    .font(.system(size: 19, design: .serif))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .end:
            VStack(spacing: 12) {
                Image(systemName: "sailboat.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("End of the year")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Sample book

enum BookPage: Hashable {
    case title
    case month(name: String, symbol: String, text: String)
    case end

    static let harbourYear: [BookPage] = [
        .title,
        .month(name: "January", symbol: "snowflake",
               text: "The boats stay in. Nets hang in the sheds like grey curtains, and the people who own them talk about engines over coffee that is mostly milk. The harbour wall takes the weather for all of us. On the calmest mornings you can hear the bell buoy from the bakery, two streets back, ringing for nobody."),
        .month(name: "February", symbol: "wind",
               text: "Wind month. Bins roll down the hill on their own, and the ferry runs when it feels like it. The school puts up a list of who can take whom home. Children learn early which corners to cross quickly. By the end of the month the first daffodils appear along the churchyard wall, flattened and stubborn."),
        .month(name: "March", symbol: "sun.horizon.fill",
               text: "The light comes back before the warmth does. Painters arrive with folding stools and leave with cold hands. Someone always repaints the blue bench by the slipway, and someone else always sits on it too soon. The first crab pots go out, stacked on decks like small brown houses."),
        .month(name: "April", symbol: "cloud.rain.fill",
               text: "Rain that can't decide. The tide tables are pinned behind every bar, and the talk is all about the spring tides, when the water climbs the steps of the lifeboat station and the car park becomes a pond. Visitors start to return, mostly to look at the sea, which has been here all along."),
        .month(name: "May", symbol: "fish.fill",
               text: "Mackerel season. The quay smells of diesel and salt, and children with hand lines crowd the end of the pier from four o'clock. The fish shop writes the catch on a chalkboard each morning. If the board is still blank at noon, the boats did well and nobody had time to update it."),
        .month(name: "June", symbol: "sun.max.fill",
               text: "Long evenings. Nobody goes to bed while it is still light, so nobody goes to bed. The harbour fills with small boats on Sundays, and the rowing club races around the outer buoy and back. The winner buys the drinks, which is why the winner is rarely in a hurry."),
        .month(name: "July", symbol: "sailboat.fill",
               text: "The town doubles in size. Every spare room is let, and the queue for ice cream reaches the post office. Locals learn to shop before nine. In the middle of the month the regatta fills the bay with sails, and for one afternoon the whole town stands on the wall and cheers for boats it cannot tell apart."),
        .month(name: "August", symbol: "beach.umbrella.fill",
               text: "Heat, by our standards. The tar on the quay goes soft, and dogs lie flat in the shade of the fish boxes. Swimmers count their strokes to the moored dinghy and back. Late in the month the fog rolls in one evening and stays, and the foghorn sounds through the night like an old man clearing his throat."),
        .month(name: "September", symbol: "leaf.fill",
               text: "The visitors go home and take the noise with them. The cafés stay open a little longer than they need to, out of habit. This is the best month for the cliff path: blackberries in the hedges, gannets diving off the point, and nobody to pass on the narrow parts."),
        .month(name: "October", symbol: "cloud.bolt.rain.fill",
               text: "The first proper storm. Shutters go up on the seafront, and the lifeboat crew checks the boat twice. Afterwards the beach is covered in weed and driftwood, and people walk it slowly, heads down, looking for what the sea has brought. Once it was a ship's wheel. Mostly it is rope."),
        .month(name: "November", symbol: "flame.fill",
               text: "Dark by five. The pub lights its fire for the first time and leaves it lit until spring. The quiz night returns, the same team wins it every week, and the same team complains. On clear nights, if you walk past the last streetlamp, the stars over the harbour are almost too many."),
        .month(name: "December", symbol: "sparkles",
               text: "Lights strung along the harbour wall, reflected twice: once in the water and once in the wet road. The boats come in for the holidays, decorated with whatever is left in the shed. On the last night of the year the whole town walks to the end of the pier to hear every horn in the bay sound at once.")
    ]
}
