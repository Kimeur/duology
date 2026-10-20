import Foundation

/// What the person may use: packs they bought, and Plus while it is active.
///
/// Built from the product IDs of StoreKit's current entitlements, which the app checks
/// (verified, not revoked) before it passes them here. Foundation only, so the rules run on
/// the Mac in Tools/run-model-tests.sh.
nonisolated struct Ownership: Equatable, Sendable {
    /// Packs bought one by one. They stay owned when Plus ends.
    private(set) var boughtPacks: Set<Pack.ID> = []
    /// The active Plus plan, or nil.
    private(set) var plan: Plan.ID?

    init() {}

    /// Sorts entitlement product IDs into packs and a plan. IDs the catalog doesn't know
    /// are ignored, so an old product can't unlock anything.
    init(entitlements: some Sequence<String>, catalog: Catalog) {
        for id in entitlements {
            if catalog.isPlan(id) {
                // One subscription group, so at most one plan is active. Keep the yearly one
                // if StoreKit ever reports both during an upgrade.
                if plan == nil || catalog.plan(id)?.period == .year { plan = id }
            } else if catalog.pack(id) != nil {
                boughtPacks.insert(id)
            }
        }
    }

    var hasPlus: Bool { plan != nil }

    /// The person can listen to this pack.
    func unlocks(_ pack: Pack.ID) -> Bool { hasPlus || boughtPacks.contains(pack) }

    /// Bought on its own, so it stays when Plus ends.
    func bought(_ pack: Pack.ID) -> Bool { boughtPacks.contains(pack) }
}
