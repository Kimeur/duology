import StoreKit
import SwiftUI

/// The app's only StoreKit code: products, purchases, entitlements and restore.
///
/// It lives in RootView, above every layout, so opening and closing the phone never reloads
/// products or loses a purchase in flight. In Xcode the products come from
/// StoreKit/Shop.storekit (the scheme's StoreKit configuration), with no network.
@Observable
final class Store {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    let catalog: Catalog
    private(set) var phase: Phase = .loading
    private(set) var products: [String: Product] = [:]
    private(set) var ownership = Ownership()
    /// True when this person can still get the yearly plan's free trial.
    private(set) var isTrialEligible = false
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(catalog: Catalog) {
        self.catalog = catalog
    }

    /// StoreKit's prices by product ID, for the basket total.
    var prices: [String: Decimal] { products.mapValues(\.price) }

    func product(_ id: String) -> Product? { products[id] }

    /// "$2.99", in the person's storefront currency. Nil until StoreKit answers.
    func displayPrice(_ id: String) -> String? { products[id]?.displayPrice }

    /// Formats any amount in the storefront's currency, for totals.
    func format(_ amount: Decimal) -> String? {
        products.values.first.map { amount.formatted($0.priceFormatStyle) }
    }

    /// Call once, at launch. Listens for transactions first, so nothing that arrives while
    /// the products load is missed, then loads products and what the person owns.
    func start() async {
        if updates == nil {
            updates = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    await self?.handle(result)
                }
            }
        }
        await loadProducts()
        await refreshOwnership()
    }

    func loadProducts() async {
        phase = .loading
        do {
            let list = try await Product.products(for: catalog.productIDs)
            products = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            phase = list.isEmpty ? .failed("The shop can't reach the App Store right now.") : .ready
            if let yearly = catalog.yearlyPlan.flatMap({ products[$0.id] }), let subscription = yearly.subscription {
                isTrialEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Reads every current entitlement. Only verified, unrevoked transactions unlock anything.
    func refreshOwnership() async {
        var ids: [String] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.append(transaction.productID)
            }
        }
        ownership = Ownership(entitlements: ids, catalog: catalog)
    }

    /// Transactions that arrive outside a purchase call: Ask to Buy approvals, purchases on
    /// another device, renewals, refunds. Finish only verified ones.
    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
        }
        await refreshOwnership()
    }

    /// Buys one product. `purchase` is SwiftUI's purchase action, read from the environment
    /// of the view that asks: StoreKit shows its confirmation sheet in that view's scene,
    /// on whichever display it is on.
    func buy(_ id: String, with purchase: PurchaseAction) async -> CheckoutRun.Outcome {
        guard let product = products[id] else {
            return .failed("This item isn't for sale right now.")
        }
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshOwnership()
                return .bought
            case .success(.unverified):
                return .failed("The App Store couldn't confirm this purchase.")
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("The App Store returned an unknown result.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Restore purchases: asks the App Store for this Apple Account's transactions. It can
    /// ask the person to sign in, so call it only from a button they pressed.
    func restore() async -> String? {
        do {
            try await AppStore.sync()
            await refreshOwnership()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
