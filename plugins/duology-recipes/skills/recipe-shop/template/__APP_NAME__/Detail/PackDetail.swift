import SwiftUI

/// One pack. Open, it fills the trailing pane next to the grid; closed, the stack pushes it.
/// The same view in both, so the basket button says the same thing after a fold.
struct PackDetail: View {
    @Bindable var model: ShopModel
    let pack: Pack
    /// Two panes: closes the pack and gives the grid the whole window again. Nil when the
    /// stack pushed it, because the back button does that job.
    var onClose: (() -> Void)?
    @DuoMetrics private var tokens
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x6) {
            PackArt(pack: pack, cornerRadius: tokens.cardRadius)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if let onClose {
                        // Glass on a control, never on content. Top trailing, inside the
                        // trailing pane: never in the fold.
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .padding(DuoSpace.x3)
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("detail.close")
                    }
                }
            header
            BuyBox(model: model, pack: pack)
            Text(pack.summary)
                .font(DuoType.body)
                .fixedSize(horizontal: false, vertical: true)
            TrackList(pack: pack, isUnlocked: model.ownership.unlocks(pack.id))
        }
        .padding(.vertical, DuoSpace.x4)
        .onAppear {
            // Open, the pack appears beside the grid. Move VoiceOver to it, or it would stay
            // on the tile in the other pane and say nothing changed.
            if onClose != nil { titleFocused = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x2) {
            HStack(spacing: DuoSpace.x2) {
                Text(pack.category.name)
                if pack.isNew {
                    Badge(text: "New")
                }
            }
            .font(DuoType.secondary.weight(.medium))
            .foregroundStyle(.secondary)
            Text(pack.name)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
                .accessibilityIdentifier("detail.title")
            Text(pack.tagline)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(pack.lengthText)
                .font(DuoType.secondary)
                .foregroundStyle(.secondary)
        }
    }
}

/// The price and the one action that matters: add to the basket, or what the person has.
private struct BuyBox: View {
    @Bindable var model: ShopModel
    let pack: Pack

    var body: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: DuoSpace.x3) {
                switch model.state(of: pack) {
                case .owned:
                    Label("You own this pack", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(ShopColor.success)
                        .accessibilityIdentifier("detail.owned")
                case .plus:
                    Label("Included with Plus", systemImage: "star.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("detail.owned")
                case .inBasket, .forSale:
                    let inBasket = model.cart.contains(pack.id)
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.store.displayPrice(pack.id) ?? "Price unavailable")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .accessibilityIdentifier("detail.price")
                        Spacer(minLength: DuoSpace.x2)
                        Text("Buy once, keep it")
                            .font(DuoType.meta)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        model.toggleInBasket(pack.id)
                    } label: {
                        Label(inBasket ? "In basket" : "Add to basket",
                              systemImage: inBasket ? "checkmark" : "bag.badge.plus")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(inBasket ? Color.secondary : Color.accentColor)
                    .disabled(model.store.product(pack.id) == nil)
                    .accessibilityHint(inBasket ? "Removes it from the basket" : "")
                    .accessibilityIdentifier("detail.basket")
                    Button("Or get every pack with Plus") {
                        model.isPlusOpen = true
                    }
                    .font(DuoType.secondary.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: DuoTokens.minTouchTarget)
                    .accessibilityIdentifier("detail.plus")
                }
            }
        }
    }
}

/// The sounds in a pack. Locked ones show a lock until the pack is unlocked.
private struct TrackList: View {
    let pack: Pack
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DuoSpace.x3) {
            Text("In this pack")
                .font(DuoType.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(pack.tracks.enumerated()), id: \.offset) { index, track in
                    if index > 0 {
                        Divider().padding(.leading, 52)
                    }
                    HStack(spacing: DuoSpace.x3) {
                        Image(systemName: isUnlocked ? "play.circle.fill" : "lock.fill")
                            .font(.title3)
                            .foregroundStyle(isUnlocked ? Color.accentColor : Color.secondary)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        Text(track.title)
                        Spacer(minLength: DuoSpace.x2)
                        Text(track.duration, format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                            .font(DuoType.secondary)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, DuoSpace.x3)
                    .frame(minHeight: DuoTokens.minTouchTarget)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, DuoSpace.x1)
            .background(DuoColor.card, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail.tracks")
    }
}

/// Opened from the grid on the closed phone.
struct PackScreen: View {
    @Bindable var model: ShopModel
    let id: Pack.ID

    var body: some View {
        ScrollView {
            if let pack = model.catalog.pack(id) {
                PackDetail(model: model, pack: pack, onClose: nil)
                    .duoContainerMargins()
            }
        }
        .background(DuoColor.groupedBackground)
        // The pack's name is the heading right below, so the bar says what kind of screen it is.
        .navigationTitle("Pack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.isBasketOpen = true
                } label: {
                    Label("Basket", systemImage: model.cart.isEmpty ? "bag" : "bag.fill")
                }
                .badge(model.cart.count)
                .accessibilityIdentifier("toolbar.basket")
            }
        }
    }
}
