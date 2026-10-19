import SwiftUI

struct Trip: Identifiable {
    let id: Int
    let city: String
    let dates: String
    let note: String
    let colors: [Color]
    var isFavorite = false
}

extension Trip {
    static let samples: [Trip] = [
        Trip(id: 1, city: "Lisbon", dates: "7 – 10 November", note: "Tram 28 early, before the crowds. Dinner booked in Alfama on Saturday.",
             colors: [.orange, .pink]),
        Trip(id: 2, city: "Kyoto", dates: "2 – 9 December", note: "Temple passes are in the wallet. Ryokan check-in after 3 pm.",
             colors: [.red, .purple], isFavorite: true),
        Trip(id: 3, city: "Reykjavík", dates: "14 – 18 January", note: "Rent the car at the airport. Northern lights tour on the second night.",
             colors: [.teal, .indigo]),
        Trip(id: 4, city: "Marrakesh", dates: "20 – 24 February", note: "Riad near the Medina. Ask about the cooking class on Friday.",
             colors: [.yellow, .orange]),
        Trip(id: 5, city: "Vancouver", dates: "3 – 8 April", note: "Bikes along the Seawall. Ferry to Victoria if it isn't raining.",
             colors: [.green, .blue]),
        Trip(id: 6, city: "Buenos Aires", dates: "12 – 19 May", note: "Tango lesson on Tuesday. Pick up the leather bag in Palermo.",
             colors: [.blue, .mint]),
    ]
}
