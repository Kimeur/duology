import StoreKit
import SwiftUI

/// The paywall. Open: what Plus gives on the leading side; the plans, the Subscribe button and
/// the terms on the trailing side. Closed: one column, Subscribe pinned at the bottom.
///
/// Every price, period and trial comes from StoreKit, never from the catalog, so the screen
/// shows what the App Store will charge in the person's currency.
struct PlusScreen: View {
    @Bindable var model: ShopModel
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss
    /// The yearly plan until the person picks another.
    @State private var choice: Plan.ID?
    @State private var isBuying = false
    @State private var message: String?
    @State private var showsManage = false

    var body: some View {
        NavigationStack {
            ActionPanes(isTwoPane: model.isTwoPane) {
                Benefits(model: model)
            } panel: {
                if model.ownership.hasPlus {
                    Label("Plus is on. Every pack is yours.", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(ShopColor.success)
                        .accessibilityIdentifier("plus.active")
                } else {
                    PlanPicker(model: model, choice: $choice)
                }
            } action: {
                actionButton
            } footer: {
                Terms(model: model, message: $message)
            }
            .navigationTitle("Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("plus.close")
                }
            }
            .manageSubscriptionsSheet(isPresented: $showsManage)
        }
        .onAppear {
            if choice == nil {
                choice = model.catalog.yearlyPlan?.id ?? model.catalog.plans.first?.id
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        Group {
            if model.ownership.hasPlus {
                Button {
                    showsManage = true
                } label: {
                    Text("Manage Plus").frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                }
            } else {
                Button {
                    subscribe()
                } label: {
                    HStack(spacing: DuoSpace.x2) {
                        if isBuying { ProgressView() }
                        Text(subscribeTitle)
                    }
                    .frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                }
                .disabled(isBuying || choice.flatMap(model.store.product) == nil)
            }
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("plus.subscribe")
    }

    private var subscribeTitle: String {
        let plan = choice.flatMap(model.catalog.plan)
        if plan?.period == .year, model.store.isTrialEligible,
           let offer = choice.flatMap(model.store.product)?.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            return "Try it free"
        }
        return "Subscribe"
    }

    private func subscribe() {
        guard let choice else { return }
        isBuying = true
        message = nil
        Task {
            switch await model.store.buy(choice, with: purchase) {
            case .bought: dismiss()
            case .pending: message = "Waiting for approval. Plus starts once it's approved."
            case .cancelled: break
            case .failed(let text): message = text
            }
            isBuying = false
        }
    }
}

/// What Plus gives, with a few packs to show it.
private struct Benefits: View {
    let model: ShopModel
    @DuoMetrics private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x5) {
            // A mosaic of real packs. Four across in any pane, so it scales with the width.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DuoSpace.x2), count: 4),
                      spacing: DuoSpace.x2) {
                ForEach(model.catalog.packs.prefix(8)) { pack in
                    PackArt(pack: pack, cornerRadius: 12)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DuoSpace.x2) {
                Text("Every pack, one price")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("plus.title")
                Text("Plus unlocks the whole shop while it's on.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: DuoSpace.x4) {
                Benefit(symbol: "square.grid.2x2.fill",
                        title: "All \(model.catalog.packs.count) packs",
                        detail: "Every pack in the shop, and each new one as it comes out.")
                Benefit(symbol: "person.2.fill", title: "Family Sharing",
                        detail: "Up to five family members can use Plus too.")
                Benefit(symbol: "checkmark.shield.fill", title: "Keep what you bought",
                        detail: "Packs you bought on their own stay yours if Plus ends.")
            }
        }
    }
}

private struct Benefit: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DuoSpace.x3) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(DuoType.secondary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The two plans as a single choice.
private struct PlanPicker: View {
    let model: ShopModel
    @Binding var choice: Plan.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text("Choose a plan")
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            if case .failed(let message) = model.store.phase {
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(DuoType.secondary)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.catalog.plans) { plan in
                PlanCard(model: model, plan: plan, isChosen: choice == plan.id) {
                    choice = plan.id
                }
            }
        }
    }
}

private struct PlanCard: View {
    let model: ShopModel
    let plan: Plan
    let isChosen: Bool
    let choose: () -> Void

    var body: some View {
        let product = model.store.product(plan.id)
        Button(action: choose) {
            HStack(alignment: .center, spacing: DuoSpace.x3) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChosen ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DuoSpace.x2) {
                        Text(plan.period == .year ? "Yearly" : "Monthly")
                            .font(.headline)
                        if plan.period == .year, let saving = saving {
                            Badge(text: "Save \(saving)%")
                        }
                    }
                    if let product {
                        // The billed amount is the biggest price on the card.
                        Text("\(product.displayPrice) a \(plan.period == .year ? "year" : "month")")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        if let trial = trialText(product) {
                            Text(trial)
                                .font(DuoType.secondary)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Price unavailable")
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DuoSpace.x4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isChosen ? Color.accentColor : Color.clear, lineWidth: 2.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
        .accessibilityIdentifier("plan.\(plan.id)")
    }

    /// Yearly against twelve months, from StoreKit's prices.
    private var saving: Int? {
        guard let yearly = model.store.product(plan.id)?.price,
              let monthly = model.catalog.plans.first(where: { $0.period == .month })
                .flatMap({ model.store.product($0.id)?.price }) else { return nil }
        return PlanMath.percentSaved(yearly: yearly, monthly: monthly)
    }

    private func trialText(_ product: Product) -> String? {
        guard model.store.isTrialEligible, let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let length = offer.period.formatted(.units(allowed: [.days, .weeks], width: .wide))
        return "\(length) free, then billed each year"
    }
}

/// What people need next to a subscribe button: how renewal works, links to the terms and the
/// privacy policy, and a way to restore. App Review guideline 3.1.2(c) and Schedule 2 of the
/// developer agreement set the rules; read them before you submit.
private struct Terms: View {
    let model: ShopModel
    @Binding var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            if let message {
                Text(message)
                    .font(DuoType.secondary)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("plus.message")
            }
            Text("Plus renews automatically until you cancel it in Settings, at least a day before the period ends. Packs you bought on their own stay yours.")
                .font(DuoType.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DuoSpace.x4) {
                // Replace both with your own pages. The first is Apple's standard licence.
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(DuoType.meta.weight(.medium))
            Button("Restore purchases") {
                Task { message = await model.store.restore() ?? "Purchases restored." }
            }
            .font(DuoType.meta.weight(.medium))
            .frame(minHeight: DuoTokens.minTouchTarget)
            .accessibilityIdentifier("plus.restore")
        }
    }
}
