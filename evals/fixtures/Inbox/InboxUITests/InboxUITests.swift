import XCTest

final class InboxUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpenMessage() throws {
        let app = XCUIApplication()
        app.launch()
        let row = app.buttons["inbox.row.1"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.staticTexts["message.subject"].waitForExistence(timeout: 10))
    }
}
