// MARK: - BASTurnRuntimeEngine — chapter 四百四 / M968
// 系统熵 reduction 第二章 第六刀
//
// Phase 2 entropy chapter 四百四 sixth cut:V2 runtime engine
// actor that wraps `BASEBrainRuntimeCoordinator` (V1 struct)
// and adds the M963 lifecycle audit channel (`turn:complete`
// envelope emission)。Pure delegation V1 invocation;byte-equal
// `BASEBrainTurnResult`。 Future commits incrementally replace
// stages with native V2 actor logic。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit + M932 LLM Engine
// pattern:
//
//   > V1 runTurn has no per-turn lifecycle channel comparable
//   > to M932 LLM Engine's start/complete event pair。 V2
//   > actor centralizes audit emission via
//   > BASTurnRuntimeAuditEnvelope。
//
// V2 actor's first-shipped surface (M968) is just delegation
// + complete-envelope emission。 V1 stays unchanged。 Hosts
// opt into V2 by constructing a `BASTurnRuntimeEngine`
// wrapping their existing coordinator + an event log。
//
// ## What this ships (M968)
//
//   - `BASTurnRuntimeEngine` actor with:
//       * coordinator: BASEBrainRuntimeCoordinator (held by ref-
//         like value semantics — struct copies are cheap +
//         immutable services keep working)
//       * eventLog: any BASEventLogStorage? (optional)
//       * sequenceCounter: per-engine monotonic sequence
//   - `runTurn(_:timestampMsOverride:)` async method
//   - When `eventLog` is wired,emits a `.complete` envelope
//     after V1 returns,with payloadJson built from
//     `BASRuntimeAuditEmissionSummary` (M967)
//   - `.start` envelope deferred to future commit (requires
//     pre-V1 sessionID/turnID derivation,which needs context
//     analysis we can't easily replicate at the V2 surface
//     yet)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四 doctrine pins
//   - chapter 二百一一 single-source-of-truth — V2's audit
//     emission collapses through ONE envelope channel
//   - chapter 三百九二 (M892) replay-determinism — pure
//     delegation + sorted-keys JSON encoding produces byte-
//     stable output for same input
//   - ADR-014 OPT-IN — V1 coordinator unchanged;hosts opt
//     into V2 by wrapping

import Foundation
import BASOrchestration
import BASRuntimeCore

/// V2 runtime engine actor wrapping V1 `BASEBrainRuntimeCoordinator`
/// + adding the M963 lifecycle audit channel。
public actor BASTurnRuntimeEngine {

    // MARK: - Dependencies

    private let coordinator: BASEBrainRuntimeCoordinator
    private let eventLog: (any BASEventLogStorage)?
    private let eventIDFactory: @Sendable () -> String
    private let clockMs: @Sendable () -> Int64

    // MARK: - Mutable state (actor-isolated)

    private var sequenceCounter: Int = 0

    // MARK: - Init

    public init(
        coordinator: BASEBrainRuntimeCoordinator,
        eventLog: (any BASEventLogStorage)? = nil,
        eventIDFactory: @escaping @Sendable () -> String =
            { UUID().uuidString },
        clockMs: @escaping @Sendable () -> Int64 =
            { Int64(Date().timeIntervalSince1970 * 1000) }
    ) {
        self.coordinator = coordinator
        self.eventLog = eventLog
        self.eventIDFactory = eventIDFactory
        self.clockMs = clockMs
    }

    /// chapter 四百七 / M998 — convenience init taking the
    /// typed `BASTurnRuntimeEngineConfiguration` bundle (M998)
    /// instead of 4 separate params。 Hosts construct one
    /// config + reuse across multiple actor instances or host
    /// runtime restarts。
    public init(
        coordinator: BASEBrainRuntimeCoordinator,
        configuration: BASTurnRuntimeEngineConfiguration
    ) {
        self.init(
            coordinator: coordinator,
            eventLog: configuration.eventLog,
            eventIDFactory: configuration.eventIDFactory,
            clockMs: configuration.clockMs)
    }

    // MARK: - runTurn

    /// V2 runTurn:delegates to V1 coordinator,then emits a
    /// `.complete` audit envelope on the wired event log
    /// (when present)。Byte-equal to V1's result。
    ///
    /// chapter 四百六 / M989:`auditProjections` parameter
    /// added。 Hosts pre-build the M976
    /// `BASRuntimeAuditProjectionsBundle` (5 namespace slots
    /// for kunlun / abyssal / cthulhu / tribunal /
    /// riskCalibration) and pass it here。 The V2 actor
    /// surfaces the bundle's `populatedSlotCount` in the
    /// `.complete` envelope payload for downstream audit
    /// consumers。
    public func runTurn(
        _ request: BASEBrainTurnRequest,
        auditProjections:
            BASRuntimeAuditProjectionsBundle? = nil,
        permitEscalationLedger:
            BASPermitEscalationLedger? = nil,
        timestampMsOverride: Int64? = nil
    ) async -> BASEBrainTurnResult {
        let result = coordinator.runTurn(request)
        // chapter 四百六 / M991: V2 actor now emits BOTH .start
        // and .complete lifecycle envelopes per turn。 Both fire
        // post-V1 so they share the V1-derived sessionID/turnID
        // (audit-consistent;sacrifices "start fires before V1"
        // semantics for ID-coherence which audit consumers
        // prioritize)。 Sequence numbers preserve start-before-
        // complete ordering。
        // chapter 四百六 v2 / M996: optional permitEscalationLedger
        // (M966 typed) param threads firedStageCount into the
        // .complete envelope payload。
        await emitStartEnvelope(
            for: result,
            timestampMsOverride: timestampMsOverride)
        await emitCompleteEnvelope(
            for: result,
            auditProjections: auditProjections,
            permitEscalationLedger: permitEscalationLedger,
            timestampMsOverride: timestampMsOverride)
        return result
    }

    // MARK: - Audit emission

    private func emitStartEnvelope(
        for result: BASEBrainTurnResult,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1
        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let envelope = BASTurnRuntimeAuditEnvelope.start(
            turnID: turnID,
            sessionID: result.runtimeTrace.sessionID,
            timestampMs: timestampMs,
            sequenceNumber: nextSeq)
        // chapter 四百六 v2 / M995 — typed extension collapses
        // 9-line entry construction + append to 1 call。
        await log.appendTurnEnvelope(
            envelope,
            eventID: eventIDFactory())
    }

    private func emitCompleteEnvelope(
        for result: BASEBrainTurnResult,
        auditProjections:
            BASRuntimeAuditProjectionsBundle?,
        permitEscalationLedger:
            BASPermitEscalationLedger?,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1

        // chapter 四百六 / M993 + M996 — typed factory call
        // collapses 12-line summary construction to 1 line +
        // threads permit escalation ledger fired-stage count
        // through the .complete envelope payload。
        let summary = BASRuntimeAuditEmissionSummary.from(
            result: result,
            auditProjections: auditProjections,
            permitEscalationLedger: permitEscalationLedger)

        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let envelope = BASTurnRuntimeAuditEnvelope.complete(
            turnID: turnID,
            sessionID: result.runtimeTrace.sessionID,
            timestampMs: timestampMs,
            sequenceNumber: nextSeq,
            payloadJson: summary.payloadJson())
        // chapter 四百六 v2 / M995 — typed extension collapses
        // 9-line entry construction + append to 1 call。
        await log.appendTurnEnvelope(
            envelope,
            eventID: eventIDFactory())
    }
}
