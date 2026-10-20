import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift) and finds elements by
/// identifier, never by screen position. So each test passes in whatever pose the simulator
/// is in: closed, the detail is pushed; open, it sits in the trailing pane.
final class __APP_NAME__UITests: XCTestCase {

    /// Sample transaction 6: Vinyl Corner, entertainment, on 18 October. Among the six
    /// newest, so the closed phone's dashboard lists it without "Show all".
    private let vinyl = 6
    /// Sample transaction 8: Sushi Komachi, eating out, on 17 October.
    private let sushi = 8
    /// Sample transaction 10: Harbor Market, groceries, on 16 October.
    private let market = 10

    // MARK: Overview

    @MainActor
    func testOverviewShowsBalanceAndRecentSpending() {
        let app = launch()
        let balance = element(app, "balance.total")
        XCTAssertTrue(balance.waitForExistence(timeout: 30))
        XCTAssertTrue(balance.label.contains("11,108.91"), "the sample balance: \(balance.label)")
        XCTAssertTrue(element(app, "spending.card").exists, "the spending chart shows")
        XCTAssertTrue(element(app, "summary.out").exists, "money out shows")
        XCTAssertTrue(reveal(app, "txn.1"), "the newest transaction shows")
    }

    // MARK: List and detail

    @MainActor
    func testPickingATransactionShowsItsDetail() {
        let app = launch()
        XCTAssertTrue(element(app, "pane.leading").waitForExistence(timeout: 30))
        XCTAssertTrue(reveal(app, "txn.\(vinyl)"), "the row shows")
        element(app, "txn.\(vinyl)").tapCentre()
        let title = element(app, "detail.title")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the detail opens")
        XCTAssertEqual(title.label, "Vinyl Corner")
        XCTAssertTrue(element(app, "detail.history").exists, "with what this merchant cost each month")
        if isTwoPane(app) {
            XCTAssertTrue(element(app, "txn.\(vinyl)").isSelected, "open: the row stays picked beside the detail")
        }
        closeDetail(app)
        XCTAssertTrue(element(app, "detail.title").waitForNonExistence(timeout: 5), "the detail closes")
        XCTAssertTrue(element(app, "spending.card").exists, "and the dashboard is back")
    }

    @MainActor
    func testLaunchSelectionOpensTheDetail() {
        let app = launch(["-select", "\(market)"])
        let title = element(app, "detail.title")
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        XCTAssertEqual(title.label, "Harbor Market")
        XCTAssertTrue(element(app, "detail.amount").label.contains("81.65"))
    }

    @MainActor
    func testChangingTheCategoryMovesTheTransaction() {
        let app = launch(["-select", "\(sushi)"])
        let picker = element(app, "detail.category")
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        picker.tapCentre()
        let groceries = app.buttons["Groceries"].firstMatch
        XCTAssertTrue(groceries.waitForExistence(timeout: 5), "the category menu opens")
        groceries.tapCentre()
        closeDetail(app)
        XCTAssertTrue(element(app, "pane.leading").waitForExistence(timeout: 5))
        if !isTwoPane(app) {
            // Closed, the dashboard lists the six newest; this one is further down. The button
            // exists before it scrolls in, and a coordinate tap doesn't scroll (measured: the
            // tap landed off screen and did nothing), so reveal it first.
            XCTAssertTrue(reveal(app, "activity.showAll"), "closed: a button for the rest")
            element(app, "activity.showAll").tapCentre()
        }
        XCTAssertTrue(reveal(app, "txn.\(sushi)"), "the row shows")
        let row = element(app, "txn.\(sushi)")
        XCTAssertTrue(row.label.contains("Groceries"), "the list shows the new category: \(row.label)")
    }

    // MARK: Filter

    @MainActor
    func testFilterShowsOneCategory() {
        let app = launch(["-filter", "dining"])
        XCTAssertTrue(element(app, "pane.leading").waitForExistence(timeout: 30))
        XCTAssertTrue(reveal(app, "txn.\(sushi)"), "eating out stays")
        XCTAssertFalse(element(app, "txn.\(market)").exists, "groceries go")
        let clear = element(app, "filter.clear")
        XCTAssertTrue(clear.exists, "the filter says what it shows")
        clear.tapCentre()
        XCTAssertTrue(reveal(app, "txn.1"), "clearing it brings everything back")
    }

    // MARK: Layout and screenshots

    /// Open: two panes side by side, the gap between them on the fold. Closed: one pane.
    /// Run it once per pose (set the pose in Device Hub). Saves a screenshot of each display to
    /// the result bundle (export with `xcrun xcresulttool export attachments`); the display not
    /// in use is black.
    @MainActor
    func testLayoutInThisPose() {
        let app = launch()
        XCTAssertTrue(element(app, "pane.leading").waitForExistence(timeout: 30), "the dashboard shows")
        let window = app.windows.firstMatch.frame
        let leading = element(app, "pane.leading").frame
        // Compare left and right edges only: the panes scroll, the columns don't move.
        let balance = element(app, "balance.total").frame
        XCTAssertTrue(balance.minX >= leading.minX && balance.maxX <= leading.maxX, "the balance is in the leading pane")
        if isTwoPane(app) {
            let trailing = element(app, "pane.trailing").frame
            let frames = XCTAttachment(string: "window \(window)\nleading pane \(leading)\ntrailing pane \(trailing)")
            frames.name = "pane-frames"
            frames.lifetime = .keepAlways
            add(frames)
            XCTAssertLessThanOrEqual(leading.maxX, trailing.minX - 12, "a gutter or the fold between the panes")
            XCTAssertLessThan(trailing.minX - leading.maxX, 60, "but no wider than the fold's frame")
            XCTAssertTrue(reveal(app, "txn.\(vinyl)"))
            element(app, "txn.\(vinyl)").tapCentre()
            let title = element(app, "detail.title")
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            XCTAssertTrue(title.frame.minX >= trailing.minX && title.frame.maxX <= trailing.maxX,
                          "the detail is in the trailing pane")
            let close = element(app, "detail.close").frame
            XCTAssertGreaterThanOrEqual(min(close.width, close.height), 44, "the close button is a 44 pt target")
        } else {
            XCTAssertGreaterThan(leading.width, window.width * 0.6, "closed: one pane fills the window")
        }
        // One screenshot per display. XCUIScreen.main is the outer display, which is black
        // while the phone is open (measured); XCUIScreen.screens lists both.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "dashboard-\(Int(window.width))x\(Int(window.height))-screen\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
        return app
    }

    /// Scrolls the leading pane until the element is on screen. Rows are lazy, so a row
    /// below the visible part of the pane doesn't exist until it scrolls in.
    @MainActor
    private func reveal(_ app: XCUIApplication, _ id: String) -> Bool {
        let target = element(app, id)
        let pane = element(app, "pane.leading")
        for _ in 0..<10 {
            if target.exists, target.isHittable { return true }
            pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        }
        return target.exists && target.isHittable
    }

    /// Open, the trailing pane exists. Closed, the stack pushes the detail instead.
    @MainActor
    private func isTwoPane(_ app: XCUIApplication) -> Bool {
        element(app, "pane.trailing").exists
    }

    /// Open: the detail's close button. Closed: the navigation stack's back button.
    ///
    /// On the closed iPhone Duo the back button sits in the vertical bar, which XCUITest
    /// reports as a Toolbar, not a NavigationBar: `app.navigationBars.buttons` doesn't find
    /// it (measured). Its identifier, `BackButton`, does.
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
