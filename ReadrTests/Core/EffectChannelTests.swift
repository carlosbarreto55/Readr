import Testing

@testable import Readr

@Suite("Effect channel")
@MainActor
struct EffectChannelTests {

    @Test("An effect reaches the current subscriber")
    func delivers() async {
        let channel = EffectChannel<Int>()
        var effects = channel.stream().makeAsyncIterator()
        channel.send(1)
        #expect(await effects.next() == 1)
    }

    @Test("Effects sent with nobody listening reach the next subscriber, in order")
    func buffers() async {
        let channel = EffectChannel<Int>()
        channel.send(1)
        channel.send(2)
        var effects = channel.stream().makeAsyncIterator()
        #expect(await effects.next() == 1)
        #expect(await effects.next() == 2)
    }

    @Test("A new stream still delivers after the previous consumer was cancelled")
    func survivesCancelledConsumer() async throws {
        let channel = EffectChannel<Int>()
        let first = channel.stream()
        // What SwiftUI does to a screen's `.task` when a route is pushed over it.
        let consumer = Task {
            for await _ in first {}
        }
        consumer.cancel()
        await consumer.value

        var second = channel.stream().makeAsyncIterator()
        channel.send(7)
        #expect(await second.next() == 7)
    }

    @Test("Sending into a stream whose consumer went away keeps the effect")
    func keepsEffectForDeadStream() async {
        let channel = EffectChannel<Int>()
        let first = channel.stream()
        let consumer = Task {
            for await _ in first {}
        }
        consumer.cancel()
        await consumer.value

        channel.send(3)
        var next = channel.stream().makeAsyncIterator()
        #expect(await next.next() == 3)
    }

    @Test("A new subscriber replaces the old one, which finishes")
    func replacesSubscriber() async {
        let channel = EffectChannel<Int>()
        var old = channel.stream().makeAsyncIterator()
        var new = channel.stream().makeAsyncIterator()
        channel.send(5)
        #expect(await old.next() == nil)
        #expect(await new.next() == 5)
    }
}
