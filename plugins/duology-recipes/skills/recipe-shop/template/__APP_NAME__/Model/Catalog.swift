import Foundation

/// What kind of sound a pack holds, for the filter bar.
nonisolated enum PackCategory: String, CaseIterable, Identifiable, Sendable {
    case rain, water, nature, city, indoors

    var id: String { rawValue }

    var name: String {
        switch self {
        case .rain: "Rain"
        case .water: "Water"
        case .nature: "Nature"
        case .city: "City"
        case .indoors: "Indoors"
        }
    }
}

/// One recording in a pack.
nonisolated struct Track: Hashable, Sendable {
    var title: String
    var minutes: Int

    var duration: Duration { .seconds(minutes * 60) }
}

/// One thing the shop sells: a sound pack, bought once (a StoreKit non-consumable).
nonisolated struct Pack: Identifiable, Hashable, Sendable {
    /// The StoreKit product ID. The same string in StoreKit/Shop.storekit and, later, in
    /// App Store Connect. Tools/run-model-tests.sh checks the two files agree.
    let id: String
    var name: String
    var tagline: String
    var summary: String
    var category: PackCategory
    /// SF Symbol for the artwork.
    var symbol: String
    /// Hue of the artwork's gradient, 0...1. The view turns it into colours.
    var hue: Double
    var tracks: [Track]
    /// The price in the StoreKit configuration. Only the model tests use it; the app always
    /// shows the price StoreKit returns, in the person's currency.
    var referencePrice: Decimal
    var isNew = false

    var minutes: Int { tracks.reduce(0) { $0 + $1.minutes } }
    var duration: Duration { .seconds(minutes * 60) }
}

/// A Plus subscription: every pack while it is active. Both plans sit in one subscription
/// group, so a person has one or the other, never both.
nonisolated struct Plan: Identifiable, Hashable, Sendable {
    enum Period: Sendable {
        case month, year
    }

    /// The StoreKit product ID.
    let id: String
    var period: Period
    var referencePrice: Decimal
    /// Free days before the first payment, for people who never had Plus. 0 for none.
    var trialDays: Int
}

/// Everything the shop sells.
nonisolated struct Catalog: Equatable, Sendable {
    var packs: [Pack]
    var plans: [Plan]

    /// Every product ID to ask StoreKit for: the packs and the plans.
    var productIDs: [String] { packs.map(\.id) + plans.map(\.id) }

    func pack(_ id: Pack.ID) -> Pack? { packs.first { $0.id == id } }
    func plan(_ id: Plan.ID) -> Plan? { plans.first { $0.id == id } }
    func isPlan(_ id: String) -> Bool { plans.contains { $0.id == id } }

    /// Packs in shop order, only one category when `category` is set.
    func packs(in category: PackCategory?) -> [Pack] {
        guard let category else { return packs }
        return packs.filter { $0.category == category }
    }

    /// Categories that have at least one pack, in their declared order.
    var categories: [PackCategory] {
        PackCategory.allCases.filter { category in packs.contains { $0.category == category } }
    }

    var yearlyPlan: Plan? { plans.first { $0.period == .year } }
}
