import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
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

    /// ②-observe (opt-in, 红线 7) — per-turn MODEL-HONESTY observation sink. Each turn `runTurn` scores the
    /// realized body on the flattery / hedging / overclaim axes (pure, deterministic) and hands the host a
    /// typed `BASModelHonestyObservationRecord`; the host durably stores it (e.g. into a
    /// `BASModelHonestyObservationStore`) from its own context. Default nil ⇒ nothing is computed or emitted
    /// and the turn is byte-equal (mirrors `provisionalVerdictSink`). OBSERVE lane only: it never gates and
    /// never feeds the sovereign verdict (feeding model CONTENT into the parity-bound verdict is the trap
    /// this deliberately stays clear of — the signal closes the "sycophancy is structurally invisible" gap).
    public var modelHonestyObservationSink:
        (@Sendable (BASModelHonestyObservationRecord) -> Void)?

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

    /// chapter 一千零三十九 / ADR-018 P1 — OPT-IN deliberation-loop
    /// gate。 Default false preserves byte-equality per 红线 7 +
    /// ADR-014:when false,`runTurn` executes exactly one L9
    /// deliberation pass (the pre-P1 single-pass behaviour)。 When
    /// true,runTurn runs up to the service-requested budget
    /// (min(maxLoops, stepIndex)) of refinement passes — each
    /// carrying the prior pass's candidate IDs forward via the
    /// `iterate(…:priorCandidateIDs:)` contract — exiting early on a
    /// terminal stop (maxLoopsReached / blocked / replaced /
    /// guardTakeover)。 Does NOT change any other coordinator output。
    public var deliberationLoopEnabled: Bool

    /// chapter 一千零四十二 / ADR-020 Arc-3 Phase C — OPT-IN, default-nil
    /// sink for the pre-render provisional sovereign verdict
    /// (`BASProvisionalVerdict`)。 When set AND `deliberationLoopEnabled`
    /// is true,`runTurn` emits a render-independent FORECAST of the
    /// post-render verdict level to this closure just before render —
    /// OBSERVATION-ONLY (it gates nothing; the caution-reduction such a
    /// forecast could gate is excluded as architecturally unsafe,
    /// ADR-020 §1)。 Default nil preserves byte-equality per 红线 7 +
    /// ADR-014:nil → no emission → no effect。 NOT in any
    /// canonical-bytes / seal / hash path.
    public var provisionalVerdictSink:
        (@Sendable (BASProvisionalVerdict) -> Void)?

    /// chapter 一千零四十二 / ADR-020 Step 4 — OPT-IN, default-nil
    /// evidence the deliberation loop matches a turn's typed unknowns
    /// against to WITHHOLD a floored fraction of its own added caution
    /// (`BASDeliberationCaution.uncertainDeliberationRiskIncrement`)
    /// when stored evidence resolves those unknowns。 Default nil → no
    /// resolution → no withholding → byte-equality per 红线 7 + ADR-014。
    /// Dormant in Commit 1 (no `runTurn` path reads it yet); the
    /// consequential floored caution-withholding lands in Commit 2。
    /// NOT in any canonical-bytes / seal / hash path.
    public var evidenceLedger: BASEvidenceLedger? = nil

    /// chapter 一千零四十二 / ADR-020 Step 4 — OPT-IN, default-nil
    /// write-back sink for newly-resolved evidence atoms。 Mirrors
    /// `provisionalVerdictSink`: when set,`runTurn` (Commit 2) emits the
    /// turn's newly-resolved `BASEvidenceAtom`s to this closure —
    /// OBSERVATION-ONLY (it feeds no render/seal/verdict/hash)。 Default
    /// nil → no emission → byte-equality per 红线 7 + ADR-014:nil →
    /// no effect。 NOT in any canonical-bytes / seal / hash path.
    public var resolvedEvidenceSink:
        (@Sendable ([BASEvidenceAtom]) -> Void)? = nil

    /// chapter 一千零四十三 / ADR-018 P2 — OPT-IN, default-false gate for
    /// the ShadowTrial N→N+1 feedback loop。 Mirrors
    /// `deliberationLoopEnabled`:when false, `runTurn` produces a turn
    /// byte-identically to the pre-feedback-loop behaviour。 Default
    /// false preserves byte-equality per 红线 7 + ADR-014。 Dormant in
    /// Commit 1 (no `runTurn` path reads it yet);the consequential
    /// N→N+1 wiring lands in Commit 2。 NOT in any canonical-bytes /
    /// seal / hash path.
    public var shadowTrialFeedbackEnabled: Bool

    /// chapter 一千零四十三 / ADR-018 P2 — OPT-IN, default-nil pending-trial
    /// ledger carried in from the host (slot-in)。 This is last turn's
    /// pending shadow trials, seeded so this turn can advance them via
    /// `BASShadowTrialFeedbackLedger.evaluate(...)`。 Mirrors
    /// `evidenceLedger`。 Default nil → no carried trials → byte-equality
    /// per 红线 7 + ADR-014。 Dormant in Commit 1 (no `runTurn` path reads
    /// it yet)。 NOT in any canonical-bytes / seal / hash path.
    public var pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil

    /// chapter 一千零四十三 / ADR-018 P2 — OPT-IN, default-nil write-back
    /// sink for this turn's evaluated trials (sink-out)。 Mirrors
    /// `resolvedEvidenceSink`:when set, `runTurn` (Commit 2) emits the
    /// turn's evaluated `BASShadowTrialRecord`s to this closure for the
    /// host to carry into the NEXT turn — OBSERVATION-ONLY (it feeds no
    /// render/seal/verdict/hash)。 Default nil → no emission →
    /// byte-equality per 红线 7 + ADR-014:nil → no effect。 NOT in any
    /// canonical-bytes / seal / hash path.
    public var resolvedTrialSink:
        (@Sendable ([BASShadowTrialRecord]) -> Void)? = nil

    /// chapter 一百八十六 / ADR-019 §15 — OPT-IN, default-false gate for the SSM caution operator
    /// (Mamba/SSM as an AUTHORITATIVE raise-caution-only L11 input)。 Mirrors `deliberationLoopEnabled`:
    /// when false, `runTurn` produces a turn byte-identically to the pre-operator behaviour (红线 7 /
    /// ADR-014)。 When true AND the turn is genuinely-uncertain, the CPU-deterministic `ssmCaution`
    /// RAISES the final bound `totalRisk` (monotonic, ≤ 1) as an INPUT the sovereign verdict GATES —
    /// never a verdict / permit / commit token, and it can never DOWNGRADE (不变量 #2)。 NOT in any
    /// canonical-bytes / seal / hash path.
    public var ssmCautionOperatorEnabled: Bool

    /// chapter 一百八十六 / ADR-019 §15 — OPT-IN, default-nil sink for the per-turn SSM operator
    /// observation (`BASMambaSSMTurnObservation`)。 Mirrors `provisionalVerdictSink`: when set AND
    /// `ssmCautionOperatorEnabled` is true, `runTurn` emits the turn's SSM observation here —
    /// OBSERVATION-ONLY (it feeds no render / seal / verdict / hash)。 Default nil → no emission →
    /// byte-equal (红线 7 / ADR-014)。 NOT in any canonical-bytes / seal / hash path.
    public var ssmCautionObservationSink:
        (@Sendable (BASMambaSSMTurnObservation) -> Void)? = nil

    /// T3.2 — OPT-IN, default-false NESTED gate for the SSM neuromodulation suggestion RECORD
    /// (`BASSSMNeuromodulationField`)。 Effective only inside the `ssmCautionOperatorEnabled` block:
    /// when true (and the observation sink is set), the emitted `BASMambaSSMTurnObservation` carries a
    /// raise-only/conserve-only `neuromodulationSuggestion` — OBSERVATION-ONLY (a RECORD forever; gates
    /// never auto-promote — nothing applies it to a live path)。 When false (default) the field stays
    /// nil and the suggestion is never computed → byte-equal + zero cost (红线 7 / ADR-014)。 NOT in any
    /// canonical-bytes / seal / hash path.
    public var ssmNeuromodulationSuggestionsEnabled: Bool

    /// ADR-039 Phase 4 — OPT-IN: when true AND `ssmReasoningInputSink` is set, `runTurn` emits the per-turn
    /// DETERMINISTIC SSM scan input here so the HOST runs the Metal SSMScan OFF the sync turn thread. The
    /// CPU `ssmCaution` above stays the authoritative verdict input — UNCHANGED. The Metal reasoning result
    /// is a NON-governance side-channel: feeds no verdict/permit/commit/render/seal/replay, and never folds
    /// into `request.priorSSMState`. Default false/nil → no emission → byte-equal (红线 7). NOT in any
    /// canonical-bytes / seal / hash path.
    public var ssmMetalReasoningEnabled: Bool
    public var ssmReasoningInputSink:
        (@Sendable (BASSSMReasoningTurnInput) -> Void)? = nil

    /// ADR-039 Phase 5 — OPT-IN: when true AND `attentionReasoningInputSink` is set, runTurn emits the
    /// per-turn DETERMINISTIC attention input here so the HOST runs Metal attention (Phase-3 routed) OFF
    /// the turn thread. NON-governance side-channel: feeds no verdict/permit/commit/render/seal/replay and
    /// never folds into governance. Default false/nil → no emission → byte-equal (红线 7).
    public var attentionMetalReasoningEnabled: Bool
    public var attentionReasoningInputSink:
        (@Sendable (BASAttentionReasoningTurnInput) -> Void)? = nil

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
        // ②-observe (opt-in, 红线 7) — per-turn model-honesty observation sink。 Default nil → byte-equal;
        // emits a typed record (flattery/hedging/overclaim axes) only when a host provides this sink。
        modelHonestyObservationSink:
            (@Sendable (BASModelHonestyObservationRecord) -> Void)? = nil,
        projectionBlockEmissionHandler:
            (@Sendable
                (BASAuditObservationProjectionsBundleObservation)
                -> Void)? = nil,
        // chapter 九百六十 / M3505 — Phase 2 ch1 OPT-IN slot。
        // Default nil preserves V1 byte-equality per 红线 7 +
        // ADR-014。 Setting this param activates the Agent Fabric
        // observation surface (call `runAgentFabricObservation`)
        // — does NOT change existing runTurn behavior。
        agentFabric: BASAgentFabricRuntime? = nil,
        // chapter 一千零三十九 / ADR-018 P1 — OPT-IN deliberation
        // loop。 Default false → single pass (byte-equal, 红线 7).
        deliberationLoopEnabled: Bool = false,
        // chapter 一千零四十二 / ADR-020 Arc-3 Phase C — OPT-IN sink for
        // the pre-render provisional verdict。 Default nil → no emission
        // → byte-equal (红线 7)。 Observation-only; gates nothing.
        provisionalVerdictSink:
            (@Sendable (BASProvisionalVerdict) -> Void)? = nil,
        // chapter 一千零四十二 / ADR-020 Step 4 — OPT-IN evidence ledger。
        // Default nil → no resolution → byte-equal (红线 7)。 Dormant in
        // Commit 1; the floored caution-withholding lands in Commit 2.
        evidenceLedger: BASEvidenceLedger? = nil,
        // chapter 一千零四十二 / ADR-020 Step 4 — OPT-IN write-back sink
        // for newly-resolved evidence atoms。 Default nil → no emission
        // → byte-equal (红线 7)。 Observation-only; gates nothing.
        resolvedEvidenceSink:
            (@Sendable ([BASEvidenceAtom]) -> Void)? = nil,
        // chapter 一千零四十三 / ADR-018 P2 — OPT-IN ShadowTrial N→N+1
        // feedback loop。 Default false → no feedback → byte-equal
        // (红线 7)。 Dormant in Commit 1; the N→N+1 wiring lands in
        // Commit 2.
        shadowTrialFeedbackEnabled: Bool = false,
        // chapter 一千零四十三 / ADR-018 P2 — OPT-IN pending-trial ledger
        // (slot-in)。 Default nil → no carried trials → byte-equal
        // (红线 7)。 Dormant in Commit 1.
        pendingTrialLedgerIn: BASShadowTrialFeedbackLedger? = nil,
        // chapter 一千零四十三 / ADR-018 P2 — OPT-IN write-back sink for
        // this turn's evaluated trials (sink-out)。 Default nil → no
        // emission → byte-equal (红线 7)。 Observation-only; gates nothing.
        resolvedTrialSink:
            (@Sendable ([BASShadowTrialRecord]) -> Void)? = nil,
        // chapter 一百八十六 / ADR-019 §15 — OPT-IN SSM caution operator。
        // Default false → never invoked → byte-equal (红线 7)。
        ssmCautionOperatorEnabled: Bool = false,
        // chapter 一百八十六 / ADR-019 §15 — OPT-IN SSM observation sink。
        // Default nil → no emission → byte-equal (红线 7)。 Observation-only.
        ssmCautionObservationSink:
            (@Sendable (BASMambaSSMTurnObservation) -> Void)? = nil,
        // T3.2 — OPT-IN nested SSM neuromodulation suggestion record。 Default false → field
        // stays nil → byte-equal + zero cost (红线 7)。 Observation-only; a record forever.
        ssmNeuromodulationSuggestionsEnabled: Bool = false,
        // ADR-039 Phase 4 — OPT-IN Metal SSM reasoning side-channel。 Default false/nil →
        // no emission → byte-equal (红线 7)。 Non-governance; host runs Metal off-turn.
        ssmMetalReasoningEnabled: Bool = false,
        ssmReasoningInputSink:
            (@Sendable (BASSSMReasoningTurnInput) -> Void)? = nil,
        // ADR-039 Phase 5 — OPT-IN Metal attention reasoning side-channel。 Default false/nil →
        // no emission → byte-equal (红线 7)。 Non-governance; host runs Metal off-turn (Phase-3 routed).
        attentionMetalReasoningEnabled: Bool = false,
        attentionReasoningInputSink:
            (@Sendable (BASAttentionReasoningTurnInput) -> Void)? = nil
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
        self.modelHonestyObservationSink = modelHonestyObservationSink
        self.projectionBlockEmissionHandler =
            projectionBlockEmissionHandler
        self.agentFabric = agentFabric
        self.deliberationLoopEnabled = deliberationLoopEnabled
        self.provisionalVerdictSink = provisionalVerdictSink
        self.evidenceLedger = evidenceLedger
        self.resolvedEvidenceSink = resolvedEvidenceSink
        self.shadowTrialFeedbackEnabled = shadowTrialFeedbackEnabled
        self.pendingTrialLedgerIn = pendingTrialLedgerIn
        self.resolvedTrialSink = resolvedTrialSink
        self.ssmCautionOperatorEnabled = ssmCautionOperatorEnabled
        self.ssmCautionObservationSink = ssmCautionObservationSink
        self.ssmNeuromodulationSuggestionsEnabled =
            ssmNeuromodulationSuggestionsEnabled
        self.ssmMetalReasoningEnabled = ssmMetalReasoningEnabled
        self.ssmReasoningInputSink = ssmReasoningInputSink
        self.attentionMetalReasoningEnabled = attentionMetalReasoningEnabled
        self.attentionReasoningInputSink = attentionReasoningInputSink
        // (ADR-018 P2) shadow-trial feedback slots wired above; DORMANT
        // until Commit 2 reads them. (ADR-019 §15) the SSM caution
        // operator flag + sink are wired above; the consequential L11
        // seam reads `ssmCautionOperatorEnabled` in runTurn.
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
