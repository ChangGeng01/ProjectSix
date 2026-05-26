import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
// M320 — `BASUnknownReserve.derive(...)` lives in BASWorldPrior
// and is invoked from `runTurn` to project per-turn unknowns.
import BASWorldPrior

// MARK: - M71 split — BASEBrainRuntimeCoordinator now lives in its own file.
// Types (BASEBrainTurnRequest / BASEBrainTurnResult), evolution summary/
// precision-hotcold/breath-bridge helpers, and shared internal utilities
// (EvolutionSovereignBridgeProjection, String.trimmedNonEmpty, etc.) moved to
// sibling files in BASHostKit during the M71 cohesion split.  The coordinator
// itself is next on the list to be split by cohesion; this commit only removes
// the duplicated pre-struct content.

public struct BASEBrainRuntimeCoordinator {
    public var powerClockService: any BASPowerClockServicing
    public var hostProfileService: any BASHostProfileServicing
    public var contextService: any BASContextServicing
    public var decomposeService: any BASDecomposeServicing
    public var memoryService: any BASMemoryServicing
    public var neuralCoreService: (any BASNeuralCoreServicing)?
    public var loopService: any BASLoopServicing
    public var triSelfService: any BASTriSelfServicing
    public var riskService: any BASRiskServicing
    public var actionService: any BASActionServicing
    public var evolutionService: any BASEvolutionServicing
    public var policyLineage: BASRuntimePolicyLineage?
    public var hostRhythmProfile: BASHostRhythmProfile
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?

    // chapter 六百一 / M1781 — V1 fold Phase I continuation wave 2:
    //
    // M420 Kunlun hot-path string constants + M422 kunlunCenterline
    // Rules helper + M450 cosmic-cold counterweight derivation
    // (4 helper functions + their per-axis magic-number constants)
    // MOVED OUT of this V1 monolith file into sibling extension
    // file:
    //
    //   `EBrainRuntimeCoordinator+CoreHelpers.swift`
    //
    // = ~232 LOC reduction (2136 → ~1904)。
    //
    // V1 byte-equality preserved — pure code MOVE,no logic change。
    // BASStressSweepCanonical60Driver regression guard verifies
    // V1 byte-equality per-turn。

    // chapter 六百 / M1777 — V1 fold Phase I continuation:
    //
    // 3 audit-projection static helpers (deriveYaochi /
    // deriveHeavenGate / deriveLayerReconciliation) +
    // 1 fileprivate reveal-conditions constant +
    // coverageStatus classifier + 4 public per-turn
    // reconciliation constants (layerReconciliationExpected
    // Layers / layerReconciliationExpectedLayerIDs /
    // fullCoverageExpectedLayerIDs / layerReconciliation
    // BudgetCeiling) MOVED OUT of this V1 monolith file
    // into sibling extension file:
    //
    //   `EBrainRuntimeCoordinator+AuditProjectionHelpers.swift`
    //
    // = 367 LOC reduction (2472 → ~2105)。
    //
    // V1 byte-equality preserved — pure code MOVE,no
    // logic change。 The 3 derive helpers' visibility
    // broadened `fileprivate` → `internal` for cross-
    // file `Self.deriveXxx(...)` access from this V1
    // monolith。 The 4 public constants stay public
    // (cross-package callers unchanged)。 The coverage
    // Status helper stays internal (already was;
    // EBrainRuntimeCoordinator+SovereignCommit.swift
    // continues to call it through `Self.coverageStatus`)。
    // yaochiAuditRevealConditions stays fileprivate
    // (only consumed by the co-located deriveYaochi
    // AuditProjection in the new sibling file)。
    //
    // BASStressSweepCanonical60Driver regression guard
    // verifies V1 byte-equality preserved per-turn。

    /// chapter 四百二 / M948:optional event log surface for hosts
    /// that opt into event-sourced atom storage。Default nil
    /// preserves byte-equal pre-Phase-1 behavior。
    public let memoryEventLog: (any BASEventLogStorage)?

    /// chapter 四百二 / M948:optional mutation event emitter
    /// hosts can use to bridge `BASMemoryMutationWriter` outcomes
    /// into the typed event log。Default nil preserves byte-equal
    /// pre-Phase-1 behavior。Per-turn `runTurn` is unchanged in
    /// Phase 1;Phase 2 (chapter 四百三) collapses the per-call
    /// emit-then-write step into one routine。
    public let memoryMutationEventEmitter:
        BASMemoryMutationEventEmitter?

    /// chapter 五百十九 / M1453:optional projection-block
    /// emission handler。 When set,V1 monolith fires this
    /// synchronous callback with the typed
    /// `BASAuditObservationProjectionsBundleObservation`
    /// after constructing the audit projections at line
    /// 2035。
    ///
    /// Hosts wire this to capture per-turn projection
    /// coverage:
    ///   - Synchronous loggers can record directly
    ///   - Async observers can wrap submission in
    ///     `Task { await observer.recordEmission(rec) }`
    ///   - Tests can capture into a local for inspection
    ///
    /// Default nil preserves V1 byte-equality —
    /// pre-M1453 behavior is identical when handler not
    /// set。 ADR-014 OPT-IN preserved。
    public let projectionBlockEmissionHandler:
        (@Sendable
            (BASAuditObservationProjectionsBundleObservation)
            -> Void)?

    /// chapter 九百六十 / M3505 — Phase 2 ch1:Agent Fabric
    /// runtime bundle。 OPT-IN per ADR-014 — default nil means
    /// no fabric per-turn touch,coordinator behavior byte-equal
    /// to pre-ch-960 (红线 7 preserved)。 When set,callers can
    /// invoke `runAgentFabricObservation(...)` to run the 4-seat
    /// dispatcher alongside the existing turn flow。
    ///
    /// Observation-only mode (this chapter):the dispatcher's
    /// `BASAgentTurnResult` is returned to the caller but does
    /// NOT mutate any existing coordinator output。 Future
    /// fabric-authoritative mode (ch 961+) lets accepted deltas
    /// drive coordinator output。
    public var agentFabric: BASAgentFabricRuntime?

    public init(
        powerClockService: any BASPowerClockServicing,
        hostProfileService: any BASHostProfileServicing,
        contextService: any BASContextServicing,
        decomposeService: any BASDecomposeServicing,
        memoryService: any BASMemoryServicing,
        neuralCoreService: (any BASNeuralCoreServicing)? = nil,
        loopService: any BASLoopServicing,
        triSelfService: any BASTriSelfServicing,
        riskService: any BASRiskServicing,
        actionService: any BASActionServicing,
        evolutionService: any BASEvolutionServicing,
        policyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil,
        memoryEventLog: (any BASEventLogStorage)? = nil,
        memoryMutationEventEmitter:
            BASMemoryMutationEventEmitter? = nil,
        projectionBlockEmissionHandler:
            (@Sendable
                (BASAuditObservationProjectionsBundleObservation)
                -> Void)? = nil,
        // chapter 九百六十 / M3505 — Phase 2 ch1 OPT-IN slot。
        // Default nil preserves V1 byte-equality per 红线 7 +
        // ADR-014。 Setting this param activates the Agent Fabric
        // observation surface (call `runAgentFabricObservation`)
        // — does NOT change existing runTurn behavior。
        agentFabric: BASAgentFabricRuntime? = nil
    ) {
        self.powerClockService = powerClockService
        self.hostProfileService = hostProfileService
        self.contextService = contextService
        self.decomposeService = decomposeService
        self.memoryService = memoryService
        self.neuralCoreService = neuralCoreService
        self.loopService = loopService
        self.triSelfService = triSelfService
        self.riskService = riskService
        self.actionService = actionService
        self.evolutionService = evolutionService
        self.policyLineage = policyLineage
        self.hostRhythmProfile = hostRhythmProfile
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
        self.memoryEventLog = memoryEventLog
        self.memoryMutationEventEmitter =
            memoryMutationEventEmitter
        self.projectionBlockEmissionHandler =
            projectionBlockEmissionHandler
        self.agentFabric = agentFabric
    }

    // MARK: - Agent Fabric observation (ch 960)

    /// chapter 九百六十 / M3505 — observation-only fabric dispatch。
    /// Per ADR-014 + 红线 7,this method is the ONLY agent-fabric
    /// per-turn touch in ch 960 — callers explicitly invoke it,
    /// `runTurn` does NOT call it implicitly。 If `agentFabric`
    /// is nil,returns nil (no-op,zero overhead)。
    ///
    /// What this does when fabric is set:
    ///   1. Build up to 9 seat DTOs from the supplied L7 frame +
    ///      L9 candidate paths + 5 optional pre-built DTOs
    ///      (memory / critic / hostAlignment / sovereignSentinel
    ///      / evolutionShadow) via `BASAgentFabricAdapters`
    ///   2. Call `BASAgentTurnDispatcher.dispatch(...)` which runs
    ///      the configured seat set through the merge + apply
    ///      pipeline,writes events to the trace log if configured
    ///   3. Return the `BASAgentTurnResult` — caller decides
    ///      what (if anything) to do with it
    ///
    /// In ch 960 observation mode the result is recorded for
    /// audit + replay (via the optional trace log) but is NOT
    /// used to mutate any existing coordinator output。 Future
    /// chapter 961+ (fabric-authoritative mode) wires the
    /// dispatcher's surface delta into the actual render frame
    /// + risk gate。
    ///
    /// chapter 九百八十五 / M3630 — Cross-Module Integration Arc
    /// ch3 (closes ch 982.5 META-REVIEW Gap 8):the 5 optional
    /// pre-built DTOs let callers wire the 5 optional seats
    /// (Memory/Critic/HostAlignment/SovereignSentinel/
    /// EvolutionShadow) through this entry point。 Previous
    /// versions of `runAgentFabricObservation` only built DTOs
    /// for Scout/Planner/Risk/Surface — the other 5 seats were
    /// unreachable through coordinator even when their roster
    /// slots were configured。 Defaulted nil preserves all prior
    /// callers byte-equal。
    public func runAgentFabricObservation(
        turnID: String,
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String? = nil,
        memory: BASMemorySeatInput? = nil,
        critic: BASCriticSeatInput? = nil,
        hostAlignment: BASHostAlignmentInput? = nil,
        sovereignSentinel:
            BASSovereignSentinelInput? = nil,
        evolutionShadow:
            BASEvolutionShadowInput? = nil,
        riskOverride: BASRiskInput? = nil,
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) async -> BASAgentTurnResult? {
        // chapter 九百九十四.5 META-REVIEW Round-10 HIGH-1 fix:
        // added `riskOverride` to plumb BASRiskCard enrichment
        // through coordinator。 Pre-fix the L7-only path always
        // ran;ch 987 enrichment was unreachable through this
        // entry point。 Default nil preserves byte-equality。
        guard let agentFabric else { return nil }
        let input = BASAgentFabricAdapters.turnInput(
            turnID: turnID,
            decomposeFrame: decomposeFrame,
            candidatePaths: candidatePaths,
            acceptedCandidateID: acceptedCandidateID,
            memory: memory,
            critic: critic,
            hostAlignment: hostAlignment,
            sovereignSentinel: sovereignSentinel,
            evolutionShadow: evolutionShadow,
            riskOverride: riskOverride,
            priorityContext: priorityContext,
            nowNanos: nowNanos)
        return await agentFabric.dispatchTurn(input: input)
    }

    // chapter 六百二 / M1785 — V1 fold Phase I continuation
    // wave 3 (THE BIG MOVE):
    //
    // `runTurn(_:)` (1733 LOC) + `runTurnAndIngest(_:
    // lifecycleCoordinator:)` (12 LOC) MOVED OUT of this
    // V1 monolith file into sibling extension file:
    //
    //   `EBrainRuntimeCoordinator+RunTurn.swift`
    //
    // = 1744 LOC reduction (1918 → 174)。
    //
    // V1 byte-equality preserved by construction — pure
    // code MOVE,callers continue to invoke
    // `coordinator.runTurn(request)` unchanged。 The
    // method body's `self.xxx` instance-property access
    // + `Self.xxx` static-helper access work identically
    // from a sibling extension file。
    //
    // CUMULATIVE V1 REDUCTION (chapter 477 baseline):
    //   2540 → 174 = -2366 LOC (-93.1%,vs plan target 80)。
    //
    // BASStressSweepCanonical60Driver regression guard
    // verifies V1 byte-equality preserved per-turn。
}
