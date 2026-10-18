import Foundation

/// Search and sort rules for the places list. Plain Swift, no UI.
enum PlaceFilter {
    enum SortOrder: String, CaseIterable {
        case name
        case rating
        case region
    }

    /// Places whose name, region or summary contains every word of the query,
    /// ignoring case and accents. An empty query keeps every place.
    static func filter(_ places: [Place], query: String) -> [Place] {
        let words = query
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
        guard !words.isEmpty else { return places }
        return places.filter { place in
            let haystack = "\(place.name) \(place.region) \(place.summary)"
            return words.allSatisfy { word in
                haystack.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    /// Sorted copy. Ties keep the order by name.
    static func sort(_ places: [Place], by order: SortOrder) -> [Place] {
        switch order {
        case .name:
            return places.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .rating:
            return places.sorted {
                $0.rating != $1.rating
                    ? $0.rating > $1.rating
                    : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        case .region:
            return places.sorted {
                $0.region != $1.region
                    ? $0.region < $1.region
                    : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }
}
