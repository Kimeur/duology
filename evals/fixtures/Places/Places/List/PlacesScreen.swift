import SwiftUI

struct PlacesScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        // Regular width means we're on iPad: show the list and the detail side by side.
        let isPad = sizeClass == .regular
        if isPad {
            PadPlacesLayout()
        } else {
            PhonePlacesLayout()
        }
    }
}

/// iPhone: a list that pushes the detail.
struct PhonePlacesLayout: View {
    @State private var query = ""
    @State private var order: PlaceFilter.SortOrder = .name

    private var places: [Place] {
        PlaceFilter.sort(PlaceFilter.filter(Place.samples, query: query), by: order)
    }

    var body: some View {
        NavigationStack {
            List(places) { place in
                NavigationLink(value: place) {
                    PlaceRow(place: place)
                }
            }
            .navigationTitle("Places")
            .navigationDestination(for: Place.self) { place in
                PlaceDetail(place: place)
            }
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $order) {
                            ForEach(PlaceFilter.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue.capitalized).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                AddPlaceButton()
            }
        }
    }
}

/// iPad: list on the left, detail on the right.
struct PadPlacesLayout: View {
    @State private var query = ""
    @State private var order: PlaceFilter.SortOrder = .name
    @State private var selection: Place?

    private var places: [Place] {
        PlaceFilter.sort(PlaceFilter.filter(Place.samples, query: query), by: order)
    }

    var body: some View {
        HStack(spacing: 0) {
            NavigationStack {
                List(places, selection: $selection) { place in
                    PlaceRow(place: place)
                        .tag(place)
                }
                .navigationTitle("Places")
                .searchable(text: $query)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Edit") {}
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $order) {
                                ForEach(PlaceFilter.SortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue.capitalized).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .frame(width: 390)

            Divider()

            if let selection {
                PlaceDetail(place: selection)
            } else {
                Text("Select a place")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            AddPlaceButton()
        }
    }
}

/// Floating button, centred at the bottom of the screen.
struct AddPlaceButton: View {
    @State private var showingForm = false

    var body: some View {
        Button {
            showingForm = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 4)
        }
        .padding(.bottom, 24)
        .sheet(isPresented: $showingForm) {
            Text("New place")
                .presentationDetents([.medium])
        }
    }
}
