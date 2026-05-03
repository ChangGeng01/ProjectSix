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
            BASUpdateTicketObservationBundle? = nil
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
                projections.updateTicketObservationBundle)
    }
}
