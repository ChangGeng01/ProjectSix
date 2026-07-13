import Foundation

// 六十五.2 — typed state graph pub/sub bus.
//
// deep-audit DORMANT (2026-07-13): test-only scaffolding — NO production consumer. The 9
// default seats pull `QinaoLoop` directly; nothing subscribes/publishes on this bus in a live
// path (only tests construct it). Per pin-boundary-defer-interface it stays dormant, honestly
// marked, NOT wired speculatively (a reader-less bus is the repo's "上膛未击发" loaded-gun
// anti-pattern). TRIGGER to activate = the first host that adopts the propose/dispose seat
// fabric onto the sovereign spine. The whole seat-fabric propose→commit lane shares this
// dormancy — see QinaoSeatFabricDormancyBoundaryTests, which fails closed if a production
// module starts wiring `dispatchProposals`.
//
// ## Why this exists
//
// Manifesto v4 八.2 says "agent 不是彼此聊天，而是一起看
// 同一块黑板"——共享状态图是协同的载体。`QinaoSeatDomain`
// (六十四.2) typed 列出了 11+ 域；但 runtime pub/sub 总线
// 还没 ship——9 默认 seat 都直接拉 `QinaoLoop` 引用。
//
// 六十五.2 ships a typed pub/sub bus: agents subscribe to
// domains; writers publish typed deltas; bus delivers to
// matching subscribers. Pure in-process; backing AsyncStream
// for ordered delivery.
//
// ## Doctrine
//
// - **Pure typed actor.** No I/O, no network — in-process
//   event distribution.
// - **Subscription is by domain set.** Agent's
//   `canonicalCapability.readDomains` directly drives
//   subscription set.
// - **Publish is content-typed.** Each publish carries a
//   `QinaoStateGraphEvent` with target domain + payload +
//   originating agent.
// - **Failure isolation.** A slow / crashed subscriber does
//   not block other subscribers (each gets its own
//   AsyncStream).

/// Typed event published to the bus.
public struct QinaoStateGraphEvent:
    Sendable, Equatable, Hashable, Codable
{
    public let domain: QinaoSeatDomain
    /// Opaque to bus; concrete domain modules deserialize.
    public let payload: String
    /// Which seat published this (or nil if from QinaoLoop /
    /// other infrastructure).
    public let originAgent: QinaoSeat?
    /// Monotonically increasing sequence number assigned by
    /// the bus on publish.
    public let sequence: Int

    public init(
        domain: QinaoSeatDomain,
        payload: String,
        originAgent: QinaoSeat? = nil,
        sequence: Int
    ) {
        self.domain = domain
        self.payload = payload
        self.originAgent = originAgent
        self.sequence = sequence
    }
}

/// Subscription handle. Caller iterates `events` to receive
/// typed deltas; calling `close()` unsubscribes.
public struct QinaoStateGraphSubscription: Sendable {
    public let agent: QinaoSeat
    public let domains: Set<QinaoSeatDomain>
    public let events: AsyncStream<QinaoStateGraphEvent>
    public let close: @Sendable () -> Void
}

/// Actor managing the bus state.
public actor QinaoStateGraphBus {
    private struct Continuation {
        let domains: Set<QinaoSeatDomain>
        let agent: QinaoSeat
        let yield:
            @Sendable (QinaoStateGraphEvent) -> Void
        let finish: @Sendable () -> Void
    }

    private var nextSeq: Int = 1
    private var continuations: [String: Continuation] = [:]
    private var publishedCount: Int = 0

    public init() {}

    /// Subscribe agent to a set of domains. Returns a
    /// subscription whose `events` AsyncStream yields
    /// matching events.
    ///
    /// **Buffering**: bounded at 1024 events per subscriber
    /// to prevent runaway memory growth from a slow / dead
    /// consumer. Oldest events are dropped on overflow.
    /// Subscribers iterating in real time will never hit
    /// this cap; back-pressured consumers self-recover.
    ///
    /// **Cleanup**: when the caller drops its
    /// `QinaoStateGraphSubscription` without calling
    /// `close()`, the underlying AsyncStream's `next()`
    /// gets cancelled — `onTermination` fires and self-
    /// unsubscribes the actor entry. No continuation leak.
    public func subscribe(
        agent: QinaoSeat,
        domains: Set<QinaoSeatDomain>
    ) -> QinaoStateGraphSubscription {
        let id = "sub-\(nextSeq)"
        nextSeq += 1
        let (stream, continuation) = AsyncStream<
            QinaoStateGraphEvent
        >.makeStream(
            bufferingPolicy: .bufferingNewest(1024))
        let sid = id
        // Auto-cleanup on stream termination (consumer
        // drops the subscription, task cancellation, etc.).
        continuation.onTermination = {
            [weak self] _ in
            Task { [weak self] in
                await self?.unsubscribe(id: sid)
            }
        }
        let yield: @Sendable (
            QinaoStateGraphEvent
        ) -> Void = { event in
            continuation.yield(event)
        }
        let finish: @Sendable () -> Void = {
            continuation.finish()
        }
        continuations[id] = Continuation(
            domains: domains,
            agent: agent,
            yield: yield,
            finish: finish)
        return QinaoStateGraphSubscription(
            agent: agent,
            domains: domains,
            events: stream,
            close: { [weak self] in
                Task { [weak self] in
                    await self?.unsubscribe(id: sid)
                }
            })
    }

    /// Subscribe an agent using its canonical capability's
    /// readDomains.
    public func subscribeCanonical(
        seat: QinaoSeat
    ) -> QinaoStateGraphSubscription {
        subscribe(
            agent: seat,
            domains: seat.canonicalCapability
                .readDomains)
    }

    /// Internal — unsubscribe by id.
    private func unsubscribe(id: String) {
        if let entry = continuations[id] {
            entry.finish()
            continuations[id] = nil
        }
    }

    /// Publish an event to the bus. Subscribers whose
    /// domains include `domain` receive it; others do not.
    /// Returns the assigned sequence number.
    @discardableResult
    public func publish(
        domain: QinaoSeatDomain,
        payload: String,
        originAgent: QinaoSeat? = nil
    ) -> Int {
        publishedCount += 1
        let event = QinaoStateGraphEvent(
            domain: domain,
            payload: payload,
            originAgent: originAgent,
            sequence: publishedCount)
        for entry in continuations.values
        where entry.domains.contains(domain)
        {
            entry.yield(event)
        }
        return event.sequence
    }

    /// Inspection — total events published.
    public func totalPublished() -> Int { publishedCount }

    /// Inspection — current subscriber count.
    public func subscriberCount() -> Int {
        continuations.count
    }
}
