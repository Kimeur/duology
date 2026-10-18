# Dual view

The same data shown two ways at once: a list of places and a map of them, Markdown and its preview, a table and a chart. Closed, one view with a switch. Open, both, side by side, kept in sync.

Prior art: Microsoft's [dual view pattern](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/dual-view) for Surface Duo. Apple's split arrangement is the matching tool: two distinct pieces of content, shown at the same time, neither covering the other ([talk 111463](https://developer.apple.com/videos/play/tech-talks/111463/?time=879)).

## Use it when

- Both views show the same items, so a selection in one makes sense in the other.
- People compare or check one view against the other: where is this restaurant, does the preview look right.

Not this pattern:

- A list on one side and the picked item's details on the other is [list-detail](list-detail.md). Microsoft's dual view guidance warns against mixing the two.
- Two views that must both show in every pose, such as a photo before and after an edit, or two players. A dual view shows one view when closed. Use `EvenSplit` from the `duo-layout` skill.
- Two separate documents side by side are better as two windows. iPhone Duo supports multiple windows and Split View on the inner display ([talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/?time=179)).

## How it behaves

| State | What shows |
|---|---|
| Closed (outer display) | One view. A segmented control switches between List and Map. Selection carries over. |
| Open, flat, held wide | Both. List on the leading side, map on the trailing side. The switch is gone. |
| Open, partly folded like a book | Both, one per side of the fold. The arrangement handles the fold. |
| Open, held tall, or in Split View | One view and the switch. |

## Apple APIs

| Need | SwiftUI | UIKit |
|---|---|---|
| Two views side by side that adapt to the fold | [`ArrangementView`](https://developer.apple.com/documentation/swiftui/arrangementview) with [`.split.axes(.horizontal)`](https://developer.apple.com/documentation/swiftui/splitarrangementviewstyle/axes(_:)) | [`UIArrangementViewController`](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) with `updateArrangement(.split.axes(.horizontal))` |
| Shared selection and map camera | an `@Observable` model, [`Map(position:selection:)`](https://developer.apple.com/documentation/mapkit/map), `List(selection:)` | a shared model object |
| The switch when closed | [`Picker`](https://developer.apple.com/documentation/swiftui/picker) with `.segmented` in a `principal` toolbar item | `UISegmentedControl` in the navigation item |

Arrangements are iOS 27.1. Keep your current layout for older systems behind `if #available(iOS 27.1, *)`.

## Rules

1. Share one model. Selection, filters and the map camera live in it, not in either view. When the phone opens, the view that comes back reads the same state.
2. Mark the selection in both views. A selected row and a highlighted pin tell people the two views are linked.
3. Edit in one view only. Microsoft's guidance: one side edits, the other previews. If both sides edit the same thing, people lose track of which one is "real".
4. Keep sides stable. When both show, the list is always leading and the map always trailing, whatever the switch said while closed.
5. Show the switch only when one view shows. Two views and a switch is a confusing combination.
6. A segmented control is too wide for a vertical bar, so it stays in the horizontal navigation bar. That is expected ([talk 111466](https://developer.apple.com/videos/play/tech-talks/111466/?time=307)).

## Recipe

Self-contained. Typechecks against the iOS 27.1 simulator SDK, also with an iOS 26 deployment target.

```swift
import MapKit
import SwiftUI

struct Place: Identifiable, Hashable {
    let id: Int
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Both views read and write this model, so the selection and the map camera
/// survive when a view is rebuilt.
@MainActor @Observable
final class PlacesModel {
    var places: [Place]
    var selection: Place.ID?
    var camera: MapCameraPosition = .automatic

    init(places: [Place]) {
        self.places = places
    }
}

@available(iOS 27.1, *)
struct PlacesDualView: View {
    enum Face: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }

    @State private var model: PlacesModel
    @State private var shownWhenAlone = Face.list
    @State private var bothFit = false
    @Environment(\.horizontalSizeClass) private var widthClass

    init(places: [Place]) {
        _model = State(initialValue: PlacesModel(places: places))
    }

    var body: some View {
        NavigationStack {
            ArrangementView {
                face(bothFit ? .list : shownWhenAlone)
            } secondary: {
                face(bothFit ? .map : (shownWhenAlone == .list ? .map : .list))
            }
            .arrangementViewStyle(.split.axes(.horizontal))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                // Mirrors Apple's documented split rule. Check it in Device Hub.
                bothFit = widthClass == .regular && size.width > size.height
            }
            .navigationTitle("Places")
            .toolbar {
                if !bothFit {
                    ToolbarItem(placement: .principal) {
                        Picker("Show", selection: $shownWhenAlone) {
                            ForEach(Face.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func face(_ face: Face) -> some View {
        switch face {
        case .list: PlacesList(model: model)
        case .map: PlacesMap(model: model)
        }
    }
}

struct PlacesList: View {
    @Bindable var model: PlacesModel

    var body: some View {
        List(model.places, selection: $model.selection) { place in
            Text(place.name)
        }
    }
}

struct PlacesMap: View {
    @Bindable var model: PlacesModel

    var body: some View {
        Map(position: $model.camera, selection: $model.selection) {
            ForEach(model.places) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tag(place.id)
            }
        }
    }
}
```

How it works:

- The primary slot holds whatever must show when only one fits. Closed, that is the view the switch picked. Open, it is the list.
- SwiftUI treats each slot as a different place in the view tree, so moving a view from one slot to the other rebuilds it. That is why the selection and the camera live in `PlacesModel`: the rebuilt map returns to the same place.
- `bothFit` copies Apple's rule for a split (side by side when wider than tall, with size class as an input). We found no API that says whether the secondary is on screen; see [supporting-pane.md](supporting-pane.md#what-we-measured).

## Pitfalls

- **State inside the views.** A `@State var camera` inside the map view resets every time the map changes slot.
- **Two maps.** Don't keep a hidden second copy of a heavy view to avoid rebuilds. One map, fed by the model, is enough.
- **Dual view as list-detail.** If tapping a row replaces the other side with that row's details, you built list-detail. Use `NavigationSplitView` instead.
- **Map gestures in the fold.** The map can run across the fold, but put map controls (recentre, filters) in the toolbar or in one region. See [displacement.md](displacement.md).
- **Pinch on the simulator.** Device Hub can't send two-finger touches in Xcode 27 ([Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)). Test map pinch on a device.

## Test it

1. Closed: List shows. Pick a place, switch to Map: the pin is selected.
2. Open: list leading, map trailing, both showing the same selection. No switch.
3. Closed on Map, then open: the list is leading again and the map is where you left it.
4. Partially Open: one view per side, nothing interactive in the fold.
5. Split View: one view and the switch.

## Gallery screen

[`samples/DuologyGallery/DuologyGallery/Patterns/DualView.swift`](https://github.com/Kimeur/duology/blob/main/samples/DuologyGallery/DuologyGallery/Patterns/DualView.swift)

## Sources

IDs point to [`reference/sources.md`](https://github.com/Kimeur/duology/blob/main/reference/sources.md): D1 (hub), D2 (HIG), V3 (talk 111463), V4 (talk 111464), V6 (talk 111466), A12 (Xcode 27 release notes), P1e (Microsoft dual view).
