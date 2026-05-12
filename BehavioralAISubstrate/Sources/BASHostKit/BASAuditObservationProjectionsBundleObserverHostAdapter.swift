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
//   - Exposes a SYNC `handler` closure that wraps each
//     emission in a detached Task to forward to the
//     actor
//   - Hosts wire `adapter.handler` to the coordinator's
//     `projectionBlockEmissionHandler` slot
//
// Trade-off:Task launch overhead per emission (~µs)。
// Acceptable for the substrate's per-turn audit
// emission cadence (turns are ms-scale)。
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

    public init(
        observer:
            BASAuditObservationProjectionsBundleObserver
    ) {
        self.observer = observer
    }

    /// Sync closure ready to wire to the M1453
    /// `projectionBlockEmissionHandler` slot。 Each
    /// invocation launches a detached Task that
    /// forwards the observation to the actor's
    /// `recordEmission(_:)` method。
    public var handler: @Sendable
        (BASAuditObservationProjectionsBundleObservation)
        -> Void
    {
        let observer = self.observer
        return { observation in
            Task.detached {
                await observer.recordEmission(
                    observation)
            }
        }
    }
}
