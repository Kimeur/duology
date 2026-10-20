import StoreKitTest
import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// StoreKit: the scheme's StoreKit configuration reaches the app only when Xcode runs it
/// (measured: with `xcodebuild test`, prices stayed unavailable, even with the file set on
/// the test action too). So each test opens an `SKTestSession` on StoreKit/Shop.storekit,
/// found through this file's path on the Mac. It clears past purchases and turns off the
/// confirmation sheets, so purchases complete without a tap.
///
/// Every test starts from launch switches (LaunchOptions.swift) and finds elements by
/// identifier, never by screen position, so each one passes in whatever pose the simulator
/// is in: closed, a pack is pushed; open, it sits in the trailing pane.
final class __APP_NAME__UITests: XCTestCase {

    @MainActor private static var session: SKTestSession?

    // MARK: Shop

    @MainActor
    func testPricesComeFromTheStoreKitConfiguration() {
        let app = launch()
        let tile = element(app, "tile.pack.rain")
        XCTAssertTrue(tile.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(tile, labelContaining: "$2.99"), "StoreKit's price: \(tile.label)")
        XCTAssertTrue(waitFor(element(app, "shop.plusPrice"), labelContaining: "$29.99"),
                      "the Plus card shows the yearly price")
    }

    /// Closed: two packs per row. Open with nothing picked: four, two on each side of the fold,
    /// and two once a pack takes the trailing pane.
    @MainActor
    func testPacksSitInEvenColumns() {
        let app = launch()
        XCTAssertTrue(element(app, "tile.pack.rain").waitForExistence(timeout: 30))
        let alone = firstRow(app)
        XCTAssertEqual(alone.count % 2, 0, "an even number per row, so the fold falls between packs")
        element(app, "tile.pack.harbor").tapCentre()
        XCTAssertTrue(element(app, "detail.title").waitForExistence(timeout: 5))
        if hasTwoPanes(app) {
            XCTAssertEqual(alone.count, 4, "open: four packs per row")
            XCTAssertEqual(firstRow(app).count, 2, "open with a pack: two per row in the leading pane")
        } else {
            XCTAssertEqual(alone.count, 2, "closed: two packs per row")
        }
    }

    // MARK: List and detail

    @MainActor
    func testPickingAPackShowsItsDetail() {
        let app = launch()
        let tile = element(app, "tile.pack.harbor")
        XCTAssertTrue(tile.waitForExistence(timeout: 30))
        tile.tapCentre()
        let title = element(app, "detail.title")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the pack opens")
        XCTAssertEqual(title.label, "Harbor at Dawn")
        XCTAssertTrue(element(app, "detail.tracks").exists, "with its sounds")
        if hasTwoPanes(app) {
            let leading = element(app, "pane.leading").frame
            let trailing = element(app, "pane.trailing").frame
            XCTAssertLessThanOrEqual(leading.maxX, trailing.minX, "open: the grid and the pack side by side")
            XCTAssertTrue(title.frame.minX >= trailing.minX, "the pack is in the trailing pane")
            XCTAssertTrue(element(app, "tile.pack.harbor").isSelected, "and its tile stays picked")
            XCTAssertEqual(firstRow(app).count, 2, "the grid keeps two packs per row in its pane")
            let close = element(app, "detail.close").frame
            XCTAssertGreaterThanOrEqual(min(close.width, close.height), 44, "the close button is a 44 pt target")
        }
        closeDetail(app)
        XCTAssertTrue(element(app, "detail.title").waitForNonExistence(timeout: 5), "the pack closes")
        XCTAssertTrue(element(app, "tile.pack.harbor").waitForExistence(timeout: 5), "and the grid is back")
    }

    // MARK: Basket

    @MainActor
    func testAddingAPackFillsTheBasket() {
        let app = launch(["-select", "pack.rain"])
        let add = element(app, "detail.basket")
        XCTAssertTrue(add.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(add, enabled: true), "StoreKit loaded the product")
        XCTAssertEqual(add.label, "Add to basket")
        add.tapCentre()
        XCTAssertTrue(waitFor(add, labelContaining: "In basket"), "the button says it's in")
        openBasket(app)
        XCTAssertTrue(element(app, "basket.line.pack.rain").waitForExistence(timeout: 5), "the basket has it")
        XCTAssertTrue(waitFor(element(app, "basket.total"), labelContaining: "$2.99"))
    }

    @MainActor
    func testBasketTotalsAndRemoves() {
        let app = launch(["-basket", "pack.rain,pack.harbor,pack.fireside", "-openBasket"])
        let total = element(app, "basket.total")
        XCTAssertTrue(total.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(total, labelContaining: "$8.97"), "2.99 + 3.99 + 1.99: \(total.label)")
        XCTAssertTrue(element(app, "basket.buy").label.contains("Buy 3 packs"), element(app, "basket.buy").label)
        if hasTwoPanes(app) {
            let trailing = element(app, "pane.trailing").frame
            XCTAssertTrue(element(app, "basket.buy").frame.minX >= trailing.minX, "open: Buy is in the trailing pane")
            XCTAssertTrue(element(app, "basket.lines").frame.maxX <= trailing.minX, "and the packs beside it")
        } else {
            XCTAssertTrue(element(app, "basket.buy").isHittable, "closed: Buy is pinned in reach")
        }
        attachScreenshot(app, "basket")
        element(app, "basket.remove.pack.fireside").tapCentre()
        XCTAssertTrue(waitFor(total, labelContaining: "$6.98"), "one pack fewer: \(total.label)")
        XCTAssertFalse(element(app, "basket.line.pack.fireside").exists)
    }

    // MARK: Checkout

    @MainActor
    func testCheckoutBuysEveryPackInTheBasket() {
        // Packs in the grid's first row, so their tiles exist on the closed phone without scrolling.
        let app = launch(["-basket", "pack.rain,pack.harbor", "-openBasket"])
        let buy = element(app, "basket.buy")
        XCTAssertTrue(buy.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(buy, enabled: true), "Buy works once the prices load")
        buy.tapCentre()
        let done = element(app, "basket.done")
        XCTAssertTrue(done.waitForExistence(timeout: 30), "both purchases go through")
        XCTAssertEqual(done.label, "2 packs are yours")
        buy.tapCentre()   // now "Back to the shop"
        let tile = element(app, "tile.pack.rain")
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "back in the shop")
        XCTAssertTrue(waitFor(tile, labelContaining: "owned"), "the shop shows it owned: \(tile.label)")
        openBasket(app)
        XCTAssertTrue(element(app, "basket.empty").waitForExistence(timeout: 5), "the basket is empty")
    }

    @MainActor
    func testAFailedPurchaseStopsCheckoutUntilResumed() async throws {
        let session = startStoreKit()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let app = launch(["-basket", "pack.cafe,pack.library", "-openBasket"], resetStoreKit: false)
        let buy = element(app, "basket.buy")
        XCTAssertTrue(buy.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(buy, enabled: true))
        buy.tapCentre()
        XCTAssertTrue(waitFor(buy, labelContaining: "Buy the rest"), "an error stops checkout: \(buy.label)")
        XCTAssertFalse(element(app, "basket.done").exists, "nothing was bought")
        try await session.setSimulatedError(nil, forAPI: .purchase)
        buy.tapCentre()
        XCTAssertTrue(element(app, "basket.done").waitForExistence(timeout: 30), "the rest goes through")
        XCTAssertEqual(element(app, "basket.done").label, "2 packs are yours")
    }

    @MainActor
    func testAskToBuyLeavesThePackWaiting() {
        let session = startStoreKit()
        session.askToBuyEnabled = true
        let app = launch(["-basket", "pack.ocean", "-openBasket"], resetStoreKit: false)
        let buy = element(app, "basket.buy")
        XCTAssertTrue(waitFor(buy, enabled: true, timeout: 30))
        buy.tapCentre()
        XCTAssertTrue(element(app, "basket.pending").waitForExistence(timeout: 30), "pending is not a failure")
        XCTAssertEqual(element(app, "basket.done").label, "Waiting for approval")
    }

    // MARK: Plus

    @MainActor
    func testPlusShowsBothPlansFromStoreKit() {
        let app = launch(["-openPlus"])
        let yearly = element(app, "plan.plus.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 30))
        XCTAssertTrue(waitFor(yearly, labelContaining: "$29.99"), yearly.label)
        XCTAssertTrue(waitFor(element(app, "plan.plus.monthly"), labelContaining: "$3.99"))
        let subscribe = element(app, "plus.subscribe")
        XCTAssertTrue(waitFor(subscribe, enabled: true), "Subscribe works once the plans load")
        XCTAssertTrue(subscribe.isHittable, "Subscribe is in reach")
        if hasTwoPanes(app) {
            let trailing = element(app, "pane.trailing").frame
            XCTAssertTrue(yearly.frame.minX >= trailing.minX, "open: the plans are in the trailing pane")
            XCTAssertTrue(element(app, "plus.title").frame.maxX <= trailing.minX, "beside what Plus gives")
        }
        attachScreenshot(app, "plus")
        // Closed, the plans sit below the benefits, and the pinned Subscribe button covers the
        // bottom of the screen. A coordinate tap doesn't scroll, so bring the plan into view first.
        XCTAssertTrue(reveal(app, "plan.plus.monthly", above: "plus.subscribe"), "the monthly plan scrolls into view")
        element(app, "plan.plus.monthly").tapCentre()
        XCTAssertTrue(element(app, "plan.plus.monthly").isSelected, "a plan can be picked")
        app.buttons["plus.close"].firstMatch.tapCentre()
        XCTAssertTrue(element(app, "tile.pack.rain").waitForExistence(timeout: 5), "Close goes back to the shop")
    }

    @MainActor
    func testSubscribingUnlocksEveryPack() {
        let app = launch(["-openPlus", "-basket", "pack.rain"])
        let subscribe = element(app, "plus.subscribe")
        XCTAssertTrue(waitFor(subscribe, enabled: true, timeout: 30))
        XCTAssertEqual(subscribe.label, "Try it free", "the yearly plan offers its free week")
        subscribe.tapCentre()
        let title = element(app, "shop.plusTitle")
        XCTAssertTrue(title.waitForExistence(timeout: 30), "the paywall closes on success")
        XCTAssertTrue(waitFor(title, labelContaining: "while Plus is on"), title.label)
        XCTAssertTrue(waitFor(element(app, "tile.pack.harbor"), labelContaining: "included with Plus"))
        openBasket(app)
        XCTAssertTrue(element(app, "basket.empty").waitForExistence(timeout: 5), "Plus empties the basket")
    }

    // MARK: Layout and screenshots

    /// Open: the grid spans the window, four packs per row; with a pack open, the grid and the
    /// pack sit on each side of the fold. Closed: one column. Run it once per pose (set the pose
    /// in Device Hub). Saves screenshots to the result bundle
    /// (export with `xcrun xcresulttool export attachments`).
    @MainActor
    func testLayoutInThisPose() {
        let app = launch()
        XCTAssertTrue(element(app, "tile.pack.rain").waitForExistence(timeout: 30), "the shop shows")
        XCTAssertTrue(waitFor(element(app, "tile.pack.rain"), labelContaining: "$"), "with prices")
        attachScreenshot(app, "shop")
        element(app, "tile.pack.harbor").tapCentre()
        XCTAssertTrue(element(app, "detail.title").waitForExistence(timeout: 5))
        if hasTwoPanes(app) {
            let leading = element(app, "pane.leading").frame
            let trailing = element(app, "pane.trailing").frame
            XCTAssertLessThanOrEqual(leading.maxX, trailing.minX - 12, "a gutter or the fold between the panes")
            XCTAssertLessThan(trailing.minX - leading.maxX, 60, "but no wider than the fold's frame")
            let frames = XCTAttachment(string: "window \(app.windows.firstMatch.frame)\nleading pane \(leading)\ntrailing pane \(trailing)")
            frames.name = "pane-frames"
            frames.lifetime = .keepAlways
            add(frames)
        }
        attachScreenshot(app, "pack")
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String] = [], resetStoreKit: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        if resetStoreKit {
            startStoreKit()
        }
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
        return app
    }

    /// A StoreKit test session on the project's configuration, back to its defaults, with no
    /// past purchases and no confirmation sheets. The file is found from this source file's
    /// path, which the simulator can read; a device can't, so run these on a simulator.
    @MainActor
    @discardableResult
    private func startStoreKit() -> SKTestSession {
        let session: SKTestSession
        if let open = Self.session {
            session = open
        } else {
            let file = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("StoreKit/Shop.storekit")
            do {
                session = try SKTestSession(contentsOf: file)
            } catch {
                fatalError("Can't open \(file.path): \(error)")
            }
            Self.session = session
        }
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Scrolls the leading pane until the element is on screen and, when `pinned` is given,
    /// fully above that pinned button. Elements of a lazy grid don't exist until they scroll in.
    @MainActor
    private func reveal(_ app: XCUIApplication, _ id: String, above pinned: String? = nil) -> Bool {
        let target = element(app, id)
        let pane = element(app, "pane.leading")
        func inView() -> Bool {
            guard target.exists, target.isHittable else { return false }
            guard let pinned else { return true }
            return target.frame.maxY <= element(app, pinned).frame.minY
        }
        for _ in 0..<8 where !inView() {
            pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        return inView()
    }

    /// The tiles in the first row of the grid, left to right.
    @MainActor
    private func firstRow(_ app: XCUIApplication) -> [CGRect] {
        let tiles = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'tile.'"))
            .allElementsBoundByIndex
            .map(\.frame)
        guard let top = tiles.map(\.minY).min() else { return [] }
        return tiles.filter { abs($0.minY - top) < 2 }.sorted { $0.minX < $1.minX }
    }

    /// Open, the screen has a trailing pane. Read from the app, never from the pose: a narrow
    /// Split View window on the open phone has one pane, like the closed phone.
    @MainActor
    private func hasTwoPanes(_ app: XCUIApplication) -> Bool {
        element(app, "pane.trailing").exists
    }

    /// Open: the pack's close button. Closed: the navigation stack's back button.
    ///
    /// On the closed iPhone Duo the back button sits in the vertical bar, which XCUITest
    /// reports as a Toolbar, not a NavigationBar, so `app.navigationBars.buttons` doesn't
    /// find it. Its identifier, `BackButton`, does.
    @MainActor
    private func closeDetail(_ app: XCUIApplication) {
        let close = element(app, "detail.close")
        if close.exists {
            close.tapCentre()
            return
        }
        let back = app.buttons["BackButton"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "closed: a back button")
        back.tapCentre()
    }

    @MainActor
    private func openBasket(_ app: XCUIApplication) {
        let basket = app.buttons["toolbar.basket"].firstMatch
        XCTAssertTrue(basket.waitForExistence(timeout: 5), "a basket button in the bar")
        basket.tapCentre()
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, labelContaining text: String, timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    @MainActor
    private func waitFor(_ element: XCUIElement, enabled: Bool, timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled))
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    /// One screenshot per display; the one not in use is black. `XCUIScreen.main` and
    /// `app.screenshot()` give the outer display only, black while the phone is open (measured);
    /// `XCUIScreen.screens` lists both.
    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let window = app.windows.firstMatch.frame
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "\(name)-\(Int(window.width))x\(Int(window.height))-screen\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
}

extension XCUIElement {
    /// Taps through a coordinate made from the element itself. On the iPhone Duo simulator,
    /// points worked out from the app's frame can miss the app; element-relative ones land.
    @MainActor
    func tapCentre() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
