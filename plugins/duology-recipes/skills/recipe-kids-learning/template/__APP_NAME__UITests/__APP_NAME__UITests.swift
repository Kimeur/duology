import XCTest

/// Drives the real app on the iPhone Duo simulator: Tools/run-ui-tests.sh, or Product > Test.
///
/// Every test starts from launch switches (see LaunchOptions.swift), finds elements by
/// identifier, and reads state from the test markers (`home.state`, `lesson.state`,
/// `gate.state`, `grownups.state`), never from screen positions. So the tests pass in
/// whatever pose the simulator is in. With -uiTesting the app records what it would say
/// aloud instead of speaking.
///
/// Taps go through `tap(_:in:until:)`: it taps, waits for the state the tap should cause,
/// and taps again (up to three times) only if that state never came. On a simulator shared
/// with other apps, another app can take the foreground between XCUITest's check and its
/// touch, and the touch is lost. Every tap here is safe to repeat.
final class __APP_NAME__UITests: XCTestCase {

    // MARK: Home

    @MainActor
    func testHomeOpensAnActivity() {
        let app = launch(["-resetState"])
        for id in ["counting", "letters", "shapes"] {
            XCTAssertTrue(element(app, "activity.\(id)").waitForExistence(timeout: 30), "the \(id) card shows")
        }
        XCTAssertEqual(state(app, "home.state")["stars"], "0", "a new child has no stars")
        XCTAssertEqual(element(app, "activity.letters").value as? String, "0 of 4 stars")
        XCTAssertTrue(tap("activity.letters", in: app, until: { has(app, "lesson.state", "activity=letters") }),
                      "the card opens its activity")
        XCTAssertEqual(state(app, "lesson.state")["question"], "0", "at its first question")
        XCTAssertTrue(waitFor(app, "lesson.state", "said=Which picture starts with the letter B?"),
                      "a new question is read aloud when it appears")
    }

    // MARK: Answering

    @MainActor
    func testAnsweringEarnsAStar() {
        let app = launchLesson(["-open", "counting"])     // three stars; answers 2, 3 and 4
        XCTAssertTrue(tap("answer.2", in: app, until: { has(app, "lesson.state", "wrong=2") }),
                      "a wrong answer is set aside")
        var now = state(app, "lesson.state")
        XCTAssertEqual(now["stars"], "0", "no star for a wrong answer")
        XCTAssertEqual(now["solved"], "0", "and no penalty: the question stays")
        XCTAssertEqual(now["said"], "Not that one. Try again!", "gentle feedback, out loud")
        XCTAssertFalse(element(app, "answer.2").isEnabled, "the wrong answer can't be picked again")
        XCTAssertTrue(tap("answer.3", in: app, until: { has(app, "lesson.state", "solved=1") }),
                      "the right answer solves the question")
        now = state(app, "lesson.state")
        XCTAssertEqual(now["stars"], "1", "and earns a star")
        XCTAssertEqual(element(app, "lesson.stars").label, "1 of 4 stars", "the star shows on screen")
        XCTAssertTrue(element(app, "lesson.next").waitForExistence(timeout: 5), "a Next button replaces the answers")
        XCTAssertTrue(tap("lesson.next", in: app, until: { has(app, "lesson.state", "question=1") }),
                      "Next shows the second question")
        XCTAssertEqual(state(app, "lesson.state")["solved"], "0")
    }

    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = launchLesson(["-open", "shapes"])
        XCTAssertTrue(tap("answer.circle", in: first, until: { has(first, "lesson.state", "solved=1") }))
        let app = launch()   // no -resetState: the saved progress comes back
        XCTAssertTrue(waitFor(app, "home.state", "stars=1"), "the star survives quitting the app")
        XCTAssertEqual(element(app, "activity.shapes").value as? String, "1 of 4 stars")
        XCTAssertTrue(tap("activity.shapes", in: app, until: { has(app, "lesson.state", "activity=shapes") }))
        let now = state(app, "lesson.state")
        XCTAssertEqual(now["question"], "0", "the activity comes back where it was")
        XCTAssertEqual(now["solved"], "1", "with the question still solved and Next showing")
        XCTAssertTrue(element(app, "lesson.next").exists)
    }

    @MainActor
    func testSpeakerReadsTheQuestion() {
        let app = launchLesson(["-open", "shapes", "-question", "3"])
        // Measured before any tap: a pressed button shrinks a little while it animates back.
        let speaker = element(app, "lesson.speaker").frame
        XCTAssertGreaterThanOrEqual(min(speaker.width, speaker.height), 88, "a big speaker button")
        XCTAssertTrue(tap("answer.heart", in: app, until: { has(app, "lesson.state", "said=Not that one. Try again!") }))
        XCTAssertTrue(tap("lesson.speaker", in: app, until: {
            has(app, "lesson.state", "said=Can you find the same shape? Tap it.")
        }), "the speaker button reads the question again")
    }

    @MainActor
    func testFinishingAnActivity() {
        let app = launchLesson(["-open", "letters", "-question", "3"])
        XCTAssertTrue(tap("answer.moon", in: app, until: { has(app, "lesson.state", "solved=1") }))
        XCTAssertTrue(tap("lesson.next", in: app, until: { has(app, "lesson.state", "finished=1") }),
                      "after the last question the activity is done")
        XCTAssertTrue(tap("lesson.playAgain", in: app, until: { has(app, "lesson.state", "question=0") }),
                      "Play again starts over")
        XCTAssertEqual(state(app, "lesson.state")["stars"], "1", "and keeps the star")
    }

    // MARK: The parental gate

    @MainActor
    func testGateClosesOnAWrongAnswerAndOpensOnTheRightOne() {
        var app = launch(["-resetState", "-gateSeed", "42"])
        openGate(app)
        let first = gateQuestion(app)
        XCTAssertEqual(state(app, "gate.state")["entry"], "", "nothing typed yet")
        type(first.answer + 1, in: app)
        XCTAssertTrue(has(app, "gate.state", "entry=\(first.answer + 1)"), "the pad types")
        XCTAssertTrue(tap("gate.check", in: app, until: { !element(app, "gate.state").exists }),
                      "a wrong answer closes the gate")
        XCTAssertFalse(element(app, "grownups.state").exists, "and the grown-ups area stays shut")

        openGate(app)
        let second = gateQuestion(app)
        XCTAssertNotEqual(second.text, first.text, "the next opening asks another question")
        type(second.answer, in: app)
        XCTAssertTrue(tap("gate.check", in: app, until: { element(app, "grownups.state").exists }),
                      "the right answer opens the grown-ups area")
        for id in ["grownups.reset", "grownups.privacy", "grownups.readAloud"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 5), "\(id) is in the grown-ups area")
        }
        XCTAssertTrue(tap("grownups.done", in: app, until: { !element(app, "grownups.state").exists }), "Done closes it")
        openGate(app)
        XCTAssertTrue(element(app, "gate.question").exists, "and the gate asks again next time")

        // The seed makes the questions repeat: a new launch with it asks the same first question.
        app = launch(["-gateSeed", "42"])
        openGate(app)
        XCTAssertEqual(gateQuestion(app).text, first.text, "the same seed, the same first question")
    }

    @MainActor
    func testResetProgressIsBehindTheGate() {
        let lesson = launchLesson(["-open", "counting"])
        XCTAssertTrue(tap("answer.3", in: lesson, until: { has(lesson, "lesson.state", "stars=1") }))
        let app = launch(["-gateSeed", "7"])
        XCTAssertTrue(waitFor(app, "home.state", "stars=1"))
        openGate(app)
        type(gateQuestion(app).answer, in: app)
        XCTAssertTrue(tap("gate.check", in: app, until: { element(app, "grownups.state").exists }))
        XCTAssertTrue(waitFor(app, "grownups.state", "stars=1"), "the grown-ups area shows the stars")
        XCTAssertTrue(tap("grownups.reset", in: app, until: { app.buttons["Reset All Stars"].exists }), "reset asks first")
        XCTAssertTrue(tap("Reset All Stars", in: app, until: { has(app, "grownups.state", "stars=0") }),
                      "reset clears the stars")
        XCTAssertTrue(tap("grownups.done", in: app, until: { has(app, "home.state", "stars=0") }), "everywhere")
    }

    // MARK: Layout and screenshots

    /// The lesson in whatever pose the simulator is in: the question and the answers in two
    /// panes that don't overlap, every answer at least 88 pt and off the fold, the answers
    /// below the fold in tabletop and on the right page when open. Saves the frames and a
    /// screenshot of each display to the result bundle (export with
    /// `xcrun xcresulttool export attachments`).
    @MainActor
    func testLessonLayoutInThisPose() throws {
        let app = launchLesson(["-open", "counting"])
        let marker = state(app, "lesson.state")
        let mode = marker["mode"] ?? ""
        let window = app.windows.firstMatch.frame
        let prompt = element(app, "lesson.questionPane").frame
        let answers = element(app, "lesson.answersPane").frame
        let fold = element(app, "fold")
        let foldFrame = fold.exists ? fold.frame : nil
        var report = ["mode=\(mode) folded=\(marker["folded"] ?? "") lesson=\(marker["size"] ?? "") fold(view)=\(marker["fold"] ?? "")",
                      "window=\(describe(window)) prompt=\(describe(prompt)) answers=\(describe(answers))",
                      "fold(screen)=\(foldFrame.map(describe) ?? "none") grid=\(marker["grid"] ?? "") button=\(marker["button"] ?? "")"]

        XCTAssertFalse(prompt.insetBy(dx: 1, dy: 1).intersects(answers.insetBy(dx: 1, dy: 1)), "the panes don't overlap")
        switch mode {
        case "foldLeftRight":
            let f = try XCTUnwrap(foldFrame, "a fold that splits the screen has a marker")
            XCTAssertLessThanOrEqual(prompt.maxX, f.minX + 1, "the question ends at the fold")
            XCTAssertGreaterThanOrEqual(answers.minX, f.maxX - 1, "the answers start after it")
        case "foldTopBottom":
            let f = try XCTUnwrap(foldFrame, "a fold that splits the screen has a marker")
            XCTAssertLessThanOrEqual(prompt.maxY, f.minY + 1, "the picture ends above the fold")
            XCTAssertGreaterThanOrEqual(answers.minY, f.maxY - 1, "the answers sit below it, on the table side")
        case "stacked":
            XCTAssertLessThanOrEqual(prompt.maxY, answers.minY + 1, "closed: the question above the answers")
        default:
            XCTAssertEqual(mode, "sideBySide")
            XCTAssertLessThanOrEqual(prompt.maxX, answers.minX + 1, "sideways: the question beside the answers")
        }
        for id in ["answer.2", "answer.3", "answer.4"] {
            let button = element(app, id)
            XCTAssertTrue(button.isHittable, "\(id) is on screen")
            assertBigTarget(button, id, avoiding: foldFrame)
            XCTAssertTrue(answers.insetBy(dx: -1, dy: -1).contains(button.frame), "\(id) is in the answers pane")
            report.append("\(id)=\(describe(button.frame))")
        }
        let speaker = element(app, "lesson.speaker")
        assertBigTarget(speaker, "the speaker button", avoiding: foldFrame)
        report.append("speaker=\(describe(speaker.frame))")
        attach(app, name: "lesson-\(mode)", report: report, window: window)

        XCTAssertTrue(tap("answer.3", in: app, until: { element(app, "lesson.next").exists }))
        RunLoop.current.run(until: Date().addingTimeInterval(1))   // let the panel settle
        let next = element(app, "lesson.next")
        assertBigTarget(next, "Next", avoiding: foldFrame)
        XCTAssertTrue(answers.insetBy(dx: -1, dy: -1).contains(next.frame), "Next sits in the answers pane")
        attach(app, name: "lesson-solved-\(mode)", report: ["next=\(describe(next.frame))"], window: window)
    }

    /// The home screen and the parental gate in whatever pose the simulator is in: cards
    /// large and off the fold; the gate's keys reachable. Saves a screenshot of each display.
    @MainActor
    func testHomeAndGateInThisPose() {
        let app = launch(["-resetState", "-gateSeed", "42"])
        XCTAssertTrue(element(app, "activity.counting").waitForExistence(timeout: 30))
        let marker = state(app, "home.state")
        let fold = element(app, "fold")
        let foldFrame = fold.exists ? fold.frame : nil
        let welcome = element(app, "home.welcomePane").frame
        let cards = element(app, "home.cardsPane").frame
        XCTAssertFalse(welcome.insetBy(dx: 1, dy: 1).intersects(cards.insetBy(dx: 1, dy: 1)), "the panes don't overlap")
        var report = ["mode=\(marker["mode"] ?? "") home=\(marker["size"] ?? "") fold(view)=\(marker["fold"] ?? "")",
                      "welcome=\(describe(welcome)) cards=\(describe(cards)) fold(screen)=\(foldFrame.map(describe) ?? "none")"]
        for id in ["counting", "letters", "shapes"] {
            let card = element(app, "activity.\(id)")
            XCTAssertTrue(card.isHittable, "\(id) is on screen")
            assertBigTarget(card, "the \(id) card", avoiding: foldFrame)
            report.append("activity.\(id)=\(describe(card.frame))")
        }
        attach(app, name: "home-\(marker["mode"] ?? "")", report: report, window: app.windows.firstMatch.frame)
        openGate(app)
        for key in (0...9).map({ "gate.key.\($0)" }) + ["gate.delete", "gate.check", "gate.close"] {
            XCTAssertTrue(element(app, key).exists, "\(key) is there")
        }
        let key = element(app, "gate.key.5")
        XCTAssertGreaterThanOrEqual(min(key.frame.width, key.frame.height), 44, "gate keys are at least 44 pt")
        attach(app, name: "gate-\(marker["mode"] ?? "")", report: ["key=\(describe(key.frame))"],
               window: app.windows.firstMatch.frame)
    }

    // MARK: Helpers

    /// Opens straight into an activity and waits for its marker.
    @MainActor
    private func launchLesson(_ arguments: [String]) -> XCUIApplication {
        let app = launch(["-resetState"] + arguments)
        XCTAssertTrue(waitFor(app, "lesson.state", "activity="), "the activity is open")
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

    /// Taps the element with this identifier (or button title), then waits up to five seconds
    /// for `done`. If it never comes, brings the app back to the front and taps again, three
    /// times at most. Only for taps that are safe to repeat.
    @MainActor
    @discardableResult
    private func tap(_ id: String, in app: XCUIApplication, until done: () -> Bool) -> Bool {
        for _ in 0..<3 {
            let target = element(app, id).exists ? element(app, id) : app.buttons[id].firstMatch
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

    @MainActor
    private func openGate(_ app: XCUIApplication) {
        XCTAssertTrue(element(app, "home.grownups").waitForExistence(timeout: 30), "the Grown-ups button is in the bar")
        XCTAssertTrue(tap("home.grownups", in: app, until: { element(app, "gate.state").exists }), "the gate opens")
    }

    private struct Asked: Equatable {
        let left: Int
        let right: Int
        var answer: Int { left * right }
        var text: String { "\(left)x\(right)" }
    }

    @MainActor
    private func gateQuestion(_ app: XCUIApplication) -> Asked {
        let marker = state(app, "gate.state")
        return Asked(left: Int(marker["left"] ?? "") ?? 0, right: Int(marker["right"] ?? "") ?? 0)
    }

    /// Types a number on the gate's pad, one digit at a time, checking each one landed.
    @MainActor
    private func type(_ number: Int, in app: XCUIApplication) {
        var typed = ""
        for digit in String(number) {
            typed.append(digit)
            let expected = typed
            XCTAssertTrue(tap("gate.key.\(digit)", in: app, until: { has(app, "gate.state", "entry=\(expected)") }),
                          "typed \(expected)")
        }
    }

    /// At least 88 pt on both sides (our choice for small hands), and not on the fold.
    @MainActor
    private func assertBigTarget(_ element: XCUIElement, _ name: String, avoiding fold: CGRect?,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(min(frame.width, frame.height), 88, "\(name) is at least 88 pt: \(frame)",
                                    file: file, line: line)
        if let fold {
            XCTAssertFalse(frame.intersects(fold), "\(name) stays off the fold: \(frame) vs \(fold)", file: file, line: line)
        }
    }

    /// The frames as text, and one screenshot per display; the one not in use is black.
    /// XCUIScreen.main is the outer display, black while the phone is open; XCUIScreen.screens lists both.
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

    /// True when a marker contains `fragment` now, such as "stars=1". Fields end with "|", so
    /// "stars=1|" never matches "stars=12|".
    @MainActor
    private func has(_ app: XCUIApplication, _ id: String, _ fragment: String) -> Bool {
        let needle = fragment.hasSuffix("=") ? fragment : fragment + "|"
        let marker = element(app, id)
        // Reading a missing element's value fails the test, so check it is there first.
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
