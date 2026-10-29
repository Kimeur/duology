import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift), finds elements by
/// identifier, and reads state from the test markers (`list.state`, `note.state`), never from
/// screen positions. So the tests pass in whatever pose the simulator is in. The summary's
/// buttons have the same identifiers in the bar (closed) and in the pane (open), so the same
/// taps work in both.
///
/// The on-device model fails on the simulator (it logs "Simulator is not supported"), so the
/// tests use the stand-in engines: `simple`, `standin` (streams at a set pace) and `failing`.
/// `testOnDeviceModelOrItsFallback` asks the real model and passes either way.
///
/// Taps go through `tap(_:in:until:)`: it taps, waits for the state the tap should cause, and
/// taps again (up to three times) only if that state never came. On a simulator shared with
/// other apps, another app can take the foreground between XCUITest's check and its touch, and
/// the touch is lost. Every tap here is safe to repeat.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: The list

    @MainActor
    func testListShowsTheSampleNotes() {
        let app = launch(["-resetState"])
        XCTAssertTrue(waitFor(app, "list.state", "count=4"), "four sample notes")
        XCTAssertTrue(has(app, "list.state", "ids=sample.offsite,sample.sourdough,sample.garden,sample.groceries"),
                      "newest first")
        XCTAssertTrue(tap("note.card.sample.garden", in: app, until: { has(app, "note.state", "id=sample.garden") }),
                      "a card opens its note")
        XCTAssertEqual(element(app, "note.title").value as? String ?? "", "", "the garden note has no title")
    }

    @MainActor
    func testNewNoteIsSavedAndAnEmptyOneIsDropped() {
        var app = launch(["-resetState"])
        XCTAssertTrue(waitFor(app, "list.state", "count=4"))
        XCTAssertTrue(tap("list.new", in: app, until: { has(app, "note.state", "words=0") }), "New Note opens an empty note")
        typeInto("note.title", "Weekend", in: app)
        typeInto("note.body", "Pick up the bike from the repair shop on Saturday morning before ten.", in: app)
        XCTAssertTrue(waitFor(app, "note.state", "words=14"), "what is typed reaches the note")
        goBack(app)
        XCTAssertTrue(waitFor(app, "list.state", "count=5"), "the new note stays in the list")

        XCTAssertTrue(tap("list.new", in: app, until: { has(app, "note.state", "words=0") }))
        goBack(app)
        XCTAssertTrue(waitFor(app, "list.state", "count=5"), "a new note left empty is dropped")

        app = launch()   // no -resetState: the saved notes come back
        XCTAssertTrue(waitFor(app, "list.state", "count=5"), "the note survives quitting the app")
        XCTAssertTrue(app.staticTexts["Weekend"].waitForExistence(timeout: 5), "with its title")
    }

    // MARK: Summaries

    @MainActor
    func testSimpleSummary() {
        let app = launchNote("sample.offsite", ["-summarizer", "simple"])
        XCTAssertTrue(has(app, "note.state", "digest=none"), "no summary yet")
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "digest=simple") }),
                      "Summarize makes one")
        let now = state(app, "note.state")
        XCTAssertEqual(now["headline"], "We meet in Lyon on 12 March for two days.", "the first sentence")
        XCTAssertEqual(now["points"], "3", "the note's three bullet points")
        XCTAssertEqual(now["todos"], "3", "its three open to-dos")
        XCTAssertEqual(now["current"], "1")
        XCTAssertEqual(now["fallback"], "0", "simple by choice here, so no reason to give")
        openFullSummary(app)
        XCTAssertTrue(element(app, "summary.headline").waitForExistence(timeout: 5), "the full summary shows the headline")
        XCTAssertEqual(element(app, "summary.label").label, "Simple summary, no AI", "and says it isn't from AI")
        XCTAssertTrue(element(app, "summary.todo.2").exists, "and the to-dos")
    }

    @MainActor
    func testStreamingCanBeStopped() {
        let app = launchNote("sample.sourdough", ["-summarizer", "standin", "-standInPace", "1"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "phase=working") }))
        XCTAssertTrue(waitFor(app, "note.state", "draft=The", timeout: 10), "the headline streams in, word by word")
        XCTAssertTrue(tap("summary.stop", in: app, until: { has(app, "note.state", "phase=idle") }), "Stop ends it")
        XCTAssertTrue(has(app, "note.state", "digest=none"), "and keeps nothing half-written")
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "phase=working") }))
        XCTAssertTrue(waitFor(app, "note.state", "digest=simple", timeout: 30), "a full run ends with a summary")
        XCTAssertEqual(state(app, "note.state")["headline"], "The third loaf finally rose.")
    }

    /// A stand-in summary streams for about 40 seconds. Press Open, Partially Open or Closed in
    /// Device Hub (or run `duo-pose set`) while it runs, after "stream started" shows in the
    /// test log: the summary must only grow, never restart, and finish once. In one pose it
    /// passes too; the report lists the layouts it went through.
    @MainActor
    func testStreamKeepsGoingThroughFolds() {
        let app = launchNote("sample.offsite", ["-summarizer", "standin", "-standInPace", "2.5"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "phase=working") }))
        print("stream started")
        var report: [String] = []
        var modes: [String] = []
        var last = (words: 0, points: 0)
        let start = Date()
        while Date().timeIntervalSince(start) < 90 {
            let now = state(app, "note.state")
            if now["phase"] == "idle" { break }
            let words = (now["draft"] ?? "").split(separator: " ").count
            let points = Int(now["draftPoints"] ?? "") ?? 0
            XCTAssertGreaterThanOrEqual(words, last.words, "the headline never starts over")
            XCTAssertGreaterThanOrEqual(points, last.points, "the points never start over")
            last = (max(words, last.words), max(points, last.points))
            let mode = now["mode"] ?? ""
            if modes.last != mode { modes.append(mode) }
            report.append(String(format: "t=%.1f mode=%@ folded=%@ words=%d points=%d", Date().timeIntervalSince(start),
                                 mode, now["folded"] ?? "", words, points))
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        let end = state(app, "note.state")
        XCTAssertEqual(end["digest"], "simple", "the stream finished with a summary (the stand-in's is saved as simple)")
        XCTAssertEqual(end["headline"], "We meet in Lyon on 12 March for two days.", "the whole headline")
        XCTAssertEqual(end["points"], "3")
        let text = XCTAttachment(string: (["layouts=\(modes.joined(separator: ">"))"] + report).joined(separator: "\n"))
        text.name = "stream-through-folds"
        text.lifetime = .keepAlways
        add(text)
    }

    @MainActor
    func testModelFailureFallsBackToASimpleSummary() {
        let app = launchNote("sample.garden", ["-summarizer", "failing"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "phase=working") }))
        XCTAssertTrue(waitFor(app, "note.state", "digest=simple", timeout: 15), "a failed request still ends with a summary")
        XCTAssertTrue(has(app, "note.state", "fallback=1"), "which says why it isn't from AI")
        openFullSummary(app)
        XCTAssertTrue(element(app, "summary.fallback").waitForExistence(timeout: 5), "the reason is on screen")
        XCTAssertTrue(element(app, "summary.again").exists, "with a way to try again")
    }

    @MainActor
    func testSummaryGoesOutOfDateAndSurvivesARelaunch() {
        var app = launchNote("sample.offsite", ["-summarizer", "simple"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "digest=simple") }))
        typeInto("note.body", " Extra line.", in: app)
        XCTAssertTrue(waitFor(app, "note.state", "current=0"), "an edit marks the summary out of date")
        XCTAssertTrue(has(app, "note.state", "digest=simple"), "but keeps it")

        app = launch(["-open", "sample.offsite", "-summarizer", "simple"])
        XCTAssertTrue(waitFor(app, "note.state", "id=sample.offsite"))
        XCTAssertTrue(has(app, "note.state", "digest=simple") && has(app, "note.state", "current=0"),
                      "the summary and its state survive quitting the app")
        openFullSummary(app)
        XCTAssertTrue(element(app, "summary.outOfDate").waitForExistence(timeout: 5), "the pane says the note changed")
        XCTAssertTrue(tap("summary.again", in: app, until: { has(app, "note.state", "current=1") }),
                      "Summarize Again brings it up to date")
    }

    @MainActor
    func testAShortNoteCantBeSummarized() {
        let app = launchNote("sample.groceries", ["-summarizer", "simple"])
        let button = element(app, "summary.summarize")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertFalse(button.isEnabled, "too few words to summarize")
    }

    /// Asks the real on-device model. On a device with Apple Intelligence it should give an AI
    /// summary; on the simulator the model fails and the app falls back. Either way a summary
    /// comes, labelled. The frames report says which one.
    @MainActor
    func testOnDeviceModelOrItsFallback() {
        let app = launchNote("sample.sourdough", ["-summarizer", "ai"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "phase=") }))
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline && has(app, "note.state", "digest=none") {
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        let now = state(app, "note.state")
        XCTAssertNotEqual(now["digest"], "none", "a summary arrives, from the model or the fallback")
        if now["digest"] == "simple" {
            XCTAssertEqual(now["fallback"], "1", "a fallback says why")
        }
        let report = XCTAttachment(string: "digest=\(now["digest"] ?? "") headline=\(now["headline"] ?? "") points=\(now["points"] ?? "")")
        report.name = "on-device-model-result"
        report.lifetime = .keepAlways
        add(report)
    }

    // MARK: Layout and screenshots

    /// The note in whatever pose the simulator is in: the note and its summary in two regions
    /// that don't overlap, each wholly on one side of the fold; every summary button at least
    /// 44 pt and off the fold. Closed, Details opens the full summary in a sheet. Saves the
    /// frames and a screenshot of each display to the result bundle (export with
    /// `xcrun xcresulttool export attachments`).
    @MainActor
    func testNoteLayoutInThisPose() throws {
        let app = launchNote("sample.offsite", ["-summarizer", "simple"])
        XCTAssertTrue(tap("summary.summarize", in: app, until: { has(app, "note.state", "digest=simple") }))
        RunLoop.current.run(until: Date().addingTimeInterval(1))   // let the pane settle
        let marker = state(app, "note.state")
        let mode = marker["mode"] ?? ""
        let window = app.windows.firstMatch.frame
        let editor = element(app, "note.editorPane").frame
        let summaryID = mode == "single" ? "summary.bar" : "summary.pane"
        let summary = element(app, summaryID).frame
        let fold = element(app, "fold")
        let foldFrame = fold.exists ? fold.frame : nil
        var report = ["mode=\(mode) folded=\(marker["folded"] ?? "") note=\(marker["size"] ?? "") fold(view)=\(marker["fold"] ?? "")",
                      "window=\(describe(window)) editor=\(describe(editor)) \(summaryID)=\(describe(summary))",
                      "fold(screen)=\(foldFrame.map(describe) ?? "none")"]

        XCTAssertFalse(editor.insetBy(dx: 1, dy: 1).intersects(summary.insetBy(dx: 1, dy: 1)), "the regions don't overlap")
        switch mode {
        case "foldLeftRight":
            let f = try XCTUnwrap(foldFrame, "a fold that splits the screen has a marker")
            XCTAssertLessThanOrEqual(editor.maxX, f.minX + 1, "the note ends at the fold")
            XCTAssertGreaterThanOrEqual(summary.minX, f.maxX - 1, "the summary starts after it")
        case "foldTopBottom":
            let f = try XCTUnwrap(foldFrame, "a fold that splits the screen has a marker")
            XCTAssertLessThanOrEqual(editor.maxY, f.minY + 1, "the note ends above the fold")
            XCTAssertGreaterThanOrEqual(summary.minY, f.maxY - 1, "the summary sits below it, on the table side")
        case "single":
            XCTAssertLessThanOrEqual(editor.maxY, summary.minY + 1, "closed: the bar below the note")
        default:
            XCTAssertEqual(mode, "sideBySide")
            XCTAssertLessThanOrEqual(editor.maxX, summary.minX + 1)
        }
        let buttons = mode == "single" ? ["summary.details"] : ["summary.again", "summary.clear"]
        for id in buttons {
            let button = element(app, id)
            XCTAssertTrue(button.isHittable, "\(id) is on screen")
            assertTarget(button, id, avoiding: foldFrame)
            XCTAssertTrue(summary.insetBy(dx: -1, dy: -1).contains(button.frame), "\(id) is in the summary's region")
            report.append("\(id)=\(describe(button.frame))")
        }
        attach(app, name: "note-\(mode)", report: report, window: window)

        if mode == "single" {
            XCTAssertTrue(tap("summary.details", in: app, until: { has(app, "note.state", "sheet=1") }), "Details opens the sheet")
            XCTAssertTrue(element(app, "summary.headline").waitForExistence(timeout: 5), "with the full summary")
            attach(app, name: "note-sheet", report: ["again=\(describe(element(app, "summary.again").frame))"], window: window)
            XCTAssertTrue(tap("summary.done", in: app, until: { has(app, "note.state", "sheet=0") }), "Done closes it")
        }
    }

    /// The list in whatever pose the simulator is in: cards at least 44 pt, and none on a fold
    /// that runs top to bottom. Saves a screenshot of each display.
    @MainActor
    func testListInThisPose() {
        let app = launch(["-resetState"])
        XCTAssertTrue(waitFor(app, "list.state", "count=4"))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let marker = state(app, "list.state")
        let fold = element(app, "fold")
        let foldFrame = fold.exists ? fold.frame : nil
        var report = ["columns=\(marker["columns"] ?? "") foldsBetween=\(marker["foldsBetween"] ?? "") width=\(marker["width"] ?? "")",
                      "fold(view)=\(marker["fold"] ?? "") fold(screen)=\(foldFrame.map(describe) ?? "none")"]
        for id in ["sample.offsite", "sample.sourdough"] {
            let card = element(app, "note.card.\(id)")
            XCTAssertTrue(card.isHittable, "\(id) is on screen")
            assertTarget(card, id, avoiding: marker["foldsBetween"] == "1" ? foldFrame : nil)
            report.append("card.\(id)=\(describe(card.frame))")
        }
        attach(app, name: "list-\(marker["columns"] ?? "")col", report: report, window: app.windows.firstMatch.frame)
    }

    // MARK: Helpers

    @MainActor
    private func launchNote(_ id: String, _ arguments: [String]) -> XCUIApplication {
        let app = launch(["-resetState", "-open", id] + arguments)
        XCTAssertTrue(waitFor(app, "note.state", "id=\(id)"), "the note is open")
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

    /// Closed, the full summary is in a sheet behind Details; open, it's already on screen.
    @MainActor
    private func openFullSummary(_ app: XCUIApplication) {
        if has(app, "note.state", "mode=single") {
            XCTAssertTrue(tap("summary.details", in: app, until: { has(app, "note.state", "sheet=1") }), "Details opens the sheet")
        }
    }

    /// The back button. Closed, on the iPhone Duo, it sits in the vertical bar beside the
    /// screen, outside `navigationBars`; its identifier is the same everywhere.
    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let back = app.buttons["BackButton"].exists ? app.buttons["BackButton"] : app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "a back button")
        back.tap()
        XCTAssertTrue(element(app, "list.state").waitForExistence(timeout: 10), "back on the list")
    }

    @MainActor
    private func typeInto(_ id: String, _ text: String, in app: XCUIApplication) {
        let field = element(app, id)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(id) is there")
        field.tapCentre()
        field.typeText(text)
    }

    /// At least 44 pt on both sides, and not on the fold.
    @MainActor
    private func assertTarget(_ element: XCUIElement, _ name: String, avoiding fold: CGRect?,
                              file: StaticString = #filePath, line: UInt = #line) {
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(min(frame.width, frame.height), 44, "\(name) is at least 44 pt: \(frame)", file: file, line: line)
        if let fold {
            XCTAssertFalse(frame.intersects(fold), "\(name) stays off the fold: \(frame) vs \(fold)", file: file, line: line)
        }
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

    /// The frames as text, and one screenshot per display; the one not in use is black.
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

    /// True when a marker contains `fragment` now, such as "count=4". Fields end with "|", so
    /// "count=4|" never matches "count=41|". A fragment ending in "=" matches any value.
    @MainActor
    private func has(_ app: XCUIApplication, _ id: String, _ fragment: String) -> Bool {
        let needle = fragment.hasSuffix("=") ? fragment : fragment + "|"
        let marker = element(app, id)
        return marker.exists && (marker.value as? String ?? "").contains(needle)
    }

    /// Waits until a marker contains `fragment`.
    @MainActor
    private func waitFor(_ app: XCUIApplication, _ id: String, _ fragment: String, timeout: TimeInterval = 30) -> Bool {
        let needle = fragment.hasSuffix("=") ? fragment : fragment + "|"
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
