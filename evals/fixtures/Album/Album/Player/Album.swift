import Foundation

struct Track: Identifiable, Hashable {
    let id: Int
    let title: String
    let length: String
}

struct Album {
    let title: String
    let artist: String
    let year: Int
    let tracks: [Track]
}

extension Album {
    static let nightDrive = Album(title: "Night Drive", artist: "The Low Hours", year: 2026, tracks: [
        Track(id: 1, title: "Headlights", length: "3:41"),
        Track(id: 2, title: "Exit 12", length: "4:05"),
        Track(id: 3, title: "Neon Rain", length: "3:22"),
        Track(id: 4, title: "Service Station", length: "2:58"),
        Track(id: 5, title: "Long Way Round", length: "5:10"),
        Track(id: 6, title: "Radio Static", length: "3:47"),
        Track(id: 7, title: "Toll Bridge", length: "4:16"),
        Track(id: 8, title: "Almost Home", length: "4:39"),
    ])
}
