/// Delivers a presentation model's effects to whichever screen is listening now.
///
/// A screen consumes effects in a SwiftUI `.task`, which SwiftUI cancels whenever
/// the view disappears — every time a route is pushed over it. Cancelling a task
/// that is awaiting an `AsyncStream` finishes that stream for good, so a model
/// holding one stream for its lifetime stops navigating the first time the
/// reader leaves and comes back. Each `stream()` call therefore hands out a fresh
/// stream, replacing the previous subscriber.
///
/// Effects sent while nobody is listening are buffered and delivered to the next
/// subscriber, rather than lost in the gap between a disappearance and the next
/// appearance.
@MainActor
final class EffectChannel<Effect: Sendable> {
    private var subscriber: AsyncStream<Effect>.Continuation?
    private var buffered: [Effect] = []

    init() {}

    isolated deinit {
        subscriber?.finish()
    }

    func send(_ effect: Effect) {
        if let subscriber, case .enqueued = subscriber.yield(effect) {
            return
        }
        // No listener, or its stream already ended: keep it for the next one.
        subscriber = nil
        buffered.append(effect)
    }

    /// A new stream of effects. The previous stream, if any, is finished.
    func stream() -> AsyncStream<Effect> {
        subscriber?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: Effect.self)
        subscriber = continuation
        for effect in buffered {
            continuation.yield(effect)
        }
        buffered.removeAll()
        return stream
    }
}
