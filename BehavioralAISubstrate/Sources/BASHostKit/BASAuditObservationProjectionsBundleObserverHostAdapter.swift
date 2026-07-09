// MARK: - BASAuditObservationProjectionsBundleObserverHostAdapter
// chapter 五百二十 / M1457 — host adapter bridging the
//                            sync M1453 handler slot to
//                            the M1426 actor observer
//
// ## Why this exists
//
// Chapter 519 (M1453+M1454) shipped a SYNCHRONOUS
// closure slot (`projectionBlockEmissionHandler`) on
// BASEBrainRuntimeCoordinator。 The V1 monolith fires
// this slot with a typed observation per turn。
//
// However,the chapter 512 observer infrastructure
// (`BASAuditObservationProjectionsBundleObserver`)
// is an ACTOR — its `recordEmission(_:)` method is
// async-isolated。 The sync slot can't directly call
// the actor's async API without wrapping the call。
//
// This adapter is the typed bridge:
//
//   - Takes a `BASAuditObservationProjectionsBundle
//     Observer` actor instance
//   - Exposes a SYNC `handler` closure that FIFO-enqueues
//     each emission onto a single ordered pump, which
//     forwards them to the actor in ARRIVAL order
//   - Hosts wire `adapter.handler` to the coordinator's
//     `projectionBlockEmissionHandler` slot
//
// Trade-off:one long-lived consumer Task per adapter (not
// per emission)。 The sync `yield` is O(1);ordering is
// guaranteed by the single consumer, honoring 章节 三百九二
// (audit hostkit-rest MED-5 — the prior per-emission
// Task.detached delivered in scheduler order, not arrival)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (adapter is a fully optional bridge,V1 hot path
//     unchanged when adapter not constructed)
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — adapter
//     is the ONLY supported way to bridge sync handler
//     to actor observer (avoids ad-hoc Task launches at
//     each host)
//   - chapter 三百九二:replay-determinism preserved —
//     each emission is a value-type record fired in
//     arrival order through the actor
//   - chapter 四百二十九:typed-surface count 64 → 65
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1456 → M1457

import Foundation
import BASRuntimeCore

/// Order-preserving serial pump (audit hostkit-rest MED-5). A SINGLE long-lived
/// consumer drains a FIFO `AsyncStream` into the actor observer, so emissions land
/// in ARRIVAL order. The prior adapter launched a `Task.detached` PER emission, so
/// N independent tasks reached the actor in SCHEDULER order — silently breaking the
/// chapter 三百九二 "replay-determinism, fired in arrival order" contract the
/// header still pins (a comment-lie: detached tasks are unordered). `yield` is
/// synchronous + thread-safe + FIFO, so it captures the sync handler's arrival order
/// exactly; the single consumer then appends strictly in that order.
private final class BASAuditEmissionOrderedPump: Sendable {
    private let continuation:
        AsyncStream<BASAuditObservationProjectionsBundleObservation>.Continuation

    init(observer: BASAuditObservationProjectionsBundleObserver) {
        let (stream, continuation) = AsyncStream<
            BASAuditObservationProjectionsBundleObservation>.makeStream()
        self.continuation = continuation
        // Exactly ONE consumer ⇒ records append in yield (arrival) order, never
        // interleaved. Unbounded buffering (makeStream default) ⇒ no emission dropped.
        Task {
            for await observation in stream {
                await observer.recordEmission(observation)
            }
        }
    }

    /// Synchronous, thread-safe, FIFO enqueue — captures arrival order exactly.
    func submit(_ observation: BASAuditObservationProjectionsBundleObservation) {
        continuation.yield(observation)
    }
}

/// Typed bridge from the M1453 sync handler slot to the
/// M1426 actor observer。 Hosts wire `adapter.handler`
/// to the coordinator's
/// `projectionBlockEmissionHandler` parameter at
/// construction time。
public struct BASAuditObservationProjectionsBundleObserverHostAdapter:
    Sendable
{

    /// The actor observer this adapter routes
    /// emissions into。
    public let observer:
        BASAuditObservationProjectionsBundleObserver

    /// The order-preserving pump backing `handler`。 One consumer per adapter,
    /// created at init so every emission through this adapter is serialized in
    /// arrival order (audit hostkit-rest MED-5).
    private let pump: BASAuditEmissionOrderedPump

    public init(
        observer:
            BASAuditObservationProjectionsBundleObserver
    ) {
        self.observer = observer
        self.pump = BASAuditEmissionOrderedPump(observer: observer)
    }

    /// Sync closure ready to wire to the M1453
    /// `projectionBlockEmissionHandler` slot。 Each
    /// invocation FIFO-enqueues the observation onto the
    /// adapter's single ordered pump, which forwards it to
    /// the actor's `recordEmission(_:)` in arrival order。
    public var handler: @Sendable
        (BASAuditObservationProjectionsBundleObservation)
        -> Void
    {
        let pump = self.pump
        return { observation in
            pump.submit(observation)
        }
    }
}
