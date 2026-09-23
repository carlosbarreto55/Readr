import Foundation

/// Fans each value out to any number of `AsyncStream`s.
///
/// A value type with no locking: it belongs to one actor, which serializes every
/// use. Observers are pushed to, which is what lets a screen follow a queue
/// without polling it.
struct Broadcaster<Value: Sendable> {
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    var isEmpty: Bool { continuations.isEmpty }

    /// Registers a stream's continuation; the returned id removes it.
    mutating func add(_ continuation: AsyncStream<Value>.Continuation) -> UUID {
        let id = UUID()
        continuations[id] = continuation
        return id
    }

    mutating func remove(_ id: UUID) {
        continuations[id] = nil
    }

    func send(_ value: Value) {
        for continuation in continuations.values {
            continuation.yield(value)
        }
    }
}
