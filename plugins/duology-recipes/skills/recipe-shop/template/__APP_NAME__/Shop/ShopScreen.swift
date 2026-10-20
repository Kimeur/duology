import SwiftUI

/// The shop.
///
/// Closed (compact width): one column. Two cards on top (Plus, and a new pack), then the
/// packs, two per row. A pack pushes onto the stack.
///
/// Open (regular width), nothing picked: the whole window is one even grid of 8 columns with
/// the fold as its middle gutter. Packs span 2 columns, so 4 per row, 2 on each side.
///
/// Open, a pack picked: two panes split on the fold. The grid moves to the leading pane
/// (compact, 4 columns, 2 packs per row) and the pack fills the trailing pane. Each pane
/// scrolls on its own, and the panes sit in the same place flat and partly folded.
struct ShopScreen: View {
    @Bindable var model: ShopModel
    @DuoMetrics private var tokens
    @State private var geometry = PaneGeometry()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let frames = model.isTwoPane && model.selectedPack != nil
            ? PaneFrames(width: geometry.width, count: tokens.columns, gutter: tokens.gutter, fold: geometry.fold)
            : nil
        FoldPanes(frames: frames) {
            ScrollView {
                // Alone, the grid spans the fold; as the leading pane, it stops before it.
                ShopColumn(model: model,
                           width: frames?.leading.width ?? geometry.width,
                           fold: frames == nil ? geometry.fold : nil)
            }
            .accessibilityIdentifier("pane.leading")
        } trailing: {
            ScrollView {
                if let pack = model.selectedPack {
                    PackDetail(model: model, pack: pack) {
                        model.selection = nil
                    }
                    // A new pack starts at the top, with VoiceOver on its name.
                    .id(pack.id)
                }
            }
            .accessibilityIdentifier("pane.trailing")
        }
        // Measured inside the margins, so the fold comes back in the grid's coordinates.
        .onPaneGeometryChange { geometry = $0 }
        .duoContainerMargins()
        .background(DuoColor.groupedBackground)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: model.selection)
        .navigationTitle("Sound Shop")
        .toolbar {
            // On iPhone Duo the system puts these in the vertical bar on the side.
            ToolbarItem(placement: .primaryAction) {
                CategoryMenu(category: $model.category)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.isBasketOpen = true
                } label: {
                    Label("Basket", systemImage: model.cart.isEmpty ? "bag" : "bag.fill")
                }
                .badge(model.cart.count)
                .accessibilityValue(model.cart.count == 1 ? "1 pack" : "\(model.cart.count) packs")
                .accessibilityIdentifier("toolbar.basket")
            }
        }
    }
}

/// The leading pane when a pack is open, and the whole screen otherwise.
private struct ShopColumn: View {
    @Bindable var model: ShopModel
    /// The grid's width and fold, in its own coordinates.
    let width: CGFloat
    let fold: DuoFold?
    @DuoMetrics private var tokens

    var body: some View {
        let grid = DuoColumns(width: width, count: tokens.columns, gutter: tokens.gutter, fold: fold)
        // Cards span 4 columns (a whole side of the fold), packs span 2. Both double at
        // accessibility text sizes. A group never crosses the fold.
        let cards = grid.grouped(by: tokens.span(4))
        let tiles = grid.grouped(by: tokens.span(2))
        VStack(alignment: .leading, spacing: tokens.sectionSpacing) {
            LazyVGrid(columns: cards.gridItems, alignment: .leading, spacing: tokens.gutter) {
                PlusCard(model: model)
                if let spotlight = model.catalog.packs.first(where: \.isNew) {
                    SpotlightCard(model: model, pack: spotlight)
                }
            }
            .padding(.leading, cards.leadingInset)

            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                header
                    // Text stays on one side of the fold: the first half of the grid.
                    .frame(maxWidth: cards.columns.first?.width, alignment: .leading)
                    .padding(.leading, cards.leadingInset)
                if model.packs.isEmpty {
                    ContentUnavailableView("No Packs", systemImage: "waveform",
                                           description: Text("Nothing in this category yet."))
                }
                LazyVGrid(columns: tiles.gridItems, alignment: .leading, spacing: tokens.gutter) {
                    ForEach(model.packs) { pack in
                        PackTile(model: model, pack: pack)
                    }
                }
                .padding(.leading, tiles.leadingInset)
                // A container, so its identifier doesn't replace the tiles' own.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("shop.grid")
            }
        }
        .padding(.vertical, DuoSpace.x4)
        // Take the offered width, not the sum of the fixed columns (duo-design-system grid.md).
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.category?.name ?? "All packs")
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DuoSpace.x2)
            if let category = model.category {
                Button {
                    model.category = nil
                } label: {
                    Label(category.name, systemImage: "xmark.circle.fill")
                        .font(DuoType.secondary.weight(.medium))
                        .padding(.horizontal, DuoSpace.x3)
                        .duoTouchTarget()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Clear filter: \(category.name)")
                .accessibilityIdentifier("filter.clear")
            } else {
                Text("\(model.packs.count) packs")
                    .font(DuoType.secondary)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// One pack in the grid. The whole tile is one button that opens the pack; the price is text.
private struct PackTile: View {
    @Bindable var model: ShopModel
    let pack: Pack
    @DuoMetrics private var tokens
    @ScaledMetric(relativeTo: .body) private var artHeight: CGFloat = 116

    var body: some View {
        let isSelected = model.isTwoPane && model.selection == pack.id
        Button {
            model.selection = pack.id
        } label: {
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                // One height for every tile, so a row lines up across the fold even though
                // the two halves of the grid can differ in width.
                PackArt(pack: pack, cornerRadius: tokens.cardRadius - DuoSpace.x2)
                    .frame(height: artHeight)
                    .overlay(alignment: .topLeading) {
                        if pack.isNew {
                            Text("New")
                                .font(DuoType.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, DuoSpace.x2)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.28), in: Capsule())
                                .padding(DuoSpace.x2)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    // Fixed line counts, so every tile in a row has the same height.
                    Text(pack.name)
                        .font(DuoType.itemTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(pack.tagline)
                        .font(DuoType.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                PriceLine(model: model, pack: pack)
            }
            .padding(DuoSpace.x2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: tokens.cardRadius))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: tokens.cardRadius)
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: tokens.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name), \(pack.tagline), \(PriceLine.text(model: model, pack: pack))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("tile.\(pack.id)")
    }
}

/// The price slot: StoreKit's price, or what the person already has.
struct PriceLine: View {
    let model: ShopModel
    let pack: Pack

    var body: some View {
        switch model.state(of: pack) {
        case .owned: Badge(text: "Owned", symbol: "checkmark")
        case .plus: Badge(text: "With Plus", symbol: "star.fill")
        case .inBasket: Badge(text: "In basket", symbol: "bag.fill")
        case .forSale:
            Text(model.store.displayPrice(pack.id) ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
        }
    }

    /// The same, for VoiceOver.
    static func text(model: ShopModel, pack: Pack) -> String {
        switch model.state(of: pack) {
        case .owned: "owned"
        case .plus: "included with Plus"
        case .inBasket: "in basket"
        case .forSale: model.store.displayPrice(pack.id) ?? "price unavailable"
        }
    }
}

private struct CategoryMenu: View {
    @Binding var category: PackCategory?

    var body: some View {
        Menu {
            Picker("Show", selection: $category) {
                Label("All packs", systemImage: "square.grid.2x2").tag(PackCategory?.none)
                ForEach(PackCategory.allCases) { item in
                    Text(item.name).tag(PackCategory?.some(item))
                }
            }
        } label: {
            Label("Filter", systemImage: category == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityIdentifier("filter.menu")
    }
}
