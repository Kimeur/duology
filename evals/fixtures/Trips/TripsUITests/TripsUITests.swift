import XCTest

final class TripsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["trip.favorite.1"].waitForExistence(timeout: 20))
    }
}
