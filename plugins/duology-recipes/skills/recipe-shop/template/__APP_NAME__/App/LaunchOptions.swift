import SwiftUI

/// Launch switches for the UI tests, and for trying things by hand from the scheme.
/// Debug builds only: a Release build ignores every switch.
///
///   -uiTesting          animations off
///   -select ID          open a pack, for example -select pack.harbor
///   -category NAME      show one category, for example -category rain
///   -basket ID,ID       start with these packs in the basket
///   -openBasket         start on the basket
///   -openPlus           start on the Plus screen
enum LaunchOptions {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif

    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    static func configure() {
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    /// The sample shop, with any switches applied.
    static func makeModel() -> ShopModel {
        let catalog = SampleCatalog.catalog
        let basket = value(after: "-basket")?
            .split(separator: ",")
            .map(String.init)
            .filter { catalog.pack($0) != nil } ?? []
        let model = ShopModel(catalog: catalog, store: Store(catalog: catalog), cart: Cart(basket))
        if let id = value(after: "-select"), catalog.pack(id) != nil {
            model.selection = id
        }
        if let name = value(after: "-category") {
            model.category = PackCategory(rawValue: name)
        }
        model.isBasketOpen = arguments.contains("-openBasket")
        model.isPlusOpen = arguments.contains("-openPlus")
        return model
    }

    /// The value after the last `name`, so a later switch overrides an earlier one.
    private static func value(after name: String) -> String? {
        guard let index = arguments.lastIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
