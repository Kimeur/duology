import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift), finds elements by
/// identifier, and reads the player through the `player.state` test marker, never
/// through screen positions or the picture. So a test passes whatever pose, display
/// or orientation the simulator is in. The sample clips are 12 seconds long, so tests
/// that need time start paused (-paused), replay the clip (-loop) or stop at the end
/// (-autoplay 0) rather than race the clock.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: Library

    @MainActor
    func testLibraryOpensAnEpisode() {
        let app = launch(["-resetState"])
        let row = element(app, "episode.night-sky-notes-2")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the library lists the episodes")
        row.tapCentre()
        XCTAssertTrue(element(app, "detail.play").waitForExistence(timeout: 5), "the detail shows a Play button")
        XCTAssertTrue(app.staticTexts["One face of the Moon"].exists, "for the episode that was tapped")
    }

    // MARK: Playing

    @MainActor
    func testPlayOpensThePlayerAndPlays() {
        let app = launch(["-resetState", "-select", "small-repairs-1"])
        let play = element(app, "detail.play")
        XCTAssertTrue(play.waitForExistence(timeout: 30))
        play.tapCentre()
        XCTAssertTrue(waitForState(app, "presented=1", timeout: 5), "the player opens")
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 5), "and plays")
        XCTAssertTrue(waitForTime(app, atLeast: 2, timeout: 8), "the time moves on")
        XCTAssertEqual(state(app)["item"], "small-repairs-1")
    }

    @MainActor
    func testPauseStopsTheClock() {
        let app = launchPlayer(["-play", "small-repairs-1", "-loop"])
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 5))
        element(app, "player.playPause").tapCentre()
        XCTAssertTrue(waitForState(app, "playing=0", timeout: 3), "pause stops playback")
        let paused = time(app)
        sleep(2)
        XCTAssertEqual(time(app), paused, "and the time stays put")
    }

    @MainActor
    func testSkipForwardAndBack() {
        let app = launchPlayer(["-play", "small-repairs-1", "-paused"])
        element(app, "player.forward").tapCentre()
        XCTAssertTrue(waitForState(app, "time=10", timeout: 3), "forward 10 seconds")
        element(app, "player.back").tapCentre()
        XCTAssertTrue(waitForState(app, "time=0", timeout: 3), "back 10 seconds")
    }

    // MARK: Up next

    @MainActor
    func testUpNextCardAppearsNearTheEnd() {
        // The card shows 6 s before the end of a 12 s clip: half the clip, at most the lead.
        let app = launchPlayer(["-play", "small-repairs-1", "-paused", "-start", "4"])
        let card = element(app, "upNext.card")
        XCTAssertFalse(card.exists, "no card 8 s before the end")
        element(app, "player.playPause").tapCentre()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "the card appears near the end")
        XCTAssertTrue(waitForState(app, "upNext=counting", timeout: 2), "and counts down")
    }

    @MainActor
    func testUpNextPlayNowStartsTheNextEpisode() {
        // Paused 5 s before the end: the card is up and nothing races the clock.
        let app = launchPlayer(["-play", "small-repairs-1", "-paused", "-start", "7"])
        let card = element(app, "upNext.card")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the up next card shows")
        element(app, "upNext.playNow").tapCentre()
        XCTAssertTrue(waitForState(app, "item=small-repairs-2", timeout: 3), "Play Now starts the next episode")
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 3))
        XCTAssertTrue(card.waitForNonExistence(timeout: 3), "and the card goes away")
    }

    @MainActor
    func testCancelledUpNextStopsAtTheEnd() {
        let app = launchPlayer(["-play", "small-repairs-1", "-paused", "-start", "7"])
        XCTAssertTrue(element(app, "upNext.card").waitForExistence(timeout: 5))
        element(app, "upNext.cancel").tapCentre()
        XCTAssertTrue(element(app, "upNext.card").waitForNonExistence(timeout: 3), "cancel closes the card")
        element(app, "player.playPause").tapCentre()
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 3), "play on to the end")
        XCTAssertTrue(waitForState(app, "playing=0", timeout: 20), "the episode stops at its end: \(state(app))")
        XCTAssertEqual(state(app)["item"], "small-repairs-1", "without moving on")
    }

    @MainActor
    func testAutoplayMovesOnAtTheEnd() {
        let app = launchPlayer(["-play", "small-repairs-2", "-start", "9"])
        XCTAssertTrue(waitForState(app, "item=small-repairs-3", timeout: 20), "the next episode starts by itself")
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 3))
    }

    // MARK: Keeping the player

    /// The player lives above every screen: closing the player screen keeps playing,
    /// and opening it again shows the same episode at the same point.
    @MainActor
    func testClosingThePlayerKeepsPlaying() {
        // -autoplay 0: if the clip ends during the test, it stops instead of moving on.
        let app = launchPlayer(["-play", "night-sky-notes-1", "-autoplay", "0"])
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 5))
        element(app, "player.close").tapCentre()
        let mini = element(app, "mini.open")
        XCTAssertTrue(mini.waitForExistence(timeout: 5), "the mini player shows under the library")
        XCTAssertTrue(waitForState(app, "presented=0", timeout: 3))
        let before = time(app)
        XCTAssertTrue(waitForTime(app, atLeast: before + 2, timeout: 6), "playback goes on with the player closed")
        mini.tapCentre()
        XCTAssertTrue(waitForState(app, "presented=1", timeout: 5), "the mini player opens the player again")
        XCTAssertEqual(state(app)["item"], "night-sky-notes-1", "on the same episode")
        XCTAssertGreaterThanOrEqual(time(app), before + 2, "at the same point, not from the start")
    }

    /// Going to the Home Screen doesn't stop the sound: the model takes the player
    /// off its layer in the background, so iOS doesn't pause the video.
    @MainActor
    func testSoundGoesOnInTheBackground() {
        let app = launchPlayer(["-play", "night-sky-notes-3", "-autoplay", "0"])
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 5))
        let before = time(app)
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        XCTAssertTrue(element(app, "player.playPause").waitForExistence(timeout: 10), "the app is back")
        // The clip may have reached its end meanwhile (12 s), so check the time, not the state.
        XCTAssertGreaterThanOrEqual(time(app), min(before + 3, 12),
                                    "the time went on while the app was away: \(state(app))")
    }

    @MainActor
    func testPictureInPictureStarts() throws {
        let app = launchPlayer(["-play", "night-sky-notes-2", "-start", "1"])
        let pip = element(app, "player.pip")
        guard pip.waitForExistence(timeout: 5) else {
            throw XCTSkip("Picture in Picture isn't supported here")
        }
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 5))
        pip.tapCentre()
        XCTAssertTrue(waitForState(app, "pip=1", timeout: 8), "Picture in Picture starts")
        XCTAssertTrue(waitForState(app, "presented=0", timeout: 3), "and the app goes back to the library")
        XCTAssertTrue(element(app, "mini.open").waitForExistence(timeout: 3), "with the mini player")
        XCTAssertTrue(waitForState(app, "playing=1", timeout: 3), "still playing")
    }

    // MARK: Layout and screenshots

    /// The video and the controls in whatever pose the simulator is in: controls over
    /// the video when the phone is closed or flat, beside it folded like a book, below
    /// it in tabletop. Every control is at least 44 pt. Saves a screenshot of each
    /// display to the result bundle (export with `xcrun xcresulttool export attachments`).
    @MainActor
    func testPlayerLayoutInThisPose() {
        let app = launchPlayer(["-play", "small-repairs-1", "-paused", "-start", "4"])
        let video = element(app, "player.video").frame
        let controls = element(app, "player.playPause").frame
        let window = app.windows.firstMatch.frame
        let layout = element(app, "player.layout").value as? String ?? ""
        switch layout {
        case "layout=side-by-side":
            XCTAssertGreaterThan(controls.minX, video.maxX, "book: the controls sit beside the video")
        case "layout=stacked":
            XCTAssertGreaterThan(controls.minY, video.maxY, "tabletop: the controls sit below the video")
        default:
            XCTAssertEqual(layout, "layout=overlay")
            XCTAssertTrue(window.contains(controls), "closed or flat: the controls are on screen")
        }
        for id in ["player.close", "player.back", "player.playPause", "player.forward", "player.next"] {
            let frame = element(app, id).frame
            XCTAssertGreaterThanOrEqual(min(frame.width, frame.height), 44, "\(id) is at least 44 pt")
        }
        // One screenshot per display; the one not in use is black. XCUIScreen.main is the
        // outer display, black while the phone is open (measured); XCUIScreen.screens lists both.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "player-\(layout)-\(Int(window.width))x\(Int(window.height))-screen\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    // MARK: Helpers

    /// Opens straight into the player.
    @MainActor
    private func launchPlayer(_ arguments: [String]) -> XCUIApplication {
        let app = launch(["-resetState", "-upNextLead", "6"] + arguments)
        XCTAssertTrue(element(app, "player.playPause").waitForExistence(timeout: 30), "the player is open")
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

    /// The `player.state` marker as a dictionary: item, playing, time, upNext, pip, surfaces, presented.
    @MainActor
    private func state(_ app: XCUIApplication) -> [String: String] {
        let value = element(app, "player.state").value as? String ?? ""
        var result: [String: String] = [:]
        for pair in value.split(separator: "|") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
        }
        return result
    }

    @MainActor
    private func time(_ app: XCUIApplication) -> Int {
        Int(state(app)["time"] ?? "") ?? -1
    }

    /// Waits until the marker contains `fragment`, such as "playing=1".
    @MainActor
    private func waitForState(_ app: XCUIApplication, _ fragment: String, timeout: TimeInterval) -> Bool {
        let marker = element(app, "player.state")
        // Fields are separated by "|", and the value ends with one, so "time=1|"
        // never matches "time=10|".
        let predicate = NSPredicate(format: "value CONTAINS %@", fragment + "|")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: marker)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForTime(_ app: XCUIApplication, atLeast seconds: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if time(app) >= seconds { return true }
            usleep(250_000)
        }
        return false
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
