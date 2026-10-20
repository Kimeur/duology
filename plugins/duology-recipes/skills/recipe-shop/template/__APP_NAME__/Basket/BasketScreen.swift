import StoreKit
import SwiftUI

/// The basket and checkout. Open: the packs on the leading side, the total and the Buy
/// button on the trailing side. Closed: one column, Buy pinned at the bottom.
struct BasketScreen: View {
    @Bindable var model: ShopModel
    @Environment(\.purchase) private var purchase
    @State private var restoreMessage: String?

    var body: some View {
        Group {
            if model.basketRows.isEmpty {
                ContentUnavailableView {
                    Label("Your basket is empty", systemImage: "bag")
                } description: {
                    Text("Add a pack from the shop, or get every pack with Plus.")
                } actions: {
                    Button("Browse packs") { model.isBasketOpen = false }
                        .buttonStyle(.borderedProminent)
                }
                .accessibilityIdentifier("basket.empty")
            } else {
                ActionPanes(isTwoPane: model.isTwoPane) {
                    BasketLines(model: model)
                } panel: {
                    Summary(model: model)
                } action: {
                    BuyButton(model: model) {
                        Task { await model.checkOut(with: purchase) }
                    }
                } footer: {
                    Fineprint(model: model, restoreMessage: $restoreMessage)
                }
            }
        }
        .background(DuoColor.groupedBackground)
        .navigationTitle("Basket")
        .navigationBarTitleDisplayMode(.inline)
        // Leaving mid-purchase would hide the progress; StoreKit's own sheet still decides.
        .navigationBarBackButtonHidden(model.checkout?.isBuying == true)
    }
}

/// The packs, with what happened to each during checkout.
private struct BasketLines: View {
    @Bindable var model: ShopModel

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text(model.basketRows.count == 1 ? "1 pack" : "\(model.basketRows.count) packs")
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(model.basketRows.enumerated()), id: \.element) { index, id in
                    if let pack = model.catalog.pack(id) {
                        if index > 0 {
                            Divider().padding(.leading, 84)
                        }
                        BasketRow(model: model, pack: pack)
                    }
                }
            }
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: 20))
            // A container, so its identifier doesn't replace the rows' own.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("basket.lines")
        }
    }
}

private struct BasketRow: View {
    @Bindable var model: ShopModel
    let pack: Pack

    var body: some View {
        let status = model.checkout?.status(of: pack.id)
        HStack(spacing: DuoSpace.x3) {
            PackArt(pack: pack, cornerRadius: 10)
                .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("basket.line.\(pack.id)")
                Text(pack.lengthText)
                    .font(DuoType.secondary)
                    .foregroundStyle(.secondary)
                if let status {
                    StatusText(status: status)
                }
            }
            Spacer(minLength: DuoSpace.x2)
            Text(model.store.displayPrice(pack.id) ?? "–")
                .font(.body.weight(.semibold))
                .monospacedDigit()
            if model.checkout == nil {
                Button {
                    model.removeFromBasket(pack.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .duoTouchTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(pack.name)")
                .accessibilityIdentifier("basket.remove.\(pack.id)")
            }
        }
        .padding(.horizontal, DuoSpace.x3)
        .padding(.vertical, DuoSpace.x2)
    }
}

private struct StatusText: View {
    let status: CheckoutRun.Status

    var body: some View {
        Group {
            switch status {
            case .waiting: Label("Waiting", systemImage: "clock")
            case .buying: Label("Confirm in the App Store sheet", systemImage: "hourglass")
            case .bought: Label("Bought", systemImage: "checkmark.circle.fill").foregroundStyle(ShopColor.success)
            case .pending: Label("Waiting for approval", systemImage: "person.badge.clock")
            case .cancelled: Label("Not bought", systemImage: "xmark.circle")
            case .failed(let message): Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .font(DuoType.meta.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

/// The total, and Plus when it would cost less.
private struct Summary: View {
    @Bindable var model: ShopModel

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x4) {
            if let checkout = model.checkout, checkout.isFinished {
                Done(model: model, checkout: checkout)
            } else {
                DuoCard {
                    VStack(alignment: .leading, spacing: DuoSpace.x2) {
                        Text("Total")
                            .font(DuoType.secondary.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(model.totalText ?? "–")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .accessibilityIdentifier("basket.total")
                        Text("Each pack is its own App Store purchase. You confirm each one, and you keep them for good.")
                            .font(DuoType.meta)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let message = model.checkout?.failure {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(DuoType.secondary)
                        .foregroundStyle(.orange)
                }
                PlusOffer(model: model)
            }
        }
    }
}

/// After every pack is bought or waiting for approval.
private struct Done: View {
    @Bindable var model: ShopModel
    let checkout: CheckoutRun

    private var title: String {
        switch checkout.bought.count {
        case 0: "Waiting for approval"
        case 1: "1 pack is yours"
        default: "\(checkout.bought.count) packs are yours"
        }
    }

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ShopColor.success)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("basket.done")
                if !checkout.pending.isEmpty {
                    Text(checkout.pending.count == 1
                         ? "1 pack is waiting for approval. It unlocks once approved."
                         : "\(checkout.pending.count) packs are waiting for approval. They unlock once approved.")
                        .font(DuoType.secondary)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("basket.pending")
                }
            }
        }
    }
}

/// Plus, as the other way to pay. Stronger when the basket costs more than a year of it.
private struct PlusOffer: View {
    @Bindable var model: ShopModel

    var body: some View {
        let yearly = model.catalog.yearlyPlan.flatMap { model.store.displayPrice($0.id) }
        Button {
            model.isPlusOpen = true
        } label: {
            HStack(spacing: DuoSpace.x3) {
                Image(systemName: "star.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.suggestsPlus ? "Plus costs less than this basket" : "Or get every pack with Plus")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let yearly {
                        Text("\(model.catalog.packs.count) packs for \(yearly) a year")
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DuoSpace.x2)
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DuoSpace.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("basket.plus")
    }
}

/// Buy, or carry on, or leave after a finished checkout.
private struct BuyButton: View {
    @Bindable var model: ShopModel
    let buy: () -> Void

    var body: some View {
        let checkout = model.checkout
        Group {
            if let checkout, checkout.isFinished {
                Button {
                    model.closeCheckout()
                    model.isBasketOpen = false
                } label: {
                    Text("Back to the shop").frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                }
            } else {
                Button(action: buy) {
                    HStack(spacing: DuoSpace.x2) {
                        if checkout?.isBuying == true {
                            ProgressView()
                        }
                        Text(title(checkout))
                    }
                    .frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                }
                .disabled(checkout?.isBuying == true || model.totalText == nil)
            }
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("basket.buy")
    }

    private func title(_ checkout: CheckoutRun?) -> String {
        guard let checkout else {
            let count = model.cart.count
            let packs = count == 1 ? "1 pack" : "\(count) packs"
            return model.totalText.map { "Buy \(packs) · \($0)" } ?? "Buy \(packs)"
        }
        if checkout.isBuying {
            let done = checkout.bought.count + checkout.pending.count + 1
            return "Buying \(done) of \(checkout.lines.count)"
        }
        return "Buy the rest"
    }
}

private struct Fineprint: View {
    @Bindable var model: ShopModel
    @Binding var restoreMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x2) {
            Button("Restore purchases") {
                Task { restoreMessage = await model.store.restore() ?? "Purchases restored." }
            }
            .font(DuoType.secondary.weight(.medium))
            .frame(minHeight: DuoTokens.minTouchTarget)
            .accessibilityIdentifier("basket.restore")
            if let restoreMessage {
                Text(restoreMessage)
                    .font(DuoType.meta)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
