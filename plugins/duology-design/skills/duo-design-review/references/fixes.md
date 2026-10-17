# Fixes for each rule

Code to quote in the **Fix** line of a finding. Every block typechecks against the iOS 27.1 simulator SDK in Xcode 27.1, in Swift 5 and Swift 6 mode, with deployment targets iOS 27.1 and iOS 26.0. Names such as `GameBoard`, `Artwork`, `ItemList` or `TransportControls` stand for the app's own views.

APIs newer than the app's deployment target sit behind `@available` or `if #available`. Reserved regions and `ArrangementView` are iOS 27.1. `topBarPinnedTrailing` and `visibilityPriority(_:)` are iOS 27.0. Every API is listed with its doc link in [`reference/api-index.md`](../../../../../reference/api-index.md).

## R1 No letterboxing

First, build with Xcode 27.1. Apps built with older SDKs don't fill the display ([prepare page](https://developer.apple.com/iphone-duo/prepare/)). Then remove fixed root sizes. A game that must keep its shape fills the rest with artwork ([HIG, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Best-practices)).

```swift
import SwiftUI

// Before: a fixed, iPhone-sized canvas. On iPhone Duo it sits in the
// middle of the inner display with empty bands around it.
struct FixedBoardScreen: View {
    var body: some View {
        GameBoard().frame(width: 390, height: 844)
    }
}

// After: the board fills the window. When a game must keep its own shape,
// fill the leftover space with artwork, never with plain bars.
struct AdaptiveBoardScreen: View {
    /// The game's own shape, width / height. Not a device ratio.
    var boardAspectRatio: CGFloat = 3 / 2
    var keepsBoardShape = false

    var body: some View {
        if keepsBoardShape {
            ZStack {
                GameBackdrop().ignoresSafeArea()
                GameBoard().aspectRatio(boardAspectRatio, contentMode: .fit)
            }
        } else {
            GameBoard().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
```

For hero images and backgrounds that should run under a vertical bar, use [`backgroundExtensionEffect()`](https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect()) in SwiftUI or [`UIBackgroundExtensionView`](https://developer.apple.com/documentation/uikit/uibackgroundextensionview) in UIKit ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). For a cropped subject, choose fill or fit from the view's current shape, or set a focal point ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

## R2 State survives fold and unfold

Keep the same views alive when the layout changes, and keep state outside views that come and go. For a list and its detail, use one [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview) for every size, with the selection stored above it. Don't build list-detail from stacks: closed, they pile the list on top of the detail. Full recipe: `duo-patterns`, [list-detail](../../duo-patterns/references/list-detail.md).

```swift
import SwiftUI

struct LibraryScreen: View {
    // The selection lives above the split view, in scene storage, so fold,
    // unfold and a relaunch by the system all keep it.
    @SceneStorage("library.selectedID") private var selectedID: String?

    var body: some View {
        // One container for every size. Closed, it collapses to one stack:
        // the list, then the reader. Open, it shows both side by side.
        // Swapping in another screen on a size class change would rebuild
        // the views and reset their state.
        NavigationSplitView {
            // ItemList is a List(selection: $selectedID).
            ItemList(selectedID: $selectedID)
        } detail: {
            Reader(itemID: selectedID)
        }
    }
}
```

For two views that must both stay visible at every size, such as a player and its controls, use [`AnyLayout`](https://developer.apple.com/documentation/swiftui/anylayout). It swaps the layout without rebuilding its children; R12 shows it. Scroll position, playback, focus, navigation paths and UIKit: load `duo-continuity`.

## R3 No size from the main screen

Size from the view and re-read on every change ([prepare page](https://developer.apple.com/iphone-duo/prepare/)). A grid must also follow R5, so this block calls `columnCount` from [R5](#r5-even-grids): copy both. Across the inner display held wide (951 pt), 160 pt columns fit 5; the fold makes it 4.

```swift
import SwiftUI

/// What the grid reads from its own geometry.
nonisolated struct GridSpace: Equatable, Sendable {
    var width: CGFloat = 0
    var foldCrossesGrid = false
}

struct AdaptivePhotos: View {
    @State private var space = GridSpace()

    var body: some View {
        // Size from the view, and re-read it on every change. A fold can
        // resize the app in the middle of a session. The count comes from
        // columnCount in R5, so a grid the fold crosses gets an even count.
        PhotoGrid(columns: columnCount(width: space.width, minColumnWidth: 160,
                                       foldCrossesGrid: space.foldCrossesGrid))
            .onGeometryChange(for: GridSpace.self) { proxy in
                var space = GridSpace(width: proxy.size.width)
                if #available(iOS 27.1, *) {
                    // Count inactive folds too, so the grid doesn't jump on a fold.
                    let folds = proxy.reservedRegions(kind: .division, options: .includeInactive)
                    space.foldCrossesGrid = folds.contains { fold in
                        // A top-to-bottom fold inside the grid's width.
                        fold.frame.height > fold.frame.width
                            && fold.frame.minX > 0 && fold.frame.maxX < proxy.size.width
                    }
                }
                return space
            } action: { newSpace in
                space = newSpace
            }
    }
}
```

UIKit: lay out in `viewDidLayoutSubviews`, take the scale from the trait collection, and create windows from a scene.

```swift
import UIKit

final class CanvasViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Not UIScreen.main.bounds or UIScreen.main.scale (deprecated in iOS 26).
        let size = view.bounds.size
        let scale = traitCollection.displayScale
        layoutCanvas(size: size, scale: scale)
    }

    private func layoutCanvas(size: CGSize, scale: CGFloat) {
        // Lay out from the view's own size.
    }
}

@MainActor
func makeWindow(for scene: UIWindowScene) -> UIWindow {
    // Not UIWindow(frame: UIScreen.main.bounds).
    UIWindow(windowScene: scene)
}
```

If you need the screen at all, read it when needed from `view.window?.windowScene?.screen`; don't store it ([prepare page](https://developer.apple.com/iphone-duo/prepare/)).

## R4 Nothing interactive in the fold

System sheets, alerts, menus, popovers and toolbar buttons already move off the fold. For custom controls, read the active `.division` region and place them beside it ([`reservedRegions(kind:options:layoutDirectionBehavior:)`](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions(kind:options:layoutdirectionbehavior:))). Frames are in the view's own space and mirror for right-to-left by default, so `.position` works in both directions.

```swift
import SwiftUI

/// Where controls may go: the whole view, or the trailing or bottom part
/// while the phone is partly folded.
@available(iOS 27.1, *)
func controlsArea(in proxy: GeometryProxy) -> CGRect {
    let bounds = CGRect(origin: .zero, size: proxy.size)
    // Filter on isActive yourself. Apple's doc and Duology's simulator
    // measurements disagree on what the default query returns.
    guard let fold = proxy.reservedRegions(kind: .division).first(where: { $0.isActive }) else {
        return bounds
    }
    if fold.frame.height >= fold.frame.width {
        // The fold runs top to bottom (held like a book): use the trailing part.
        return CGRect(x: fold.frame.maxX, y: 0,
                      width: bounds.width - fold.frame.maxX, height: bounds.height)
    } else {
        // The fold runs side to side (propped up like a laptop): use the bottom part.
        return CGRect(x: 0, y: fold.frame.maxY,
                      width: bounds.width, height: bounds.height - fold.frame.maxY)
    }
}

@available(iOS 27.1, *)
struct NowPlayingScreen: View {
    var body: some View {
        GeometryReader { proxy in
            let area = controlsArea(in: proxy)
            ZStack {
                Artwork()
                TransportControls()
                    .frame(width: max(0, min(area.width - 32, 360)))
                    .position(x: area.midX, y: area.maxY - 80)
            }
        }
    }
}
```

UIKit: [`UIView.reservedRegions(kind:options:)`](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)). Full displacement recipe: `duo-patterns`, displacement.

## R5 Even grids

Count inactive folds too, so the column count doesn't change when the phone folds ([talk 111463, 7:50](https://developer.apple.com/videos/play/tech-talks/111463/?time=470)). Find out whether a fold crosses the grid with `reservedRegions(kind: .division, options: .includeInactive)` on the grid's own geometry.

```swift
/// How many columns fit, rounded down to an even number when a
/// top-to-bottom fold crosses the grid, active or not.
func columnCount(width: Double, minColumnWidth: Double, foldCrossesGrid: Bool) -> Int {
    let fit = max(1, Int(width / minColumnWidth))
    guard foldCrossesGrid, fit > 1 else { return fit }
    return fit.isMultiple(of: 2) ? fit : fit - 1
}
```

The full grid, with the fold as the middle gap and uneven margins handled: `duo-patterns`, [feed reflow](../../duo-patterns/references/feed-reflow.md).

## R6 Side controls, symbols and titles

Put items in the toolbar of a `NavigationStack` or `NavigationSplitView`, not in a custom bar. Give every item a title and a symbol. Put Close in `cancellationAction` and Done in `topBarPinnedTrailing` so they lead the vertical bar ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [talk 111462, 5:00](https://developer.apple.com/videos/play/tech-talks/111462/?time=300)).

```swift
import SwiftUI

@available(iOS 27.0, *)
struct NoteScreen: View {
    var body: some View {
        NavigationStack {
            NoteBody()
                .navigationTitle("Note")
                .toolbar {
                    // Top of the vertical bar: Close, then the prominent action.
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") {}
                    }
                    ToolbarItem(placement: .topBarPinnedTrailing) {
                        Button("Done", systemImage: "checkmark") {}
                    }
                    // A title and a symbol on every item: the bar shows the
                    // symbol, the overflow menu shows both.
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Share", systemImage: "square.and.arrow.up") {}
                        Button("Delete", systemImage: "trash") {}
                    }
                    .visibilityPriority(.low)
                }
        }
    }
}
```

We ran this layout on the iPhone Duo simulator, closed: Close and Done drew at the top of the vertical bar on the trailing edge, Share and Delete at its bottom. UIKit, overflow menus, compression and opting out: load `duo-navigation`.

## R7 Tabletop and book layouts

[`ArrangementView`](https://developer.apple.com/documentation/swiftui/arrangementview) with the overlay style does the tabletop move for you. Flat or closed, the primary view sits over the secondary. Partly folded, the primary goes to the trailing or bottom part and the secondary to the leading or top part ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)). So make the controls primary and the media secondary.

```swift
import SwiftUI

@available(iOS 27.1, *)
struct PlayerScreen: View {
    var body: some View {
        // Overlay style: controls over the video while flat or closed.
        // Partly folded, the primary (controls) moves to the trailing or
        // bottom part and the secondary (video) to the leading or top part.
        ArrangementView {
            PlayerControls()
        } secondary: {
            VideoSurface()
        }
        .arrangementViewStyle(.overlay)
    }
}
```

Keep navigation and scrolling containers in the right place:

- Never put a `NavigationStack`, `NavigationSplitView` or `TabView` inside an `ArrangementView`. An arrangement lays out its two views but gives no navigation ([HIG, Arrangement views](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Arrangement-views), [talk 111463, 16:15](https://developer.apple.com/videos/play/tech-talks/111463/?time=975)).
- Never put an `ArrangementView` inside a `List` or `ScrollView`. Part of it can end up out of reach ([hub](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [talk 111463, 16:26](https://developer.apple.com/videos/play/tech-talks/111463/?time=986)).
- An arrangement inside a `NavigationSplitView` is unverified. Apple's sources disagree: the HIG says to put split views and tab views around an arrangement, and the hub says to avoid an arrangement inside a navigation split view. A `NavigationStack` or `TabView` around the arrangement fits both.

Two pages in book pose: `duo-patterns`, [two-page](../../duo-patterns/references/two-page.md). UIKit: [`UIArrangementViewController`](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller).

## R8 Split View and PiP work

Split View needs no API. It needs layouts that follow the window, with each side's safe area read on its own ([talk 111461, 7:30](https://developer.apple.com/videos/play/tech-talks/111461/?time=450)). Rules R3 and R6 cover most of it.

For video, the standard player gives Picture in Picture once the audio session and background mode are set ([Adopting Picture in Picture in a standard player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player), [Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)).

```swift
import AVKit
import UIKit

@MainActor
func makePlayer(url: URL) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = AVPlayer(url: url)
    controller.allowsPictureInPicturePlayback = true
    // Let PiP start by itself when the person leaves the app while this
    // inline player is the main content. Set it only for video that is the
    // person's main focus.
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    return controller
}

/// Call once at launch. PiP also needs the "Audio, AirPlay, and Picture in
/// Picture" background mode in the target's capabilities.
func configurePlaybackAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .moviePlayback)
    try session.setActive(true)
}
```

Also implement the delegate's restore callback so the player comes back when PiP stops (see the AVKit article above).

## R9 Camera preview upright

Adopt the rotation coordinator ([talk 111465, 8:03](https://developer.apple.com/videos/play/tech-talks/111465/?time=483), [`AVCaptureDevice.RotationCoordinator`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)). Apply its preview angle to the preview layer's connection, and its capture angle to the output connection before each capture.

```swift
import AVFoundation

/// Keeps the camera preview upright. On iPhone Duo the coordinator also
/// updates when the app moves between the outer and inner display.
@MainActor
final class PreviewRotation {
    private var coordinator: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?

    func attach(device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.coordinator = coordinator
        self.previewLayer = previewLayer
        apply(coordinator.videoRotationAngleForHorizonLevelPreview)
        // The header says this property delivers KVO updates on the main queue.
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            MainActor.assumeIsolated {
                self?.apply(angle)
            }
        }
    }

    private func apply(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}
```

To know which camera faces the person after a fold, use `AVCaptureDeviceDirectionCoordinator`, which lives in AVKit ([Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces)). When a rear camera faces the person, mirror the preview ([talk 111465, 6:17](https://developer.apple.com/videos/play/tech-talks/111465/?time=377)).

## R10 Same features on the outer display

No single API. Map each element that appears only when open to a path when closed:

| Open | Closed |
|---|---|
| Sidebar | Tab bar (`TabView` with `.sidebarAdaptable`; see `duo-navigation`) |
| List beside detail | List, then detail (`NavigationSplitView` collapses on its own) |
| Supporting pane | A sheet or a pushed screen (`duo-patterns`, supporting pane) |
| Extra toolbar items | The same items, overflowing into the system menu |

## R11 Multiple windows

UIKit: give the menu a `UIWindowScene.ActivationAction` with an alternate action, and pass an error handler when you request a scene from code ([talk 111464, 3:38](https://developer.apple.com/videos/play/tech-talks/111464/?time=218)).

```swift
import UIKit

/// "Open in New Window" for a menu. The system shows the alternate action
/// where a new window isn't possible (Apple names iPhone; on iPhone Duo the
/// talk says new windows only open on the inner display).
@MainActor
func openInNewWindowAction(documentID: String, openInPlace: @escaping () -> Void) -> UIAction {
    let inPlace = UIAction(title: "Open", image: UIImage(systemName: "doc")) { _ in
        openInPlace()
    }
    return UIWindowScene.ActivationAction(alternate: inPlace) { _ in
        let activity = NSUserActivity(activityType: "com.example.document.open")
        activity.userInfo = ["id": documentID]
        return UIWindowScene.ActivationConfiguration(userActivity: activity)
    }
}

/// Requests a new window from code and handles the failure, which happens
/// on the outer display.
@MainActor
func requestNewWindow(documentID: String, onFailure: @escaping @MainActor (any Error) -> Void) {
    let activity = NSUserActivity(activityType: "com.example.document.open")
    activity.userInfo = ["id": documentID]
    var request = UISceneSessionActivationRequest()
    request.userActivity = activity
    UIApplication.shared.activateSceneSession(for: request) { error in
        Task { @MainActor in onFailure(error) }
    }
}
```

What we measured on the simulator, closed: the request succeeded and the new window replaced the visible one; the error handler didn't run. So design the outer display path as "replace this window", and make sure the person can get back. SwiftUI's `supportsMultipleWindows` read `true` while closed, so it doesn't tell you whether a new window will appear beside the old one. Real-device behaviour is unverified.

## R12 Smooth transitions

Change the layout of the same views, and animate the change unless Reduce Motion is on.

```swift
import SwiftUI

struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: Content

    var body: some View {
        let layout = widthClass == .regular
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 16))
        // Same views, new positions: the change animates as one move.
        layout { content }
            .animation(reduceMotion ? nil : .smooth, value: widthClass)
    }
}
```

Avoid `.id(...)` values that change with size, and `if`/`else` branches that swap whole view trees on a size class change. Both rebuild the views and reset their state.

## R13 Touch targets of 44 pt

Keep the symbol small if you like; make the hit region at least 44 × 44 pt ([HIG, Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)).

```swift
import SwiftUI

struct IconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                // The symbol can stay small; the hit region can't.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
    }
}
```

## R14 Hardware keyboard

SwiftUI: attach standard shortcuts to the buttons that do those actions, and handle Space in media views ([HIG, Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)).

```swift
import SwiftUI

struct NotesCommands: View {
    @State private var isPlaying = false

    var body: some View {
        VStack {
            Button("New Note", systemImage: "square.and.pencil") {}
                .keyboardShortcut("n", modifiers: .command)
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.cancelAction)
        }
        // Space plays and pauses media with a connected keyboard.
        .focusable()
        .onKeyPress(.space) {
            isPlaying.toggle()
            return .handled
        }
    }
}
```

UIKit: return key commands from the responder that handles them.

```swift
import UIKit

final class EditorViewController: UIViewController {
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "New Note", action: #selector(newNote), input: "n", modifierFlags: .command)]
    }

    @objc private func newNote() {
        // Create the note.
    }
}
```

## R15 Drag and drop

Make items draggable as a `Transferable` value and accept drops of that type. Add a menu path for people who can't drag ([HIG, Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop)). The `dropDestination(for:isEnabled:action:)` form with a `DropSession` is iOS 26.0; the SDK marks the older `action:isTargeted:` form for deprecation.

```swift
import SwiftUI

struct PhotoTile: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url)
            .frame(width: 120, height: 120)
            .draggable(url)
            // A non-drag path for the same action.
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") {
                    UIPasteboard.general.url = url
                }
            }
    }
}

@available(iOS 26.0, *)
struct AlbumDropArea: View {
    @State private var photos: [URL] = []

    var body: some View {
        List(photos, id: \.self) { Text($0.lastPathComponent) }
            .dropDestination(for: URL.self) { items, _ in
                photos.append(contentsOf: items)
            }
    }
}
```
