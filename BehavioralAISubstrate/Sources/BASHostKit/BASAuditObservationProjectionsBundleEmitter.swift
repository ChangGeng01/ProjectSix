// MARK: - BASAuditObservationProjectionsBundleEmitter
// chapter 五百十三 / M1429 — typed emitter facade routing
//                            projection-block observations
//
// Static facade that takes optional Kunlun + Cthulhu input
// blocks and routes the observation to the M1426 observer
// actor via the correct M1425 factory variant
// (`.fullyCovered` / `.kunlunOnly` / `.cthulhuOnly` /
// `.uncovered`)。 Hosts emit one call per turn;the facade
// picks the right factory based on which inputs are nil。
//
// ## Why this exists
//
// Today,callers wanting to record a projection-block
// observation must:
//   1. Inspect their own state to know which blocks fired
//   2. Pick the correct M1425 factory (4 variants)
//   3. Call recordEmission(...) with the result
//
// Chapter 513 closes this with a typed facade:
//   - Pass `kunlunInputs:` / `cthulhuInputs:` (each
//     optional)
//   - Facade picks the right factory automatically
//   - Forwards to observer.recordEmission(...)
//
// This makes the wire-in idiomatic — one line at the
// emission call site instead of a 4-branch switch。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//     (facade is opt-in,no production callers wire it
//     at chapter 513 close-out)
//   - 红线 7:additive surface only
//   - chapter 三百九二:replay-determinism — facade is
//     stateless,delegates to M1425 + M1426 (both
//     replay-deterministic)
//   - chapter 四百二十九:typed-surface count 58 → 59
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1428 → M1429

import Foundation

/// Stateless typed facade routing projection-block
/// observations through the M1426 observer。 Pure
/// dispatcher — no state,no side effects beyond the
/// observer mutation。
public enum BASAuditObservationProjectionsBundleEmitter {

    /// Emit a projection-block observation to the
    /// observer。 Routes to the correct M1425 factory
    /// based on the optional pattern:
    ///
    ///   - both inputs non-nil → `.fullyCovered`
    ///   - only kunlun non-nil → `.kunlunOnly`
    ///   - only cthulhu non-nil → `.cthulhuOnly`
    ///   - both nil → `.uncovered`
    ///
    /// The facade's coverage-routing PROOF lives in
    /// `BASAuditObservationProjectionsBundleEmitterTests
    /// .testFacadeRoutesToCorrectFactory*`。
    public static func emit(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        to observer:
            BASAuditObservationProjectionsBundleObserver,
        kunlunInputs:
            BASAuditObservationProjectionsKunlunInputs?,
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs?
    ) async {
        let observation = makeObservation(
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt,
            kunlunInputs: kunlunInputs,
            cthulhuInputs: cthulhuInputs)
        await observer.recordEmission(observation)
    }

    /// Pure factory — builds the observation WITHOUT
    /// recording it。 Callers wanting to inspect the
    /// observation before recording (or wanting a
    /// synchronous build path that doesn't touch an
    /// actor) use this variant。
    public static func makeObservation(
        turnID: String,
        sessionID: String,
        emittedAt: Date,
        kunlunInputs:
            BASAuditObservationProjectionsKunlunInputs?,
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs?
    ) -> BASAuditObservationProjectionsBundleObservation {
        switch (kunlunInputs, cthulhuInputs) {
        case (let k?, let c?):
            return
                BASAuditObservationProjectionsBundleObservation
                    .fullyCovered(
                        turnID: turnID,
                        sessionID: sessionID,
                        emittedAt: emittedAt,
                        kunlunInputs: k,
                        cthulhuInputs: c)
        case (let k?, nil):
            return
                BASAuditObservationProjectionsBundleObservation
                    .kunlunOnly(
                        turnID: turnID,
                        sessionID: sessionID,
                        emittedAt: emittedAt,
                        kunlunInputs: k)
        case (nil, let c?):
            return
                BASAuditObservationProjectionsBundleObservation
                    .cthulhuOnly(
                        turnID: turnID,
                        sessionID: sessionID,
                        emittedAt: emittedAt,
                        cthulhuInputs: c)
        case (nil, nil):
            return
                BASAuditObservationProjectionsBundleObservation
                    .uncovered(
                        turnID: turnID,
                        sessionID: sessionID,
                        emittedAt: emittedAt)
        }
    }
}
