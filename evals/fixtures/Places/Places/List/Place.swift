import Foundation

struct Place: Identifiable, Hashable {
    let id: Int
    var name: String
    var region: String
    var summary: String
    var symbol: String
    var rating: Int
    var visited: Bool

    static let samples: [Place] = [
        Place(id: 1, name: "Cedar Falls", region: "North", summary: "A short walk to a tall waterfall.", symbol: "drop", rating: 5, visited: true),
        Place(id: 2, name: "Glass Lake", region: "North", summary: "Clear water and a flat loop trail.", symbol: "water.waves", rating: 4, visited: false),
        Place(id: 3, name: "Red Mesa", region: "South", summary: "Sandstone cliffs and wide views.", symbol: "mountain.2", rating: 4, visited: true),
        Place(id: 4, name: "Owl Woods", region: "East", summary: "Old trees and quiet paths.", symbol: "tree", rating: 3, visited: false),
        Place(id: 5, name: "Salt Flats", region: "South", summary: "White ground to the horizon.", symbol: "sun.max", rating: 3, visited: false),
        Place(id: 6, name: "Fern Gully", region: "West", summary: "A damp valley full of ferns.", symbol: "leaf", rating: 4, visited: true),
        Place(id: 7, name: "Lantern Cave", region: "East", summary: "A cave tour with lamps only.", symbol: "flashlight.on.fill", rating: 5, visited: false),
        Place(id: 8, name: "Kite Hill", region: "West", summary: "Windy grass on a round hill.", symbol: "wind", rating: 2, visited: false),
        Place(id: 9, name: "Stone Bridge", region: "North", summary: "A natural arch over a river.", symbol: "point.topleft.down.to.point.bottomright.curvepath", rating: 4, visited: true),
        Place(id: 10, name: "Heron Marsh", region: "East", summary: "Boardwalks and wading birds.", symbol: "bird", rating: 3, visited: false),
        Place(id: 11, name: "Ember Ridge", region: "South", summary: "A ridge walk at sunset.", symbol: "flame", rating: 5, visited: false),
        Place(id: 12, name: "Pine Harbor", region: "West", summary: "Boats, pines and a lighthouse.", symbol: "sailboat", rating: 4, visited: true),
        Place(id: 13, name: "Moss Steps", region: "North", summary: "Stone steps up a green slope.", symbol: "stairs", rating: 2, visited: false),
        Place(id: 14, name: "Dune Point", region: "South", summary: "Sand dunes beside the sea.", symbol: "beach.umbrella", rating: 3, visited: false),
        Place(id: 15, name: "Echo Canyon", region: "West", summary: "Shout and hear it twice.", symbol: "speaker.wave.3", rating: 4, visited: false),
        Place(id: 16, name: "Willow Bend", region: "East", summary: "A slow river under willows.", symbol: "figure.walk", rating: 3, visited: true),
    ]
}
