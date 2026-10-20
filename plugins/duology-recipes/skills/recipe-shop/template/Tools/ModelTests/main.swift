// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
import Foundation

var failures = 0
var passes = 0

func check(_ ok: Bool, _ message: String) {
    if ok {
        passes += 1
        print("ok   \(message)")
    } else {
        failures += 1
        print("FAIL \(message)")
    }
}

func near(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.01) -> Bool { abs(a - b) <= tolerance }
func price(_ text: String) -> Decimal { Decimal(string: text)! }

let catalog = SampleCatalog.catalog
let prices = Dictionary(uniqueKeysWithValues: catalog.packs.map { ($0.id, $0.referencePrice) }
    + catalog.plans.map { ($0.id, $0.referencePrice) })

// MARK: Catalog

let ids = catalog.productIDs
check(Set(ids).count == ids.count, "every product ID is unique")
check(ids.allSatisfy { id in id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" } },
      "product IDs use only letters, digits, dots and underscores, as App Store Connect allows")
check(catalog.packs.allSatisfy { !$0.name.isEmpty && !$0.tracks.isEmpty && $0.minutes > 0 },
      "every pack has a name and at least one track")
check(catalog.pack("pack.rain")?.duration == .seconds(120 * 60), "a pack's length adds up its tracks")
check(catalog.packs.allSatisfy { (0...1).contains($0.hue) }, "every hue is between 0 and 1")
check(catalog.categories == PackCategory.allCases, "every category has packs")
check(catalog.packs(in: .rain).map(\.id) == ["pack.rain", "pack.thunder"], "filtering keeps shop order")
check(catalog.packs(in: nil).count == 12, "no filter shows all twelve")
check(catalog.packs.filter(\.isNew).count == 2, "two packs are new")
check(catalog.yearlyPlan?.id == "plus.yearly", "the yearly plan")
check(catalog.isPlan("plus.monthly") && !catalog.isPlan("pack.rain"), "plans and packs are told apart")

// MARK: The StoreKit configuration agrees with the catalog

// StoreKit/Shop.storekit is what Xcode sells in the simulator. A product missing there never
// loads; a price that differs makes the tests and the screenshots disagree.
struct StoreKitFile: Decodable {
    struct Localization: Decodable { var displayName: String }
    struct Offer: Decodable { var paymentMode: String; var subscriptionPeriod: String }
    struct Product: Decodable {
        var productID: String
        var displayPrice: String
        var type: String
        var localizations: [Localization]
        var recurringSubscriptionPeriod: String?
        var introductoryOffer: Offer?
    }
    struct Group: Decodable { var subscriptions: [Product] }
    var products: [Product]
    var subscriptionGroups: [Group]
}

let configURL = URL(fileURLWithPath: "StoreKit/Shop.storekit")
if let data = try? Data(contentsOf: configURL), let file = try? JSONDecoder().decode(StoreKitFile.self, from: data) {
    let products = Dictionary(uniqueKeysWithValues: file.products.map { ($0.productID, $0) })
    let subscriptions = file.subscriptionGroups.flatMap(\.subscriptions)
    let plans = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.productID, $0) })
    check(catalog.packs.allSatisfy { products[$0.id]?.type == "NonConsumable" },
          "every pack is a non-consumable in the StoreKit file")
    check(catalog.packs.allSatisfy { products[$0.id].map { price($0.displayPrice) } == $0.referencePrice },
          "every pack's price matches the StoreKit file")
    check(catalog.packs.allSatisfy { products[$0.id]?.localizations.first?.displayName == $0.name },
          "every pack's name matches the StoreKit file")
    check(Set(products.keys) == Set(catalog.packs.map(\.id)), "the StoreKit file sells nothing the catalog lacks")
    check(file.subscriptionGroups.count == 1, "both plans sit in one subscription group")
    check(catalog.plans.allSatisfy { plan in
        guard let product = plans[plan.id] else { return false }
        let period = plan.period == .year ? "P1Y" : "P1M"
        return product.type == "RecurringSubscription" && product.recurringSubscriptionPeriod == period
            && price(product.displayPrice) == plan.referencePrice
    }, "every plan's period and price match the StoreKit file")
    check(catalog.plans.allSatisfy { plan in
        let offer = plans[plan.id]?.introductoryOffer
        let days = offer.map { $0.subscriptionPeriod == "P1W" ? 7 : $0.subscriptionPeriod == "P1M" ? 30 : -1 } ?? 0
        return days == plan.trialDays && (offer == nil || offer?.paymentMode == "free")
    }, "free trials match the StoreKit file")
    check(Set(plans.keys) == Set(catalog.plans.map(\.id)), "the StoreKit file has no plan the catalog lacks")
} else {
    check(false, "StoreKit/Shop.storekit can be read (run from the project folder)")
}

// MARK: Ownership

let none = Ownership()
check(!none.hasPlus && !none.unlocks("pack.rain"), "nothing owned at first")
let some = Ownership(entitlements: ["pack.rain", "pack.ocean", "pack.gone"], catalog: catalog)
check(some.bought("pack.rain") && some.unlocks("pack.ocean") && !some.unlocks("pack.fireside"),
      "bought packs unlock, others don't")
check(!some.unlocks("pack.gone"), "an ID the catalog doesn't know unlocks nothing")
let plus = Ownership(entitlements: ["plus.monthly", "pack.rain"], catalog: catalog)
check(plus.hasPlus && plus.unlocks("pack.fireside"), "Plus unlocks every pack")
check(plus.bought("pack.rain") && !plus.bought("pack.fireside"), "but only bought packs count as bought")
check(Ownership(entitlements: ["plus.yearly", "plus.monthly"], catalog: catalog).plan == "plus.yearly"
      && Ownership(entitlements: ["plus.monthly", "plus.yearly"], catalog: catalog).plan == "plus.yearly",
      "both plans at once (an upgrade in flight): the yearly one wins")

// MARK: Basket

var cart = Cart()
check(cart.add("pack.rain") && !cart.add("pack.rain") && cart.count == 1, "a pack goes in once")
cart.add("pack.harbor")
cart.add("pack.fireside")
check(cart.items == ["pack.rain", "pack.harbor", "pack.fireside"], "the basket keeps the order packs were added")
check(cart.total(prices: prices) == price("8.97"), "2.99 + 3.99 + 1.99 is exactly 8.97")
check(cart.total(prices: ["pack.rain": 1]) == nil, "no total while a price is missing")
cart.toggle("pack.harbor")
check(!cart.contains("pack.harbor") && cart.count == 2, "toggle takes a pack out")
cart.toggle("pack.harbor")
check(cart.items.last == "pack.harbor", "and puts it back at the end")
check(Cart(["pack.rain", "pack.rain", "pack.ocean"]).items == ["pack.rain", "pack.ocean"], "a starting list drops repeats")
var owned = cart
let gone = owned.removeUnlocked(some)
check(gone == ["pack.rain"] && owned.items == ["pack.fireside", "pack.harbor"], "packs the person owns leave the basket")
var withPlus = cart
withPlus.removeUnlocked(plus)
check(withPlus.isEmpty, "Plus empties the basket")
check(!cart.suggestsPlus(prices: prices, yearly: price("29.99")), "a small basket doesn't push Plus")
let everything = Cart(catalog.packs.map(\.id))
check(everything.total(prices: prices) == price("33.88"), "the whole shop costs 33.88")
check(everything.suggestsPlus(prices: prices, yearly: price("29.99")), "a basket dearer than a year of Plus suggests it")
check(!everything.suggestsPlus(prices: prices, yearly: nil), "no suggestion without a yearly price")

// MARK: Checkout

var run = CheckoutRun(packs: ["a", "b", "c"])
check(run.next == "a" && !run.isBuying && !run.isFinished, "checkout starts with the first pack")
run.start("b")
check(run.status(of: "b") == .waiting, "only the next pack can start")
run.start("a")
check(run.next == nil && run.isBuying, "nothing else starts while one is being bought")
run.finish("b", .bought)
check(run.status(of: "b") == .waiting, "a pack that isn't being bought can't finish")
run.finish("a", .bought)
check(run.next == "b" && run.bought == ["a"], "a purchase moves on to the next pack")
run.start("b")
run.finish("b", .cancelled)
check(run.isStopped && run.next == nil && run.remaining == ["b", "c"], "a cancel stops the run")
run.resume()
check(!run.isStopped && run.next == "b" && run.status(of: "b") == .waiting, "resume carries on from the cancelled pack")
run.start("b")
run.finish("b", .pending)
check(run.next == "c" && run.pending == ["b"], "pending (Ask to Buy) moves on")
run.start("c")
run.finish("c", .failed("No network"))
check(run.isStopped && run.failure == "No network" && !run.isFinished, "an error stops the run with its message")
run.resume()
run.start("c")
run.finish("c", .bought)
check(run.isFinished && run.bought == ["a", "c"] && run.remaining.isEmpty, "every pack bought or pending: finished")
var dropping = CheckoutRun(packs: ["a", "b"])
dropping.start("a")
dropping.drop("a")
dropping.drop("b")
check(dropping.lines.map(\.id) == ["a"], "drop keeps a pack that is being bought")
check(CheckoutRun(packs: []).isFinished && CheckoutRun(packs: []).next == nil, "an empty run has nothing to do")

// MARK: Plans

check(PlanMath.percentSaved(yearly: price("29.99"), monthly: price("3.99")) == 37,
      "29.99 a year against 3.99 a month saves 37%, rounded down")
check(PlanMath.percentSaved(yearly: price("47.88"), monthly: price("3.99")) == nil, "no saving, no badge")
check(PlanMath.percentSaved(yearly: 50, monthly: price("3.99")) == nil, "a dearer year, no badge")
check(PlanMath.percentSaved(yearly: 10, monthly: 0) == nil, "a free month, no badge")

// MARK: The grid on the fold

// Numbers from duo-design-system's worked example: the outer display's grid is 362 pt wide;
// the open phone's is 847 pt with the fold's frame at 435 to 475 in the grid's coordinates.
let flatFold = DuoFold(minX: 435, maxX: 475, isActive: false)
let bentFold = DuoFold(minX: 435, maxX: 475, isActive: true)

let closedTiles = DuoColumns(width: 362, count: 4, gutter: 12).grouped(by: 2)
check(closedTiles.columns.count == 2 && near(closedTiles.columns[0].width, 175), "closed: two packs per row, 175 pt each")
let closedCards = DuoColumns(width: 362, count: 4, gutter: 12).grouped(by: 4)
check(closedCards.columns.count == 1 && near(closedCards.columns[0].width, 362), "closed: one card per row")
for (name, fold) in [("flat", flatFold), ("partly folded", bentFold)] {
    let tiles = DuoColumns(width: 847, count: 8, gutter: 16, fold: fold).grouped(by: 2)
    check(tiles.columns.count == 4 && tiles.split == 2, "open, \(name): four packs per row, two on each side")
    check(!tiles.columns.contains { $0.x < fold.maxX && $0.maxX > fold.minX } || !fold.isActive,
          "open, \(name): no pack in the fold")
    let cards = DuoColumns(width: 847, count: 8, gutter: 16, fold: fold).grouped(by: 4)
    check(cards.columns.count == 2 && cards.columns[0].maxX <= fold.maxX && cards.columns[1].x >= fold.minX,
          "open, \(name): one card on each side of the fold")
}
let flatTiles = DuoColumns(width: 847, count: 8, gutter: 16, fold: flatFold).grouped(by: 2)
check(near(flatTiles.columns[1].maxX + 8, 455) && near(flatTiles.columns[2].x - 8, 455),
      "flat: the gutter between the halves is centred on the fold line")
let accessible = DuoColumns(width: 847, count: 8, gutter: 16, fold: flatFold).grouped(by: 4)
check(accessible.columns.count == 2, "accessibility sizes (span 4): one pack per side")
let pane = PaneFrames(width: 847, count: 8, gutter: 16, fold: bentFold)
check(pane.map { near($0.leading.maxX, 435) && near($0.trailing.x, 475) } == true,
      "a pack open: the grid ends at the fold, the pack starts after it")
check(PaneFrames(width: 0, count: 8, gutter: 16, fold: nil) == nil, "no panes before the first layout pass")

// MARK: Concurrency

// The app target compiles with default main actor isolation. Here the model runs off the
// main actor, and the check calls a method, a computed property or == on every model type,
// so a type that loses `nonisolated` stops this build. Add a line for each new type.
let offMain = await Task.detached { () -> Bool in
    let shop = SampleCatalog.catalog                                          // SampleCatalog
    let same = shop == SampleCatalog.catalog                                   // Catalog ==
    let pack = shop.pack("pack.rain")
    let minutes = (pack?.minutes ?? 0) > 0 && pack == shop.packs.first        // Pack
    let category = PackCategory.rain.name == "Rain"                            // PackCategory
    let track = pack?.tracks.first?.duration == .seconds(1200)                  // Track
    let plan = shop.plan("plus.yearly")?.period == .year                       // Plan, Plan.Period
    let owner = Ownership(entitlements: ["pack.rain"], catalog: shop)
    let owns = owner.unlocks("pack.rain") && owner == owner                    // Ownership
    var basket = Cart(["pack.rain"])
    let added = basket.add("pack.ocean") && basket != Cart()                   // Cart
    var checkout = CheckoutRun(packs: ["pack.rain"])
    checkout.start("pack.rain")
    checkout.finish("pack.rain", .bought)                                      // CheckoutRun.Outcome
    let line = checkout.lines.first == CheckoutRun.Line(id: "pack.rain", status: .bought) // Line, Status
    let math = PlanMath.percentSaved(yearly: 30, monthly: 4) == 37             // PlanMath
    let fold = DuoFold(minX: 1, maxX: 2, isActive: false)
    let folds = fold == DuoFold(minX: 1, maxX: 2, isActive: false)            // DuoFold ==
    let grid = DuoColumns(width: 100, count: 4, gutter: 4, fold: nil)
    let column = grid.columns.first?.maxX == 22                                 // DuoColumns, Column
    let panes = PaneFrames(width: 100, count: 4, gutter: 4, fold: nil)?.gap == 4 // PaneFrames
    return same && minutes && category && track && plan && owns && added && line && math
        && folds && column && panes
}.value
check(offMain, "the model runs off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
