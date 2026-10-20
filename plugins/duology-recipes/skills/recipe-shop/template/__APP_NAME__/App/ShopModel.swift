import Observation
import StoreKit
import SwiftUI

/// A screen pushed on the navigation stack.
enum Route: Hashable {
    case pack(Pack.ID)
    case basket
}

/// Holds the basket, the selection, the filter and the checkout for every view. It lives in
/// RootView, above the navigation stack and the panes, so opening, closing and rotating the
/// phone never lose what the person picked or a checkout that is running.
@Observable
final class ShopModel {
    let catalog: Catalog
    let store: Store
    private(set) var cart: Cart
    /// The pack on show: in the trailing pane when open, pushed when closed.
    var selection: Pack.ID?
    /// Only this category in the grid. Nil shows every pack.
    var category: PackCategory?
    /// Two panes on the inner display. RootView sets it from the window's width class.
    var isTwoPane = false
    var isBasketOpen = false
    var isPlusOpen = false
    /// The basket being bought, line by line. Nil before checkout.
    private(set) var checkout: CheckoutRun?

    init(catalog: Catalog, store: Store, cart: Cart = Cart()) {
        self.catalog = catalog
        self.store = store
        self.cart = cart
    }

    var packs: [Pack] { catalog.packs(in: category) }
    var selectedPack: Pack? { selection.flatMap(catalog.pack) }
    var ownership: Ownership { store.ownership }

    /// The navigation path, worked out from the selection and the basket. Closed, the
    /// selected pack is pushed; open, it sits in the trailing pane, so only the basket is
    /// pushed. One source of truth, so closing the phone on a pack shows that pack, and
    /// opening it shows the pack beside the grid.
    var path: [Route] {
        get {
            var routes: [Route] = []
            if !isTwoPane, let selection { routes.append(.pack(selection)) }
            if isBasketOpen { routes.append(.basket) }
            return routes
        }
        set {
            isBasketOpen = newValue.contains(.basket)
            // Open, the stack can report a shorter path while it pops. Keep the selection.
            guard !isTwoPane else { return }
            selection = newValue.compactMap { route -> Pack.ID? in
                if case .pack(let id) = route { return id }
                return nil
            }.last
        }
    }

    // MARK: Basket

    func toggleInBasket(_ id: Pack.ID) {
        guard checkout?.isBuying != true else { return }
        cart.toggle(id)
        // Changing the basket ends a finished or stopped checkout's summary.
        checkout = nil
    }

    func removeFromBasket(_ id: Pack.ID) {
        guard checkout?.isBuying != true else { return }
        cart.remove(id)
        checkout = nil
    }

    /// The basket total in the storefront's currency, or nil while a price is missing.
    var totalText: String? {
        cart.total(prices: store.prices).flatMap(store.format)
    }

    var suggestsPlus: Bool {
        cart.suggestsPlus(prices: store.prices, yearly: catalog.yearlyPlan.flatMap { store.product($0.id)?.price })
    }

    /// Rows the basket shows: the checkout's lines while there is one, so a bought pack stays
    /// on screen with its tick; otherwise the basket.
    var basketRows: [Pack.ID] { checkout?.lines.map(\.id) ?? cart.items }

    /// What the person now owns changed: a purchase, a restore, Plus, Ask to Buy, another
    /// device. Drop packs they no longer need to buy.
    func ownershipChanged() {
        guard checkout?.isBuying != true else { return }
        cart.removeUnlocked(store.ownership)
    }

    // MARK: Checkout

    /// Buys the basket one pack at a time, or carries on after a cancel or an error.
    func checkOut(with purchase: PurchaseAction) async {
        guard checkout?.isBuying != true, !cart.isEmpty || checkout != nil else { return }
        if var run = checkout, !run.isFinished {
            run.resume()
            checkout = run
        } else {
            checkout = CheckoutRun(packs: cart.items)
        }
        while let id = checkout?.next {
            checkout?.start(id)
            let outcome = await store.buy(id, with: purchase)
            checkout?.finish(id, outcome)
        }
        // Bought and pending packs leave the basket; the checkout keeps them for the summary.
        for id in (checkout?.bought ?? []) + (checkout?.pending ?? []) {
            cart.remove(id)
        }
    }

    /// Leaves the summary after a finished checkout.
    func closeCheckout() {
        checkout = nil
    }
}
