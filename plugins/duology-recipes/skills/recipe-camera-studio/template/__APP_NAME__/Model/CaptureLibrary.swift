import Foundation

/// One photo or video in the studio's gallery. The file lives in the app's Documents/Captures
/// folder; `created` is the app's own date, so the gallery never reads file dates (a
/// required-reason API).
nonisolated struct Capture: Codable, Equatable, Identifiable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable { case photo, video }

    var id: String
    var kind: Kind
    var created: Date
    /// Seconds, for a video.
    var duration: Double?
    /// Made by the stand-in camera (the simulator), not a real one.
    var isStandIn: Bool

    init(id: String = UUID().uuidString, kind: Kind, created: Date = Date(), duration: Double? = nil, isStandIn: Bool = false) {
        self.id = id
        self.kind = kind
        self.created = created
        self.duration = duration
        self.isStandIn = isStandIn
    }

    /// The photo or the movie.
    var fileName: String { kind == .photo ? "\(id).jpg" : "\(id).mov" }
    /// A still for the gallery's grid. A photo is its own; a video has one saved beside it.
    var posterName: String { kind == .photo ? fileName : "\(id)-poster.jpg" }
    /// Every file that belongs to this capture.
    var fileNames: [String] { kind == .photo ? [fileName] : [fileName, posterName] }

    /// What VoiceOver says for its cell.
    var spokenTitle: String {
        let what = kind == .photo ? "Photo" : "Video, \(RecordingClock.spoken(duration ?? 0))"
        return isStandIn ? "\(what), stand-in camera" : what
    }
}

/// The gallery's index: every capture, newest first. `StudioStore` keeps one and saves it as
/// JSON after every change. A value type, so the rules are tested on the Mac.
nonisolated struct CaptureLibrary: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = CaptureLibrary.currentVersion
    private(set) var captures: [Capture]

    init(captures: [Capture] = []) {
        self.captures = captures
    }

    /// Newest first; captures made at the same moment keep a fixed order.
    var sorted: [Capture] {
        captures.sorted { $0.created != $1.created ? $0.created > $1.created : $0.id < $1.id }
    }

    var latest: Capture? { sorted.first }

    func capture(_ id: Capture.ID) -> Capture? {
        captures.first { $0.id == id }
    }

    mutating func add(_ capture: Capture) {
        captures.removeAll { $0.id == capture.id }
        captures.append(capture)
    }

    /// Removes a capture and returns the files to delete.
    @discardableResult
    mutating func remove(_ id: Capture.ID) -> [String] {
        guard let capture = capture(id) else { return [] }
        captures.removeAll { $0.id == id }
        return capture.fileNames
    }

    /// Drops entries whose file is gone (deleted outside the app, or a crash mid-save).
    mutating func keepOnly(existing fileNames: Set<String>) {
        captures.removeAll { !fileNames.contains($0.fileName) }
    }

    // Reads files without a version too, so a future format can still read this one.
    private enum CodingKeys: String, CodingKey { case version, captures }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        captures = try container.decodeIfPresent([Capture].self, forKey: .captures) ?? []
    }

    /// The index file: JSON, dates as ISO 8601 text.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> CaptureLibrary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CaptureLibrary.self, from: data)
    }
}
