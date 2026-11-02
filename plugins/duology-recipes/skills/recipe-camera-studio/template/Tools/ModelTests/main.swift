// Model tests. They build __APP_NAME__/Model/*.swift with this file and run on the Mac.
// Run from the project folder: Tools/run-model-tests.sh
import CoreGraphics
import Foundation
import ImageIO

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

// MARK: Layouts in each pose

// The studio screen's size (inside the safe area, no navigation bar) and the fold's frame in
// it, on the iPhone Duo simulator (iOS 27.1), from the studio.state marker of
// testStudioLayoutInThisPose in each pose.
let closedSize = CGSize(width: 382, height: 644)
let wideSize = CGSize(width: 867, height: 635)
let tallSize = CGSize(width: 669, height: 835)
let wideFold = CGRect(x: 455.5, y: 0, width: 40, height: 669)
let tallFold = CGRect(x: 0, y: 373.5, width: 669, height: 40)

let closed = StudioLayout(size: closedSize, fold: FoldGeometry())
check(closed.mode == .floating && closed.edge == .bottom, "closed: the preview fills the screen, the controls float along the bottom")
check(closed.preview.size == closedSize && near(closed.controls.maxY, closedSize.height)
      && near(closed.controls.height, StudioLayout.controlsThickness), "closed: a \(Int(StudioLayout.controlsThickness)) pt bar at the bottom edge")

let flat = StudioLayout(size: wideSize, fold: FoldGeometry(frame: wideFold, isActive: false))
check(flat.mode == .floating && flat.edge == .trailing, "open and flat: the controls float along the trailing edge")
check(!flat.controls.intersects(wideFold), "open and flat: the controls stay off the fold, though the preview may cross it")

let book = StudioLayout(size: wideSize, fold: FoldGeometry(frame: wideFold, isActive: true))
check(book.mode == .foldLeftRight && book.edge == .trailing, "book: the preview on the left page, the controls on the right")
check(near(book.preview.maxX, wideFold.minX) && near(book.controls.minX, wideFold.maxX),
      "book: the pages meet at the fold's frame, not at half the width")
check(!book.controls.intersects(wideFold) && !book.preview.intersects(wideFold), "book: nothing on the fold")

let tallFlat = StudioLayout(size: tallSize, fold: FoldGeometry(frame: tallFold, isActive: false))
check(tallFlat.mode == .floating && tallFlat.edge == .bottom && !tallFlat.controls.intersects(tallFold),
      "open, held tall and flat: controls float along the bottom, off the fold")
let tabletop = StudioLayout(size: tallSize, fold: FoldGeometry(frame: tallFold, isActive: true))
check(tabletop.mode == .foldTopBottom && tabletop.edge == .bottom, "tabletop: the preview above the fold, the controls below it")
check(near(tabletop.preview.maxY, tallFold.minY) && near(tabletop.controls.minY, tallFold.maxY),
      "tabletop: the controls start below the fold's frame, on the half that rests on the table")
check(tabletop.controls.height >= 88 && book.controls.width >= 88, "folded, the controls' region has room for the 76 pt shutter")

let sideways = StudioLayout(size: CGSize(width: closedSize.height, height: closedSize.width), fold: FoldGeometry())
check(sideways.mode == .floating && sideways.edge == .trailing, "closed and held sideways: the controls float along the trailing edge")
let splitView = StudioLayout(size: CGSize(width: 420, height: 553),
                             fold: FoldGeometry(frame: CGRect(x: 380, y: -82, width: 40, height: 669), isActive: true))
check(splitView.mode == .floating, "a fold at the window's edge (Split View) is ignored")
check(StudioLayout(size: closedSize, fold: FoldGeometry(), controlsThickness: 900).controls.height <= closedSize.width / 2,
      "the controls never take more than half the short side, whatever the text size")

let fromRegions = FoldGeometry(candidates: [(CGRect(x: -40, y: 0, width: 40, height: 100), true), (wideFold, false)], in: wideSize)
check(fromRegions.frame == wideFold && !fromRegions.isActive, "a fold region outside the view is ignored")

// MARK: The self-timer and the clock

check(TimerSetting.off.next == .three && TimerSetting.three.next == .ten && TimerSetting.ten.next == .off,
      "the timer cycles off, 3 s, 10 s")
var countdown = Countdown(seconds: 3)
check(countdown.left == 3 && !countdown.isDone, "a 3-second countdown starts at 3")
check(!countdown.tick() && countdown.left == 2 && !countdown.tick() && countdown.left == 1, "it counts down one second at a time")
check(countdown.tick() && countdown.isDone, "and fires once, at zero")
check(!countdown.tick() && countdown.left == 0, "never again after that")
check(Countdown(seconds: 0).total == 1, "a countdown lasts at least a second")

check(RecordingClock.text(0) == "0:00" && RecordingClock.text(7.9) == "0:07" && RecordingClock.text(65) == "1:05"
      && RecordingClock.text(3600) == "1:00:00" && RecordingClock.text(-3) == "0:00", "the recording time reads 0:07, 1:05, 1:00:00")
check(RecordingClock.spoken(65) == "1 minute 5 seconds" && RecordingClock.spoken(1) == "1 second" && RecordingClock.spoken(120) == "2 minutes",
      "and VoiceOver hears it in words")

check(CameraAccess.denied.opensSettings && !CameraAccess.restricted.opensSettings, "only a denied camera offers Settings")
check(CameraAccess.authorized.message == nil && CameraAccess.noCamera.message != nil && CameraAccess.denied.message != nil,
      "every state that hides the preview says why")

// MARK: The gallery's index

let start = Date(timeIntervalSinceReferenceDate: 820_000_000)
var library = CaptureLibrary()
let photo = Capture(id: "p1", kind: .photo, created: start)
let video = Capture(id: "v1", kind: .video, created: start.addingTimeInterval(10), duration: 4.2, isStandIn: true)
library.add(photo)
library.add(video)
check(library.sorted.map(\.id) == ["v1", "p1"] && library.latest == video, "the gallery shows the newest first")
check(photo.fileName == "p1.jpg" && photo.posterName == "p1.jpg" && video.fileName == "v1.mov" && video.posterName == "v1-poster.jpg",
      "a photo is its own poster; a video keeps one beside it")
check(video.spokenTitle == "Video, 4 seconds, stand-in camera" && photo.spokenTitle == "Photo", "VoiceOver names each capture")
library.add(Capture(id: "p1", kind: .photo, created: start))
check(library.captures.count == 2, "adding the same capture twice keeps one")
check(library.remove("v1") == ["v1.mov", "v1-poster.jpg"] && library.captures.map(\.id) == ["p1"], "delete returns every file to remove")
check(library.remove("nope").isEmpty, "deleting a missing capture removes nothing")
library.add(video)
library.keepOnly(existing: ["p1.jpg", "Captures.json"])
check(library.captures.map(\.id) == ["p1"], "an entry whose file is gone is dropped")
let tie = CaptureLibrary(captures: [Capture(id: "b", kind: .photo, created: start), Capture(id: "a", kind: .photo, created: start)])
check(tie.sorted.map(\.id) == ["a", "b"], "captures made at the same moment keep a fixed order")

let saved = try library.encoded()
check((try? CaptureLibrary.decode(saved)) == library, "the index survives a save and a load")
// An index written by this version must load in the next one: keep this format readable.
let written = #"{"captures":[{"created":"2026-11-02T10:00:00Z","duration":3.5,"id":"v9","isStandIn":false,"kind":"video"}],"version":1}"#
check((try? CaptureLibrary.decode(Data(written.utf8)))?.capture("v9")?.duration == 3.5, "an index in the current format loads")
check((try? CaptureLibrary.decode(Data(#"{"captures":[]}"#.utf8)))?.version == CaptureLibrary.currentVersion, "an index without a version loads")

// MARK: The stand-in camera's picture

let size = AppFacts.standInSize
let swatches = StandInFrame.swatches(in: size, time: 0)
check(swatches.count == StandInFrame.barColors.count + 3, "seven bars, the band, the dot and the corner tag")
check(swatches.prefix(7).allSatisfy { $0.rect.minY == 0 } && near(swatches[6].rect.maxX, size.width), "the bars span the top, edge to edge")
let dotAt = { (time: Double) in StandInFrame.swatches(in: size, time: time)[8].rect.minX }
check(dotAt(0) < dotAt(0.5) && dotAt(0.5) < dotAt(1.5) && near(dotAt(0), dotAt(StandInFrame.period)),
      "the dot moves across and comes back every \(Int(StandInFrame.period)) s, so a frame shows it is live")
check(StandInFrame.swatches(in: .zero, time: 0).isEmpty, "no space, nothing to draw")
check(StandInFrame.fitted(CGSize(width: 4, height: 3), in: CGSize(width: 800, height: 300)) == CGRect(x: 200, y: 0, width: 400, height: 300),
      "the picture is letterboxed to 4:3, centred")

if let image = StandInFrame.render(size: size, time: 0) {
    check(image.width == 1200 && image.height == 900, "a stand-in photo is 1200 × 900")
    let pixel = { (x: Int, y: Int) -> (Int, Int, Int) in
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        let p = context.data!.assumingMemoryBound(to: UInt8.self)
        return (Int(p[0]), Int(p[1]), Int(p[2]))
    }
    let left = pixel(130, 300), right = pixel(1110, 300)
    check(abs(left.0 - 191) < 3 && abs(left.2 - 191) < 3, "the leftmost bar is 75 % grey \(left), the right way up and round")
    check(right.0 < 3 && abs(right.2 - 191) < 3, "the rightmost bar is 75 % blue \(right)")
    check(pixel(60, 60) == (255, 255, 255) && pixel(1140, 60) != (255, 255, 255), "the corner tag is top left")
    if let jpeg = StandInFrame.jpeg(image), let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
       let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
        check(jpeg.starts(with: [0xFF, 0xD8]) && properties[kCGImagePropertyPixelWidth] as? Int == 1200,
              "it saves as a 1200-pixel JPEG")
        check(properties[kCGImagePropertyHasAlpha] as? Bool != true, "with no alpha channel")
    } else {
        check(false, "the stand-in photo encodes as JPEG")
    }
} else {
    check(false, "the stand-in frame renders")
}

// MARK: Privacy: nothing leaves the device

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
    ("URLSession", "networking"), ("URLRequest", "networking"), ("NWConnection", "networking"), ("import Network", "networking"),
    ("WKWebView", "a web view"), ("import WebKit", "a web view"),
    ("ASIdentifierManager", "the advertising identifier"), ("import AdSupport", "advertising"),
    ("AppTrackingTransparency", "tracking"), ("identifierForVendor", "a device identifier"),
    ("import CloudKit", "photos leaving the device"), ("PHPhotoLibrary", "reading the photo library"),
    ("import CoreLocation", "location in photos"),
]
for (token, why) in forbidden {
    let hits = sources.filter { $0.code.contains(token) }.map(\.file)
    check(hits.isEmpty, "no \(token) (\(why))\(hits.isEmpty ? "" : " in \(hits)")")
}
let urlLiterals = sources.filter { $0.code.contains("http://") || $0.code.contains("https://") }.map(\.file)
check(urlLiterals.isEmpty, "no web address in the app's code\(urlLiterals.isEmpty ? "" : " (\(urlLiterals))")")

// Required-reason APIs (Apple's list): none used, so the manifest declares none. The gallery
// keeps its own dates in its index instead of reading file dates.
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
    check((manifest["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true, "privacy manifest: no required-reason API, matching the sources")
} else {
    check(false, "__APP_NAME__/PrivacyInfo.xcprivacy can be read (run from the project folder)")
}

// Usage strings: without them the app crashes the first time it asks.
let project = (try? String(contentsOf: URL(fileURLWithPath: "__APP_NAME__.xcodeproj/project.pbxproj"), encoding: .utf8)) ?? ""
for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"] {
    check(project.components(separatedBy: "INFOPLIST_KEY_\(key) = ").count == 3, "\(key) is set for Debug and Release")
}
check(!project.contains("NSPhotoLibraryUsageDescription"), "no full photo library access asked for: the app only adds, through Share")

// MARK: Every type stays nonisolated

// The app target compiles with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, and so does this
// program. Each line below needs its type to be nonisolated; drop `nonisolated` from one
// and this file stops compiling. Add a line for each new model type.
let offMain = await Task.detached { () -> Bool in
    let fold = FoldGeometry(candidates: [(wideFold, true)], in: wideSize)                // FoldGeometry
    let layout = StudioLayout(size: wideSize, fold: fold)                               // StudioLayout
    let mode: StudioLayout.Mode = layout.mode                                           // Mode
    let edge: StudioLayout.ControlsEdge = layout.edge                                   // ControlsEdge
    let capture: CaptureMode = .video                                                   // CaptureMode
    let timer: TimerSetting = .three                                                    // TimerSetting
    var countdown = Countdown(seconds: timer.rawValue)                                  // Countdown
    let clock = RecordingClock.text(5)                                                  // RecordingClock
    let access: CameraAccess = .noCamera                                                // CameraAccess
    var library = CaptureLibrary()                                                      // CaptureLibrary
    library.add(Capture(kind: Capture.Kind.photo))                                      // Capture, Kind
    let swatch: StandInFrame.Swatch? = StandInFrame.swatches(in: AppFacts.standInSize, time: 1).first  // StandInFrame, Swatch, AppFacts
    return mode == .foldLeftRight && edge == .trailing && capture == .video && !countdown.tick()
        && clock == "0:05" && access.message != nil && library.captures.count == 1 && swatch != nil
}.value
check(offMain, "the model works off the main actor")

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
