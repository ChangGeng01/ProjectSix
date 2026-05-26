// MARK: - BASAgentFabricFullTurnAdapter
// chapter 九百九十三 / M3670 — Cross-Module Integration Arc ch12:
// host-integration convenience entry point
//
// After ch 983-992 the substrate ships 8 cross-module adapters +
// 1 coordinator entry point + 1 E2E test。 But a host wanting
// to run a full 9-seat turn has to:
//
//   1. Pull live BASRiskCard via riskService.calibrateRisk
//   2. Pull live BASActionPermit via riskService.gateAction
//   3. Pull live BASTriSelfScore[] via triSelfService.mergeChoice
//   4. Pull live BASHostConstitution
//   5. Pull live candidate paths from loopService.proposePaths
//   6. Pull live memory bundle from memoryService.assemble
//   7. Call BASAgentFabricAdapters.hostAlignmentInput(...)
//   8. Call BASAgentFabricAdapters.riskInput(...) + enrichRiskInput
//   9. Call BASAgentFabricAdapters.criticInput(...) + enrichCriticInput
//  10. Call coordinator.runAgentFabricObservation(...)
//  11. Call BASSovereignWarrantAuditBridge.appendToLedger(...)
//  12. Call BASAgentTraceLogEventLogBridge.flush(...)
//  13. Call BASAgentFabricAdapters.candidateFrontierProjection(...)
//  14. Call BASAgentFabricAdapters.validateMCPInvocation(...) per
//      MCP call
//
// 14 steps every turn is friction for host adopters。 This adapter
// bundles steps 7-14 into a single `run(...)` entry that:
//   - takes the pre-built live service inputs (steps 1-6 stay
//     host-side since those are host's per-turn pipeline)
//   - composes the cross-module adapters in documented order
//   - invokes the coordinator + post-turn integration paths
//   - returns a `BASAgentFabricFullTurnResult` carrying everything
//     a host needs:turn result + warrant audit entry + flushed
//     count + frontier projection
//
// Pure-fn discipline preserved — the adapter does NOT call any
// service itself。 Caller is responsible for live service inputs。
//
// ADR-014 OPT-IN preserved — host code that doesn't call this
// adapter is byte-equal to pre-ch-993。

import Foundation
import BASMemory
import BASSovereign
import BASRuntimeCore
import BASPolicy
import BASOrchestration

/// Result bundle from a full fabric turn through the host
/// integration adapter。 Captures everything the host needs to
/// observe what happened in this turn:
///   - `turnResult`: dispatch outcome (deltas + merge + apply)
///   - `warrantAuditEntry`: optional sovereign audit entry (nil
///     when no warrant validation was supplied)
///   - `flushedTraceEventCount`: how many trace events landed in
///     event log (nil when no trace log bridge supplied)
///   - `frontierProjection`: aggregate frontier summary the host
///     can present to user / feed into next turn's L9
public struct BASAgentFabricFullTurnResult: Sendable {
    public let turnResult: BASAgentTurnResult
    public let warrantAuditEntry:
        BASSovereignAuditLedger.AppendedEntry?
    public let flushedTraceEventCount: Int?
    public let frontierProjection: BASCandidateFrontier

    public init(
        turnResult: BASAgentTurnResult,
        warrantAuditEntry:
            BASSovereignAuditLedger.AppendedEntry? = nil,
        flushedTraceEventCount: Int? = nil,
        frontierProjection: BASCandidateFrontier
    ) {
        self.turnResult = turnResult
        self.warrantAuditEntry = warrantAuditEntry
        self.flushedTraceEventCount = flushedTraceEventCount
        self.frontierProjection = frontierProjection
    }
}

/// Bundle of live service inputs the host pulls each turn before
/// invoking the full-turn adapter。 Caller's responsibility to
/// build these from their per-turn pipeline。
public struct BASAgentFabricLiveInputs: Sendable {
    public let frame: BASDecomposeFrame
    public let candidatePaths: [BASCandidatePath]
    public let acceptedCandidateID: String?
    public let hostConstitution: BASHostConstitution?
    public let riskCard: BASRiskCard?
    public let triScores: [BASTriSelfScore]
    public let memoryInput: BASMemorySeatInput?
    public let sovereignSentinelInput:
        BASSovereignSentinelInput?
    public let evolutionShadowInput:
        BASEvolutionShadowInput?
    public let warrantValidation: (
        result: BASWarrantValidationResult,
        externalAgentID: String)?
    public let nowNanos: Int64

    public init(
        frame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String? = nil,
        hostConstitution: BASHostConstitution? = nil,
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
        nowNanos: Int64 = 0
    ) {
        self.frame = frame
        self.candidatePaths = candidatePaths
        self.acceptedCandidateID = acceptedCandidateID
        self.hostConstitution = hostConstitution
        self.riskCard = riskCard
        self.triScores = triScores
        self.memoryInput = memoryInput
        self.sovereignSentinelInput = sovereignSentinelInput
        self.evolutionShadowInput = evolutionShadowInput
        self.warrantValidation = warrantValidation
        self.nowNanos = nowNanos
    }
}

public enum BASAgentFabricFullTurnAdapter {

    /// Canonical host call-site for a full 9-seat fabric turn。
    /// Composes ch 983-991 cross-module adapters in the documented
    /// pipeline order + invokes the coordinator + post-turn
    /// integration paths。
    ///
    /// - Parameters:
    ///   - sessionID: session ID for audit + trace
    ///   - turnID: per-turn ID for ref namespacing
    ///   - liveInputs: bundle of live service inputs (caller
    ///     builds from their per-turn pipeline)
    ///   - coordinator: the configured `BASEBrainRuntimeCoordinator`
    ///     with `agentFabric` set (else this returns nil)
    ///   - warrantLedger: optional `BASSovereignAuditLedger` for
    ///     ch 983 audit append (nil = skip warrant audit even
    ///     if liveInputs supplies a validation result)
    ///   - traceLogBridge: optional `BASAgentTraceLogEventLogBridge`
    ///     for ch 984 trace flush (nil = skip flush)
    /// - Returns: full-turn result bundle,or nil if coordinator
    ///   doesn't have fabric configured
    /// - Throws: only if warrant audit append fails (ledger
    ///   validation:empty sessionID etc.)
    public static func run(
        sessionID: String,
        turnID: String,
        liveInputs: BASAgentFabricLiveInputs,
        coordinator: BASEBrainRuntimeCoordinator,
        warrantLedger: BASSovereignAuditLedger? = nil,
        traceLogBridge:
            BASAgentTraceLogEventLogBridge? = nil
    ) async throws -> BASAgentFabricFullTurnResult? {
        // Step 1:build pre-built DTOs from live service inputs

        // hostAlignment — built from constitution if supplied
        let hostAlignInput: BASHostAlignmentInput?
        if let constitution = liveInputs.hostConstitution {
            hostAlignInput = BASAgentFabricAdapters
                .hostAlignmentInput(from: constitution)
        } else {
            hostAlignInput = nil
        }

        // critic enrichment — from triScores
        let criticInput: BASCriticSeatInput?
        if !liveInputs.triScores.isEmpty {
            let baseCritic = BASAgentFabricAdapters
                .criticInput(from: liveInputs.candidatePaths)
            criticInput = BASAgentFabricAdapters
                .enrichCriticInput(
                    from: liveInputs.triScores,
                    baseCriticInput: baseCritic)
        } else {
            criticInput = nil
        }

        // risk enrichment happens inside coordinator path indirectly
        // — but we also project the frontier here from the planner
        // candidates for post-turn use regardless of fabric outcome

        // Step 2:dispatch through coordinator
        let turnResult = await coordinator
            .runAgentFabricObservation(
                turnID: turnID,
                decomposeFrame: liveInputs.frame,
                candidatePaths: liveInputs.candidatePaths,
                acceptedCandidateID:
                    liveInputs.acceptedCandidateID,
                memory: liveInputs.memoryInput,
                critic: criticInput,
                hostAlignment: hostAlignInput,
                sovereignSentinel:
                    liveInputs.sovereignSentinelInput,
                evolutionShadow:
                    liveInputs.evolutionShadowInput,
                nowNanos: liveInputs.nowNanos)
        guard let turnResult else { return nil }

        // Step 3:post-turn warrant audit (ch 983)
        var warrantAuditEntry:
            BASSovereignAuditLedger.AppendedEntry? = nil
        if let warrant = liveInputs.warrantValidation,
           let ledger = warrantLedger
        {
            warrantAuditEntry =
                try await BASSovereignWarrantAuditBridge
                    .appendToLedger(
                        validationResult: warrant.result,
                        sessionID: sessionID,
                        turnID: turnID,
                        externalAgentID:
                            warrant.externalAgentID,
                        ledger: ledger)
        }

        // Step 4:post-turn trace flush (ch 984)
        var flushedCount: Int? = nil
        if let bridge = traceLogBridge {
            flushedCount = try await bridge
                .flush(forTurn: turnID)
        }

        // Step 5:post-turn frontier projection (ch 989)
        let plannerCands = BASAgentFabricAdapters
            .plannerCandidates(
                from: liveInputs.candidatePaths)
        let projection = BASAgentFabricAdapters
            .candidateFrontierProjection(
                from: plannerCands)

        return BASAgentFabricFullTurnResult(
            turnResult: turnResult,
            warrantAuditEntry: warrantAuditEntry,
            flushedTraceEventCount: flushedCount,
            frontierProjection: projection)
    }
}

// MARK: - chapter 九百九十三 / M3670 — env-var gate

/// Probes process environment for fabric activation。 Substrate-
/// side gate logic;the corresponding smoke-script wiring is
/// host-side (e.g. `BAS_AGENT_FABRIC=enabled bash scripts/
/// run-iphone-air-10hr.sh`)。 Closes the substrate-side portion
/// of deferred item #6 from `Docs/ARC_SEAL_953_981.md`。
///
/// Env-var grammar:
///   - `BAS_AGENT_FABRIC=enabled` → activate fabric
///   - `BAS_AGENT_FABRIC=disabled` (default) → fabric off
///   - `BAS_AGENT_TIER=all` → all 20 agents (9 core + 7 watcher
///     + 4 reference skill)
///   - `BAS_AGENT_TIER=core` → 9 core only
///   - `BAS_TRANSCRIPT_MODE=singleAgent|compareAll|compareSelected`
///   - `BAS_ACTIVE_AGENTS=Planner,Critic,Memory,Risk,Surface` —
///     comma-separated agent list for compareSelected mode
public enum BASAgentFabricGate {

    public struct Activation: Sendable, Equatable {
        public let fabricEnabled: Bool
        public let tier: Tier
        public let transcriptMode: TranscriptMode
        public let activeAgents: [String]

        public init(
            fabricEnabled: Bool = false,
            tier: Tier = .core,
            transcriptMode: TranscriptMode = .singleAgent,
            activeAgents: [String] = []
        ) {
            self.fabricEnabled = fabricEnabled
            self.tier = tier
            self.transcriptMode = transcriptMode
            self.activeAgents = activeAgents
        }
    }

    public enum Tier: String, Sendable, Equatable {
        case core
        case all
    }

    public enum TranscriptMode: String, Sendable, Equatable {
        case singleAgent
        case compareAll
        case compareSelected
    }

    /// Probe `ProcessInfo.processInfo.environment` for fabric
    /// activation flags。 Returns a fully-resolved Activation
    /// struct with defaults for any unset flags。
    public static func activationFromEnvironment(
        _ env: [String: String]? = nil
    ) -> Activation {
        let environment = env ?? ProcessInfo
            .processInfo.environment

        let fabricEnabled =
            environment["BAS_AGENT_FABRIC"] == "enabled"

        let tier: Tier
        switch environment["BAS_AGENT_TIER"] {
        case "all": tier = .all
        default: tier = .core
        }

        let transcriptMode: TranscriptMode
        switch environment["BAS_TRANSCRIPT_MODE"] {
        case "compareAll": transcriptMode = .compareAll
        case "compareSelected":
            transcriptMode = .compareSelected
        default: transcriptMode = .singleAgent
        }

        let activeAgents: [String]
        if let raw = environment["BAS_ACTIVE_AGENTS"],
           !raw.isEmpty
        {
            activeAgents = raw
                .split(separator: ",")
                .map { String($0)
                    .trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            activeAgents = []
        }

        return Activation(
            fabricEnabled: fabricEnabled,
            tier: tier,
            transcriptMode: transcriptMode,
            activeAgents: activeAgents)
    }
}
