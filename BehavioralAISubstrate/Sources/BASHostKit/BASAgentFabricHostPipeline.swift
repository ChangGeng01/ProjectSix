// MARK: - BASAgentFabricHostPipeline
// chapter 九百九十五 / M3680 — Host application reference pipeline
//
// After ch 953-994.7 the substrate ships:
//   - 9 cross-module adapters
//   - 2 cross-module bridges (warrant audit + trace log fan-out)
//   - 1 host-integration convenience adapter
//   - 1 env-var gate
//   - 11 reserved L14 prefixes
//   - 14,447 substrate-wide tests at 0 failures
//
// What was still missing:**a reference host pipeline** that any
// host can drop into their per-turn flow。 Pre-ch-995 a host had
// to:
//   1. Manually pull live service inputs from 6 services
//   2. Construct BASAgentFabricLiveInputs themselves
//   3. Call BASAgentFabricFullTurnAdapter.run(...)
//   4. Consume the result + propagate to downstream consumers
//   5. Manage env-var gate activation
//   6. Handle errors + log appropriately
//
// This file ships a REFERENCE pipeline class that bundles
// steps 1-6 into one entry point。 Hosts call:
//
//     let pipeline = BASAgentFabricHostPipeline(
//         coordinator: coordinator,
//         warrantLedger: ledger,    // optional
//         traceLogBridge: bridge)   // optional
//     let outcome = try await pipeline.runTurn(
//         turnID: "t.1",
//         decomposeFrame: frame,
//         candidatePaths: paths)
//
// And the pipeline:
//   1. Probes env-var gate;skips if disabled
//   2. Pulls live BASRiskCard via riskService.calibrateRisk
//   3. Pulls live BASTriSelfScore[] via triSelfService.mergeChoice
//   4. Pulls live BASHostConstitution from coordinator
//   5. Assembles BASAgentFabricLiveInputs
//   6. Calls BASAgentFabricFullTurnAdapter.run(...)
//   7. Returns a BASAgentFabricHostOutcome bundling the result
//      + a structured log of what happened
//
// Host can then use the outcome to:
//   - Drive UI surface (read result.turnResult.emittedDeltas)
//   - Consume warrant audit (result.warrantAuditEntry)
//   - Display frontier projection (result.frontierProjection)
//   - Log pipeline diagnostics (outcome.diagnostics)
//
// Pure-fn discipline preserved for service input building。 The
// pipeline does NOT mutate any coordinator state — it consumes
// services via the protocol surface only。
//
// ADR-014 OPT-IN preserved — hosts that don't construct
// BASAgentFabricHostPipeline see byte-equal pre-ch-995 behavior。

import Foundation
import BASMemory
import BASOrchestration
import BASRuntimeCore
import BASPolicy
import BASSovereign

/// Outcome bundle returned by `BASAgentFabricHostPipeline.runTurn`。
/// Captures both the fabric result + structured diagnostics so a
/// host can introspect the pipeline run。
public struct BASAgentFabricHostOutcome: Sendable {
    /// The fabric's turn result (deltas + merge + apply)。 Nil
    /// when fabric was disabled by env-var gate or coordinator
    /// didn't have fabric configured。
    public let result: BASAgentFabricFullTurnResult?

    /// Whether the pipeline actually ran the fabric (false =
    /// skipped due to gate / nil fabric)。
    public let activated: Bool

    /// Reason for non-activation (when activated == false)。
    /// Nil when activated。 Useful for host logging。
    public let skipReason: String?

    /// Structured diagnostics for host logging:
    ///   - "gate.fabric": "enabled"/"disabled"
    ///   - "gate.tier": "core"/"all"
    ///   - "card.totalRisk": "0.85"
    ///   - "tri.veto-count": "1"
    ///   - "deltas.emitted": "9"
    ///   - "warrant.audit": "appended"/"skipped"
    ///   - "trace.flushed": "9"
    /// Pure-fn assembled (no I/O at log site — host decides
    /// what to do with the diagnostics)。
    public let diagnostics: [String: String]

    public init(
        result: BASAgentFabricFullTurnResult?,
        activated: Bool,
        skipReason: String? = nil,
        diagnostics: [String: String] = [:]
    ) {
        self.result = result
        self.activated = activated
        self.skipReason = skipReason
        self.diagnostics = diagnostics
    }
}

/// Reference host pipeline for the agent fabric。 One instance
/// per coordinator + per session;`runTurn` is called once per
/// per-turn cycle from the host's per-turn loop。
///
/// Thread safety:the pipeline holds a reference to the
/// `BASEBrainRuntimeCoordinator` (which is a class with mutable
/// `agentFabric` slot,not Sendable across actor boundaries by
/// design)。 The pipeline itself is intended to be held by a
/// single actor / main context per the host's per-turn loop。
/// Cross-actor use should pass the pipeline through an actor
/// boundary explicitly or rebuild per-actor。
public struct BASAgentFabricHostPipeline {

    private let coordinator: BASEBrainRuntimeCoordinator
    private let warrantLedger: BASSovereignAuditLedger?
    private let traceLogBridge:
        BASAgentTraceLogEventLogBridge?
    private let sessionID: String
    private let environmentOverride: [String: String]?

    public init(
        coordinator: BASEBrainRuntimeCoordinator,
        sessionID: String,
        warrantLedger: BASSovereignAuditLedger? = nil,
        traceLogBridge:
            BASAgentTraceLogEventLogBridge? = nil,
        environmentOverride: [String: String]? = nil
    ) {
        self.coordinator = coordinator
        self.sessionID = sessionID
        self.warrantLedger = warrantLedger
        self.traceLogBridge = traceLogBridge
        self.environmentOverride = environmentOverride
    }

    /// Drive one full fabric turn through the host pipeline。
    /// Returns a `BASAgentFabricHostOutcome` whether or not the
    /// fabric actually ran — host can inspect `activated` +
    /// `skipReason` to decide downstream action。
    ///
    /// Errors propagate from the underlying adapters (warrant
    /// ledger append + trace flush)。 Host MUST handle throw OR
    /// catch + log gracefully。
    ///
    /// - Parameters:
    ///   - turnID: per-turn ID for ref namespacing + audit refs
    ///   - decomposeFrame: live L7 frame (host's per-turn pipeline)
    ///   - candidatePaths: live L9 candidate paths
    ///   - acceptedCandidateID: optional winner if pre-decided
    ///   - warrantValidation: optional warrant outcome to audit
    public func runTurn(
        turnID: String,
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String? = nil,
        warrantValidation: (
            result: BASWarrantValidationResult,
            externalAgentID: String)? = nil,
        nowNanos: Int64 = 0
    ) async throws -> BASAgentFabricHostOutcome {
        var diagnostics: [String: String] = [:]

        // Step 1:gate check
        let activation = BASAgentFabricGate
            .activationFromEnvironment(environmentOverride)
        diagnostics["gate.fabric"] =
            activation.fabricEnabled ? "enabled" : "disabled"
        diagnostics["gate.tier"] = activation.tier.rawValue
        diagnostics["gate.transcriptMode"] =
            activation.transcriptMode.rawValue
        guard activation.fabricEnabled else {
            return BASAgentFabricHostOutcome(
                result: nil,
                activated: false,
                skipReason: "env-var gate disabled fabric",
                diagnostics: diagnostics)
        }
        guard coordinator.agentFabric != nil else {
            return BASAgentFabricHostOutcome(
                result: nil,
                activated: false,
                skipReason:
                    "coordinator has no agentFabric configured",
                diagnostics: diagnostics)
        }

        // Step 2:assemble live inputs
        // Note:in this reference implementation we don't pull
        // BASRiskCard / BASTriSelfScore from services because
        // doing so requires a fully-built thoughtFrame /
        // contextFrame which the host's per-turn pipeline owns。
        // Host implementations override `enrichLiveInputs(...)`
        // by building their own pipeline subclass or by passing
        // additional parameters。 The reference pipeline ships
        // the GATE + ADAPTER WIRING;the host-specific service
        // input building is per-host concern by design。
        let liveInputs = BASAgentFabricLiveInputs(
            frame: decomposeFrame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: acceptedCandidateID,
            hostConstitution:
                coordinator.hostConstitution,
            warrantValidation: warrantValidation,
            nowNanos: nowNanos)

        if let constitution = coordinator.hostConstitution {
            diagnostics["host.id"] = constitution.hostID
        }
        diagnostics["candidates.count"] =
            "\(candidatePaths.count)"

        // Step 3:invoke fabric through convenience adapter
        let result = try await BASAgentFabricFullTurnAdapter
            .run(
                sessionID: sessionID,
                turnID: turnID,
                liveInputs: liveInputs,
                coordinator: coordinator,
                warrantLedger: warrantLedger,
                traceLogBridge: traceLogBridge)

        // Step 4:diagnostics from result
        if let result {
            diagnostics["deltas.emitted"] =
                "\(result.turnResult.emittedDeltas.count)"
            diagnostics["deltas.accepted"] =
                "\(result.turnResult.mergeResult.acceptedDeltaIDs.count)"
            diagnostics["warrant.audit"] =
                result.warrantAuditEntry != nil ?
                    "appended" : "skipped"
            if let flushed = result.flushedTraceEventCount {
                diagnostics["trace.flushed"] = "\(flushed)"
            } else {
                diagnostics["trace.flushed"] = "skipped"
            }
            diagnostics["frontier.width"] =
                "\(result.frontierProjection.frontierWidth)"
            diagnostics["frontier.guarded"] =
                "\(result.frontierProjection.guardPaths.count)"
        }

        return BASAgentFabricHostOutcome(
            result: result,
            activated: true,
            diagnostics: diagnostics)
    }
}
