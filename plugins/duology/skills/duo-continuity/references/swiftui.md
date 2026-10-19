# SwiftUI continuity patterns

Full code for each row of the "what must survive" table in [SKILL.md](../SKILL.md). Every block typechecks against the iOS 27.1 simulator SDK, together with the shared types below, in Swift 5 mode, Swift 6 mode, and Swift 6 with `MainActor` as the default isolation.

*Measured* results come from the probes in [evidence.md](evidence.md). They flip the size class from code; they are not a real fold.

## Shared types

```swift
import SwiftUI
import Observation

struct Item: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var title: String
}

/// App-wide: who is signed in. One instance for every window.
@MainActor @Observable
final class Session {
    var userName: String?
}

/// Per window: what this window shows.
@MainActor @Observable
final class LibraryModel {
    var items: [Item] = (1...200).map { Item(id: $0, title: "Item \($0)") }
    var selection: Item.ID?
    var path = NavigationPath()
    var scroll = ScrollPosition(idType: Item.ID.self)
    var sheetItem: Item?
    var itemToDelete: Item?
    var details: [Item.ID: String] = [:]     // loaded once per item, kept across folds
}
```

## Who owns what

- App-wide objects (session, stores, upload service) live in the `App` and go down through `.environment`.
- Per-window objects live in the window's root view. On the inner display people can open more than one window, so a selection shared by every window would be wrong.
- The root view never changes identity. Switching between signed-in and signed-out content is a data change, so a new identity there is correct. Switching on layout is not.

```swift
import SwiftUI

@main
struct LibraryApp: App {
    @State private var session = Session()           // shared by every window

    var body: some Scene {
        WindowGroup {
            WindowRoot()
                .environment(session)
        }
    }
}

struct WindowRoot: View {
    @Environment(Session.self) private var session
    @State private var model = LibraryModel()        // one per window

    var body: some View {
        Group {
            if session.userName == nil {
                Button("Sign in") { session.userName = "Sam" }  // your sign-in flow
            } else {
                Text("Library")                                 // your signed-in root
            }
        }
        .environment(model)
    }
}
```

Apple's guide to this ownership model: [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app). WWDC23 [Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/) explains `@Observable`, and WWDC21 [Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/) explains view identity.

## Pick a layout without a branch

Decide from the size class when you can. When you need the real space, measure a frame that fills the offered space, not the content, so the measurement can't feed back into the layout.

```swift
import SwiftUI

struct MediaRow: View {
    @State private var isWide = false     // layout only; losing it costs nothing

    var body: some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top))
            : AnyLayout(VStackLayout(alignment: .leading))
        layout {
            Image(systemName: "photo")
            Text("Caption")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // measure the space, not the content
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { wide in
            isWide = wide
        }
    }
}
```

- [onGeometryChange(for:of:action:)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)) reports the value only when it changes.
- A custom `Layout` type is another branch-free option. `duo-layout` has one that splits at the fold.
- [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits) is fine for labels and icons. Don't put `@State`, a text field or a scroll view inside it; read state from the model instead.

## Restore after a relaunch

A fold keeps the window alive, so the model is enough. `@SceneStorage` covers the other case: the system ends the app in the background and later brings the window back ([SceneStorage](https://developer.apple.com/documentation/swiftui/scenestorage), [Restoring your app's state with SwiftUI](https://developer.apple.com/documentation/swiftui/restoring-your-app-s-state-with-swiftui)).

```swift
import SwiftUI

struct RestoringRoot: View {
    @State private var model = LibraryModel()
    @SceneStorage("library.selection") private var savedSelection: Int?
    @SceneStorage("library.path") private var savedPath: Data?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $model.path) {
            List(model.items) { item in
                NavigationLink(item.title, value: item.id)
            }
            .navigationDestination(for: Item.ID.self) { Text("Item \($0)") }
        }
        .environment(model)
        .task { restore() }                       // runs once: this view never changes identity
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { save() }
        }
    }

    private func restore() {
        model.selection = savedSelection
        if let savedPath,
           let saved = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: savedPath) {
            model.path = NavigationPath(saved)
        }
    }

    private func save() {
        savedSelection = model.selection
        if let codable = model.path.codable {   // nil when a pushed value isn't Codable
            savedPath = try? JSONEncoder().encode(codable)
        }
    }
}
```

- Apple's `SceneStorage` page says: keep the data small, don't store sensitive data, and expect the system to choose when it saves. Data goes away when the scene is destroyed.
- Two `@SceneStorage` properties with the same key in one scene share a value. *Measured:* a value written in one size-class branch was read back by the view in the other branch.
- `NavigationPath.codable` is `nil` if any pushed value isn't `Codable` ([codable](https://developer.apple.com/documentation/swiftui/navigationpath/codable)).
- Save on `.background`, not `.inactive`. *Measured* on the simulator (v0.2, `duo-scenes`): a fold kept the scene `active`, with no `.inactive`. A real device is unverified, so don't depend on it.

## Scroll position

Store the position as an item ID in the model and attach it to a `ScrollView` whose identity never changes. Change columns inside it, not around it.

```swift
import SwiftUI

struct GalleryView: View {
    @Environment(LibraryModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        @Bindable var model = model
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: sizeClass == .compact ? 2 : 4)) {
                ForEach(model.items) { item in
                    Text(item.title).frame(height: 80)
                }
            }
            .scrollTargetLayout()                      // the views ScrollPosition can name
        }
        .scrollPosition($model.scroll, anchor: .top)
        .toolbar {
            Button("Top") { model.scroll.scrollTo(edge: .top) }
        }
    }
}
```

- Read the current item with `model.scroll.viewID(type: Item.ID.self)` ([ScrollPosition](https://developer.apple.com/documentation/swiftui/scrollposition)).
- Before iOS 18, use [scrollPosition(id:anchor:)](https://developer.apple.com/documentation/swiftui/view/scrollposition(id:anchor:)) with an `Item.ID?` in the model.
- *Measured:* an ID position kept item 150 at the top through 4 → 1 → 4 columns. A point position (`scrollTo(y:)`) kept the offset and showed other items.
- *Measured:* `onScrollTargetVisibilityChange(idType:threshold:_:)` reported no IDs after the column count changed, while `viewID` stayed right. Restore from the position, not from that callback.
- *Measured:* `scrollPosition(id:)` did not scroll a `List`. A `List` keeps its own offset while its identity is stable, and inside a collapsing `NavigationSplitView` it came back at the same offset. To jump a `List` to an item, use [ScrollViewReader](https://developer.apple.com/documentation/swiftui/scrollviewreader).

## Text, focus and selection

```swift
import SwiftUI

struct MessageDraft: Equatable {
    var subject = ""
    var message = ""
}

enum DraftField: Hashable { case subject, message }

@MainActor @Observable
final class ComposeModel {
    var draft = MessageDraft()
    var messageSelection: TextSelection?
}

struct ComposeView: View {
    @Bindable var model: ComposeModel
    @FocusState private var focus: DraftField?     // view state: keep this view's identity stable
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let layout = sizeClass == .compact
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(alignment: .top))
        layout {
            TextField("Subject", text: $model.draft.subject)
                .focused($focus, equals: .subject)
            TextEditor(text: $model.draft.message, selection: $model.messageSelection)
                .focused($focus, equals: .message)
        }
    }
}
```

- [FocusState](https://developer.apple.com/documentation/swiftui/focusstate) can't live in a model. It belongs to a view, so the field and that view must keep their identity.
- *Measured:* focus survived two size-class flips when the field kept its identity, and became `nil` when the field sat in an `if`/`else`.
- [TextSelection](https://developer.apple.com/documentation/swiftui/textselection) and the `selection:` initializers of [TextField](https://developer.apple.com/documentation/swiftui/textfield/init(_:text:selection:prompt:axis:)) and [TextEditor](https://developer.apple.com/documentation/swiftui/texteditor/init(text:selection:)) need iOS 18.
- *Unverified:* what the software keyboard does when the window moves to the other display. Run the Device Hub pass with the keyboard up.

## Form input

Bind every field to one draft struct in the model. Validate in the model, not in `onAppear` or `onDisappear`.

```swift
import SwiftUI

struct AddressForm: Equatable {
    var name = ""
    var street = ""
    var city = ""
    var isComplete: Bool { !name.isEmpty && !street.isEmpty && !city.isEmpty }
}

@MainActor @Observable
final class CheckoutModel {
    var address = AddressForm()
}

struct AddressFields: View {
    @Bindable var model: CheckoutModel
    var body: some View {
        Form {
            TextField("Name", text: $model.address.name)
            TextField("Street", text: $model.address.street)
            TextField("City", text: $model.address.city)
        }
    }
}
```

## Playback

```swift
import SwiftUI
import AVKit

@MainActor @Observable
final class PlaybackModel {
    let player = AVPlayer()
    private(set) var currentURL: URL?

    func play(_ url: URL) {
        guard url != currentURL else { return }      // a fold never restarts the same item
        currentURL = url
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
    }
}

struct PlayerScreen: View {
    let playback: PlaybackModel                      // owned by the window root
    let url: URL
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let layout = sizeClass == .compact ? AnyLayout(VStackLayout()) : AnyLayout(HStackLayout())
        layout {
            VideoPlayer(player: playback.player)
            Text("Up next")
        }
        .task(id: url) { playback.play(url) }       // keyed on the data; a repeat is a no-op
    }
}
```

- [VideoPlayer](https://developer.apple.com/documentation/avkit/videoplayer) is only a view of the player. Rebuilding it doesn't touch playback. *Measured:* playback ran on through every flip.
- Apple's [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview) page uses an overlay arrangement for player controls over video. It takes the player view once, so the same rule holds. See `duo-layout`.

## Uploads and downloads

Start long work from an action, inside a service object that outlives every view. SwiftUI cancels a `.task` when its view goes away or changes identity ([task(id:name:priority:file:line:_:)](https://developer.apple.com/documentation/swiftui/view/task(id:name:priority:file:line:_:))).

```swift
import SwiftUI

@MainActor @Observable
final class UploadCenter {
    enum Status: Equatable { case running, done, failed }
    private(set) var uploads: [UUID: Status] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]

    @discardableResult
    func start(file: URL, to endpoint: URL) -> UUID {
        let id = UUID()
        uploads[id] = .running
        tasks[id] = Task {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            do {
                _ = try await URLSession.shared.upload(for: request, fromFile: file)
                uploads[id] = .done
            } catch {
                uploads[id] = .failed
            }
            tasks[id] = nil
        }
        return id
    }

    func cancel(_ id: UUID) { tasks[id]?.cancel() }
}

struct AttachButton: View {
    @Environment(UploadCenter.self) private var uploads
    let file: URL
    let endpoint: URL

    var body: some View {
        Button("Upload") { uploads.start(file: file, to: endpoint) }   // an action, not .task
    }
}
```

- Put `UploadCenter` in the `App`, next to the session, so every window sees the same uploads.
- For uploads that must go on while the app is in the background, use a session made with [background(withIdentifier:)](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/background(withidentifier:)).

## Loading without reloading

```swift
import SwiftUI

struct ItemDetail: View {
    @Environment(LibraryModel.self) private var model
    let item: Item

    var body: some View {
        Text(model.details[item.id] ?? "Loading…")
            .task(id: item.id) {
                guard model.details[item.id] == nil else { return }  // cached: a fold shows it at once
                model.details[item.id] = await fetchDetail(item.id)
            }
    }
}

func fetchDetail(_ id: Item.ID) async -> String {
    "Detail for item \(id)"   // your network call
}
```

- Key `.task(id:)` on the data the view shows. If the view is rebuilt anyway, the cache in the model makes the rerun free.

## Sheets, alerts and sign-in

```swift
import SwiftUI

struct LibraryShell: View {
    @Environment(LibraryModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Text("Screen with layout switches")            // your content
            .sheet(item: $model.sheetItem) { item in
                Text(item.title)
            }
            .alert("Delete this item?", item: $model.itemToDelete) { item in
                Button("Delete", role: .destructive) {
                    model.items.removeAll { $0.id == item.id }
                }
            }
    }
}
```

- Attach presentations at a view that never changes identity. *Measured:* a sheet attached inside an `if`/`else` closed on a flip while its `isPresented` binding stayed `true`.
- [sheet(item:onDismiss:content:)](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:)) and [alert(_:item:actions:)](https://developer.apple.com/documentation/swiftui/view/alert(_:item:actions:)) take the item from the model. The `alert` and `confirmationDialog` item overloads are new in the iOS 27 SDK and also build for older targets ([API index](https://github.com/Kimeur/duology/blob/main/reference/api-index.md#ios-27-swiftui-wwdc26)).
- Keep the session in the app-level `Session` object and tokens in [Keychain Services](https://developer.apple.com/documentation/security/keychain-services). Present sign-in from the window root. *Unverified:* whether a web sign-in sheet in flight survives a fold.

## Panes that hide

When the phone closes, extra panes leave the view tree:

- a `NavigationSplitView` collapses to one stack (*measured:* the sidebar's `onDisappear` ran on collapse and its `onAppear` on expand);
- a split `ArrangementView` shows only its primary view when it can't split, for example closed and held sideways (`duo-layout` measured this), so the secondary view's own state goes;
- your own "only when regular" panes go away.

Anything a hidden pane must remember goes in the model: its scroll position, its draft, its selection.
