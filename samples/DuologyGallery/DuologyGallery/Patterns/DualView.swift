import MapKit
import SwiftUI

/// Dual view: one day of places, as a list and as a map.
///
/// Open and held wide, the list sits on the leading side and the map on the
/// trailing side, sharing one selection. Closed, one view shows, with a switch.
/// Both views read one model, so the selection and the map camera survive when
/// a view moves between the arrangement's slots.
///
/// Built on `ArrangementView` with a horizontal-only split (iOS 27.1).
/// Pattern guide: `duo-patterns/references/dual-view.md`.
struct DualView: View {
    enum Face: String, CaseIterable {
        case list = "List"
        case map = "Map"
    }

    @State private var model = PlacesModel()
    @State private var shownWhenAlone = LaunchOptions.show.flatMap { Face(rawValue: $0.capitalized) } ?? .list
    @State private var bothFit = false
    @Environment(\.horizontalSizeClass) private var widthClass

    var body: some View {
        NavigationStack {
            content
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                    // Mirrors Apple's documented split rule. Check it in Device Hub.
                    let fits = widthClass == .regular && size.width > size.height
                    if #available(iOS 27.1, *) {
                        bothFit = fits
                    } else {
                        bothFit = false
                    }
                }
                .navigationTitle("Lisbon in a Day")
                .navigationBarTitleDisplayMode(.inline)
                .galleryCloseButton()
                .toolbar {
                    // Show the switch only when one view shows. A segmented control
                    // is too wide for a vertical bar, so it stays in the top bar.
                    if !bothFit {
                        ToolbarItem(placement: .principal) {
                            Picker("Show", selection: $shownWhenAlone) {
                                ForEach(Face.allCases, id: \.self) { Text($0.rawValue) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                    }
                }
                .onChange(of: model.selection) { _, id in
                    model.focus(on: id)
                }
                .task {
                    if model.selection == nil, let preset = LaunchOptions.selection {
                        model.selection = preset
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                // The primary slot holds whatever must show when only one view fits.
                face(bothFit ? .list : shownWhenAlone)
            } secondary: {
                face(bothFit ? .map : (shownWhenAlone == .list ? .map : .list))
                    .splitArrangementLayoutRatio(0.58)
            }
            .arrangementViewStyle(.split.axes(.horizontal))
        } else {
            face(shownWhenAlone)
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

// MARK: - Model

/// Both views read and write this model, so the selection and the camera
/// survive when a view is rebuilt.
@Observable
final class PlacesModel {
    var places = Place.lisbon
    var selection: Place.ID?
    var camera: MapCameraPosition = .region(Place.lisbonOverview)

    func focus(on id: Place.ID?) {
        guard let place = places.first(where: { $0.id == id }) else { return }
        withAnimation(.smooth) {
            camera = .region(MKCoordinateRegion(
                center: place.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.035)
            ))
        }
    }
}

struct Place: Identifiable, Hashable {
    let id: Int
    var name: String
    var time: String
    var kind: String
    var note: String
    var symbol: String
    var color: Color
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let lisbonOverview = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.7125, longitude: -9.1700),
        span: MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.12)
    )

    static let lisbon: [Place] = [
        Place(id: 1, name: "Belém Tower", time: "09:00", kind: "Landmark",
              note: "Go early, before the tour buses. The river view from the bastion is the best part.",
              symbol: "building.columns.fill", color: Color(hex: 0x2B55C7), latitude: 38.6916, longitude: -9.2160),
        Place(id: 2, name: "Jerónimos Monastery", time: "10:00", kind: "Landmark",
              note: "The cloister is worth the queue. Allow an hour.",
              symbol: "building.columns.fill", color: Color(hex: 0x2B55C7), latitude: 38.6979, longitude: -9.2068),
        Place(id: 3, name: "Pastry stop in Belém", time: "11:15", kind: "Café",
              note: "Custard tarts, still warm, with cinnamon on top.",
              symbol: "cup.and.saucer.fill", color: Color(hex: 0xC2410C), latitude: 38.6975, longitude: -9.2033),
        Place(id: 4, name: "LX Factory", time: "12:30", kind: "Lunch",
              note: "Old printing works turned market. Lunch, then the bookshop with the bicycle on the ceiling.",
              symbol: "fork.knife", color: Color(hex: 0xC2410C), latitude: 38.7032, longitude: -9.1789),
        Place(id: 5, name: "Praça do Comércio", time: "14:30", kind: "Square",
              note: "Walk under the arch into Baixa. Tram 28 stops nearby.",
              symbol: "tram.fill", color: Color(hex: 0x0F8A6A), latitude: 38.7075, longitude: -9.1364),
        Place(id: 6, name: "São Jorge Castle", time: "15:30", kind: "Landmark",
              note: "A steep climb through Alfama. The walls look over the whole city.",
              symbol: "building.columns.fill", color: Color(hex: 0x2B55C7), latitude: 38.7139, longitude: -9.1335),
        Place(id: 7, name: "Senhora do Monte viewpoint", time: "18:00", kind: "Viewpoint",
              note: "The highest viewpoint in town. Bring a jacket for sunset.",
              symbol: "binoculars.fill", color: Color(hex: 0x7A4CD9), latitude: 38.7190, longitude: -9.1325),
        Place(id: 8, name: "Dinner in Príncipe Real", time: "20:00", kind: "Dinner",
              note: "Book ahead on weekends. The garden square is lovely after dark.",
              symbol: "wineglass.fill", color: Color(hex: 0xC2410C), latitude: 38.7166, longitude: -9.1490)
    ]
}

// MARK: - Views

private struct PlacesList: View {
    @Bindable var model: PlacesModel

    var body: some View {
        List(selection: $model.selection) {
            Section {
                ForEach(model.places) { place in
                    PlaceRow(place: place)
                        .tag(place.id)
                }
            } header: {
                Text("Saturday · 8 stops · 14 km")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct PlaceRow: View {
    let place: Place

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: place.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(place.color.gradient, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(place.name).font(.headline)
                    Spacer(minLength: 8)
                    Text(place.time)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(place.kind)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(place.color)
                Text(place.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PlacesMap: View {
    @Bindable var model: PlacesModel

    var body: some View {
        Map(position: $model.camera, selection: $model.selection) {
            ForEach(model.places) { place in
                Marker(place.name, systemImage: place.symbol, coordinate: place.coordinate)
                    .tint(place.color)
                    .tag(place.id)
            }
            MapPolyline(coordinates: model.places.map(\.coordinate))
                .stroke(Color(hex: 0x2B55C7).opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 6]))
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
}
