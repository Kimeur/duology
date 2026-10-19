import Foundation

struct Note: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var title: String
    var text: String
    var edited = Date()
}
