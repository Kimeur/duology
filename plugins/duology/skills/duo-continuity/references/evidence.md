# Evidence: what we measured

Every *measured* line in this skill comes from the runs below. Read the limits before you rely on them.

- **When:** 16 October 2026 for the probes, 17 October 2026 for the UI tests.
- **Tools:** Xcode 27.1 (27A9275), the iOS 27.1 simulator runtime (24A94425). The probes ran on an "iPhone Duo" simulator that was open and held wide (951 × 669 pt). The UI tests ran on a new iPhone Duo simulator, which starts closed. We never changed a pose.
- **Device:** none. Nothing here has run on a real iPhone Duo.

## The method, and its limits

Xcode 27.1 can't fold the simulator from code (see [testing.md](testing.md)). So each SwiftUI probe flips a `wide` flag on a timer. The flag switches `if`/`else` branches, `AnyLayout` axes, grid column counts and a frame width, and it overrides `horizontalSizeClass` for the whole tree. That is the code path a fold takes through your views. The UIKit probe does the same with `traitOverrides.horizontalSizeClass`.

What the flip does not do: move content to the other display, resize the window, change the scene phase, or touch the software keyboard. Those parts of a real fold are *unverified* here. Run the Device Hub pass in [testing.md](testing.md) for them.

## Does a fold relaunch the app?

*Unverified.* Apple says the app resizes when someone opens or closes the phone, and compares it to resizing in iPhone Mirroring ([Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)). We have not measured a real fold.

A size log from this project's device-facts work looks like a fold but isn't one. Its compact line, in full:

```text
PROBE change size=466x678pt h=compact v=regular scale=3.0 safe(t0 l0 b0 r0) | scene screen bounds=(669.0, 951.0) native=(2007.0, 2853.0) scale=3.0 nativeScale=3.0 maxFPS=60 window=(466.0, 678.0) traits h=1 v=2
```

The screen is still the inner one (2007 × 2853 px native), and the probe logged no hinge change. So the phone never closed. For comparison, the same probe on our closed simulator logged the outer screen and the hinge:

```text
PROBE appear size=466x678pt h=compact v=regular scale=3.0 safe(t0 l0 b0 r0) | scene screen bounds=(466.0, 678.0) native=(1398.0, 2034.0) scale=3.0 nativeScale=3.0 maxFPS=60 window=(466.0, 678.0) traits h=1 v=2
PROBE hinge: closed angle=0 | scene screen bounds=(466.0, 678.0) native=(1398.0, 2034.0) scale=3.0 nativeScale=3.0 maxFPS=60 window=(466.0, 678.0) traits h=1 v=2
```

To settle it, run a probe that logs the root view's `onAppear`, the window scene's `screen.nativeBounds` and every `onHingeChange` (the probe in [device-facts.md](https://github.com/Kimeur/duology/blob/main/reference/device-facts.md#how-we-measured) plus a `nativeBounds` print). Press Closed and then Open in Device Hub, and keep the full lines. A fold that keeps the app alive shows one appear line, then size changes whose native screen size switches between 2007 × 2853 and 1398 × 2034 px, with a hinge line at each step.

## Results

| What we tested | Result |
|---|---|
| A child view inside `if wide { HStack } else { VStack }` | New `@State` on every flip, `onAppear` again, old `.task` cancelled |
| The same child inside `AnyLayout` | One `onAppear` for the whole run, `.task` never cancelled |
| `@SceneStorage("probe.note")` written in one branch, read in the other | The other branch read the written value |
| `@FocusState` on a field with stable identity | Focus kept through two flips (to compact and back) |
| `@FocusState` on a field inside an `if`/`else` | Focus became `nil` after the flip |
| A model-owned `AVPlayer` shown by `VideoPlayer` inside an `if`/`else` | Kept playing through every flip; time kept rising |
| `ScrollPosition` by ID (item 150), grid 4 → 1 → 4 columns, width 600 → 300 → 600 pt | `viewID` stayed 150; offset moved to keep item 150 at the top (1784 → 7200 → 1776) |
| `ScrollPosition` by point (y = 1480), same grid | Offset stayed 1480; rows 31 to 33 showed instead of item 150's row |
| `onScrollTargetVisibilityChange` on the ID grid after the column change | Reported no IDs, while `viewID` stayed right |
| `.sheet(isPresented:)` attached inside an `if`/`else` | Sheet closed on the flip; the binding stayed `true` |
| The same sheet attached at the root | Stayed open through two flips |
| `NavigationSplitView` with `horizontalSizeClass` overridden to compact | Collapsed: the sidebar's `onDisappear` ran; the selection stayed; on expand the sidebar `List` came back at the same offset (6158 pt) |
| `scrollPosition(id:)` on a `List` | Didn't scroll it; `ScrollViewReader.scrollTo` did |
| `Self._printChanges()` after a flip | Branch view: `@self, @identity, __count changed.` `AnyLayout` view: `@self changed.` |
| UIKit compositional grid, `traitOverrides.horizontalSizeClass` regular → compact (4 → 2 columns), no restore | Item 74 at the top instead of item 148 |
| Same, scrolling to the saved item inside the trait handler after `layoutIfNeeded()` (an earlier version of probe 4) | Still item 74 once layout finished |
| Same, scrolling in `viewDidLayoutSubviews()` or on the next main-actor turn | Item 148 kept |
| `registerForTraitChanges(_:handler:)` with `UITraitHorizontalSizeClass` | Ran on every override change |
| `UIWindowScene.requestGeometryUpdate(_:errorHandler:)` asking for a rotation, phone open | Failed: "The current windowing mode does not allow for programmatic changes to interface orientation." So no size transition was tested. |

## Raw output, first flip

From probe 1, second run:

```text
CPROBE appear anylayout token=A1C3
CPROBE appear branch token=F52A
CPROBE before wide=true focus=nil byID.viewID=150 ... byID.y=1784 byPoint.y=1480 byPoint.visible=124...135 player=playing t=2.9
CPROBE FLIP close -> wide=false
CPROBE scenestorage narrow reads 'saved-in-wide'
CPROBE appear branch token=4504
CPROBE disappear branch token=F52A
CPROBE task-cancelled branch token=F52A
CPROBE after-close wide=false focus=nil byID.viewID=150 ... byID.y=7200 byPoint.y=1480 byPoint.visible=31...33 player=playing t=4.4
```

The `anylayout` leaf never logs again: no new token, no `disappear`, no `task-cancelled`.

## UI tests on the closed Duo simulator

We built the harness, `ReaderRoot` and `ContinuityUITests` from [testing.md](testing.md) unchanged into an app target (Swift 6, MainActor default isolation, portrait and both landscapes allowed). The new simulator was closed: the probe above logged `hinge: closed angle=0`.

| What we ran | Result |
|---|---|
| `testStateSurvivesSizeClassFlip` | Passed. The flip button and the labels at 2% opacity worked. |
| `testStateSurvivesRealFold` without `DUO_MANUAL_FOLD` | Skipped |
| `XCUIDevice.shared.orientation` set to landscape left, portrait, landscape right, portrait, waiting 8 s each | The orientation read back as set each time. The window-size label never changed. |
| Size readers on a `Text` root, in a 466 × 678 pt window with 84 pt right and 34 pt bottom safe-area insets | On the content: 108 × 20. After `.ignoresSafeArea()`: 382 × 644. Inside it (the harness): 466 × 678. |

An earlier version of the automatic test also rotated and asserted a resize. In a review run on another closed Duo simulator it failed with "rotation did not resize the app", so rotation moved to the manual test. `duo-testing` measured the same on the closed Duo.

## Build and run a probe

Each probe is one file. Build it as an app bundle, sign it ad hoc, install it on the booted simulator, and read the console:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer
mkdir -p CProbe.app
xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios27.1-simulator \
  -parse-as-library -o CProbe.app/CProbe main.swift
# Add an Info.plist with CFBundleExecutable CProbe, a bundle identifier,
# CFBundlePackageType APPL, MinimumOSVersion 27.1 and UILaunchScreen.
codesign -s - --force CProbe.app
xcrun simctl install booted CProbe.app
xcrun simctl launch --console-pty --terminate-running-process booted <bundle-id> | grep CPROBE
```

Each probe exits on its own when its script ends.

## Probe 1: identity, scene storage, focus, playback, scroll, sheets

```swift
import SwiftUI
import AVKit
import Observation

// Continuity probe. Flips a "wide" flag (and the horizontal size class with it) on a
// script, the same code path a fold or unfold takes, and logs what survives.
// Every log line starts with CPROBE so it is easy to grep.

@MainActor
func say(_ message: String) {
    print("CPROBE " + message)
    fflush(stdout)
}

@main
struct ContinuityProbeApp: App {
    @State private var lab = Lab()
    var body: some Scene {
        WindowGroup {
            Bench(lab: lab)
        }
    }
}

enum Field: Hashable { case stable, branch }

@MainActor @Observable
final class Lab {
    var wide = true
    var positionByID = ScrollPosition(idType: Int.self)
    var positionByPoint = ScrollPosition(idType: Int.self)
    var visibleByID: [Int] = []
    var visibleByPoint: [Int] = []
    var offsetByID: Double = 0
    var offsetByPoint: Double = 0
    var draft = "typed text"
    var sheetInBranch = false
    var sheetAtRoot = false
    let player: AVPlayer

    init() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tone.wav")
        try? Lab.makeWav().write(to: url)
        player = AVPlayer(url: url)
        player.isMuted = true
    }

    var playerState: String {
        let status: String
        switch player.timeControlStatus {
        case .playing: status = "playing"
        case .paused: status = "paused"
        case .waitingToPlayAtSpecifiedRate: status = "waiting"
        @unknown default: status = "unknown"
        }
        return "player=\(status) t=\(String(format: "%.1f", player.currentTime().seconds))"
    }

    // 30 s of a quiet 440 Hz tone, 8 kHz mono 16-bit PCM.
    static func makeWav() -> Data {
        let rate = 8000, seconds = 30, count = rate * seconds
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + count * 2))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(count * 2))
        for i in 0..<count {
            let s = Int16(sin(Double(i) * 2 * .pi * 440 / Double(rate)) * 2000)
            u16(UInt16(bitPattern: s))
        }
        return d
    }
}

// A leaf that reports its own lifetime.
struct Leaf: View {
    let label: String
    @State private var token = String(UUID().uuidString.prefix(4))
    var body: some View {
        Text("\(label) \(token)")
            .onAppear { say("appear \(label) token=\(token)") }
            .onDisappear { say("disappear \(label) token=\(token)") }
            .task {
                do { try await Task.sleep(for: .seconds(600)) } catch {
                    say("task-cancelled \(label) token=\(token)")
                }
            }
    }
}

struct StorageLeaf: View {
    let label: String
    @SceneStorage("probe.note") private var note = ""
    var body: some View {
        Text("note: \(note)")
            .onAppear {
                say("scenestorage \(label) reads '\(note)'")
                if note.isEmpty { note = "saved-in-\(label)" }
            }
    }
}

struct SheetBody: View {
    let label: String
    var body: some View {
        Text("sheet \(label)")
            .onAppear { say("sheet-appear \(label)") }
            .onDisappear { say("sheet-disappear \(label)") }
    }
}

struct Grid: View {
    @Binding var position: ScrollPosition
    @Binding var visible: [Int]
    @Binding var offset: Double
    let columns: Int
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
                ForEach(0..<300, id: \.self) { i in
                    Text("\(i)").frame(height: 40)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($position)
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.5) { ids in
            visible = ids.sorted()
        }
        .onScrollGeometryChange(for: Double.self, of: { Double($0.contentOffset.y) }) { _, y in
            offset = y
        }
        .frame(height: 160)
    }
}

struct Bench: View {
    @Bindable var lab: Lab
    @FocusState private var focus: Field?

    var body: some View {
        let layout = lab.wide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        VStack(spacing: 4) {
            // 1. if/else branch: the leaf moves to a new structural position.
            if lab.wide {
                HStack { Leaf(label: "branch"); StorageLeaf(label: "wide") }
            } else {
                VStack { Leaf(label: "branch"); StorageLeaf(label: "narrow") }
            }
            // 2. AnyLayout: same leaf, new layout.
            layout {
                Leaf(label: "anylayout")
                TextField("stable", text: $lab.draft).focused($focus, equals: .stable)
            }
            // 3. A text field that lives inside a branch.
            if lab.wide {
                TextField("branch-wide", text: $lab.draft).focused($focus, equals: .branch)
                    .sheet(isPresented: $lab.sheetInBranch) { SheetBody(label: "in-branch") }
            } else {
                TextField("branch-narrow", text: $lab.draft).focused($focus, equals: .branch)
            }
            // 4. Video player shown in both branches, player owned by the model.
            if lab.wide {
                VideoPlayer(player: lab.player).frame(width: 200, height: 60)
            } else {
                VideoPlayer(player: lab.player).frame(width: 120, height: 60)
            }
            // 5. Scroll position by ID versus by point; columns change with width.
            HStack {
                Grid(position: $lab.positionByID, visible: $lab.visibleByID, offset: $lab.offsetByID, columns: lab.wide ? 4 : 1)
                Grid(position: $lab.positionByPoint, visible: $lab.visibleByPoint, offset: $lab.offsetByPoint, columns: lab.wide ? 4 : 1)
            }
            .frame(width: lab.wide ? 600 : 300)
        }
        .environment(\.horizontalSizeClass, lab.wide ? .regular : .compact)
        .sheet(isPresented: $lab.sheetAtRoot) { SheetBody(label: "at-root") }
        .task { await script() }
    }

    func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func report(_ tag: String) {
        let byID = lab.positionByID.viewID(type: Int.self).map(String.init) ?? "nil"
        say("\(tag) wide=\(lab.wide) focus=\(String(describing: focus)) "
            + "byID.viewID=\(byID) byID.visible=\(lab.visibleByID.first ?? -1)...\(lab.visibleByID.last ?? -1) "
            + "byID.y=\(Int(lab.offsetByID)) byPoint.y=\(Int(lab.offsetByPoint)) "
            + "byPoint.visible=\(lab.visibleByPoint.first ?? -1)...\(lab.visibleByPoint.last ?? -1) "
            + "\(lab.playerState) sheetInBranch=\(lab.sheetInBranch) sheetAtRoot=\(lab.sheetAtRoot)")
    }

    func flip(_ tag: String) async {
        lab.wide.toggle()
        say("FLIP \(tag) -> wide=\(lab.wide)")
        await pause(1.5)
        report("after-\(tag)")
    }

    func script() async {
        say("start")
        lab.player.play()
        await pause(2)
        // Item 150 sits in row 37 with 4 columns (37 * 40 pt = 1480 pt).
        lab.positionByID.scrollTo(id: 150, anchor: .top)
        lab.positionByPoint.scrollTo(y: 1480)
        await pause(1.5)
        report("before")
        await flip("close")
        await flip("open")

        // Focus held by a field whose identity is stable.
        focus = .stable
        await pause(1)
        report("focus-stable-set")
        await flip("close")
        await flip("open")

        // Focus held by a field inside an if/else branch.
        focus = .branch
        await pause(1)
        report("focus-branch-set")
        await flip("close")
        await flip("open")
        focus = nil

        // Sheet attached inside a branch, then at the root.
        lab.sheetInBranch = true
        await pause(1.5)
        report("sheet-branch-shown")
        await flip("close")
        lab.sheetInBranch = false
        await pause(1)
        await flip("open")
        lab.sheetAtRoot = true
        await pause(1.5)
        report("sheet-root-shown")
        await flip("close")
        await flip("open")
        lab.sheetAtRoot = false
        await pause(1)
        say("done")
        exit(0)
    }
}
```

## Probe 2: NavigationSplitView collapse and List scrolling

```swift
import SwiftUI
import Observation

// Probe 2: does a horizontalSizeClass environment override collapse a
// NavigationSplitView, and does a List keep its scroll position and selection
// when the split view collapses and expands?

@MainActor
func say(_ message: String) {
    print("NPROBE " + message)
    fflush(stdout)
}

@main
struct SplitProbeApp: App {
    @State private var lab = SplitLab()
    var body: some Scene {
        WindowGroup { SplitBench(lab: lab) }
    }
}

@MainActor @Observable
final class SplitLab {
    var wide = true
    var selection: Int? = nil
    var listY: Double = -1
    var listScrollID: Int? = nil
    var column = NavigationSplitViewColumn.sidebar
    var jump: Int? = nil
}

struct Row: View {
    let i: Int
    var body: some View { Text("Row \(i)") }
}

struct SplitBench: View {
    @Bindable var lab: SplitLab
    @Environment(\.horizontalSizeClass) private var realSize

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $lab.column) {
            ScrollViewReader { proxy in
                List(0..<200, id: \.self, selection: $lab.selection) { i in
                    Row(i: i)
                }
                .scrollPosition(id: $lab.listScrollID)
                .onChange(of: lab.jump) { _, target in
                    if let target { proxy.scrollTo(target, anchor: .top) }
                }
            }
            .onScrollGeometryChange(for: Double.self, of: { Double($0.contentOffset.y) }) { _, y in
                lab.listY = y
            }
            .onAppear { say("sidebar-appear") }
            .onDisappear { say("sidebar-disappear") }
        } detail: {
            Group {
                if let s = lab.selection {
                    Text("Detail \(s)")
                } else {
                    Text("No selection")
                }
            }
            .onAppear { say("detail-appear") }
            .onDisappear { say("detail-disappear") }
        }
        .environment(\.horizontalSizeClass, lab.wide ? .regular : .compact)
        .task { await script() }
    }

    func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func report(_ tag: String) {
        say("\(tag) wide=\(lab.wide) real=\(String(describing: realSize)) selection=\(String(describing: lab.selection)) "
            + "column=\(String(describing: lab.column)) listY=\(Int(lab.listY)) listScrollID=\(String(describing: lab.listScrollID))")
    }

    func script() async {
        say("start")
        await pause(2)
        report("initial")
        lab.listScrollID = 120
        await pause(1.5)
        report("scrolled")
        lab.jump = 120
        await pause(1.5)
        report("reader-scrolled")
        lab.selection = 120
        await pause(1.5)
        report("selected")
        lab.wide = false
        await pause(2)
        report("after-close")
        lab.wide = true
        await pause(2)
        report("after-open")
        exit(0)
    }
}
```

## Probe 3: `_printChanges()` output

```swift
import SwiftUI
import Observation

// Probe 3: what Self._printChanges() prints for a view inside an if/else branch
// and for the same view inside AnyLayout when the size class flips.

@main
struct PrintProbeApp: App {
    @State private var lab = PrintLab()
    var body: some Scene { WindowGroup { PrintBench(lab: lab) } }
}

@MainActor @Observable
final class PrintLab { var wide = true }

struct BranchLeaf: View {
    @State private var count = 0
    var body: some View {
        let _ = Self._printChanges()
        Text("branch \(count)")
    }
}

struct LayoutLeaf: View {
    @State private var count = 0
    var body: some View {
        let _ = Self._printChanges()
        Text("layout \(count)")
    }
}

struct PrintBench: View {
    @Bindable var lab: PrintLab
    var body: some View {
        let layout = lab.wide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        VStack {
            if lab.wide { HStack { BranchLeaf() } } else { VStack { BranchLeaf() } }
            layout { LayoutLeaf(); Text("x") }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            print("PPROBE flip 1"); fflush(stdout)
            lab.wide.toggle()
            try? await Task.sleep(for: .seconds(1.5))
            print("PPROBE flip 2"); fflush(stdout)
            lab.wide.toggle()
            try? await Task.sleep(for: .seconds(1.5))
            print("PPROBE done"); fflush(stdout)
            exit(0)
        }
    }
}
```

## Probe 4: UIKit trait change, anchor restore, rotation request

Pass the restore mode as the last launch argument: `none`, `layout` (restore in `viewDidLayoutSubviews()`) or `async` (restore on the next main-actor turn). Build it without `-parse-as-library`, because it calls `UIApplicationMain` at top level.

```swift
import UIKit

// Probe 4 (UIKit): does a real interface rotation call viewWillTransition and the
// trait handler, and does the anchor pattern keep the top item? Also flips
// traitOverrides.horizontalSizeClass to see the trait handler and the layout react.

@MainActor func say(_ s: String) { print("UPROBE " + s); fflush(stdout) }

final class FeedViewController: UICollectionViewController {
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var anchor: IndexPath?

    init() { super.init(collectionViewLayout: Self.makeLayout()) }
    required init?(coder: NSCoder) { fatalError() }

    static func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let compact = environment.traitCollection.horizontalSizeClass == .compact
            let columns = compact ? 2 : 4
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / CGFloat(columns)), heightDimension: .absolute(120)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(120)),
                repeatingSubitem: item, count: columns)
            return NSCollectionLayoutSection(group: group)
        }
    }

    static var mode: String = ProcessInfo.processInfo.arguments.last ?? ""
    private var pendingAnchor: IndexPath?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let anchor = pendingAnchor else { return }
        pendingAnchor = nil
        collectionView.scrollToItem(at: anchor, at: .top, animated: false)
        say("layout restored top=\(topItem)")
    }
    var topItem: Int { collectionView.indexPathsForVisibleItems.min()?.item ?? -1 }

    override func viewDidLoad() {
        super.viewDidLoad()
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, n in
            var c = cell.defaultContentConfiguration(); c.text = "Item \(n)"; cell.contentConfiguration = c
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { v, p, n in
            v.dequeueConfiguredReusableCell(using: cell, for: p, item: n)
        }
        var snap = NSDiffableDataSourceSnapshot<Int, Int>()
        snap.appendSections([0]); snap.appendItems(Array(0..<300))
        dataSource.apply(snap)
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, previous: UITraitCollection) in
            let top = self.collectionView.indexPathsForVisibleItems.min()
            say("trait-handler h \(previous.horizontalSizeClass.rawValue) -> \(self.traitCollection.horizontalSizeClass.rawValue) top-at-handler=\(top?.item ?? -1)")
            guard let top else { return }
            if Self.mode == "layout" {
                self.pendingAnchor = top                  // restored in viewDidLayoutSubviews
            } else if Self.mode == "async" {
                Task { @MainActor in
                    self.collectionView.scrollToItem(at: top, at: .top, animated: false)
                    say("async restored top=\(self.topItem)")
                }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        anchor = collectionView.indexPathsForVisibleItems.min()
        say("viewWillTransition to \(Int(size.width))x\(Int(size.height)) anchor=\(anchor?.item ?? -1)")
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, let anchor = self.anchor else { return }
            self.collectionView.scrollToItem(at: anchor, at: .top, animated: false)
            say("restored anchor=\(anchor.item) top=\(self.topItem)")
        }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let feed = FeedViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = feed
        w.makeKeyAndVisible()
        window = w
        Task { await script(ws) }
    }

    func report(_ tag: String) {
        let s = feed.view.bounds.size
        say("\(tag) size=\(Int(s.width))x\(Int(s.height)) h=\(feed.traitCollection.horizontalSizeClass.rawValue) top=\(feed.topItem)")
    }

    func script(_ ws: UIWindowScene) async {
        try? await Task.sleep(for: .seconds(2))
        feed.collectionView.scrollToItem(at: IndexPath(item: 150, section: 0), at: .top, animated: false)
        try? await Task.sleep(for: .seconds(1))
        report("before")
        // 1. Trait override only (no size change).
        feed.traitOverrides.horizontalSizeClass = .compact
        try? await Task.sleep(for: .seconds(1.5))
        report("after-override-compact")
        feed.traitOverrides.horizontalSizeClass = .regular
        try? await Task.sleep(for: .seconds(1.5))
        report("after-override-regular")
        feed.traitOverrides.remove(UITraitHorizontalSizeClass.self)
        try? await Task.sleep(for: .seconds(1))
        // 2. Real rotation request.
        let current = ws.effectiveGeometry.interfaceOrientation
        let target: UIInterfaceOrientationMask = current.isPortrait ? .landscapeRight : .portrait
        say("rotate request from \(current.rawValue)")
        ws.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { error in
            Task { @MainActor in say("rotate error \(error.localizedDescription)") }
        }
        try? await Task.sleep(for: .seconds(2.5))
        report("after-rotate")
        exit(0)
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting s: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: nil, sessionRole: s.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
```
