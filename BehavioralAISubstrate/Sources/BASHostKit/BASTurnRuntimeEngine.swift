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

    // MARK: - runTurn

    /// V2 runTurn:delegates to V1 coordinator,then emits a
    /// `.complete` audit envelope on the wired event log
    /// (when present)。Byte-equal to V1's result。
    public func runTurn(
        _ request: BASEBrainTurnRequest,
        timestampMsOverride: Int64? = nil
    ) async -> BASEBrainTurnResult {
        let result = coordinator.runTurn(request)
        await emitCompleteEnvelope(
            for: result,
            timestampMsOverride: timestampMsOverride)
        return result
    }

    // MARK: - Audit emission

    private func emitCompleteEnvelope(
        for result: BASEBrainTurnResult,
        timestampMsOverride: Int64?
    ) async {
        guard let log = eventLog else { return }
        let timestampMs = timestampMsOverride ?? clockMs()
        let nextSeq = sequenceCounter
        sequenceCounter += 1

        let summary = BASRuntimeAuditEmissionSummary(
            traceID: result.runtimeTrace.sessionID,
            verdictLevelRaw:
                result.sovereignVerdict?
                    .verdictLevel.rawValue ?? "unassigned",
            permitModeRaw:
                result.actionPermit.mode.rawValue,
            ticketCount: result.updateTickets.count,
            auditID:
                result.sovereignAuditEntry?
                    .auditID ?? "unassigned",
            runMode: result.budgetFrame.runMode.rawValue)

        let turnID =
            result.sovereignAuditEntry?.turnID ??
            result.runtimeTrace.sessionID
        let envelope = BASTurnRuntimeAuditEnvelope.complete(
            turnID: turnID,
            sessionID: result.runtimeTrace.sessionID,
            timestampMs: timestampMs,
            sequenceNumber: nextSeq,
            payloadJson: summary.payloadJson())

        let entry = BASEventLogEntry(
            eventID: eventIDFactory(),
            timestampMs: envelope.timestampMs,
            kind: .substrateAudit,
            sessionID: envelope.sessionID,
            sequenceNumber: 0,
            source: "turn-runtime-engine",
            turnRef: envelope.turnID,
            actions: ["turn-complete"],
            payloadJson: envelope.payloadJson)
        _ = try? await log.append(entry)
    }
}
