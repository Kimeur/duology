// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
// duo-lint:disable-file DUO006 -- test fixtures: window sizes measured on the Duo simulator, never used for layout
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

// MARK: The bundled catalogue

let mediaFolder = URL(fileURLWithPath: "__APP_NAME__/Media")
let catalogData = try? Data(contentsOf: mediaFolder.appendingPathComponent("Catalog.json"))
check(catalogData != nil, "Media/Catalog.json is there")
let catalog = catalogData.flatMap { try? Catalog.decode(from: $0) } ?? Catalog(shows: [])
check(!catalog.shows.isEmpty, "the catalogue decodes and has shows")
check(catalog.shows.allSatisfy { !$0.episodes.isEmpty }, "every show has episodes")
let ids = catalog.episodes.map(\.id)
check(Set(ids).count == ids.count, "episode IDs are unique")
check(Set(catalog.shows.map(\.id)).count == catalog.shows.count, "show IDs are unique")
check(catalog.shows.allSatisfy { $0.colors.count == 2 && $0.colors.allSatisfy { UInt32($0, radix: 16) != nil } },
      "every show has two hex colours for its artwork")
for episode in catalog.episodes {
    if let file = episode.bundledFile {
        let path = mediaFolder.appendingPathComponent("\(file.name).\(file.ext)").path
        check(FileManager.default.fileExists(atPath: path), "\(episode.id): \(episode.media) is in Media/")
    } else {
        check(episode.remoteURL != nil, "\(episode.id): media is a file name or an https URL")
    }
    check(episode.duration > 0, "\(episode.id): has a length")
    check(episode.publishedDate != nil, "\(episode.id): has a publication day")
}
for show in catalog.shows {
    check(show.episodes.map(\.number) == Array(1...show.episodes.count), "\(show.id): episodes are numbered 1, 2, 3 in order")
}

// MARK: Catalogue lookups

let sample = Catalog(shows: [
    Show(id: "a", title: "A", host: "H", summary: "", symbol: "star", colors: ["000000", "FFFFFF"], episodes: [
        Episode(id: "a1", number: 1, title: "One", summary: "", duration: 60, media: "a1.mp4", published: "2026-10-01"),
        Episode(id: "a2", number: 2, title: "Two", summary: "", duration: 60, media: "a2.mp4", published: "2026-10-08"),
        Episode(id: "a3", number: 3, title: "Three", summary: "", duration: 60, media: "a3.mp4", published: "2026-10-15"),
    ]),
    Show(id: "b", title: "B", host: "H", summary: "", symbol: "moon", colors: ["000000", "FFFFFF"], episodes: [
        Episode(id: "b1", number: 1, title: "Stream", summary: "", duration: 600,
                media: "https://example.com/b1/master.m3u8", published: "2026-10-02"),
    ]),
])
check(sample.following("a1").map(\.id) == ["a2", "a3"], "playing episode 1 queues the rest of its show")
check(sample.following("a3").isEmpty, "the last episode of a show has nothing after it")
check(sample.following("b1").isEmpty, "the queue never crosses into another show")
check(sample.following("zz").isEmpty, "an unknown episode has nothing after it")
check(sample.show(of: "a2")?.id == "a", "an episode knows its show")
check(sample.episode("zz") == nil, "an unknown episode is nil")
check(sample.episodes.count == 4, "every episode, show by show")

let dotted = Episode(id: "x", number: 1, title: "", summary: "", duration: 1, media: "clip.v2.mp4", published: "2026-1-5")
check(dotted.bundledFile?.name == "clip.v2" && dotted.bundledFile?.ext == "mp4", "a file name with dots splits at the last one")
check(sample.episode("b1")?.bundledFile == nil && sample.episode("b1")?.remoteURL != nil, "an https stream is a URL, not a file")
let noExtension = Episode(id: "y", number: 1, title: "", summary: "", duration: 1, media: "clip", published: "oops")
check(noExtension.bundledFile == nil, "a name with no extension is not a bundled file")
check(noExtension.publishedDate == nil, "a bad date is nil, not a crash")
let day = dotted.publishedDate.map { Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: $0) }
check(day?.year == 2026 && day?.month == 1 && day?.day == 5, "publication days parse as year, month, day")

// MARK: Queue

var queue = PlaybackQueue()
check(queue.current == nil && queue.next == nil, "an empty queue plays nothing")
queue.start("a1", then: ["a2", "a3", "a1"])
check(queue.current == "a1" && queue.next == "a2", "start plays the first and lines up the next")
check(queue.items == ["a1", "a2", "a3"], "the started episode is not queued twice")
check(queue.advance() == "a2" && queue.previous == "a1", "advance moves on one")
queue.advance()
check(queue.current == "a3" && queue.next == nil, "the last episode has no next")
check(queue.advance() == nil && queue.current == "a3", "advancing past the end changes nothing")
check(queue.goBack() == "a2", "go back moves back one")
queue.start("b1", then: [])
check(queue.current == "b1" && queue.next == nil && queue.items == ["b1"], "a new start replaces the queue")
queue.clear()
check(queue.current == nil, "clear empties it")

// MARK: Up next

var policy = UpNextPolicy()
check(policy.lead(for: 600) == 10, "a long episode shows the card 10 s before the end")
check(policy.lead(for: 12) == 6, "a 12 s clip shows it at half time, not from the start")
check(policy.card(position: 100, duration: 600, hasNext: true, dismissed: false) == .hidden, "no card mid-episode")
check(policy.card(position: 590, duration: 600, hasNext: true, dismissed: false) == .counting(10), "the card counts down from 10")
check(policy.card(position: 595.2, duration: 600, hasNext: true, dismissed: false) == .counting(5), "seconds round up")
check(policy.card(position: 599, duration: 600, hasNext: false, dismissed: false) == .hidden, "no card when nothing follows")
check(policy.card(position: 599, duration: 600, hasNext: true, dismissed: true) == .hidden, "no card once dismissed")
check(policy.card(position: 5, duration: 0, hasNext: true, dismissed: false) == .hidden, "no card before the length is known")
check(policy.card(position: 7, duration: 12, hasNext: true, dismissed: false) == .counting(5), "the 12 s clip: card at 7 s, 5 to go")
check(policy.shouldAdvance(position: 600, duration: 600, hasNext: true, dismissed: false), "at the end, autoplay moves on")
check(!policy.shouldAdvance(position: 598, duration: 600, hasNext: true, dismissed: false), "not before the end")
check(!policy.shouldAdvance(position: 600, duration: 600, hasNext: true, dismissed: true), "not after the card was dismissed")
check(!policy.shouldAdvance(position: 600, duration: 600, hasNext: false, dismissed: false), "not at the end of the queue")
policy.autoplay = false
check(policy.card(position: 595, duration: 600, hasNext: true, dismissed: false) == .waiting, "autoplay off: the card waits")
check(!policy.shouldAdvance(position: 600, duration: 600, hasNext: true, dismissed: false), "autoplay off: nothing starts by itself")
policy = UpNextPolicy(lead: 0, autoplay: true)
check(policy.card(position: 599.9, duration: 600, hasNext: true, dismissed: false) == .hidden, "lead 0 never shows the card")

// MARK: Resume positions

var resume = ResumePositions()
resume.record("a1", at: 1, duration: 600)
check(resume.resume("a1") == 0, "a second in counts as not started")
resume.record("a1", at: 245, duration: 600)
check(resume.resume("a1") == 245 && !resume.isFinished("a1"), "a position mid-episode is kept")
check(abs(resume.progress("a1", duration: 600) - 245.0 / 600) < 0.0001, "progress is position over length")
resume.record("a1", at: 590, duration: 600)
check(resume.isFinished("a1") && resume.resume("a1") == 0, "near the end: finished, and the next play starts at 0")
check(resume.progress("a1", duration: 600) == 1, "a finished episode reports full progress")
resume.record("a1", at: 30, duration: 600)
check(!resume.isFinished("a1") && resume.resume("a1") == 30, "watching it again clears finished")
resume.record("short", at: 10.5, duration: 12)
check(resume.isFinished("short"), "a 12 s clip is finished within 2 s of its end")
resume.record("a2", at: .nan, duration: 600)
check(resume.resume("a2") == 0, "a NaN position is ignored")
let encoded = try? JSONEncoder().encode(resume)
let decoded = encoded.flatMap { try? JSONDecoder().decode(ResumePositions.self, from: $0) }
check(decoded == resume, "positions survive a save and a load")
resume.forget("a1")
check(resume.resume("a1") == 0 && !resume.isFinished("a1"), "forget clears an episode")

// MARK: Fold geometry (frames measured on the iPhone Duo simulator, iOS 27.1)

let wide = CGSize(width: 951, height: 669)       // open, held wide
let tall = CGSize(width: 669, height: 951)       // open, held tall
let closed = CGSize(width: 382, height: 644)     // closed, the safe area
let bookFold = CGRect(x: 455, y: 0, width: 40, height: 669)
let tabletopFold = CGRect(x: 0, y: 455, width: 669, height: 40)
check(FoldGeometry.liesInside(bookFold, of: wide), "the open phone's fold splits the wide window")
check(FoldGeometry.liesInside(tabletopFold, of: tall), "and the tall one")
check(!FoldGeometry.liesInside(CGRect(x: 382, y: 0, width: 84, height: 174), of: closed),
      "a region past the view's edge (the closed phone's status bar column) is not a fold")
check(!FoldGeometry.liesInside(CGRect(x: 0, y: 0, width: 40, height: 669), of: wide), "a fold on the view's edge is not a fold")
var fold = FoldGeometry(candidates: [(bookFold, false)], in: wide)
check(fold.frame == bookFold && !fold.isActive && fold.isVertical, "flat and held wide: an inactive, top-to-bottom fold")
fold = FoldGeometry(candidates: [(CGRect(x: 900, y: 0, width: 40, height: 669), false), (bookFold, true)], in: wide)
check(fold.isActive && fold.frame == bookFold, "an active fold wins over an inactive one")
fold = FoldGeometry(candidates: [(CGRect(x: 382, y: 0, width: 84, height: 174), true)], in: closed)
check(fold.frame == nil && !fold.isActive, "nothing inside the view: no fold")
check(!FoldGeometry(frame: tabletopFold, isActive: true).isVertical, "tabletop's fold runs side to side")

// MARK: Player regions

let book = FoldGeometry(frame: bookFold, isActive: true)
let tabletop = FoldGeometry(frame: tabletopFold, isActive: true)
let flatWide = FoldGeometry(frame: bookFold, isActive: false)
let wideBounds = CGRect(origin: .zero, size: wide)
let tallBounds = CGRect(origin: .zero, size: tall)
check(FoldRegions.split(CGRect(origin: .zero, size: closed), fold: FoldGeometry()) == nil, "closed: the controls float over the video")
check(FoldRegions.split(wideBounds, fold: flatWide) == nil, "open and flat: the controls float too")
if let regions = FoldRegions.split(wideBounds, fold: book) {
    check(near(regions.video, CGRect(x: 0, y: 0, width: 455, height: 669)), "book: the video takes the leading region")
    check(near(regions.controls, CGRect(x: 495, y: 0, width: 456, height: 669)), "book: the controls take the trailing region")
    check(!regions.video.intersects(bookFold) && !regions.controls.intersects(bookFold), "book: nothing in the fold's 40 pt")
} else {
    check(false, "book splits the player")
}
if let regions = FoldRegions.split(tallBounds, fold: tabletop) {
    check(near(regions.video, CGRect(x: 0, y: 0, width: 669, height: 455)), "tabletop: the video sits above the fold")
    check(near(regions.controls, CGRect(x: 0, y: 495, width: 669, height: 456)), "tabletop: the controls sit below it")
} else {
    check(false, "tabletop splits the player")
}
let shifted = FoldRegions.split(CGRect(x: 10, y: 20, width: 951, height: 669), fold: book)
check(shifted.map { near($0.controls.minX, 505) && near($0.video.minY, 20) } ?? false, "regions follow the layout's origin")
check(FoldRegions.split(wideBounds, fold: FoldGeometry(frame: CGRect(x: 60, y: 0, width: 40, height: 669), isActive: true)) == nil,
      "a fold near the view's edge leaves the overlay alone")
check(FoldRegions.floatingBarSpan(width: 382, fold: FoldGeometry()) == (0, 382), "closed: the mini player spans the width")
check(FoldRegions.floatingBarSpan(width: 951, fold: flatWide) == (495, 951), "open and flat: it stays trailing the fold line")
check(FoldRegions.floatingBarSpan(width: 669, fold: tabletop) == (0, 669), "a fold across: the full width again")

// MARK: Picture placement

let upright = FoldRegions.picture(aspect: 16 / 9, in: CGSize(width: 466, height: 678), covered: 300)
check(near(upright.width, 466) && near(upright.maxY, 378 - (378 - upright.height) / 2), "closed and upright: the video moves up above the controls")
let open = FoldRegions.picture(aspect: 16 / 9, in: wide, covered: 280)
check(near(open, FoldRegions.fit(aspect: 16 / 9, in: wide)), "open: too tall to fit above the controls, so it stays centred")
check(FoldRegions.fit(aspect: 16 / 9, in: .zero) == .zero, "no space, no picture")
check(near(FoldRegions.fit(aspect: 16 / 9, in: CGSize(width: 669, height: 455)).width, 669), "tabletop's top region fits a 16:9 video at full width")

// MARK: Time text

check(TimeText.clock(0) == "0:00" && TimeText.clock(7.9) == "0:07", "seconds round down")
check(TimeText.clock(65) == "1:05" && TimeText.clock(3723) == "1:02:03", "minutes and hours")
check(TimeText.clock(.nan) == "0:00" && TimeText.clock(-4) == "0:00", "bad values read 0:00")
check(TimeText.remaining(7, of: 12) == "−0:05", "time left has a minus sign")
check(TimeText.spoken(12) == "12 seconds" && TimeText.spoken(3900) == "1 hour 5 minutes", "spoken lengths")

// MARK: Every type stays nonisolated

// The app target compiles with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, and so does
// this program. Each line below needs its type to be nonisolated; drop `nonisolated`
// from one and this file stops compiling. Add a line for each new model type.
let offMain = await Task.detached { () -> Bool in
    var q = PlaybackQueue()
    q.start("a1", then: ["a2"])
    var r = ResumePositions()
    r.record("a1", at: 30, duration: 60)
    let p = UpNextPolicy()
    let state: UpNextState = p.card(position: 55, duration: 60, hasNext: true, dismissed: false)
    let f = FoldGeometry(candidates: [(bookFold, true)], in: wide)
    let split = FoldRegions.split(wideBounds, fold: f)
    let c = Catalog(shows: [])
    let s = Show(id: "s", title: "", host: "", summary: "", symbol: "", colors: [], episodes: [])
    let e = Episode(id: "e", number: 1, title: "", summary: "", duration: 1, media: "e.mp4", published: "2026-10-01")
    return q.next == "a2" && r.resume("a1") == 30 && state.isVisible && split != nil
        && c.episodes.isEmpty && s.episodes.isEmpty && e.bundledFile != nil && TimeText.clock(1) == "0:01"
}.value
check(offMain, "the model works off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
