// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
import AppKit
import CoreGraphics
import Foundation

var failures = 0
var passes = 0

func check(_ ok: Bool, _ message: String) {
    if ok {
        passes += 1
        print("ok   \(message)")
    } else {
        failures += 1
        print("FAIL \(message)")
    }
}

func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.5 }
func near(_ a: CGRect, _ b: CGRect) -> Bool {
    near(a.minX, b.minX) && near(a.minY, b.minY) && near(a.width, b.width) && near(a.height, b.height)
}

// MARK: The sample activities

let activities = SampleActivities.all
check(activities.map(\.id) == ["counting", "letters", "shapes"], "three activities, in home screen order")
check(activities.allSatisfy { $0.problems.isEmpty },
      "every activity is well formed: \(activities.flatMap(\.problems))")
let questionIDs = activities.flatMap { $0.questions.map(\.id) }
check(Set(questionIDs).count == questionIDs.count, "question IDs are unique across the app (stars are saved by ID)")
check(activities.allSatisfy { $0.questions.count == 4 }, "four questions in each activity")

for question in SampleActivities.counting.questions {
    guard case .group(_, let count, _, _) = question.art else {
        check(false, "\(question.id): a counting question shows a group")
        continue
    }
    check(question.correctAnswer?.art == .number(count), "\(question.id): the right answer is the number of things shown")
}
for question in SampleActivities.letters.questions {
    guard case .letter(let letter) = question.art else {
        check(false, "\(question.id): a letters question shows a letter")
        continue
    }
    let starts = question.answers.filter { $0.label.uppercased().hasPrefix(letter) }.map(\.id)
    check(starts == [question.correct], "\(question.id): only the right picture starts with \(letter)")
}
for question in SampleActivities.shapes.questions {
    guard case .symbol(let outline, _) = question.art, case .symbol(let filled, _)? = question.correctAnswer?.art else {
        check(false, "\(question.id): a shapes question shows a shape")
        continue
    }
    check(filled == outline + ".fill", "\(question.id): the right answer is the same shape, filled")
}

// Every SF Symbol the content draws exists. Checked on this Mac's symbols; every name here
// shipped in iOS 17 or earlier.
let symbols = Set(activities.flatMap { [$0.symbol] + $0.questions.flatMap { [$0.art] + $0.answers.map(\.art) }.flatMap(\.symbolNames) })
let missing = symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }.sorted()
check(missing.isEmpty, "every SF Symbol in the content exists (\(symbols.count) names)\(missing.isEmpty ? "" : ": missing \(missing)")")

// MARK: Progress

let counting = SampleActivities.counting
var progress = Progress()
check(progress.stars == 0 && progress.turn(in: counting) == Progress.Turn(), "a new child has no stars and starts at question 1")
check(progress.question(in: counting)?.id == "counting.stars", "the first question is the first one")
check(progress.pick("2", in: counting) == .wrong, "a wrong answer is wrong")
check(progress.turn(in: counting).wrong == ["2"] && progress.stars == 0, "it is set aside, with no penalty and no star")
check(progress.pick("2", in: counting) == .ignored, "the same wrong answer can't count twice")
check(progress.pick("nope", in: counting) == .ignored, "an answer that isn't there does nothing")
check(progress.pick("3", in: counting) == .right, "the right answer is right")
check(progress.stars == 1 && progress.stars(in: counting) == 1 && progress.turn(in: counting).isSolved,
      "the right answer earns the question's star")
check(progress.pick("4", in: counting) == .ignored, "a solved question takes no more answers")
progress.next(in: counting)
check(progress.turn(in: counting) == Progress.Turn(question: 1), "Next moves on, with a clean slate")
progress.next(in: counting)
check(progress.turn(in: counting).question == 1, "Next does nothing before the right answer")
for _ in 1..<counting.questions.count {
    _ = progress.pick(progress.question(in: counting)!.correct, in: counting)
    progress.next(in: counting)
}
check(progress.isFinished(counting) && progress.question(in: counting) == nil, "after the last question the activity is done")
check(progress.stars(in: counting) == 4, "four questions, four stars")
progress.playAgain(counting)
check(progress.turn(in: counting).question == 0 && progress.stars == 4, "Play again starts over and keeps the stars")
_ = progress.pick("3", in: counting)
check(progress.stars == 4, "answering a starred question again adds no star")
check(progress.turn(in: SampleActivities.letters) == Progress.Turn(), "each activity keeps its own place")
progress.jump(to: 99, in: counting)
check(progress.turn(in: counting).question == 4, "a jump past the end lands on 'done'")

let saved = try JSONEncoder().encode(progress)
check((try? JSONDecoder().decode(Progress.self, from: saved)) == progress, "progress survives a save and a load")
// A file written by this version must load in the next one: keep this format readable.
let written = #"{"solved":["counting.stars","letters.b"],"turns":{"counting":{"question":1,"wrong":["2"],"isSolved":false}}}"#
let loaded = try? JSONDecoder().decode(Progress.self, from: Data(written.utf8))
check(loaded?.stars == 2 && loaded?.turn(in: counting) == Progress.Turn(question: 1, wrong: ["2"]),
      "a saved file in the current format loads")
let shrunk = try? JSONDecoder().decode(Progress.self, from: Data(#"{"solved":[],"turns":{"counting":{"question":40,"wrong":[],"isSolved":false}}}"#.utf8))
check(shrunk?.turn(in: counting).question == counting.questions.count, "a place past the end (content changed) is kept inside the activity")
progress.reset()
check(progress == Progress(), "reset forgets everything")

// MARK: The parental gate

var a = SeededGenerator(seed: 42)
var b = SeededGenerator(seed: 42)
check((0..<20).map { _ in a.next() } == (0..<20).map { _ in b.next() }, "the same seed gives the same numbers")
var c = SeededGenerator(seed: 43)
var d = SeededGenerator(seed: 42)
check((0..<5).map { _ in c.next() } != (0..<5).map { _ in d.next() }, "another seed gives other numbers")

let first = ParentalGate(seed: 42).question
check(first == ParentalGate(seed: 42).question, "the same seed asks the same first question")
var drawn: [GateQuestion] = []
var tally = ParentalGate(seed: 7)
for _ in 0..<2_000 {
    drawn.append(tally.question)
    tally.newQuestion()
}
check(drawn.allSatisfy { GateQuestion.leftFactors.contains($0.left) && GateQuestion.rightFactors.contains($0.right) },
      "factors stay in range (6 to 9, and 4 to 9)")
check(drawn.allSatisfy { (10...99).contains($0.answer) }, "every answer has two digits")
check(zip(drawn, drawn.dropFirst()).allSatisfy { $0 != $1 }, "a new question is never the one just asked")
check(Set(drawn.map { "\($0.left)x\($0.right)" }).count == GateQuestion.leftFactors.count * GateQuestion.rightFactors.count,
      "every pair of factors comes up")
check(first.text == "What is \(first.left) × \(first.right)?" && first.spoken.contains("times"),
      "the question reads 'What is 7 × 8?' on screen and says 'times' to VoiceOver")

var gate = ParentalGate(seed: 42)
check(!gate.canCheck && gate.check() == .notReady && gate.attempts == 0, "nothing typed: nothing to check, no attempt counted")
gate.type(10)
gate.type(-1)
check(gate.entry.isEmpty, "only digits 0 to 9")
gate.type(0)
gate.type(4)
check(gate.entry == "4", "no leading zero")
gate.type(2)
gate.type(9)
gate.type(9)
check(gate.entry == "429", "at most three digits")
gate.deleteLast()
check(gate.entry == "42" && gate.canCheck, "delete removes the last digit")
let asked = gate.question
let wrong = asked.answer == 42 ? 43 : 42
gate.deleteLast()
gate.deleteLast()
for digit in String(wrong) { gate.type(Int(String(digit))!) }
check(gate.check() == .failed, "a wrong answer fails")
check(gate.failures == 1 && gate.attempts == 1 && gate.entry.isEmpty, "it counts, and clears what was typed")
check(gate.question != asked, "the next opening asks a different question")
let next = gate.question
for digit in String(next.answer) { gate.type(Int(String(digit))!) }
check(gate.check() == .passed && gate.attempts == 2 && gate.failures == 1, "the right answer passes")
check(gate.question != next && gate.entry.isEmpty, "a question is used once, even when passed")
gate.type(5)
gate.cancel()
check(gate.entry.isEmpty, "closing the gate clears what was typed")

// MARK: Layouts in each pose

// The lesson's size inside the navigation stack, and the fold's frame in it, on the iPhone Duo
// simulator (iOS 27.1). Closed was measured with this app's lesson.state marker. The open and
// tabletop sizes were measured for another screen in the same kind of navigation stack (an
// inline title) on that simulator. testLessonLayoutInThisPose reports this app's own size in
// each pose (the "lesson=" line it attaches): replace these if they differ.
let closedLesson = CGSize(width: 382, height: 562)
let wideLesson = CGSize(width: 867, height: 553)
let tallLesson = CGSize(width: 669, height: 835)
let wideFold = CGRect(x: 455.5, y: -82, width: 40, height: 669)
let tallFold = CGRect(x: 0, y: 373.5, width: 669, height: 40)

func answersFit(_ layout: LessonLayout, count: Int, fold: CGRect?, _ name: String) {
    let space = layout.second.insetBy(dx: 16, dy: 16)   // the answers pane's padding
    let grid = AnswerGrid(count: count, in: space.size)
    check(grid.meetsMinimum, "\(name): \(count) answers of \(Int(grid.button.width)) × \(Int(grid.button.height)) pt, above the 88 pt minimum")
    let frames = grid.frames.map { $0.offsetBy(dx: space.minX, dy: space.minY) }
    check(frames.allSatisfy { layout.second.contains($0) }, "\(name): every answer inside the answers pane")
    if let fold {
        check(!frames.contains { $0.intersects(fold) }, "\(name): no answer on the fold")
    }
}

let closed = LessonLayout(size: closedLesson, fold: FoldGeometry())
check(closed.mode == .stacked, "closed: question above, answers below")
check(closed.first.maxY < closed.second.minY && near(closed.first.width, 382), "closed: two full-width panes, one above the other")
for count in 2...4 { answersFit(closed, count: count, fold: nil, "closed") }
check(AnswerGrid(count: 3, in: closed.second.insetBy(dx: 16, dy: 16).size).columns == 3, "closed: three answers in one row")

for active in [false, true] {
    let name = active ? "book" : "open, held wide"
    let layout = LessonLayout(size: wideLesson, fold: FoldGeometry(frame: wideFold, isActive: active))
    check(layout.mode == .foldLeftRight, "\(name): question on the left page, answers on the right")
    check(near(layout.first.maxX, wideFold.minX) && near(layout.second.minX, wideFold.maxX),
          "\(name): the pages meet at the fold's frame, not at half the width")
    for count in 2...4 { answersFit(layout, count: count, fold: wideFold, name) }
}
check(LessonLayout(size: wideLesson, fold: FoldGeometry(frame: wideFold, isActive: false))
      == LessonLayout(size: wideLesson, fold: FoldGeometry(frame: wideFold, isActive: true)),
      "flat and folded give the same pages, so folding moves nothing")
check(AnswerGrid(count: 3, in: LessonLayout(size: wideLesson, fold: FoldGeometry(frame: wideFold)).second.insetBy(dx: 16, dy: 16).size).columns == 1,
      "open: three answers in one column on the right page")

for active in [false, true] {
    let name = active ? "tabletop" : "open, held tall"
    let layout = LessonLayout(size: tallLesson, fold: FoldGeometry(frame: tallFold, isActive: active))
    check(layout.mode == .foldTopBottom, "\(name): the picture above the fold, the answers below")
    check(near(layout.first.maxY, tallFold.minY) && near(layout.second.minY, tallFold.maxY),
          "\(name): the answers start below the fold's frame")
    for count in 2...4 { answersFit(layout, count: count, fold: tallFold, name) }
}

let tent = LessonLayout(size: CGSize(width: 562, height: 382), fold: FoldGeometry())
check(tent.mode == .sideBySide && tent.first.maxX < tent.second.minX, "closed and held sideways: side by side")
for count in 2...4 { answersFit(tent, count: count, fold: nil, "closed, sideways") }
let splitView = LessonLayout(size: CGSize(width: 420, height: 553),
                             fold: FoldGeometry(frame: CGRect(x: 380, y: -82, width: 40, height: 669), isActive: true))
check(splitView.mode == .stacked, "a fold at the window's edge (Split View) is ignored")
let home = LessonLayout(size: closedLesson, fold: FoldGeometry(), firstShare: 0.3)
check(home.first.height < home.second.height, "home, closed: a short welcome above the activity cards")
check(LessonLayout(size: wideLesson, fold: FoldGeometry(frame: wideFold), firstShare: 0.3).first.maxX == wideFold.minX,
      "home, open: a fold splits where it is, whatever the share")

// MARK: The answer grid

let four = AnswerGrid(count: 4, in: CGSize(width: 400, height: 400))
check(four.columns == 2 && four.rows == 2, "four answers in a square space: two by two")
check(AnswerGrid(count: 3, in: CGSize(width: 400, height: 400)).columns != 2, "three answers never leave a half-empty row")
let capped = AnswerGrid(count: 2, in: CGSize(width: 2000, height: 2000))
check(capped.button == AnswerGrid.largestButton, "buttons stop growing at \(Int(AnswerGrid.largestButton.width)) × \(Int(AnswerGrid.largestButton.height)) pt")
check(near(capped.frames[0].minX + capped.frames[1].maxX, 2000), "the grid is centred")
let tiny = AnswerGrid(count: 3, in: CGSize(width: 120, height: 120))
check(!tiny.meetsMinimum, "a space too small for 88 pt buttons says so")
check(AnswerGrid(count: 3, in: .zero).frames.isEmpty && AnswerGrid(count: 0, in: CGSize(width: 99, height: 99)).frames.isEmpty,
      "no space or no answers: no buttons")
let some = AnswerGrid(count: 4, in: CGSize(width: 371, height: 505))
check(!zip(some.frames.indices, some.frames).contains { index, frame in
    some.frames.indices.contains { $0 != index && some.frames[$0].intersects(frame) } }, "buttons never overlap")

// MARK: Privacy: no networking, no tracking, links only behind the gate

/// Every line of the app's Swift files, without comments.
func appSources() -> [(file: String, code: String)] {
    let root = URL(fileURLWithPath: "__APP_NAME__")
    guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
    var result: [(String, String)] = []
    for case let url as URL in walker where url.pathExtension == "swift" {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let code = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { return "" }
            if let range = line.range(of: " //") { return String(line[..<range.lowerBound]) }
            return String(line)
        }.joined(separator: "\n")
        result.append((url.path.replacingOccurrences(of: root.path + "/", with: ""), code))
    }
    return result
}

let sources = appSources()
check(sources.count >= 15, "the privacy checks read the app's Swift files (\(sources.count) found; run from the project folder)")
let forbidden: [(String, String)] = [
    ("URLSession", "networking"), ("URLRequest", "networking"), ("NSURLConnection", "networking"),
    ("NWConnection", "networking"), ("import Network", "networking"), ("CFNetwork", "networking"),
    ("WKWebView", "a web view"), ("import WebKit", "a web view"),
    ("SFSafariViewController", "an in-app browser"), ("import SafariServices", "an in-app browser"),
    ("ASIdentifierManager", "the advertising identifier"), ("advertisingIdentifier", "the advertising identifier"),
    ("import AdSupport", "advertising"), ("AppTrackingTransparency", "tracking"), ("ATTrackingManager", "tracking"),
    ("identifierForVendor", "a device identifier"), ("import StoreKit", "purchases"),
    ("import CloudKit", "data leaving the device"), ("NSUbiquitousKeyValueStore", "data leaving the device"),
    ("import CoreLocation", "location"), ("import Contacts", "contacts"), ("import MessageUI", "messages"),
    ("import Speech", "speech recognition"), ("SFSpeechRecognizer", "speech recognition"),
    ("import GameKit", "Game Center"),
]
for (token, why) in forbidden {
    let hits = sources.filter { $0.code.contains(token) }.map(\.file)
    check(hits.isEmpty, "no \(token) (\(why))\(hits.isEmpty ? "" : " in \(hits)")")
}
let linkPattern = try NSRegularExpression(pattern: #"openURL|(?<![A-Za-z])Link\(|UIApplication\.shared\.open|\.open\(URL"#)
let linkFiles = sources.filter { source in
    linkPattern.firstMatch(in: source.code, range: NSRange(source.code.startIndex..., in: source.code)) != nil
}.map(\.file)
check(linkFiles == ["Grownups/GrownupsScreen.swift"], "links out of the app exist only in the grown-ups area, behind the gate (\(linkFiles))")
check(AppFacts.privacyPolicy.scheme == "https", "the privacy policy is an https address")

let manifestURL = URL(fileURLWithPath: "__APP_NAME__/PrivacyInfo.xcprivacy")
if let data = try? Data(contentsOf: manifestURL),
   let manifest = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
    check(manifest["NSPrivacyTracking"] as? Bool == false, "privacy manifest: no tracking")
    check((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true, "privacy manifest: no tracking domains")
    check((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true, "privacy manifest: no data collected")
    let reasons = (manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []).reduce(into: [String: [String]]()) {
        $0[$1["NSPrivacyAccessedAPIType"] as? String ?? ""] = $1["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
    }
    let usesDefaults = sources.contains { $0.code.contains("UserDefaults") || $0.code.contains("AppStorage") }
    check(usesDefaults == (reasons["NSPrivacyAccessedAPICategoryUserDefaults"] == ["CA92.1"]),
          "privacy manifest: UserDefaults declared with reason CA92.1 exactly when the app uses it")
    check(Set(reasons.keys).subtracting(["NSPrivacyAccessedAPICategoryUserDefaults"]).isEmpty,
          "privacy manifest: no other required-reason API declared (\(reasons.keys.sorted()))")
} else {
    check(false, "__APP_NAME__/PrivacyInfo.xcprivacy can be read (run from the project folder)")
}
let project = (try? String(contentsOf: URL(fileURLWithPath: "__APP_NAME__.xcodeproj/project.pbxproj"), encoding: .utf8)) ?? ""
check(!project.isEmpty && !project.contains("NSUserTrackingUsageDescription"), "no tracking permission text in the project")

// MARK: Every type stays nonisolated

// The app target compiles with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, and so does this
// program. Each line below needs its type to be nonisolated; drop `nonisolated` from one
// and this file stops compiling. Add a line for each new model type.
let offMain = await Task.detached { () -> Bool in
    let all = SampleActivities.all                                              // SampleActivities
    let activity = all[0]                                                       // Activity
    let question = activity.questions[0]                                        // Question
    let answer: Answer? = question.correctAnswer                                // Answer
    let art: Art = .symbol("star.fill", Tint.yellow)                            // Art, Tint
    var log = Progress()
    let pick: Progress.Pick = log.pick(question.correct, in: activity)          // Progress, Pick
    let turn: Progress.Turn = log.turn(in: activity)                            // Turn
    var generator = SeededGenerator(seed: 1)                                    // SeededGenerator
    let ask = GateQuestion(left: 6, right: 7)                                   // GateQuestion
    var gate = ParentalGate(seed: 1)                                            // ParentalGate
    let outcome: ParentalGate.Outcome = gate.check()                            // Outcome
    let fold = FoldGeometry(candidates: [(wideFold, true)], in: wideLesson)     // FoldGeometry
    let layout = LessonLayout(size: wideLesson, fold: fold)                     // LessonLayout
    let mode: LessonLayout.Mode = layout.mode                                   // Mode
    let grid = AnswerGrid(count: 3, in: layout.second.size)                     // AnswerGrid
    let facts = AppFacts.speechLanguage                                         // AppFacts
    return answer != nil && !art.symbolNames.isEmpty && pick == .right && turn.isSolved
        && generator.next() != 0 && ask.answer == 42 && outcome == .notReady && mode == .foldLeftRight
        && grid.meetsMinimum && !facts.isEmpty
}.value
check(offMain, "the model works off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
