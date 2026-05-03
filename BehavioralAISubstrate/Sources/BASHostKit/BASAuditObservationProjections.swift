import Foundation
import BASOrchestration
import BASRuntimeCore
import BASMemory
import BASPolicy
import BASWorldPrior

/// M436.4 (chapter 一百七 cross-package alignment + parameter
/// bundle refactor) — typed bag carrying all optional audit
/// observation projections fed into
/// `BASEBrainRuntimeCoordinator.buildSovereignAuditEntry(...)`.
///
/// Pre-M436.4 the function signature carried 24+ M-tagged
/// optional parameters (each with `= nil` default) accreted
/// across milestones M299/M300/M303/M304/M305/M316/M317/M318/
/// M320/M321/M402/M404/M405/M408/M409/M417/M424/M436/M436.1.
/// The chapter 一百四 deep-review MEDIUM finding M-5
/// classified this as a "parameter explosion smell" that
/// violates the 50-LoC function-size guideline by ~25× and
/// would keep growing with every audit-emission addition.
///
/// M436.4 lands the bundle struct: callers populate one
/// `BASAuditObservationProjections` value with the projections
/// they want to emit, and pass it as a single `projections`
/// parameter. Future audit emissions add a field to this struct
/// instead of a new parameter on the function.
///
/// **Doctrine pin** — additive metadata only. Every field is
/// optional or empty-default; callers that don't populate a
/// field elide its emission. Backward-compat preserved: the
/// existing per-parameter overload remains in place and
/// delegates to the new `projections`-form overload internally.
///
/// All fields are `Sendable + Equatable` so the struct can be
/// constructed in any actor context and round-tripped through
/// `Codable` if downstream tooling wants serialized audit
/// fixtures.
public struct BASAuditObservationProjections: Sendable, Equatable {

    // MARK: - M299 / M300 — top-line bundles

    public var candidateObservationBundle:
        BASCandidateObservationBundle?
    public var tribunalObservationBundle:
        BASTribunalObservationBundle?

    // MARK: - M303 / M304 — Cthulhu pressure / anchor / seal

    public var abyssalPressure: BASAbyssalPressure?
    public var humanAnchorSignal: BASHumanAnchorSignal?
    public var sealAggregate:
        BASOldSealSealingProtocol.Aggregate?

    // MARK: - M305 — L13 lifecycle

    public var lifecycleAggregate:
        BASEvolutionLifecycleSession.Aggregate?

    // MARK: - M316 / M317 / M318 — narrative / anomaly / branch

    public var narrativeDistortion: BASNarrativeDistortion?
    public var anomalyTrace: BASAnomalyTrace?
    public var abyssalBranches: [BASAbyssalBranch]

    // MARK: - M320 / M321 — unknown reserve / forbidden

    public var unknownReserve: BASUnknownReserve?
    public var forbiddenAggregate:
        BASForbiddenKnowledgeCandidate.Aggregate?

    // MARK: - M402 / M404 / M405 — Kunlun axis / jade / river

    public var kunlunAxisAlignment: BASAxisAlignment?
    public var jadeCanonVerification:
        BASKunlunJadeCanonProtocol.Verification?
    public var jadeCanonObjectClass: BASJadeCanonObjectClass?
    public var riverOriginLineage:
        BASKunlunRiverOriginProtocol.LineageReport?

    // MARK: - M408 / M409 — Yaochi / Tianmen

    public var yaochiAccess:
        BASKunlunYaochiProtocol.AccessDecision?
    public var yaochiSanctumClass: BASYaochiSanctumClass?
    public var tianmenReadiness:
        BASKunlunHeavenGateProtocol.Readiness?
    public var tianmenGateClass: BASKunlunGateClass?
    public var tianmenPassState: BASKunlunGateState?

    // MARK: - M417 — escalation suppression

    public var escalationSuppressionCodes: [String]

    // MARK: - M424 — chapter 99 schemas

    public var kunlunAxisView: BASKunlunAxisView?
    public var kunlunTianmenWarrant: BASKunlunTianmenWarrant?
    public var kunlunGateDenialWrit: BASKunlunGateDenialWrit?

    // MARK: - M436 / M436.1 — reconciliation + 11 silent bundles

    public var layerReconciliationVerdict:
        BASObservationReconciliationVerdict?
    public var layerReconciliationReport:
        BASObservationReconciliationReport?
    public var presenceObservationBundle:
        BASPresenceObservationBundle?
    public var decompositionObservationBundle:
        BASDecompositionObservationBundle?
    public var softHandObservationBundle:
        BASSoftHandObservationBundle?
    public var leaseLifeObservationBundle:
        BASLeaseLifeObservationBundle?
    public var hostConstitutionObservationBundle:
        BASHostConstitutionObservationBundle?
    public var thoughtFoldObservationBundle:
        BASThoughtFoldObservationBundle?
    public var neuralOrganObservationBundle:
        BASNeuralOrganObservationBundle?
    public var hippocampalMemoryObservationBundle:
        BASHippocampalMemoryObservationBundle?
    public var worldPriorObservationBundle:
        BASWorldPriorObservationBundle?
    public var riskObservationBundle:
        BASRiskObservationBundle?
    public var updateTicketObservationBundle:
        BASUpdateTicketObservationBundle?

    // MARK: - M448-M451 — chapter 一百十八 Cthulhu 14-layer
    // production wires (M444-M447 helpers driven from EBrainRuntime
    // Coordinator.runTurn).

    /// L4 cosmic-scale view derived from BASBudgetFrame (M444).
    /// When non-nil, audit emission adds
    /// `cthulhu.cosmic.scale:<temporal>:<spatial>` and
    /// `cthulhu.cosmic.dilution:<bool>` reason codes.
    public var cosmicScaleView: BASCosmicScaleView?

    /// L4 ontology fog projection (M444). When non-nil, audit
    /// emission adds `cthulhu.fog.quality:<rawValue>` reason code.
    public var ontologyFog: BASOntologyFog?

    /// L7 ontology shift mark derived from BASNarrativeDistortion
    /// (M444). When non-nil + has axes, audit emission adds
    /// `cthulhu.shift.axes:<sortedJoined>` and
    /// `cthulhu.shift.confidence:<rounded>` reason codes.
    public var ontologyShiftMark: BASOntologyShiftMark?

    /// L1 abyssal run mode label (M444). When non-nil, audit
    /// emission adds `cthulhu.runMode:<rawValue>` reason code.
    public var abyssalRunMode: BASAbyssalRunMode?

    /// L1 abyss budget readout (M444). When non-nil, audit
    /// emission adds `cthulhu.budget.aggregateAvailability:<rounded>`
    /// reason code.
    public var abyssBudget: BASAbyssBudget?

    /// Reason codes from the M445 `BASCthulhuAssertionCeilingGate
    /// .cap(...)` decision. Empty when the gate did not fire.
    public var cthulhuAssertionCeilingReasonCodes: [String]

    /// Reason codes from the M446 `BASCthulhuPermitEscalation
    /// .escalate(...)` decision. Empty when no escalation fired.
    public var cthulhuPermitEscalationReasonCodes: [String]

    /// L8 memory thermal layer (M456 chapter 一百二十). When
    /// non-nil, audit emission adds
    /// `cthulhu.memory.thermal:<rawValue>` reason code.
    public var memoryTemperatureLayer: BASMemoryTemperatureLayer?

    // MARK: - M480-M485 (chapter 一百二十五) — Kunlun production
    // wires for chapter-一百二十二/三 schemas.

    /// L1 ascent-lease readout (M480). When non-nil, emits
    /// `kunlun.ascent.mode:<mode>` + `kunlun.ascent.budget:<int>`.
    public var ascentLease: BASAscentLease?

    /// L6 axis-deviation readout (M481). When non-nil, emits
    /// `kunlun.axis.deviation:<3-decimal>` reason code.
    public var axisDeviation: BASAxisDeviation?

    /// L6 gate-pressure readout (M482). When non-nil, emits
    /// `kunlun.gate.urgency:<3-decimal>` + `kunlun.gate.required:
    /// <bool>` reason codes.
    public var gatePressure: BASGatePressure?

    /// L8 yaochi-memory-layer (M483). When non-nil + non-empty
    /// sanctumPolicy, emits `kunlun.yaochi.policy:<policy>`
    /// reason code.
    public var yaochiMemoryLayer: BASYaochiMemoryLayer?

    /// L10 Tianheng equilibrium (M484). When non-nil, emits
    /// `kunlun.tianheng.center:<3-decimal>` +
    /// `kunlun.tianheng.dignity:<3-decimal>` reason codes.
    public var tianhengProfile: BASTianhengProfile?

    /// L11 jade-permit-grade (M485). When non-nil, emits
    /// `kunlun.permit.grade:<clarity>:<reversibility>:<provenance>`
    /// reason code.
    public var jadePermitGrade: BASJadePermitGrade?

    // MARK: - M486-M490 (chapter 一百二十六) — L9 dream-loop +
    // L3 fold-page + L13 refinement production wires.

    /// L9 ascent-branch readouts (M486). Emits
    /// `kunlun.ascent.branchCount:<int>` + per-branch dignity
    /// pin.
    public var ascentBranches: [BASAscentBranch]

    /// L9 rest-step readouts (M487). Emits
    /// `kunlun.rest.stepCount:<int>` when non-empty.
    public var restSteps: [BASRestStep]

    /// L9 return-path readouts (M488). Emits
    /// `kunlun.return.pathCount:<int>` + dignity-honor invariant.
    public var returnPaths: [BASReturnPath]

    /// L3 jade-casket snapshot (M489). Emits
    /// `kunlun.jade.casket:<verdict>` (canonical/defective).
    public var jadeCasket: BASJadeCasketSnapshot?

    /// L13 jade-refinement tickets (M490). Emits
    /// `kunlun.refinement.ticketCount:<int>` when non-empty.
    public var jadeRefinementTickets: [BASJadeRefinementTicket]

    // MARK: - Construction

    /// All-fields-default constructor. Most callers use the
    /// `.empty` static + per-field assignment for readability.
    public init(
        candidateObservationBundle:
            BASCandidateObservationBundle? = nil,
        tribunalObservationBundle:
            BASTribunalObservationBundle? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        sealAggregate:
            BASOldSealSealingProtocol.Aggregate? = nil,
        lifecycleAggregate:
            BASEvolutionLifecycleSession.Aggregate? = nil,
        narrativeDistortion: BASNarrativeDistortion? = nil,
        anomalyTrace: BASAnomalyTrace? = nil,
        abyssalBranches: [BASAbyssalBranch] = [],
        unknownReserve: BASUnknownReserve? = nil,
        forbiddenAggregate:
            BASForbiddenKnowledgeCandidate.Aggregate? = nil,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        jadeCanonVerification:
            BASKunlunJadeCanonProtocol.Verification? = nil,
        jadeCanonObjectClass:
            BASJadeCanonObjectClass? = nil,
        riverOriginLineage:
            BASKunlunRiverOriginProtocol.LineageReport? = nil,
        yaochiAccess:
            BASKunlunYaochiProtocol.AccessDecision? = nil,
        yaochiSanctumClass: BASYaochiSanctumClass? = nil,
        tianmenReadiness:
            BASKunlunHeavenGateProtocol.Readiness? = nil,
        tianmenGateClass: BASKunlunGateClass? = nil,
        tianmenPassState: BASKunlunGateState? = nil,
        escalationSuppressionCodes: [String] = [],
        kunlunAxisView: BASKunlunAxisView? = nil,
        kunlunTianmenWarrant: BASKunlunTianmenWarrant? = nil,
        kunlunGateDenialWrit: BASKunlunGateDenialWrit? = nil,
        layerReconciliationVerdict:
            BASObservationReconciliationVerdict? = nil,
        layerReconciliationReport:
            BASObservationReconciliationReport? = nil,
        presenceObservationBundle:
            BASPresenceObservationBundle? = nil,
        decompositionObservationBundle:
            BASDecompositionObservationBundle? = nil,
        softHandObservationBundle:
            BASSoftHandObservationBundle? = nil,
        leaseLifeObservationBundle:
            BASLeaseLifeObservationBundle? = nil,
        hostConstitutionObservationBundle:
            BASHostConstitutionObservationBundle? = nil,
        thoughtFoldObservationBundle:
            BASThoughtFoldObservationBundle? = nil,
        neuralOrganObservationBundle:
            BASNeuralOrganObservationBundle? = nil,
        hippocampalMemoryObservationBundle:
            BASHippocampalMemoryObservationBundle? = nil,
        worldPriorObservationBundle:
            BASWorldPriorObservationBundle? = nil,
        riskObservationBundle:
            BASRiskObservationBundle? = nil,
        updateTicketObservationBundle:
            BASUpdateTicketObservationBundle? = nil,
        cosmicScaleView: BASCosmicScaleView? = nil,
        ontologyFog: BASOntologyFog? = nil,
        ontologyShiftMark: BASOntologyShiftMark? = nil,
        abyssalRunMode: BASAbyssalRunMode? = nil,
        abyssBudget: BASAbyssBudget? = nil,
        cthulhuAssertionCeilingReasonCodes: [String] = [],
        cthulhuPermitEscalationReasonCodes: [String] = [],
        memoryTemperatureLayer: BASMemoryTemperatureLayer? = nil,
        ascentLease: BASAscentLease? = nil,
        axisDeviation: BASAxisDeviation? = nil,
        gatePressure: BASGatePressure? = nil,
        yaochiMemoryLayer: BASYaochiMemoryLayer? = nil,
        tianhengProfile: BASTianhengProfile? = nil,
        jadePermitGrade: BASJadePermitGrade? = nil,
        ascentBranches: [BASAscentBranch] = [],
        restSteps: [BASRestStep] = [],
        returnPaths: [BASReturnPath] = [],
        jadeCasket: BASJadeCasketSnapshot? = nil,
        jadeRefinementTickets: [BASJadeRefinementTicket] = []
    ) {
        self.candidateObservationBundle =
            candidateObservationBundle
        self.tribunalObservationBundle =
            tribunalObservationBundle
        self.abyssalPressure = abyssalPressure
        self.humanAnchorSignal = humanAnchorSignal
        self.sealAggregate = sealAggregate
        self.lifecycleAggregate = lifecycleAggregate
        self.narrativeDistortion = narrativeDistortion
        self.anomalyTrace = anomalyTrace
        self.abyssalBranches = abyssalBranches
        self.unknownReserve = unknownReserve
        self.forbiddenAggregate = forbiddenAggregate
        self.kunlunAxisAlignment = kunlunAxisAlignment
        self.jadeCanonVerification = jadeCanonVerification
        self.jadeCanonObjectClass = jadeCanonObjectClass
        self.riverOriginLineage = riverOriginLineage
        self.yaochiAccess = yaochiAccess
        self.yaochiSanctumClass = yaochiSanctumClass
        self.tianmenReadiness = tianmenReadiness
        self.tianmenGateClass = tianmenGateClass
        self.tianmenPassState = tianmenPassState
        self.escalationSuppressionCodes =
            escalationSuppressionCodes
        self.kunlunAxisView = kunlunAxisView
        self.kunlunTianmenWarrant = kunlunTianmenWarrant
        self.kunlunGateDenialWrit = kunlunGateDenialWrit
        self.layerReconciliationVerdict =
            layerReconciliationVerdict
        self.layerReconciliationReport =
            layerReconciliationReport
        self.presenceObservationBundle =
            presenceObservationBundle
        self.decompositionObservationBundle =
            decompositionObservationBundle
        self.softHandObservationBundle =
            softHandObservationBundle
        self.leaseLifeObservationBundle =
            leaseLifeObservationBundle
        self.hostConstitutionObservationBundle =
            hostConstitutionObservationBundle
        self.thoughtFoldObservationBundle =
            thoughtFoldObservationBundle
        self.neuralOrganObservationBundle =
            neuralOrganObservationBundle
        self.hippocampalMemoryObservationBundle =
            hippocampalMemoryObservationBundle
        self.worldPriorObservationBundle =
            worldPriorObservationBundle
        self.riskObservationBundle = riskObservationBundle
        self.updateTicketObservationBundle =
            updateTicketObservationBundle
        self.cosmicScaleView = cosmicScaleView
        self.ontologyFog = ontologyFog
        self.ontologyShiftMark = ontologyShiftMark
        self.abyssalRunMode = abyssalRunMode
        self.abyssBudget = abyssBudget
        self.cthulhuAssertionCeilingReasonCodes =
            cthulhuAssertionCeilingReasonCodes
        self.cthulhuPermitEscalationReasonCodes =
            cthulhuPermitEscalationReasonCodes
        self.memoryTemperatureLayer = memoryTemperatureLayer
        self.ascentLease = ascentLease
        self.axisDeviation = axisDeviation
        self.gatePressure = gatePressure
        self.yaochiMemoryLayer = yaochiMemoryLayer
        self.tianhengProfile = tianhengProfile
        self.jadePermitGrade = jadePermitGrade
        self.ascentBranches = ascentBranches
        self.restSteps = restSteps
        self.returnPaths = returnPaths
        self.jadeCasket = jadeCasket
        self.jadeRefinementTickets = jadeRefinementTickets
    }

    /// All-default singleton. Used by callers that emit a
    /// minimal audit entry (e.g. tests) and don't need any
    /// projections.
    public static let empty = BASAuditObservationProjections()
}

// MARK: - M436.4 — bundle-form audit emission overload

extension BASEBrainRuntimeCoordinator {
    /// Bundle-form overload of `buildSovereignAuditEntry(...)` —
    /// callers populate one `BASAuditObservationProjections` value
    /// instead of spelling 24+ optional parameters at the call site.
    /// Internally delegates to the per-parameter form (preserved
    /// for backward-compat; deprecation candidate for next chapter).
    func buildSovereignAuditEntry(
        sovereignVerdict: BASSovereignVerdict,
        sovereignCommitTokens: [BASSovereignCommitToken],
        sovereignWarrants: [BASSovereignWarrant],
        quarantineRecords: [BASQuarantineRecord],
        runtimeTrace: BASRuntimeTrace,
        thoughtFold: BASThoughtFold,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        projections: BASAuditObservationProjections = .empty
    ) -> BASSovereignAuditEntry {
        buildSovereignAuditEntry(
            sovereignVerdict: sovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            quarantineRecords: quarantineRecords,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            riskCard: riskCard,
            actionPermit: actionPermit,
            candidateObservationBundle:
                projections.candidateObservationBundle,
            tribunalObservationBundle:
                projections.tribunalObservationBundle,
            abyssalPressure: projections.abyssalPressure,
            humanAnchorSignal: projections.humanAnchorSignal,
            sealAggregate: projections.sealAggregate,
            lifecycleAggregate: projections.lifecycleAggregate,
            narrativeDistortion: projections.narrativeDistortion,
            anomalyTrace: projections.anomalyTrace,
            abyssalBranches: projections.abyssalBranches,
            unknownReserve: projections.unknownReserve,
            forbiddenAggregate: projections.forbiddenAggregate,
            kunlunAxisAlignment: projections.kunlunAxisAlignment,
            jadeCanonVerification:
                projections.jadeCanonVerification,
            jadeCanonObjectClass: projections.jadeCanonObjectClass,
            riverOriginLineage: projections.riverOriginLineage,
            yaochiAccess: projections.yaochiAccess,
            yaochiSanctumClass: projections.yaochiSanctumClass,
            tianmenReadiness: projections.tianmenReadiness,
            tianmenGateClass: projections.tianmenGateClass,
            tianmenPassState: projections.tianmenPassState,
            escalationSuppressionCodes:
                projections.escalationSuppressionCodes,
            kunlunAxisView: projections.kunlunAxisView,
            kunlunTianmenWarrant: projections.kunlunTianmenWarrant,
            kunlunGateDenialWrit: projections.kunlunGateDenialWrit,
            layerReconciliationVerdict:
                projections.layerReconciliationVerdict,
            layerReconciliationReport:
                projections.layerReconciliationReport,
            presenceObservationBundle:
                projections.presenceObservationBundle,
            decompositionObservationBundle:
                projections.decompositionObservationBundle,
            softHandObservationBundle:
                projections.softHandObservationBundle,
            leaseLifeObservationBundle:
                projections.leaseLifeObservationBundle,
            hostConstitutionObservationBundle:
                projections.hostConstitutionObservationBundle,
            thoughtFoldObservationBundle:
                projections.thoughtFoldObservationBundle,
            neuralOrganObservationBundle:
                projections.neuralOrganObservationBundle,
            hippocampalMemoryObservationBundle:
                projections.hippocampalMemoryObservationBundle,
            worldPriorObservationBundle:
                projections.worldPriorObservationBundle,
            riskObservationBundle:
                projections.riskObservationBundle,
            updateTicketObservationBundle:
                projections.updateTicketObservationBundle,
            cosmicScaleView: projections.cosmicScaleView,
            ontologyFog: projections.ontologyFog,
            ontologyShiftMark: projections.ontologyShiftMark,
            abyssalRunMode: projections.abyssalRunMode,
            abyssBudget: projections.abyssBudget,
            cthulhuAssertionCeilingReasonCodes:
                projections.cthulhuAssertionCeilingReasonCodes,
            cthulhuPermitEscalationReasonCodes:
                projections.cthulhuPermitEscalationReasonCodes,
            memoryTemperatureLayer:
                projections.memoryTemperatureLayer,
            ascentLease: projections.ascentLease,
            axisDeviation: projections.axisDeviation,
            gatePressure: projections.gatePressure,
            yaochiMemoryLayer:
                projections.yaochiMemoryLayer,
            tianhengProfile: projections.tianhengProfile,
            jadePermitGrade: projections.jadePermitGrade,
            ascentBranches: projections.ascentBranches,
            restSteps: projections.restSteps,
            returnPaths: projections.returnPaths,
            jadeCasket: projections.jadeCasket,
            jadeRefinementTickets:
                projections.jadeRefinementTickets)
    }
}
