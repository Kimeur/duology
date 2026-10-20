import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift), finds elements by
/// identifier, and reads the reader through the `reader.state` test marker: the book,
/// chapter, saved offset, the characters on screen and the layout mode. Never through
/// screen positions. So a test passes whatever pose, display or orientation the
/// simulator is in, and checks the one rule that matters everywhere: the saved place
/// is on screen.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: Library

    @MainActor
    func testLibraryOpensABook() {
        let app = launch(["-resetState"])
        let tile = element(app, "library.book.keeper")
        XCTAssertTrue(tile.waitForExistence(timeout: 30), "the shelf shows the books")
        XCTAssertEqual(tile.value as? String, "New")
        tile.tapCentre()
        XCTAssertTrue(waitForReady(app), "the reader paginates the first chapter")
        let state = self.state(app)
        XCTAssertEqual(state["book"], "keeper")
        XCTAssertEqual(state["chapter"], "0")
        XCTAssertEqual(state["offset"], "0", "a new book opens at its first character")
        XCTAssertGreaterThan(Int(state["pages"] ?? "") ?? 0, 1, "the chapter fills more than one page")
    }

    @MainActor
    func testLibraryRemembersWhereYouAre() {
        launchReader(["-open", "bread", "-chapter", "1", "-offset", "900"])
        let app = launch()   // no -resetState: the saved place comes back
        let card = element(app, "library.continue")
        XCTAssertTrue(card.waitForExistence(timeout: 30), "Continue Reading shows the last book")
        XCTAssertTrue((element(app, "library.book.bread").value as? String ?? "").hasSuffix("percent read"),
                      "and its tile shows how far you got")
        card.tapCentre()
        XCTAssertTrue(waitForReady(app))
        XCTAssertEqual(state(app)["chapter"], "1", "the reader opens at the saved chapter")
        XCTAssertEqual(state(app)["offset"], "900", "and the saved offset")
        assertPlaceIsOnScreen(app)
    }

    // MARK: Turning pages

    @MainActor
    func testNextAndPreviousPage() {
        let app = launchReader(["-open", "keeper"])
        element(app, "reader.next").tapCentre()
        XCTAssertTrue(waitForState(app, "first=", notEqual: "first=0|", timeout: 5), "next shows later pages")
        let moved = state(app)
        XCTAssertGreaterThan(Int(moved["offset"] ?? "") ?? 0, 0, "the place moves to the new page's first character")
        assertPlaceIsOnScreen(app)
        element(app, "reader.previous").tapCentre()
        XCTAssertTrue(waitForState(app, "offset=0", timeout: 5), "previous goes back to the start")
    }

    @MainActor
    func testTheLastPageLeadsToTheNextChapter() {
        // An offset past the end lands on the chapter's last page.
        let app = launchReader(["-open", "keeper", "-chapter", "0", "-offset", "999999"])
        assertPlaceIsOnScreen(app)
        element(app, "reader.next").tapCentre()
        XCTAssertTrue(waitForState(app, "chapter=1", timeout: 5), "next on the last page opens chapter 2")
        XCTAssertTrue(waitForState(app, "offset=0", timeout: 5), "at its start")
    }

    @MainActor
    func testTheFirstPageLeadsBackToThePreviousChapter() {
        let app = launchReader(["-open", "keeper", "-chapter", "1", "-offset", "0"])
        element(app, "reader.previous").tapCentre()
        XCTAssertTrue(waitForState(app, "chapter=0", timeout: 5), "previous on the first page opens chapter 1")
        XCTAssertTrue(waitForReady(app))
        let state = self.state(app)
        let first = Int(state["first"] ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(first + pagesShown(state), Int(state["pages"] ?? "") ?? 0,
                                    "at its last page, not its first: \(state)")
        assertPlaceIsOnScreen(app)
    }

    @MainActor
    func testContentsOpensAChapter() {
        let app = launchReader(["-open", "keeper"])
        element(app, "reader.contents").tapCentre()
        let chapter = app.buttons["The Light Goes Out"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5), "the contents list the chapters")
        chapter.tapCentre()
        XCTAssertTrue(waitForState(app, "chapter=2", timeout: 5), "picking one opens it")
        XCTAssertTrue(waitForState(app, "offset=0", timeout: 5), "at its start")
    }

    @MainActor
    func testSwipeTurnsThePage() {
        let app = launchReader(["-open", "keeper"])
        element(app, "reader.page.0").swipeLeft()
        XCTAssertTrue(waitForState(app, "first=", notEqual: "first=0|", timeout: 5), "a swipe to the left turns forward")
        assertPlaceIsOnScreen(app)
    }

    // MARK: Text size

    /// Larger text makes more pages. The offset stays the same, and the page that
    /// holds it is on screen: the reader never skips or repeats text.
    @MainActor
    func testLargerTextKeepsThePlace() {
        let app = launchReader(["-open", "keeper", "-chapter", "0", "-offset", "2400"])
        let before = Int(state(app)["pages"] ?? "") ?? 0
        for _ in 0..<2 {
            element(app, "reader.textSize").tapCentre()
            let larger = app.buttons["Larger Text"]
            XCTAssertTrue(larger.waitForExistence(timeout: 5), "the text size menu opens")
            larger.tapCentre()
        }
        XCTAssertTrue(waitForState(app, "step=2", timeout: 5), "two steps larger")
        XCTAssertTrue(waitForReady(app), "the chapter paginates again")
        let after = state(app)
        XCTAssertGreaterThan(Int(after["pages"] ?? "") ?? 0, before, "larger text, more pages")
        XCTAssertEqual(after["offset"], "2400", "the place doesn't move")
        assertPlaceIsOnScreen(app)
    }

    // MARK: Layout and screenshots

    /// The pages in whatever pose the simulator is in: one page closed or held tall,
    /// two facing pages held wide or like a book, the page above the turns in
    /// tabletop. Saves a screenshot of each display to the result bundle (export with
    /// `xcrun xcresulttool export attachments`).
    @MainActor
    func testReaderLayoutInThisPose() {
        let app = launchReader(["-open", "keeper", "-chapter", "0", "-offset", "2400"])
        let first = element(app, "reader.page.0").frame
        let window = app.windows.firstMatch.frame
        let mode = state(app)["mode"] ?? ""
        switch mode {
        case "spread":
            let second = element(app, "reader.page.1").frame
            XCTAssertGreaterThanOrEqual(second.minX, first.maxX, "the second page sits beside the first")
            XCTAssertEqual(first.height, second.height, accuracy: 1)
        case "tabletop":
            let next = element(app, "reader.next").frame
            XCTAssertGreaterThanOrEqual(next.minY, first.maxY, "the page turns sit below the page")
        default:
            XCTAssertEqual(mode, "single")
            XCTAssertFalse(element(app, "reader.page.1").exists, "one page")
        }
        XCTAssertTrue(window.contains(first.insetBy(dx: 1, dy: 1)), "the page is on screen")
        for id in ["reader.previous", "reader.next", "reader.contents", "reader.textSize"] {
            let control = element(app, id)
            XCTAssertTrue(control.isHittable, "\(id) is on screen in every pose")
            // The tabletop controls are the app's own. In the bars, the system sizes the
            // buttons (measured: a 38 pt frame in a vertical bar).
            if mode == "tabletop" {
                XCTAssertGreaterThanOrEqual(min(control.frame.width, control.frame.height), 44, "\(id) is at least 44 pt")
            }
        }
        assertPlaceIsOnScreen(app)
        // One screenshot per display; the one not in use is black. XCUIScreen.main is the
        // outer display, black while the phone is open (measured); XCUIScreen.screens lists both.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "reader-\(mode)-\(Int(window.width))x\(Int(window.height))-screen\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    // MARK: Helpers

    /// Opens straight into the reader and waits for the first pagination.
    @MainActor
    @discardableResult
    private func launchReader(_ arguments: [String]) -> XCUIApplication {
        let app = launch(["-resetState"] + arguments)
        XCTAssertTrue(waitForReady(app), "the reader is open and paginated")
        return app
    }

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
        return app
    }

    /// The `reader.state` marker as a dictionary: book, chapter, offset, first, pages,
    /// mode, shown, step, ready.
    @MainActor
    private func state(_ app: XCUIApplication) -> [String: String] {
        let value = element(app, "reader.state").value as? String ?? ""
        var result: [String: String] = [:]
        for pair in value.split(separator: "|") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
        }
        return result
    }

    private func pagesShown(_ state: [String: String]) -> Int {
        state["mode"] == "spread" ? 2 : 1
    }

    /// The saved offset is inside the characters on screen.
    @MainActor
    private func assertPlaceIsOnScreen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let state = self.state(app)
        let bounds = (state["shown"] ?? "").split(separator: "-").compactMap { Int($0) }
        guard bounds.count == 2, let offset = Int(state["offset"] ?? "") else {
            XCTFail("no pages on screen: \(state)", file: file, line: line)
            return
        }
        // An offset past the chapter's end shows the last page; clamp it like the reader does.
        let place = min(offset, bounds[1] - 1)
        XCTAssertTrue(bounds[0] <= place && place < bounds[1],
                      "the place (\(offset)) is on screen (\(bounds[0])-\(bounds[1]))", file: file, line: line)
    }

    /// Waits until the reader's pages match its size, text size and chapter.
    @MainActor
    private func waitForReady(_ app: XCUIApplication) -> Bool {
        waitForState(app, "ready=1", timeout: 30)
    }

    /// Waits until the marker contains `fragment`, such as "chapter=1". Fields end with
    /// "|", so "offset=0|" never matches "offset=0123|".
    @MainActor
    private func waitForState(_ app: XCUIApplication, _ fragment: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", fragment + "|")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element(app, "reader.state"))
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the field that starts with `prefix` is no longer `current`.
    @MainActor
    private func waitForState(_ app: XCUIApplication, _ prefix: String, notEqual current: String,
                              timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@ AND NOT (value CONTAINS %@)", prefix, current)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element(app, "reader.state"))
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
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
