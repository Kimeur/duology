import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// The simulator has no camera, so every test runs the stand-in camera (`-standIn`): the same
/// shutter, timer, recording and gallery, with a test card instead of a picture. Capture with
/// a real camera needs a device.
///
/// Every test starts from launch switches (see LaunchOptions.swift), finds elements by
/// identifier, and reads state from the `studio.state` and `gallery.state` markers, never from
/// screen positions. So the tests pass in whatever pose the simulator is in.
///
/// Taps go through `tap(_:in:until:)`: it taps, waits for the state the tap should cause, and
/// taps again (up to three times) only if that state never came. On a simulator shared with
/// other apps, another app can take the foreground between XCUITest's check and its touch.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: Photos

    @MainActor
    func testShutterTakesAPhoto() {
        let app = launch(["-resetState"])
        XCTAssertTrue(waitFor(app, "studio.state", "camera=standin"), "the simulator uses the stand-in camera")
        XCTAssertTrue(has(app, "studio.state", "captures=0"))
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "captures=1") }), "the shutter takes a photo")
        XCTAssertTrue(has(app, "studio.state", "latest=photo"))
        XCTAssertEqual(element(app, "studio.gallery").label, "Gallery, latest: Photo, stand-in camera")
    }

    @MainActor
    func testSelfTimerCountsDownThenShoots() {
        let app = launch(["-resetState", "-timer", "3"])
        XCTAssertTrue(waitFor(app, "studio.state", "timer=3"))
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "countdown=3") }), "the shutter starts the countdown")
        XCTAssertTrue(element(app, "studio.countdown").exists, "the seconds show over the preview")
        XCTAssertTrue(has(app, "studio.state", "captures=0"), "no photo yet")
        XCTAssertTrue(waitFor(app, "studio.state", "countdown=1", timeout: 5), "it counts down")
        XCTAssertTrue(waitFor(app, "studio.state", "captures=1", timeout: 5), "and takes the photo at zero")
        XCTAssertTrue(has(app, "studio.state", "countdown=|"), "the countdown is gone")
    }

    @MainActor
    func testTappingDuringTheCountdownCancelsIt() {
        let app = launch(["-resetState", "-timer", "10"])
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "countdown=10") }))
        XCTAssertEqual(element(app, "studio.shutter").label, "Cancel Self-Timer")
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "countdown=|") }), "a second tap cancels")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(has(app, "studio.state", "captures=0"), "and nothing is taken")
    }

    @MainActor
    func testTimerCycles() {
        let app = launch(["-resetState"])
        XCTAssertTrue(waitFor(app, "studio.state", "timer=0"))
        XCTAssertTrue(tap("studio.timer", in: app, until: { has(app, "studio.state", "timer=3") }))
        XCTAssertTrue(tap("studio.timer", in: app, until: { has(app, "studio.state", "timer=10") }))
        XCTAssertTrue(tap("studio.timer", in: app, until: { has(app, "studio.state", "timer=0") }), "off, 3 s, 10 s, off")
    }

    // MARK: Video

    @MainActor
    func testRecordsAVideo() {
        let app = launch(["-resetState"])
        XCTAssertTrue(tap("studio.mode", in: app, until: { has(app, "studio.state", "mode=video") }), "switch to video")
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "recording=1") }), "the shutter starts recording")
        XCTAssertTrue(element(app, "studio.recording").waitForExistence(timeout: 5), "the recording time shows")
        XCTAssertFalse(element(app, "studio.mode").isEnabled, "the mode can't change while recording")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "captures=1") }), "a second tap stops and saves")
        let now = state(app, "studio.state")
        XCTAssertEqual(now["latest"], "video")
        XCTAssertGreaterThanOrEqual(Double(now["latestDuration"] ?? "") ?? 0, 2, "the movie is about 3 s long: \(now["latestDuration"] ?? "")")
    }

    // MARK: The gallery

    @MainActor
    func testGalleryShowsAndDeletes() {
        let app = launch(["-resetState"])
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "captures=1") }))
        XCTAssertTrue(tap("studio.gallery", in: app, until: { element(app, "gallery.state").exists }), "the thumbnail opens the gallery")
        XCTAssertTrue(has(app, "gallery.state", "count=1"))
        let cell = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'gallery.cell.'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "the photo is in the grid")
        cell.tapCentre()
        XCTAssertTrue(element(app, "gallery.share").waitForExistence(timeout: 5), "it opens with Share")
        XCTAssertTrue(tap("gallery.delete", in: app, until: { app.buttons["Delete Photo"].exists }), "Delete asks first")
        app.buttons["Delete Photo"].firstMatch.tap()
        XCTAssertTrue(waitFor(app, "gallery.state", "count=0"), "and removes it")
        XCTAssertTrue(tap("gallery.done", in: app, until: { !element(app, "gallery.state").exists }))
        XCTAssertTrue(has(app, "studio.state", "captures=0"))
    }

    @MainActor
    func testCapturesSurviveARelaunch() {
        let first = launch(["-resetState"])
        XCTAssertTrue(tap("studio.shutter", in: first, until: { has(first, "studio.state", "captures=1") }))
        let app = launch()   // no -resetState
        XCTAssertTrue(waitFor(app, "studio.state", "captures=1"), "the photo is still in the gallery")
    }

    // MARK: Layout and screenshots

    /// The studio in whatever pose the simulator is in: the controls off the fold, beside the
    /// preview when folded (right page in book, bottom half in tabletop), every control at least
    /// 44 pt and the shutter 76 pt. Starts a countdown so the screenshots show it on both
    /// displays: open, the outer display carries the subject view. Saves the frames and a
    /// screenshot of each display (export with `xcrun xcresulttool export attachments`).
    @MainActor
    func testStudioLayoutInThisPose() throws {
        let app = launch(["-resetState", "-timer", "10"])
        XCTAssertTrue(waitFor(app, "studio.state", "camera=standin"))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let marker = state(app, "studio.state")
        let mode = marker["layout"] ?? ""
        let window = app.windows.firstMatch.frame
        let preview = element(app, "studio.previewRegion").frame
        let controls = element(app, "studio.controlsRegion").frame
        let fold = element(app, "fold")
        let foldFrame = fold.exists ? fold.frame : nil
        var report = ["layout=\(mode) edge=\(marker["edge"] ?? "") folded=\(marker["folded"] ?? "") studio=\(marker["size"] ?? "") fold(view)=\(marker["fold"] ?? "")",
                      "subjectAvailable=\(marker["subjectAvailable"] ?? "") window=\(describe(window))",
                      "preview=\(describe(preview)) controls=\(describe(controls)) fold(screen)=\(foldFrame.map(describe) ?? "none")"]
        switch mode {
        case "foldLeftRight":
            let f = try XCTUnwrap(foldFrame)
            XCTAssertLessThanOrEqual(preview.maxX, f.minX + 1, "book: the preview ends at the fold")
            XCTAssertGreaterThanOrEqual(controls.minX, f.maxX - 1, "the controls start after it")
        case "foldTopBottom":
            let f = try XCTUnwrap(foldFrame)
            XCTAssertLessThanOrEqual(preview.maxY, f.minY + 1, "tabletop: the preview ends above the fold")
            XCTAssertGreaterThanOrEqual(controls.minY, f.maxY - 1, "the controls sit below it, on the table side")
        default:
            XCTAssertEqual(mode, "floating")
            XCTAssertTrue(preview.insetBy(dx: -1, dy: -1).contains(controls), "flat or closed: the controls float over the preview")
            if let f = foldFrame { XCTAssertFalse(controls.intersects(f), "flat: the controls stay off the fold") }
        }
        var ids = ["studio.gallery", "studio.timer", "studio.shutter", "studio.mode", "studio.switch"]
        if marker["subjectAvailable"] == "1" { ids.append("studio.subject") }
        for id in ids {
            let control = element(app, id)
            XCTAssertTrue(control.exists, "\(id) is there")
            let frame = control.frame
            XCTAssertGreaterThanOrEqual(min(frame.width, frame.height), 44, "\(id) is at least 44 pt: \(frame)")
            XCTAssertTrue(controls.insetBy(dx: -1, dy: -1).contains(frame), "\(id) is in the controls' region")
            if let f = foldFrame { XCTAssertFalse(frame.intersects(f), "\(id) stays off the fold: \(frame) vs \(f)") }
            report.append("\(id)=\(describe(frame))")
        }
        let shutter = element(app, "studio.shutter").frame
        XCTAssertGreaterThanOrEqual(min(shutter.width, shutter.height), 76, "the shutter is 76 pt")

        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "countdown=10") }))
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        attach(app, name: "studio-\(mode)", report: report, window: window)
        XCTAssertTrue(tap("studio.shutter", in: app, until: { has(app, "studio.state", "countdown=|") }), "cancel the countdown")
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-standIn"] + arguments
        app.launch()
        XCTAssertTrue(element(app, "studio.state").waitForExistence(timeout: 30), "the studio is on screen")
        return app
    }

    /// Taps the element with this identifier, then waits up to five seconds for `done`. If it
    /// never comes, brings the app back to the front and taps again, three times at most.
    @MainActor
    @discardableResult
    private func tap(_ id: String, in app: XCUIApplication, until done: () -> Bool) -> Bool {
        for _ in 0..<3 {
            let target = element(app, id)
            if target.waitForExistence(timeout: 5) {
                target.tapCentre()
            }
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                if done() { return true }
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            if app.state != .runningForeground { app.activate() }
        }
        return done()
    }

    /// The frames as text, and one screenshot per display.
    @MainActor
    private func attach(_ app: XCUIApplication, name: String, report: [String], window: CGRect) {
        let text = XCTAttachment(string: report.joined(separator: "\n"))
        text.name = "\(name)-frames"
        text.lifetime = .keepAlways
        add(text)
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "\(name)-\(Int(window.width))x\(Int(window.height))-screen\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    private func describe(_ rect: CGRect) -> String {
        String(format: "%g,%g,%gx%g", rect.minX, rect.minY, rect.width, rect.height)
    }

    /// A test marker as a dictionary: "key=value|key=value|".
    @MainActor
    private func state(_ app: XCUIApplication, _ id: String) -> [String: String] {
        let value = element(app, id).value as? String ?? ""
        var result: [String: String] = [:]
        for pair in value.split(separator: "|", omittingEmptySubsequences: false) {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
        }
        return result
    }

    /// True when a marker contains `fragment` now, such as "captures=1". Fields end with "|", so
    /// "captures=1|" never matches "captures=12|". A fragment ending in "=" or "|" is used as is.
    @MainActor
    private func has(_ app: XCUIApplication, _ id: String, _ fragment: String) -> Bool {
        let needle = fragment.hasSuffix("=") || fragment.hasSuffix("|") ? fragment : fragment + "|"
        let marker = element(app, id)
        return marker.exists && (marker.value as? String ?? "").contains(needle)
    }

    /// Waits until a marker contains `fragment`.
    @MainActor
    private func waitFor(_ app: XCUIApplication, _ id: String, _ fragment: String, timeout: TimeInterval = 30) -> Bool {
        let needle = fragment.hasSuffix("=") || fragment.hasSuffix("|") ? fragment : fragment + "|"
        let predicate = NSPredicate(format: "value CONTAINS %@", needle)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element(app, id))
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
