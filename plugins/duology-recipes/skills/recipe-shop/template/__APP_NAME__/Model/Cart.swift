import Foundation

/// The basket: packs the person wants, in the order they added them.
///
/// Prices come in from outside (StoreKit's, or the catalog's in tests), so the rules don't
/// depend on a currency. Amounts are `Decimal`, as StoreKit's `Product.price` is: never add
/// prices up as `Double`.
nonisolated struct Cart: Equatable, Sendable {
    private(set) var items: [Pack.ID] = []

    init(_ items: [Pack.ID] = []) {
        for id in items { add(id) }
    }

    var count: Int { items.count }
    var isEmpty: Bool { items.isEmpty }
    func contains(_ id: Pack.ID) -> Bool { items.contains(id) }

    /// Adds a pack once. Returns false when it was already in the basket.
    @discardableResult
    mutating func add(_ id: Pack.ID) -> Bool {
        guard !items.contains(id) else { return false }
        items.append(id)
        return true
    }

    mutating func remove(_ id: Pack.ID) {
        items.removeAll { $0 == id }
    }

    mutating func toggle(_ id: Pack.ID) {
        if contains(id) { remove(id) } else { add(id) }
    }

    /// Takes out packs the person can already use: bought here, bought on another device,
    /// restored, or covered by Plus. Returns what it took out, so the view can say so.
    @discardableResult
    mutating func removeUnlocked(_ ownership: Ownership) -> [Pack.ID] {
        let gone = items.filter { ownership.unlocks($0) }
        items.removeAll { ownership.unlocks($0) }
        return gone
    }

    /// The sum of the basket, or nil while any price is missing (StoreKit hasn't answered,
    /// or a product is not for sale in this storefront). Never show a partial total.
    func total(prices: [String: Decimal]) -> Decimal? {
        var sum = Decimal.zero
        for id in items {
            guard let price = prices[id] else { return nil }
            sum += price
        }
        return sum
    }

    /// Offer Plus instead when the basket costs at least as much as a year of it.
    func suggestsPlus(prices: [String: Decimal], yearly: Decimal?) -> Bool {
        guard let yearly, let total = total(prices: prices) else { return false }
        return total >= yearly
    }
}
