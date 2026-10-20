import Foundation

/// Buying a basket. StoreKit sells one product per purchase, and the person confirms each
/// one in the system sheet, so checkout buys the packs one after another and keeps track.
///
/// Rules:
/// - Packs go in basket order, one at a time.
/// - A cancel stops the run: the person said no, so don't open the next sheet.
///   `resume()` carries on from the pack they cancelled.
/// - An error stops it too, with the message. `resume()` tries that pack again.
/// - "Pending" (Ask to Buy, or a payment that needs action) is not a failure: the run moves on,
///   and the pack unlocks later through `Transaction.updates`.
nonisolated struct CheckoutRun: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case waiting, buying, bought, pending, cancelled
        case failed(String)
    }

    /// What one purchase came back with.
    enum Outcome: Equatable, Sendable {
        case bought, pending, cancelled
        case failed(String)
    }

    struct Line: Identifiable, Equatable, Sendable {
        let id: Pack.ID
        var status: Status
    }

    private(set) var lines: [Line]
    private(set) var isStopped = false

    init(packs: [Pack.ID]) {
        lines = packs.map { Line(id: $0, status: .waiting) }
    }

    /// The pack to buy now. Nil while one is being bought, after a stop, or when done.
    var next: Pack.ID? {
        guard !isStopped, !lines.contains(where: { $0.status == .buying }) else { return nil }
        return lines.first { $0.status == .waiting }?.id
    }

    var isBuying: Bool { lines.contains { $0.status == .buying } }

    /// Every line has an answer and nothing is left to try.
    var isFinished: Bool {
        lines.allSatisfy { [.bought, .pending].contains($0.status) }
    }

    var bought: [Pack.ID] { lines.filter { $0.status == .bought }.map(\.id) }
    var pending: [Pack.ID] { lines.filter { $0.status == .pending }.map(\.id) }
    /// Packs not bought yet: waiting, cancelled or failed.
    var remaining: [Pack.ID] {
        lines.filter { ![.bought, .pending, .buying].contains($0.status) }.map(\.id)
    }

    /// The message of the last failure, for the view.
    var failure: String? {
        for line in lines.reversed() {
            if case .failed(let message) = line.status { return message }
        }
        return nil
    }

    func status(of id: Pack.ID) -> Status? { lines.first { $0.id == id }?.status }

    /// Marks `id` as being bought. Ignored unless it is `next`.
    mutating func start(_ id: Pack.ID) {
        guard id == next, let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].status = .buying
    }

    /// Records what the purchase of `id` came back with. Ignored unless `id` is being bought.
    mutating func finish(_ id: Pack.ID, _ outcome: Outcome) {
        guard let index = lines.firstIndex(where: { $0.id == id }), lines[index].status == .buying else { return }
        switch outcome {
        case .bought: lines[index].status = .bought
        case .pending: lines[index].status = .pending
        case .cancelled:
            lines[index].status = .cancelled
            isStopped = true
        case .failed(let message):
            lines[index].status = .failed(message)
            isStopped = true
        }
    }

    /// Carries on after a cancel or an error: those packs wait again.
    mutating func resume() {
        for index in lines.indices {
            switch lines[index].status {
            case .cancelled, .failed: lines[index].status = .waiting
            default: break
            }
        }
        isStopped = false
    }

    /// Drops a pack the person no longer needs to buy, for example because a restore or Plus
    /// unlocked it. A pack that is being bought stays.
    mutating func drop(_ id: Pack.ID) {
        lines.removeAll { $0.id == id && $0.status != .buying }
    }
}
