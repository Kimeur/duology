import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift) and finds elements by
/// identifier, never by screen position. So a test passes whatever pose, display or
/// orientation the simulator is in. Two people touching at once can't be simulated
/// (Device Hub sends one touch at a time), so the tests take turns.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: Home

    @MainActor
    func testHomeStartsADuel() {
        let app = launch()
        let start = element(app, "home.start")
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        start.tapCentre()
        XCTAssertTrue(element(app, "p1.ready").waitForExistence(timeout: 5), "player 1's half shows")
        XCTAssertTrue(element(app, "p2.ready").exists, "player 2's half shows")
    }

    // MARK: Ready and countdown

    @MainActor
    func testBothPlayersMustBeReady() {
        let app = launchDuel(["-countdown", "2"])
        element(app, "p1.ready").tapCentre()
        XCTAssertEqual(element(app, "p1.ready").label, "Not ready")
        XCTAssertEqual(element(app, "p1.prompt").label, "Waiting for Player 2")
        XCTAssertFalse(element(app, "p1.countdown").exists, "one player ready is not enough")
        element(app, "p2.ready").tapCentre()
        XCTAssertTrue(element(app, "p1.countdown").waitForExistence(timeout: 2), "both ready: countdown")
        XCTAssertTrue(element(app, "p2.countdown").exists)
    }

    @MainActor
    func testTapsDuringTheCountdownDoNothing() {
        let app = launchDuel(["-countdown", "2"])
        readyBoth(app)
        XCTAssertTrue(element(app, "p1.countdown").waitForExistence(timeout: 2))
        element(app, "p1.field").tapCentre()
        element(app, "p2.field").tapCentre()
        XCTAssertTrue(element(app, "p1.target").waitForExistence(timeout: 5), "targets appear after the countdown")
        XCTAssertEqual(element(app, "p1.score").label, "Player 1, 0 of 3 hits")
        XCTAssertFalse(element(app, "p1.misses").exists, "a tap in the countdown is not a miss")
        XCTAssertFalse(element(app, "p1.locked").exists, "and doesn't lock anyone out")
    }

    // MARK: Playing

    @MainActor
    func testHitsCountInEachHalf() {
        let app = startRound(launchDuel())
        hit(app, .one)
        XCTAssertTrue(element(app, "p1.score").wait(for: \.label, toEqual: "Player 1, 1 of 3 hits", timeout: 2))
        XCTAssertEqual(element(app, "p2.score").label, "Player 2, 0 of 3 hits", "player 2's score is separate")
        hit(app, .two)
        XCTAssertTrue(element(app, "p2.score").wait(for: \.label, toEqual: "Player 2, 1 of 3 hits", timeout: 2))
    }

    @MainActor
    func testMissLocksOnlyThatPlayer() {
        let app = startRound(launchDuel(["-lockout", "5"]))
        miss(app, .one)
        XCTAssertTrue(element(app, "p1.locked").waitForExistence(timeout: 2), "a miss locks player 1")
        XCTAssertEqual(element(app, "p1.misses").label, "1 miss")
        hit(app, .one)
        XCTAssertTrue(element(app, "p1.locked").exists, "still locked when that tap landed")
        XCTAssertEqual(element(app, "p1.score").label, "Player 1, 0 of 3 hits", "a hit while locked doesn't count")
        hit(app, .two)
        XCTAssertTrue(element(app, "p2.score").wait(for: \.label, toEqual: "Player 2, 1 of 3 hits", timeout: 2),
                      "player 2 can still score")
        XCTAssertTrue(element(app, "p1.locked").waitForNonExistence(timeout: 8), "the lockout ends")
        hit(app, .one)
        XCTAssertTrue(element(app, "p1.score").wait(for: \.label, toEqual: "Player 1, 1 of 3 hits", timeout: 2))
    }

    @MainActor
    func testFirstToTheGoalWinsThenRematch() {
        let app = startRound(launchDuel())
        for _ in 0..<3 { hit(app, .one) }
        XCTAssertTrue(element(app, "p1.result").waitForExistence(timeout: 3), "winner screen")
        XCTAssertEqual(element(app, "p1.result").label, "You win!")
        XCTAssertEqual(element(app, "p2.result").label, "Player 1 wins")
        element(app, "p1.rematch").tapCentre()
        XCTAssertEqual(element(app, "p1.prompt").label, "Waiting for Player 2", "rematch needs both players")
        element(app, "p2.rematch").tapCentre()
        XCTAssertTrue(element(app, "p1.target").waitForExistence(timeout: 5), "a new round starts")
        XCTAssertEqual(element(app, "p1.score").label, "Player 1, 0 of 3 hits", "scores reset")
    }

    @MainActor
    func testTimeLimitCanEndInATie() {
        let app = launchDuel(["-timeLimit", "4"])
        readyBoth(app)
        XCTAssertTrue(element(app, "p1.clock").waitForExistence(timeout: 4), "the clock shows")
        XCTAssertTrue(element(app, "p1.result").waitForExistence(timeout: 8))
        XCTAssertEqual(element(app, "p1.result").label, "Tie game")
        XCTAssertEqual(element(app, "p2.result").label, "Tie game")
    }

    // MARK: Face to face

    @MainActor
    func testTurnedHalfStillScores() {
        let app = startRound(launchDuel(["-faceToFace"]))
        hit(app, .one)
        XCTAssertTrue(element(app, "p1.score").wait(for: \.label, toEqual: "Player 1, 1 of 3 hits", timeout: 2),
                      "a tap on the turned half's target is a hit")
        miss(app, .one)
        XCTAssertTrue(element(app, "p1.misses").waitForExistence(timeout: 2), "and a tap beside it is a miss")
        hit(app, .two)
        XCTAssertTrue(element(app, "p2.score").wait(for: \.label, toEqual: "Player 2, 1 of 3 hits", timeout: 2))
    }

    // MARK: Leaving

    @MainActor
    func testLeavingAsksFirst() {
        let app = startRound(launchDuel())
        element(app, "duel.leave").tapCentre()
        let leave = app.buttons["Leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 3), "leaving asks first")
        XCTAssertTrue(element(app, "p1.target").exists, "the game is still there")
        leave.tapCentre()
        XCTAssertTrue(element(app, "home.start").waitForExistence(timeout: 3), "back home")
    }

    // MARK: Layout and screenshots

    /// Both halves show, split along the window's long side, with equal play fields, in
    /// whatever pose and orientation the simulator is in. Saves a screenshot to the result
    /// bundle (export with `xcrun xcresulttool export attachments`).
    ///
    /// Device Hub sets the pose and the rotation. On the iPhone Duo simulator,
    /// XCUIDevice.shared.orientation reported the new orientation but the app did not
    /// turn, so this test doesn't rotate. Run it once per pose instead.
    @MainActor
    func testBothHalvesShowInThisPose() {
        let app = launch(["-openDuel", "-autoReady", "-seed", "42", "-goal", "3", "-countdown", "0", "-timeLimit", "0"])
        XCTAssertTrue(element(app, "p1.target").waitForExistence(timeout: 10), "player 1 has a target")
        XCTAssertTrue(element(app, "p2.target").exists, "player 2 has a target")
        let window = app.windows.firstMatch.frame
        // Compare the play fields: each half's background runs on into the safe area,
        // so the halves' own frames differ in size near a screen edge.
        let one = element(app, "p1.field").frame
        let two = element(app, "p2.field").frame
        let sideBySide = abs(one.midX - two.midX) > abs(one.midY - two.midY)
        XCTAssertEqual(sideBySide, window.width > window.height, "side by side when wide, stacked when tall")
        XCTAssertFalse(one.intersects(two), "the play fields don't overlap")
        XCTAssertEqual(one.width, two.width, accuracy: 1, "the play fields are the same width")
        XCTAssertEqual(one.height, two.height, accuracy: 1, "the play fields are the same height")
        let target = element(app, "p1.target").frame
        XCTAssertTrue(one.contains(target), "player 1's target is inside player 1's field")
        XCTAssertLessThan(target.width, one.width / 2, "the target's frame is the circle, not the field")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "play-\(Int(window.width))x\(Int(window.height))"
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: Helpers

    private enum Side: String {
        case one = "p1"
        case two = "p2"
    }

    /// Fixed seed, 3 hits to win, 1 s countdown, no time limit, unless `extra` overrides them.
    @MainActor
    private func launchDuel(_ extra: [String] = []) -> XCUIApplication {
        let app = launch(["-openDuel", "-seed", "42", "-goal", "3", "-countdown", "1", "-timeLimit", "0"] + extra)
        XCTAssertTrue(element(app, "p1.ready").waitForExistence(timeout: 30))
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

    @MainActor
    private func readyBoth(_ app: XCUIApplication) {
        element(app, "p1.ready").tapCentre()
        element(app, "p2.ready").tapCentre()
    }

    @MainActor
    private func startRound(_ app: XCUIApplication) -> XCUIApplication {
        readyBoth(app)
        XCTAssertTrue(element(app, "p1.target").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "p2.target").exists)
        return app
    }

    @MainActor
    private func hit(_ app: XCUIApplication, _ side: Side) {
        let target = element(app, "\(side.rawValue).target")
        XCTAssertTrue(target.waitForExistence(timeout: 2), "\(side.rawValue) has a target")
        target.tapCentre()
    }

    /// Taps the corner of the player's field farthest from their target.
    @MainActor
    private func miss(_ app: XCUIApplication, _ side: Side) {
        let field = element(app, "\(side.rawValue).field")
        let target = element(app, "\(side.rawValue).target")
        XCTAssertTrue(target.waitForExistence(timeout: 2))
        let f = field.frame
        let t = target.frame
        let dx: CGFloat = t.midX < f.midX ? 0.92 : 0.08
        let dy: CGFloat = t.midY < f.midY ? 0.92 : 0.08
        field.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy)).tap()
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
