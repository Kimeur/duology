import SwiftUI

/// Plus, on top of the shop. It says what Plus costs once StoreKit answers, or that the
/// person has it.
struct PlusCard: View {
    @Bindable var model: ShopModel

    var body: some View {
        let hasPlus = model.ownership.hasPlus
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Label(hasPlus ? "Plus is on" : "Plus", systemImage: "star.fill")
                .font(DuoType.secondary.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(hasPlus ? "Every pack is yours while Plus is on." : "Every pack, one price.")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("shop.plusTitle")
            if !hasPlus {
                HStack(alignment: .center, spacing: DuoSpace.x3) {
                    Text(priceLine)
                        .font(DuoType.secondary)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("shop.plusPrice")
                    Spacer(minLength: DuoSpace.x2)
                    Button("See Plus") {
                        model.isPlusOpen = true
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityIdentifier("shop.seePlus")
                }
            }
        }
        .padding(DuoSpace.x5)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            LinearGradient(colors: [ShopColor.plusTop, ShopColor.plusBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shop.plusCard")
    }

    private var priceLine: String {
        guard let yearly = model.catalog.yearlyPlan, let price = model.store.displayPrice(yearly.id) else {
            return "All \(model.catalog.packs.count) packs, and every new one."
        }
        return "All \(model.catalog.packs.count) packs for \(price) a year."
    }
}

/// A new pack, next to the Plus card when the phone is open.
struct SpotlightCard: View {
    @Bindable var model: ShopModel
    let pack: Pack

    var body: some View {
        Button {
            model.selection = pack.id
        } label: {
            HStack(spacing: DuoSpace.x4) {
                PackArt(pack: pack, cornerRadius: 14)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: DuoSpace.x1) {
                    Text("New this week")
                        .font(DuoType.meta.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(pack.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(pack.lengthText)
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                    PriceLine(model: model, pack: pack)
                        .padding(.top, DuoSpace.x1)
                }
                Spacer(minLength: 0)
            }
            .padding(DuoSpace.x4)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New this week: \(pack.name), \(PriceLine.text(model: model, pack: pack))")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("shop.spotlight")
    }
}

/// The app's own colours.
enum ShopColor {
    /// The Plus card. Deep in both modes, so white text on it stays above 4.5:1.
    static let plusTop = Color(red: 0.31, green: 0.27, blue: 0.80)
    static let plusBottom = Color(red: 0.17, green: 0.13, blue: 0.48)
    /// Owned and bought. Darker than system green so small text keeps 4.5:1 on white.
    static let success = DuoColor.dynamic(light: UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1),
                                          dark: UIColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1))
}
