import SwiftUI

/// Feed reflow: a homeware shop.
///
/// The grid picks its column count from its own width. When a fold crosses it,
/// active or not, the count is even, so the fold falls between two columns.
/// Partly folded, half the columns sit on each side and the fold is the middle
/// gap. The grid never moves out of the fold as a block: feeds scroll, they
/// don't displace.
///
/// Pattern guide: `duo-patterns/references/feed-reflow.md`.
struct FeedReflowView: View {
    @State private var input = FeedGridInput()
    // The fold as the scroll view sees it. Only for the status line: a fold that
    // runs side to side doesn't change the columns, rows just scroll past it.
    @State private var fold = FoldGeometry()
    @State private var category = Product.Category.all
    // A minimum tile width that grows with Dynamic Type. A content size, not a screen size.
    @ScaledMetric(relativeTo: .body) private var minTileWidth = 150.0
    private let spacing: CGFloat = 12

    private var columns: [GridItem] {
        feedColumns(for: input, minTileWidth: minTileWidth, spacing: spacing)
    }

    private var products: [Product] {
        category == .all ? Product.samples : Product.samples.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(products) { product in
                            ProductTile(product: product)
                        }
                    }
                    // Read the fold on the grid itself, inside the margins, so its
                    // frame comes back in the grid's own coordinates.
                    .onFeedGridChange { input = $0 }
                    .animation(.smooth, value: input)
                }
                // System margins. They can differ on each side next to a vertical bar.
                .containerMargins(.horizontal)
                .padding(.bottom, 24)
            }
            // Read on the scroll view, not its content, so scrolling doesn't change it.
            .onFoldChange { fold = $0 }
            .navigationTitle("Shelf")
            .galleryCloseButton()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Bag", systemImage: "bag") {}
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New this week")
                .font(.title2.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Product.Category.allCases, id: \.self) { item in
                        Button(item.rawValue) { category = item }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(category == item ? .accentColor : .secondary)
                            .accessibilityAddTraits(category == item ? .isSelected : [])
                    }
                }
            }
            // Stop at the margin, so chips never slide under the status bar or a vertical bar.
            .clipped()
            Label(layoutSummary, systemImage: "square.grid.3x2")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    /// What the grid is doing, in words. The gallery shows it so you can watch it change.
    private var layoutSummary: String {
        let count = columns.count
        let noun = count == 1 ? "column" : "columns"
        guard input.foldMinX != nil else {
            if fold.frame != nil, !fold.isVertical {
                return "\(count) \(noun), the fold runs across: rows scroll past it"
            }
            return "\(count) \(noun), no fold across the grid"
        }
        let state = input.foldIsActive ? "folded: the fold is the middle gap" : "flat: even count, ready to fold"
        return "\(count) \(noun), \(state)"
    }
}

private struct ProductTile: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [product.colors.0, product.colors.1], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: product.symbol)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if product.isNew {
                    Text("New")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(product.colors.1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white, in: Capsule())
                        .padding(8)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(product.maker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(product.price, format: .currency(code: "EUR").precision(.fractionLength(0)))
                    .font(.subheadline)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sample shop

struct Product: Identifiable {
    enum Category: String, CaseIterable {
        case all = "All"
        case kitchen = "Kitchen"
        case lighting = "Lighting"
        case living = "Living"
        case outdoors = "Outdoors"
    }

    let id: Int
    var name: String
    var maker: String
    var price: Decimal
    var symbol: String
    var category: Category
    var colors: (Color, Color)
    var isNew = false

    private static let clay = (Color(hex: 0xE07A4F), Color(hex: 0xB4441F))
    private static let sage = (Color(hex: 0x8DB580), Color(hex: 0x3F7D20))
    private static let ink = (Color(hex: 0x6E8EF5), Color(hex: 0x2B55C7))
    private static let plum = (Color(hex: 0xB78AF0), Color(hex: 0x7A4CD9))
    private static let sand = (Color(hex: 0xE8B65A), Color(hex: 0xB7791F))
    private static let sea = (Color(hex: 0x5BC0BE), Color(hex: 0x0E7490))
    private static let rose = (Color(hex: 0xF08BB4), Color(hex: 0xC0266D))
    private static let slate = (Color(hex: 0x98A6B8), Color(hex: 0x4A5A6E))

    static let samples: [Product] = [
        Product(id: 1, name: "Stoneware mug", maker: "Kiln & Co.", price: 24, symbol: "mug.fill", category: .kitchen, colors: clay, isNew: true),
        Product(id: 2, name: "Oak desk lamp", maker: "Lumen Row", price: 129, symbol: "lamp.desk.fill", category: .lighting, colors: sand),
        Product(id: 3, name: "Lounge chair", maker: "Field & Frame", price: 540, symbol: "chair.lounge.fill", category: .living, colors: sage, isNew: true),
        Product(id: 4, name: "Day pack, 18 L", maker: "Trailhead Goods", price: 85, symbol: "backpack.fill", category: .outdoors, colors: sea),
        Product(id: 5, name: "Pour-over set", maker: "Kiln & Co.", price: 48, symbol: "cup.and.saucer.fill", category: .kitchen, colors: slate),
        Product(id: 6, name: "Brass floor lamp", maker: "Lumen Row", price: 189, symbol: "lamp.floor.fill", category: .lighting, colors: plum),
        Product(id: 7, name: "Two-seat sofa", maker: "Field & Frame", price: 1290, symbol: "sofa.fill", category: .living, colors: ink),
        Product(id: 8, name: "Storm umbrella", maker: "Rainward", price: 45, symbol: "umbrella.fill", category: .outdoors, colors: rose, isNew: true),
        Product(id: 9, name: "Cast iron pan", maker: "Hearth Works", price: 69, symbol: "frying.pan.fill", category: .kitchen, colors: slate),
        Product(id: 10, name: "Bedside lamp", maker: "Lumen Row", price: 79, symbol: "lamp.table.fill", category: .lighting, colors: clay),
        Product(id: 11, name: "Wall clock", maker: "Tick Studio", price: 64, symbol: "clock.fill", category: .living, colors: sea),
        Product(id: 12, name: "Market basket", maker: "Reed & Rush", price: 42, symbol: "basket.fill", category: .outdoors, colors: sand),
        Product(id: 13, name: "Wine glasses, pair", maker: "Clearwater", price: 38, symbol: "wineglass.fill", category: .kitchen, colors: plum),
        Product(id: 14, name: "Pendant light", maker: "Lumen Row", price: 149, symbol: "lightbulb.fill", category: .lighting, colors: ink, isNew: true),
        Product(id: 15, name: "Linen bedding", maker: "Flock Mill", price: 160, symbol: "bed.double.fill", category: .living, colors: rose),
        Product(id: 16, name: "Herb planter", maker: "Green Sill", price: 29, symbol: "leaf.fill", category: .outdoors, colors: sage),
        Product(id: 17, name: "Desk fan", maker: "Breeze Lab", price: 59, symbol: "fan.fill", category: .living, colors: slate),
        Product(id: 18, name: "Canvas tote", maker: "Flock Mill", price: 22, symbol: "bag.fill", category: .outdoors, colors: clay),
        Product(id: 19, name: "Wool bear", maker: "Little Loom", price: 34, symbol: "teddybear.fill", category: .living, colors: sand),
        Product(id: 20, name: "Studio headphones", maker: "Quiet Room", price: 199, symbol: "headphones", category: .living, colors: ink),
        Product(id: 21, name: "Film camera", maker: "Darkroom Supply", price: 240, symbol: "camera.fill", category: .outdoors, colors: slate),
        Product(id: 22, name: "Gift wrap set", maker: "Shelf", price: 15, symbol: "gift.fill", category: .living, colors: rose),
        Product(id: 23, name: "Cotton tee", maker: "Flock Mill", price: 28, symbol: "tshirt.fill", category: .outdoors, colors: sea),
        Product(id: 24, name: "Sunglasses", maker: "Coastline", price: 110, symbol: "sunglasses.fill", category: .outdoors, colors: plum)
    ]
}
