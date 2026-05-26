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
///
/// chapter 九百九十五.7 META-REVIEW Round-13 MED-1 fix:added
/// typed `activation` + `fabricMode` fields so host code can
/// branch on them WITHOUT re-parsing strings from diagnostics dict。
/// Pre-fix everything was stringly-typed (host had to do
/// `BASAgentFabricMode(rawValue: outcome.diagnostics["fabric.mode"]
/// ?? "")`)。 Now host writes `if outcome.fabricMode ==
/// .authoritative { ... }` directly。 Diagnostics dict preserved
/// as supplementary string view per Round-12 doctrine。
///
/// chapter 九百九十五.9 META-REVIEW Round-14 CRITICAL-2 honest
/// disclosure:as of ch 995.9 these typed fields (activation +
/// fabricMode) have ZERO consumers in `Sources/`。 They are
/// SDK observability surfaces for HOST applications to inspect。
/// The substrate itself does NOT branch on them — that's per
/// the ch 994 scaffold doctrine (mode is a signal,not a behavior
/// switch;tier/transcriptMode are advisory only)。 Round-14
/// caught that this matches the SAME class of issue as Round-12's
/// `BASAgentFabricMode` dead-code finding,one layer deeper。
/// Disclosure preserved:these fields are PUBLIC API for host
/// consumers,not internal substrate plumbing。
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

    /// chapter 九百九十五.7 Round-13 MED-1:typed env-var gate
    /// activation。 Carries fabricEnabled / tier / transcriptMode /
    /// activeAgents as typed values。 Always populated (even when
    /// activated=false — host can inspect gate state)。
    public let activation: BASAgentFabricGate.Activation

    /// chapter 九百九十五.7 Round-13 MED-1 + LOW-1:typed fabric
    /// mode (signal,not behavior switch — per scaffold doctrine
    /// substrate doesn't branch on this)。 Nil only when
    /// `coordinator.agentFabric == nil` (no fabric configured);
    /// non-nil even when activated=false due to gate disabled,
    /// so host can distinguish "fabric configured but gate off"
    /// from "no fabric at all"。
    public let fabricMode: BASAgentFabricMode?

    /// Structured diagnostics for host logging。
    ///
    /// **Keys always present** (regardless of activated):
    ///   - "gate.fabric": "enabled"/"disabled"
    ///   - "gate.tier": tier rawValue ("core"/"all")
    ///   - "gate.transcriptMode": rawValue
    ///   - "gate.activeAgents": csv of agent names
    ///   - "fabric.mode": rawValue OR "unconfigured" when
    ///     coordinator has no fabric
    ///
    /// **Keys present only when activated**:
    ///   - "candidates.count": count of input candidatePaths
    ///   - "risk.card-supplied": "yes"/"no"
    ///   - "risk.totalRisk": numeric (when risk.card-supplied=yes)
    ///     [chapter 九百九十五.7 Round-13 HIGH-1 fix:was promised
    ///     in pre-fix docstring as "card.totalRisk" but never
    ///     emitted — now actually emitted under the corrected key]
    ///   - "tri.scores-count": count
    ///   - "tri.veto-count": count of vetoed scores (HIGH-1
    ///     fix:was promised but never emitted)
    ///   - "memory.input-supplied": "yes"/"no"
    ///   - "critic.input-supplied": "yes"/"no" (derived from
    ///     non-empty triScores)
    ///   - "sovereign.input-supplied": "yes"/"no"
    ///   - "evolution.input-supplied": "yes"/"no"
    ///   - "priority.tier-count": total agents tagged across
    ///     sovereign + risk + host tiers in priorityContext
    ///   - "host.id": from constitution
    ///
    /// **Keys present only when activated + result non-nil**:
    ///   - "deltas.emitted" / "deltas.accepted"
    ///   - "warrant.audit": "appended"/"skipped"
    ///   - "trace.flushed": count or "skipped"
    ///   - "frontier.width" / "frontier.guarded"
    ///
    /// Pure-fn assembled (no I/O at log site — host decides
    /// what to do with the diagnostics)。
    public let diagnostics: [String: String]

    public init(
        result: BASAgentFabricFullTurnResult?,
        activated: Bool,
        skipReason: String? = nil,
        activation: BASAgentFabricGate.Activation =
            BASAgentFabricGate.Activation(),
        fabricMode: BASAgentFabricMode? = nil,
        diagnostics: [String: String] = [:]
    ) {
        self.result = result
        self.activated = activated
        self.skipReason = skipReason
        self.activation = activation
        self.fabricMode = fabricMode
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
        riskCard: BASRiskCard? = nil,
        triScores: [BASTriSelfScore] = [],
        memoryInput: BASMemorySeatInput? = nil,
        sovereignSentinelInput:
            BASSovereignSentinelInput? = nil,
        evolutionShadowInput:
            BASEvolutionShadowInput? = nil,
        warrantValidation: (
            result: BASWarrantValidationResult,
            externalAgentID: String)? = nil,
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) async throws -> BASAgentFabricHostOutcome {
        // chapter 九百九十五.5 META-REVIEW Round-12 CRITICAL-1
        // fix:pre-fix this method accepted only 5 of 12
        // BASAgentFabricLiveInputs fields as parameters → the
        // other 6 enrichment inputs (riskCard / triScores /
        // memoryInput / sovereignSentinelInput /
        // evolutionShadowInput / priorityContext) were
        // unreachable through the pipeline。 SAME CLASS as
        // Round-10 riskCard and Round-11 priorityContext orphan
        // catches — but at the wrapping layer。 Fix:extended
        // signature to accept all 6 fields as defaulted-nil/
        // -empty parameters。
        var diagnostics: [String: String] = [:]

        // Step 1:gate check
        let activation = BASAgentFabricGate
            .activationFromEnvironment(environmentOverride)
        diagnostics["gate.fabric"] =
            activation.fabricEnabled ? "enabled" : "disabled"
        diagnostics["gate.tier"] = activation.tier.rawValue
        diagnostics["gate.transcriptMode"] =
            activation.transcriptMode.rawValue
        // chapter 九百九十五.5 META-REVIEW Round-12 MED-2 fix:
        // gate.activeAgents was parsed but silently dropped。
        diagnostics["gate.activeAgents"] =
            activation.activeAgents.joined(separator: ",")
        // chapter 九百九十五.7 Round-13 LOW-1 fix:always surface
        // fabric.mode even when coordinator.agentFabric == nil
        // (use "unconfigured" sentinel)。 Pre-fix the key was
        // omitted entirely on nil fabric → host couldn't
        // distinguish "key not implemented" from "no fabric"。
        let resolvedMode = coordinator.agentFabric?.mode
        diagnostics["fabric.mode"] =
            resolvedMode?.rawValue ?? "unconfigured"
        guard activation.fabricEnabled else {
            return BASAgentFabricHostOutcome(
                result: nil,
                activated: false,
                skipReason: "env-var gate disabled fabric",
                activation: activation,
                fabricMode: resolvedMode,
                diagnostics: diagnostics)
        }
        guard coordinator.agentFabric != nil else {
            return BASAgentFabricHostOutcome(
                result: nil,
                activated: false,
                skipReason:
                    "coordinator has no agentFabric configured",
                activation: activation,
                fabricMode: resolvedMode,
                diagnostics: diagnostics)
        }

        // Step 2:assemble live inputs
        // chapter 九百九十五.5 Round-12 CRITICAL-1:all 12
        // fields now flow through from the runTurn parameters
        // (or coordinator.hostConstitution which the pipeline
        // can read directly without per-call params)。
        let liveInputs = BASAgentFabricLiveInputs(
            frame: decomposeFrame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: acceptedCandidateID,
            hostConstitution:
                coordinator.hostConstitution,
            riskCard: riskCard,
            triScores: triScores,
            memoryInput: memoryInput,
            sovereignSentinelInput:
                sovereignSentinelInput,
            evolutionShadowInput:
                evolutionShadowInput,
            warrantValidation: warrantValidation,
            priorityContext: priorityContext,
            nowNanos: nowNanos)

        if let constitution = coordinator.hostConstitution {
            diagnostics["host.id"] = constitution.hostID
        }
        diagnostics["candidates.count"] =
            "\(candidatePaths.count)"
        // chapter 九百九十五.7 Round-13 CRITICAL-1 fix:emit a
        // diagnostic key for EACH of the 6 orphan-fix fields so
        // the regression tests can verify each path
        // independently。 Pre-fix only risk + tri were emitted;
        // memory/sovereign/evolution/priority orphans had no
        // observable signal → tests couldn't verify them。
        diagnostics["risk.card-supplied"] =
            riskCard != nil ? "yes" : "no"
        // chapter 九百九十五.7 Round-13 HIGH-1 fix:emit the
        // numeric risk card totalRisk that the pre-fix docstring
        // promised but never produced。
        // chapter 九百九十五.9 Round-14 MED-2 fix:renamed key
        // from "risk.totalRisk" to "risk.cardTotalRisk" to be
        // explicit that this is the INPUT card value,not the
        // enriched merged pressure that reaches the Risk seat。
        // (The enriched value is computed inside
        // BASAgentFabricFullTurnAdapter and isn't currently
        // plumbed back — host inspecting "what reached the seat"
        // would need separate plumbing。)
        if let card = riskCard {
            diagnostics["risk.cardTotalRisk"] =
                String(format: "%.4f", card.totalRisk)
        }
        diagnostics["tri.scores-count"] =
            "\(triScores.count)"
        // chapter 九百九十五.7 Round-13 HIGH-1 fix:emit
        // tri.veto-count promised by pre-fix docstring but
        // never produced。
        diagnostics["tri.veto-count"] =
            "\(triScores.filter { $0.veto }.count)"
        // chapter 九百九十五.7 Round-13 CRITICAL-1 fix:
        // diagnostics for the 4 previously-test-unverifiable
        // orphan fields
        diagnostics["memory.input-supplied"] =
            memoryInput != nil ? "yes" : "no"
        diagnostics["critic.input-supplied"] =
            !triScores.isEmpty ? "yes" : "no"
        diagnostics["sovereign.input-supplied"] =
            sovereignSentinelInput != nil ? "yes" : "no"
        diagnostics["evolution.input-supplied"] =
            evolutionShadowInput != nil ? "yes" : "no"
        let priorityTierTotal =
            priorityContext.sovereignAgentIDs.count +
            priorityContext.riskAgentIDs.count +
            priorityContext.hostAgentIDs.count
        diagnostics["priority.tier-count"] =
            "\(priorityTierTotal)"

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
            activation: activation,
            fabricMode: resolvedMode,
            diagnostics: diagnostics)
    }
}
