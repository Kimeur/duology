import Foundation

/// The books on the shelf, read from Books/Library.json.
///
/// Everything in Model/ uses Foundation (and CoreGraphics for geometry), never UIKit
/// or SwiftUI, and every type is `nonisolated` and `Sendable`. So the rules build and
/// run on the Mac in seconds: Tools/run-model-tests.sh.
nonisolated struct Library: Codable, Hashable, Sendable {
    let books: [Book]

    static func decode(from data: Data) throws -> Library {
        try JSONDecoder().decode(Library.self, from: data)
    }

    func book(_ id: Book.ID) -> Book? {
        books.first { $0.id == id }
    }
}

nonisolated struct Book: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
    /// What kind of book, for the cover and the shelf: "A story", "A field guide".
    let kind: String
    let summary: String
    /// Two colours for the drawn cover, as hex RGB such as "1F4E79".
    let colors: [String]
    let chapters: [Chapter]
}

nonisolated struct Chapter: Codable, Hashable, Sendable {
    let title: String
    /// A plain-text file in the app bundle, such as "keeper-1.txt". Blank lines
    /// separate paragraphs.
    let file: String

    /// The bundle resource name and extension, split at the last dot.
    var resource: (name: String, ext: String)? {
        guard let dot = file.lastIndex(of: "."), dot != file.startIndex else { return nil }
        let ext = file[file.index(after: dot)...]
        guard !ext.isEmpty else { return nil }
        return (String(file[..<dot]), String(ext))
    }
}
