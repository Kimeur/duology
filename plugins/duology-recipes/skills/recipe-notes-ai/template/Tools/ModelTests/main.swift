// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
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

// MARK: The sample notes

let now = Date(timeIntervalSinceReferenceDate: 820_000_000)   // whole seconds, like the saved file
let samples = SampleNotes.all(now: now)
check(samples.map(\.id) == ["sample.offsite", "sample.sourdough", "sample.garden", "sample.groceries"], "four sample notes")
check(Set(samples.map(\.id)).count == samples.count, "sample IDs are unique")
check(Notebook(notes: samples.reversed()).sorted.map(\.id) == samples.map(\.id), "the list shows them newest first")
check(samples.filter(\.canBeSummarized).map(\.id) == ["sample.offsite", "sample.sourdough", "sample.garden"],
      "three can be summarized; the short grocery list can't (under \(Note.minimumWordsToSummarize) words)")
check(samples.allSatisfy { $0.digest == nil }, "no sample comes with a summary")

// MARK: Notes

let garden = samples[2]
check(garden.displayTitle == "Garden ideas for spring", "a note without a title shows its first line")
check(garden.preview.hasPrefix("The tomatoes did well"), "and its preview starts after that line")
check(samples[0].preview.hasPrefix("We meet in Lyon"), "a titled note's preview starts with the text")
check(Note().displayTitle == "New Note" && Note().isEmpty && Note(title: "  ", body: "\n").isEmpty, "an empty note")
check(Note(title: "A", body: "b c").text == "A\n\nb c" && Note(body: "b c").text == "b c", "the text to summarize: the title, then the body")
check(Note(title: "Two words", body: "and three more").wordCount == 5, "words are counted across the title and the body")

// MARK: Fingerprints

check(Fingerprint.of("") == "cbf29ce484222325" && Fingerprint.of("a") == "af63dc4c8601ec8c",
      "the fingerprint is FNV-1a 64 (known values), so it's the same on every launch and device")
check(Fingerprint.of("note") != Fingerprint.of("note ") && Fingerprint.of("note") == Fingerprint.of("note"),
      "one character more changes it")

// MARK: The notebook

var book = Notebook(notes: samples)
let later = now.addingTimeInterval(60)
book.edit("sample.groceries", body: samples[3].body, at: later)
check(book.note("sample.groceries")?.modified == samples[3].modified, "an edit that changes nothing keeps the date")
book.edit("sample.groceries", body: samples[3].body + "\nBread", at: later)
check(book.note("sample.groceries")?.modified == later && book.sorted.first?.id == "sample.groceries",
      "a real edit moves the note to the top")
let digest = Digest(headline: "Plan", points: ["A"], todos: [], origin: .simple, source: Fingerprint.of(book.note("sample.offsite")!.text))
book.setDigest(digest, for: "sample.offsite")
check(book.note("sample.offsite")?.digest == digest && book.note("sample.offsite")?.modified == now.addingTimeInterval(-3_600),
      "saving a summary doesn't count as an edit")
check(book.note("sample.offsite")?.summaryIsCurrent == true, "a summary of the note as it is is current")
book.edit("sample.offsite", title: "Team offsite plan!", at: later)
check(book.note("sample.offsite")?.summaryIsCurrent == false && book.note("sample.offsite")?.digest == digest,
      "after an edit the summary stays, marked out of date")
book.add(Note(id: "blank", modified: later))
check(book.removeIfEmpty("blank") && book.note("blank") == nil, "an empty note is dropped when left")
check(!book.removeIfEmpty("sample.garden") && book.note("sample.garden") != nil, "a note with words is kept")
book.remove("sample.garden")
check(book.notes.count == 3, "delete removes the note")
let tie = Notebook(notes: [Note(id: "b", body: "x", modified: now), Note(id: "a", body: "x", modified: now)])
check(tie.sorted.map(\.id) == ["a", "b"], "notes changed at the same moment keep a fixed order")

let file = try book.encoded()
check((try? Notebook.decode(file)) == book, "the notebook survives a save and a load")
check(String(decoding: file, as: UTF8.self).contains(#""version":1"#), "the file says which format it is")
// A file written by this version must load in the next one: keep this format readable.
let written = #"{"notes":[{"body":"Text","digest":{"coversWholeNote":true,"headline":"H","origin":"onDeviceAI","points":["P"],"source":"x","todos":[]},"id":"n1","modified":"2026-10-29T10:00:00Z","title":"T"}],"version":1}"#
let loaded = try? Notebook.decode(Data(written.utf8))
check(loaded?.note("n1")?.digest?.origin == .onDeviceAI && loaded?.note("n1")?.title == "T",
      "a saved file in the current format loads")
check((try? Notebook.decode(Data(#"{"notes":[]}"#.utf8)))?.version == Notebook.currentVersion, "a file without a version loads")

// MARK: Tidying the model's lines

check(Digest.tidy("  - Book the train ") == "Book the train" && Digest.tidy("• Point") == "Point"
      && Digest.tidy("2. Second") == "Second" && Digest.tidy("- [ ] Task") == "Task" && Digest.tidy("“Quoted”") == "Quoted",
      "list markers, checkboxes and wrapping quotes are removed")
check(Digest.tidy("3.5 kg of flour") == "3.5 kg of flour", "a number at the start isn't a list marker")
check(Digest.limit("one two three four", words: 3) == "one two three…" && Digest.limit("one two", words: 3) == "one two",
      "lines are cut to a number of words, with an ellipsis")
let messy = DigestDraft(headline: " - Plan for the offsite in Lyon with the whole team this March ",
                        points: ["- A", "", "a", "B", "C", "D", "E"], todos: ["[ ] Call", "  "])
let clean = messy.finished(origin: .onDeviceAI, source: "s")
check(clean?.headline == "Plan for the offsite in Lyon with the whole team…",
      "the headline is tidied and cut to \(Digest.maximumHeadlineWords) words")
check(clean?.points == ["A", "B", "C", "D"], "blank and repeated points are dropped, at most \(Digest.maximumPoints)")
check(clean?.todos == ["Call"], "to-dos are tidied too")
check(DigestDraft(headline: "  ", points: ["A"]).finished(origin: .simple, source: "s") == nil, "no headline, no summary")

// MARK: The simple summary (no AI)

let offsite = SimpleSummary.digest(of: samples[0])
check(offsite?.origin == .simple && offsite?.source == Fingerprint.of(samples[0].text), "a simple summary says what made it, and from which text")
check(offsite?.headline == "We meet in Lyon on 12 March for two days.", "its headline is the first sentence")
check(offsite?.points == ["Day one is for the roadmap and the hiring plan", "Day two is for customer interviews, in small groups",
                          "Dinner on the first evening, near the hotel"], "the note's own bullet points become the points")
check(offsite?.todos == ["Book the train tickets before Friday", "Send the agenda to everyone", "ask Sam about a vegetarian menu"],
      "open to-dos are found; a ticked one ([x]) is left out")
let sourdough = SimpleSummary.digest(of: samples[1])
check(sourdough?.headline == "The third loaf finally rose." && sourdough?.points.count == Digest.maximumPoints && sourdough?.todos == [],
      "a note without bullets: the first sentence, then the next ones as points")
check(SimpleSummary.digest(of: Note()) == nil, "an empty note has no summary")
let chores = Note(body: "- [ ] Call the plumber about the kitchen sink leak\n- [ ] Pay the electricity bill before Friday")
check(chores.canBeSummarized && SimpleSummary.digest(of: chores)?.headline == "Call the plumber about the kitchen sink leak"
      && SimpleSummary.digest(of: chores)?.todos.count == 2,
      "a note of only to-dos still gets a summary: its first to-do heads it")
let done = Note(body: "- [x] Called the plumber about the kitchen sink leak\n- [x] Paid the electricity bill on Friday")
check(SimpleSummary.digest(of: done)?.headline.isEmpty == false, "so does a note of only ticked to-dos")
check(samples.filter(\.canBeSummarized).allSatisfy { SimpleSummary.digest(of: $0) != nil },
      "every note that can be summarized gets a simple summary, so the fallback never ends empty")
check(SimpleSummary.sentences(in: "Weigh 3.5 kg. Then rest! Done? Yes\nNew line") == ["Weigh 3.5 kg.", "Then rest!", "Done?", "Yes", "New line"],
      "sentences end at . ! ? before a space, and at line ends; 3.5 stays whole")
check(SimpleSummary.todo("TODO: call Sam") == "call Sam" && SimpleSummary.todo("☐ Water") == "Water"
      && SimpleSummary.todo("- [ ]") == nil && SimpleSummary.todo("Today") == nil, "to-do lines in their usual forms")
check(SimpleSummary.digest(of: samples[0]) == SimpleSummary.digest(of: samples[0]), "same note, same summary")
let fallback = SimpleSummary.digest(of: samples[1], fallbackReason: AppFacts.aiFailedReason)
check(fallback?.fallbackReason == AppFacts.aiFailedReason, "a fallback summary says why it isn't from AI")

// MARK: The prompt budget

let short = PromptBudget("A short note.")
check(short.isWhole && short.text == "A short note.", "a short note goes whole")
let sentence = "This sentence is part of a very long note. "
let long = PromptBudget(String(repeating: sentence, count: 400))
check(!long.isWhole && long.text.count <= PromptBudget.characterLimit && long.text.hasSuffix("long note."),
      "a long note is cut at a sentence end, within \(PromptBudget.characterLimit) characters")
check(PromptBudget(String(repeating: "x", count: 7_000)).text.count == PromptBudget.characterLimit, "text without spaces is cut at the limit")
check(PromptBudget(String(repeating: "word ", count: 2_000)).text.hasSuffix("word"), "text without sentence ends is cut at a space")

// MARK: The stand-in stream and the engines

let steps = StandInStream.steps(toward: SimpleSummary.draft(of: samples[0]))
let draft = SimpleSummary.draft(of: samples[0])
check(steps.count == (draft.headline ?? "").split(separator: " ").count + draft.points.count + draft.todos.count,
      "the stand-in streams the headline word by word, then each point and to-do (\(steps.count) steps)")
check(steps.first?.headline == "We" && steps.first?.points == [] && steps.last == draft, "it starts with one word and ends with the whole summary")
check(zip(steps, steps.dropFirst()).allSatisfy { ($1.headline ?? "").hasPrefix($0.headline ?? "") && $1.points.count >= $0.points.count },
      "each step only adds, like a model's partial results")
check(SummaryEngine(argument: "standin") == .standIn && SummaryEngine(argument: "AI") == .onDeviceAI
      && SummaryEngine(argument: "nope") == nil, "-summarizer names")

// MARK: Layouts in each pose

// The note screen's size inside the navigation stack, and the fold's frame in it, on the iPhone
// Duo simulator (iOS 27.1), from the note.state marker of testNoteLayoutInThisPose in each pose.
let closedNote = CGSize(width: 382, height: 562)
let wideNote = CGSize(width: 867, height: 553)
let tallNote = CGSize(width: 669, height: 835)
let wideFold = CGRect(x: 455.5, y: -82, width: 40, height: 669)
let tallFold = CGRect(x: 0, y: 373.5, width: 669, height: 40)

let closed = NoteLayout(size: closedNote, fold: FoldGeometry(), barHeight: 64)
check(closed.mode == .single && !closed.hasSummaryPane, "closed: the note alone, with the summary bar")
check(near(closed.summary.height, 64) && near(closed.summary.maxY, 562) && near(closed.editor.maxY, closed.summary.minY),
      "closed: the bar at the bottom, the note above it")
check(NoteLayout(size: closedNote, fold: FoldGeometry(), barHeight: 900).summary.height <= closedNote.height / 2,
      "the bar never takes more than half the screen, whatever the text size")

for active in [false, true] {
    let name = active ? "book" : "open, held wide"
    let layout = NoteLayout(size: wideNote, fold: FoldGeometry(frame: wideFold, isActive: active), barHeight: 64)
    check(layout.mode == .foldLeftRight, "\(name): the note on the left page, the summary on the right")
    check(near(layout.editor.maxX, wideFold.minX) && near(layout.summary.minX, wideFold.maxX),
          "\(name): the pages meet at the fold's frame, not at half the width")
    check(!layout.summary.intersects(wideFold) && !layout.editor.intersects(wideFold), "\(name): nothing on the fold")
    check(layout.summary.width >= 320, "\(name): the summary pane is \(Int(layout.summary.width)) pt wide, room for its buttons")
}
check(NoteLayout(size: wideNote, fold: FoldGeometry(frame: wideFold, isActive: false), barHeight: 64)
      == NoteLayout(size: wideNote, fold: FoldGeometry(frame: wideFold, isActive: true), barHeight: 64),
      "flat and folded give the same pages, so folding moves nothing")

for active in [false, true] {
    let name = active ? "tabletop" : "open, held tall"
    let layout = NoteLayout(size: tallNote, fold: FoldGeometry(frame: tallFold, isActive: active), barHeight: 64)
    check(layout.mode == .foldTopBottom, "\(name): the note above the fold, the summary below it")
    check(near(layout.editor.maxY, tallFold.minY) && near(layout.summary.minY, tallFold.maxY),
          "\(name): the summary starts below the fold's frame, on the half that rests on the table")
}

check(NoteLayout(size: CGSize(width: 678, height: 300), fold: FoldGeometry(), barHeight: 64).mode == .single,
      "closed and held sideways: still one pane and the bar (under \(Int(NoteLayout.twoPaneMinimumWidth)) pt)")
let iPad = NoteLayout(size: CGSize(width: 1180, height: 760), fold: FoldGeometry(), barHeight: 64)
check(iPad.mode == .sideBySide && iPad.editor.maxX < iPad.summary.minX, "a wide window without a fold: side by side")
let splitView = NoteLayout(size: CGSize(width: 420, height: 553),
                           fold: FoldGeometry(frame: CGRect(x: 380, y: -82, width: 40, height: 669), isActive: true), barHeight: 64)
check(splitView.mode == .single, "a fold at the window's edge (Split View) is ignored")

// MARK: The list's columns

let one = NoteColumns(width: closedNote.width, fold: FoldGeometry())
check(one.columns.count == 1 && near(one.columns[0].lowerBound, 16) && near(one.columns[0].upperBound, 366), "closed: one column")
for active in [false, true] {
    let columns = NoteColumns(width: wideNote.width, fold: FoldGeometry(frame: wideFold, isActive: active))
    check(columns.columns.count == 2 && columns.foldsBetween, "open\(active ? ", folded" : ""): two columns, one per page")
    check(columns.columns[0].upperBound < wideFold.minX && columns.columns[1].lowerBound > wideFold.maxX,
          "open\(active ? ", folded" : ""): the columns meet at the fold's frame, so no card is on it")
}
let tabletop = NoteColumns(width: tallNote.width, fold: FoldGeometry(frame: tallFold, isActive: true))
check(tabletop.columns.count == 2 && !tabletop.foldsBetween, "tabletop: two columns; the list scrolls across the fold")
check(NoteColumns(width: 1180, fold: FoldGeometry()).columns.count == 3, "at most three columns")
check(NoteColumns(width: 1180, fold: FoldGeometry()).columns.allSatisfy { $0.upperBound - $0.lowerBound >= NoteColumns.minimumWidth },
      "every column at least \(Int(NoteColumns.minimumWidth)) pt")

// MARK: Fold geometry

let fromRegions = FoldGeometry(candidates: [(CGRect(x: -40, y: 0, width: 40, height: 100), true), (wideFold, false)], in: wideNote)
check(fromRegions.frame == wideFold && !fromRegions.isActive, "a region outside the view is ignored")
check(FoldGeometry(candidates: [(wideFold, false), (wideFold, true)], in: wideNote).isActive, "an active fold comes first")

// MARK: Privacy: the note never leaves the device

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
    ("PrivateCloudComputeLanguageModel", "Private Cloud Compute sends the note to Apple's servers"),
    ("URLSession", "networking"), ("URLRequest", "networking"), ("NSURLConnection", "networking"),
    ("NWConnection", "networking"), ("import Network", "networking"), ("CFNetwork", "networking"),
    ("WKWebView", "a web view"), ("import WebKit", "a web view"),
    ("ASIdentifierManager", "the advertising identifier"), ("import AdSupport", "advertising"),
    ("AppTrackingTransparency", "tracking"), ("identifierForVendor", "a device identifier"),
    ("import CloudKit", "notes leaving the device"), ("NSUbiquitousKeyValueStore", "notes leaving the device"),
]
for (token, why) in forbidden {
    let hits = sources.filter { $0.code.contains(token) }.map(\.file)
    check(hits.isEmpty, "no \(token) (\(why))\(hits.isEmpty ? "" : " in \(hits)")")
}

let urlLiterals = sources.filter { $0.code.contains("http://") || $0.code.contains("https://") }.map(\.file)
check(urlLiterals.isEmpty, "no web address in the app's code, so nothing can be fetched or sent from a URL\(urlLiterals.isEmpty ? "" : " in \(urlLiterals)")")

// Only the constant reaches the model's instructions; the note goes in the prompt.
let instructionsPattern = try NSRegularExpression(pattern: #"instructions:\s*([^)\n]*)"#)
var instructionUses: [String] = []
for source in sources {
    for match in instructionsPattern.matches(in: source.code, range: NSRange(source.code.startIndex..., in: source.code)) {
        if let range = Range(match.range(at: 1), in: source.code) { instructionUses.append(String(source.code[range])) }
    }
}
check(!instructionUses.isEmpty && instructionUses.allSatisfy { $0.trimmingCharacters(in: .whitespaces) == "AppFacts.summaryInstructions" },
      "the model's instructions are always AppFacts.summaryInstructions, never the note (\(instructionUses))")
check(sources.filter { $0.code.contains("LanguageModelSession(") }.map(\.file) == ["AI/OnDeviceSummarizer.swift"],
      "one place talks to the model: AI/OnDeviceSummarizer.swift")

// Required-reason APIs (Apple's list): none used, so the manifest declares none.
let requiredReason: [(String, String)] = [
    ("UserDefaults", "UserDefaults"), ("@AppStorage", "UserDefaults"),
    ("creationDate", "file timestamps"), ("modificationDate", "file timestamps"), ("ModificationDateKey", "file timestamps"),
    ("attributesOfItem", "file timestamps"), ("systemUptime", "system boot time"), ("mach_absolute_time", "system boot time"),
    ("volumeAvailableCapacity", "disk space"), ("systemFreeSize", "disk space"), ("activeInputModes", "active keyboards"),
]
for (token, category) in requiredReason {
    let hits = sources.filter { $0.code.contains(token) }.map(\.file)
    check(hits.isEmpty, "no \(token) (a required-reason API: \(category))\(hits.isEmpty ? "" : " in \(hits)")")
}

let manifestURL = URL(fileURLWithPath: "__APP_NAME__/PrivacyInfo.xcprivacy")
if let data = try? Data(contentsOf: manifestURL),
   let manifest = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
    check(manifest["NSPrivacyTracking"] as? Bool == false, "privacy manifest: no tracking")
    check((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true, "privacy manifest: no tracking domains")
    check((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true, "privacy manifest: no data collected")
    check((manifest["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true,
          "privacy manifest: no required-reason API declared, matching the sources")
} else {
    check(false, "__APP_NAME__/PrivacyInfo.xcprivacy can be read (run from the project folder)")
}
let project = (try? String(contentsOf: URL(fileURLWithPath: "__APP_NAME__.xcodeproj/project.pbxproj"), encoding: .utf8)) ?? ""
check(!project.isEmpty && !project.contains("private-cloud-compute"), "no Private Cloud Compute entitlement in the project")

// MARK: Every type stays nonisolated

// The app target compiles with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, and so does this
// program. Each line below needs its type to be nonisolated; drop `nonisolated` from one
// and this file stops compiling. Add a line for each new model type.
let offMain = await Task.detached { () -> Bool in
    let notes = SampleNotes.all()                                                       // SampleNotes
    let note: Note = notes[0]                                                           // Note
    var book = Notebook(notes: notes)                                                   // Notebook
    book.edit(note.id, body: "x")
    let mark = Fingerprint.of(note.text)                                                // Fingerprint
    let draft: DigestDraft = SimpleSummary.draft(of: note)                              // DigestDraft, SimpleSummary
    let digest: Digest? = draft.finished(origin: Digest.Origin.simple, source: mark)    // Digest, Origin
    let budget = PromptBudget(note.text)                                                // PromptBudget
    let steps = StandInStream.steps(toward: draft)                                      // StandInStream
    let engine: SummaryEngine = .standIn                                                // SummaryEngine
    let fold = FoldGeometry(candidates: [(wideFold, true)], in: wideNote)               // FoldGeometry
    let layout = NoteLayout(size: wideNote, fold: fold, barHeight: 64)                  // NoteLayout
    let mode: NoteLayout.Mode = layout.mode                                             // Mode
    let columns = NoteColumns(width: wideNote.width, fold: fold)                        // NoteColumns
    let facts = AppFacts.summaryInstructions                                            // AppFacts
    return digest != nil && budget.isWhole && !steps.isEmpty && engine == .standIn && mode == .foldLeftRight
        && columns.foldsBetween && !facts.isEmpty && book.notes.count == 4
}.value
check(offMain, "the model works off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
