import XCTest

/// Oracle for the eval task duo-shared-screen/face-to-face-quiz.
///
/// It is not part of the fixture, so the agent never sees it. The task's check
/// copies it into the Starter app's UI test folder after the agent's run, then
/// runs it on the iPhone Duo simulator. The task prompt names the identifiers
/// it looks for.
final class QuizOracleTests: XCTestCase {
    private let people = ["p1", "p2"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        return element.label
    }

    /// Each person has four answer buttons and a score, the two groups don't
    /// overlap, each sits in its own half of the window, and every button is at
    /// least 44 pt in both directions.
    @MainActor
    func testEachPersonHasTheirOwnHalf() throws {
        let app = XCUIApplication()
        app.launch()

        var groups: [String: CGRect] = [:]
        for person in people {
            var union = CGRect.null
            for index in 0..<4 {
                let button = element(app, "\(person).answer.\(index)")
                XCTAssertTrue(button.waitForExistence(timeout: 15), "\(person).answer.\(index) is missing")
                XCTAssertTrue(button.isHittable, "\(person).answer.\(index) can't be tapped")
                let frame = button.frame
                // 0.5 pt of slack: frames come back as 43.99999... for a 44 pt button.
                XCTAssertGreaterThanOrEqual(frame.width, 43.5, "\(person).answer.\(index) is narrower than 44 pt")
                XCTAssertGreaterThanOrEqual(frame.height, 43.5, "\(person).answer.\(index) is shorter than 44 pt")
                union = union.union(frame)
            }
            XCTAssertTrue(element(app, "\(person).score").exists, "\(person).score is missing")
            groups[person] = union
        }

        let first = groups["p1"] ?? .null
        let second = groups["p2"] ?? .null
        XCTAssertFalse(first.intersects(second), "the two people's answer buttons overlap")

        let window = app.windows.firstMatch.frame
        let slack: CGFloat = 1
        let leftRight = (first.maxX <= window.midX + slack && second.minX >= window.midX - slack)
            || (second.maxX <= window.midX + slack && first.minX >= window.midX - slack)
        let topBottom = (first.maxY <= window.midY + slack && second.minY >= window.midY - slack)
            || (second.maxY <= window.midY + slack && first.minY >= window.midY - slack)
        XCTAssertTrue(leftRight || topBottom,
                      "each person's buttons should sit in their own half of the window: p1 \(first), p2 \(second), window \(window)")
    }

    /// Answering on one side never changes the other person's score.
    @MainActor
    func testAnsweringOnlyScoresForThatPerson() throws {
        let app = XCUIApplication()
        app.launch()

        let otherScore = element(app, "p2.score")
        XCTAssertTrue(otherScore.waitForExistence(timeout: 15), "p2.score is missing")
        let before = text(of: otherScore)

        for index in 0..<4 {
            let button = element(app, "p1.answer.\(index)")
            if button.waitForExistence(timeout: 2), button.isHittable {
                button.tap()
            }
        }
        XCTAssertEqual(text(of: element(app, "p2.score")), before,
                       "p2's score changed when only p1 answered")
    }
}
