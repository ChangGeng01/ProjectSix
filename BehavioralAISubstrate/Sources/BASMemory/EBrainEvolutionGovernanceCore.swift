import Foundation
import BASRuntimeCore

public enum BASExperienceCandidateType: String, Codable, CaseIterable, Sendable {
    case success
    case failure
    case guardPattern = "guard"
    case bias
    case workflow
    case host
    case rule
}

public struct BASExperienceCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var sourceRefs: [String]
    public var candidateType: BASExperienceCandidateType
    public var summary: String
    public var stabilitySignal: Double
    public var contaminationRisk: Double
    public var hostScope: String
    public var sovereignScope: String

    public init(
        schemaVersion: String = BASExperienceCandidate.currentSchemaVersion,
        candidateID: String,
        sourceRefs: [String] = [],
        candidateType: BASExperienceCandidateType,
        summary: String,
        stabilitySignal: Double,
        contaminationRisk: Double,
        hostScope: String,
        sovereignScope: String
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.sourceRefs = sourceRefs
        self.candidateType = candidateType
        self.summary = summary
        self.stabilitySignal = min(max(stabilitySignal, 0), 1)
        self.contaminationRisk = min(max(contaminationRisk, 0), 1)
        self.hostScope = hostScope
        self.sovereignScope = sovereignScope
    }
}

/// 全面进化 T2.3 低熵 — one TYPED observed effect。 The legacy
/// `observedEffects: [String]` carries colon-string conventions
/// ("key:value") that every consumer re-parses;this struct is the
/// typed parallel form。 ADDITIVE ONLY:the string field stays the
/// source of record for the spine (it sits on the replay-digest
/// preimage);typed effects ride beside it as an Optional that
/// synthesized Codable OMITS when nil — so every pre-existing record
/// and every producer that never sets it stays byte-identical。
public struct BASShadowTrialTypedEffect: BASSchemaVersioned,
    Equatable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    /// What kind of fact this effect states。 `metric` = numeric
    /// measurement,`flag` = boolean condition,`label` = enumerated
    /// classification,`prose` = free text (the legacy default)。
    public enum Kind: String, Codable, Equatable, Sendable {
        case metric
        case flag
        case label
        case prose
    }

    public var schemaVersion: String
    public var key: String
    public var value: String
    public var kind: Kind

    public init(
        schemaVersion: String =
            BASShadowTrialTypedEffect.currentSchemaVersion,
        key: String,
        value: String,
        kind: Kind
    ) {
        self.schemaVersion = schemaVersion
        self.key = key
        self.value = value
        self.kind = kind
    }
}

public struct BASShadowTrialRecord: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var trialID: String
    public var candidateRef: String
    public var trialScope: String
    public var startAt: Date
    public var endAt: Date?
    public var observedEffects: [String]
    public var failConditions: [String]
    public var promotionRecommendation: String?
    public var completionState: String
    /// 全面进化 T2.3 低熵 — typed parallel form of `observedEffects`。
    /// MUST stay `Optional` with default `nil` and synthesized Codable:
    /// `encodeIfPresent` omits the absent key,which is what keeps every
    /// record that never sets it (including the SPINE producer) byte-
    /// identical on the replay-digest preimage (ADR-014;same mechanism
    /// as `endAt`/`promotionRecommendation` above)。 Producers that set
    /// it MUST dual-write the legacy strings too — typed is a parallel
    /// lane,not a replacement。
    public var typedObservedEffects: [BASShadowTrialTypedEffect]?

    public init(
        schemaVersion: String = BASShadowTrialRecord.currentSchemaVersion,
        trialID: String,
        candidateRef: String,
        trialScope: String,
        startAt: Date = .now,
        endAt: Date? = nil,
        observedEffects: [String] = [],
        failConditions: [String] = [],
        promotionRecommendation: String? = nil,
        completionState: String,
        typedObservedEffects: [BASShadowTrialTypedEffect]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.trialID = trialID
        self.candidateRef = candidateRef
        self.trialScope = trialScope
        self.startAt = startAt
        self.endAt = endAt
        self.observedEffects = observedEffects
        self.failConditions = failConditions
        self.promotionRecommendation = promotionRecommendation
        self.completionState = completionState
        self.typedObservedEffects = typedObservedEffects
    }
}

extension BASShadowTrialRecord {
    /// 全面进化 T2.3 低熵 — the ONE canonical effect-field view both
    /// evidence composers consume。 Typed-first with string fallback:
    ///   - `typedObservedEffects == nil` (every legacy record + the
    ///     spine producer) → the legacy colon-string parse, verbatim。
    ///   - typed present → typed values WIN,but any key present in
    ///     BOTH lanes with DIFFERENT values is a producer bug ⇒
    ///     returns nil and the caller counts the record as skipped
    ///     (drift must be loud — silently preferring either lane
    ///     would let the two diverge forever)。
    /// Pure;keys/values trimmed exactly as the legacy parse did。
    public func effectFields() -> [String: String]? {
        var stringFields: [String: String] = [:]
        for effect in observedEffects {
            guard let colon = effect.firstIndex(of: ":") else { continue }
            let key = String(effect[..<colon])
                .trimmingCharacters(in: .whitespaces)
            let value = String(effect[effect.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            stringFields[key] = value
        }
        guard let typed = typedObservedEffects else { return stringFields }
        var merged = stringFields
        for e in typed {
            if let stringValue = stringFields[e.key],
               stringValue != e.value {
                return nil  // typed/string disagreement ⇒ skip record
            }
            merged[e.key] = e.value
        }
        return merged
    }
}

public struct BASVersionDelta: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var deltaID: String
    public var targetType: String
    public var beforeRef: String?
    public var afterRef: String
    public var reason: String
    public var impactScope: String
    public var rollbackRef: String?

    public init(
        schemaVersion: String = BASVersionDelta.currentSchemaVersion,
        deltaID: String,
        targetType: String,
        beforeRef: String? = nil,
        afterRef: String,
        reason: String,
        impactScope: String,
        rollbackRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.deltaID = deltaID
        self.targetType = targetType
        self.beforeRef = beforeRef
        self.afterRef = afterRef
        self.reason = reason
        self.impactScope = impactScope
        self.rollbackRef = rollbackRef
    }
}

public struct BASWorkflowCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var workflowID: String
    public var taskDomain: String
    public var steps: [String]
    public var observedGain: Double
    public var safetyNotes: [String]
    public var hostSpecific: Bool
    public var shadowTrialState: String

    public init(
        schemaVersion: String = BASWorkflowCandidate.currentSchemaVersion,
        workflowID: String,
        taskDomain: String,
        steps: [String] = [],
        observedGain: Double,
        safetyNotes: [String] = [],
        hostSpecific: Bool,
        shadowTrialState: String = "not_required"
    ) {
        self.schemaVersion = schemaVersion
        self.workflowID = workflowID
        self.taskDomain = taskDomain
        self.steps = steps
        self.observedGain = min(max(observedGain, 0), 1)
        self.safetyNotes = safetyNotes
        self.hostSpecific = hostSpecific
        self.shadowTrialState = shadowTrialState
    }
}

public struct BASGuardTemplateCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var templateID: String
    public var sceneType: String
    public var boundaryScriptRef: String?
    public var delayPacketRef: String?
    public var substituteRef: String?
    public var protectiveGain: Double
    public var overreachRisk: Double

    public init(
        schemaVersion: String = BASGuardTemplateCandidate.currentSchemaVersion,
        templateID: String,
        sceneType: String,
        boundaryScriptRef: String? = nil,
        delayPacketRef: String? = nil,
        substituteRef: String? = nil,
        protectiveGain: Double,
        overreachRisk: Double
    ) {
        self.schemaVersion = schemaVersion
        self.templateID = templateID
        self.sceneType = sceneType
        self.boundaryScriptRef = boundaryScriptRef
        self.delayPacketRef = delayPacketRef
        self.substituteRef = substituteRef
        self.protectiveGain = min(max(protectiveGain, 0), 1)
        self.overreachRisk = min(max(overreachRisk, 0), 1)
    }
}

public struct BASBiasRecord: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var biasID: String
    public var biasType: String
    public var sourceRefs: [String]
    public var severity: Double
    public var recurrenceScore: Double
    public var affectedLayers: [String]

    public init(
        schemaVersion: String = BASBiasRecord.currentSchemaVersion,
        biasID: String,
        biasType: String,
        sourceRefs: [String] = [],
        severity: Double,
        recurrenceScore: Double,
        affectedLayers: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.biasID = biasID
        self.biasType = biasType
        self.sourceRefs = sourceRefs
        self.severity = min(max(severity, 0), 1)
        self.recurrenceScore = min(max(recurrenceScore, 0), 1)
        self.affectedLayers = affectedLayers
    }
}

public struct BASRiskPatternCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var patternID: String
    public var sourceRefs: [String]
    public var riskDomain: String
    public var triggerSignals: [String]
    public var severity: Double
    public var recurrenceScore: Double
    public var sovereignReviewRequired: Bool
    public var shadowTrialState: String

    public init(
        schemaVersion: String = BASRiskPatternCandidate.currentSchemaVersion,
        patternID: String,
        sourceRefs: [String] = [],
        riskDomain: String,
        triggerSignals: [String] = [],
        severity: Double,
        recurrenceScore: Double,
        sovereignReviewRequired: Bool,
        shadowTrialState: String = "not_required"
    ) {
        self.schemaVersion = schemaVersion
        self.patternID = patternID
        self.sourceRefs = sourceRefs
        self.riskDomain = riskDomain
        self.triggerSignals = triggerSignals
        self.severity = min(max(severity, 0), 1)
        self.recurrenceScore = min(max(recurrenceScore, 0), 1)
        self.sovereignReviewRequired = sovereignReviewRequired
        self.shadowTrialState = shadowTrialState
    }
}

public struct BASRetractionOrder: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var orderID: String
    public var targetRefs: [String]
    public var cascadeRefs: [String]
    public var reasonCodes: [String]
    public var executionState: String

    public init(
        schemaVersion: String = BASRetractionOrder.currentSchemaVersion,
        orderID: String,
        targetRefs: [String] = [],
        cascadeRefs: [String] = [],
        reasonCodes: [String] = [],
        executionState: String
    ) {
        self.schemaVersion = schemaVersion
        self.orderID = orderID
        self.targetRefs = targetRefs
        self.cascadeRefs = cascadeRefs
        self.reasonCodes = reasonCodes
        self.executionState = executionState
    }
}

/// chapter 四百五 / M982:adopts `BASBundleIDProtocol` per
/// 系统熵 reduction protocol-adoption pattern (2nd of 18
/// timestamp-less bundle conformances)。
public struct BASLearningExportBundle:
    BASSchemaVersioned, BASBundleIDProtocol
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var bundleID: String
    public var candidateRefs: [String]
    public var scrubbed: Bool
    public var privacySafe: Bool
    public var sovereignSafe: Bool
    public var evaluationTags: [String]

    public init(
        schemaVersion: String = BASLearningExportBundle.currentSchemaVersion,
        bundleID: String,
        candidateRefs: [String] = [],
        scrubbed: Bool,
        privacySafe: Bool,
        sovereignSafe: Bool,
        evaluationTags: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.bundleID = bundleID
        self.candidateRefs = candidateRefs
        self.scrubbed = scrubbed
        self.privacySafe = privacySafe
        self.sovereignSafe = sovereignSafe
        self.evaluationTags = evaluationTags
    }
}

public struct BASEvolutionSeal: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sealID: String
    public var candidateRef: String
    public var allowedScope: String
    public var trialRequired: Bool
    public var approvalRequirements: [String]
    public var signature: String
    public var approvalState: String

    public init(
        schemaVersion: String = BASEvolutionSeal.currentSchemaVersion,
        sealID: String,
        candidateRef: String,
        allowedScope: String,
        trialRequired: Bool,
        approvalRequirements: [String] = [],
        signature: String,
        approvalState: String
    ) {
        self.schemaVersion = schemaVersion
        self.sealID = sealID
        self.candidateRef = candidateRef
        self.allowedScope = allowedScope
        self.trialRequired = trialRequired
        self.approvalRequirements = approvalRequirements
        self.signature = signature
        self.approvalState = approvalState
    }
}

public struct BASEvolutionPromotionGateVerdict:
    Codable, Equatable, Sendable
{
    public let allowsPromotion: Bool
    public let reasonCodes: [String]
    public let primaryReason: String?

    public init(
        allowsPromotion: Bool,
        reasonCodes: [String] = [],
        primaryReason: String? = nil
    ) {
        self.allowsPromotion = allowsPromotion
        self.reasonCodes = reasonCodes
        self.primaryReason = primaryReason ?? reasonCodes.first
    }
}

public extension BASShadowTrialRecord {
    var isPassed: Bool {
        completionState == "completed" || completionState == "passed"
    }

    var isFailed: Bool {
        completionState == "failed" || completionState == "blocked"
    }

    var isPending: Bool {
        !isPassed && !isFailed
    }
}

public extension BASEvolutionSeal {
    var isApproved: Bool {
        approvalState == "sealed" || approvalState == "approved"
    }

    var isDenied: Bool {
        approvalState == "denied" || approvalState == "rejected"
    }

    var isPending: Bool {
        !isApproved && !isDenied
    }
}

public enum BASEvolutionPromotionGate {
    public static func evaluate(
        checkpoint: BASEvolutionCheckpointStoredFields,
        targetApprovalState: BASEvolutionApprovalState
    ) -> BASEvolutionPromotionGateVerdict {
        evaluate(
            checkpoint: BASEvolutionCheckpointSummary(
                id: checkpoint.id,
                previousCheckpointID: checkpoint.previousCheckpointID,
                createdAt: checkpoint.createdAt,
                diffSummary: checkpoint.diffSummary,
                rollbackReady: checkpoint.rollbackReady,
                approvalState: checkpoint.approvalState,
                lineageSummary: checkpoint.lineageSummary
            ),
            targetApprovalState: targetApprovalState
        )
    }

    public static func evaluate(
        checkpoint: BASEvolutionCheckpointSummary,
        targetApprovalState: BASEvolutionApprovalState
    ) -> BASEvolutionPromotionGateVerdict {
        guard targetApprovalState == .automatic else {
            return BASEvolutionPromotionGateVerdict(allowsPromotion: true)
        }

        guard let governanceSummary = checkpoint.lineageSummary?.governanceSummary else {
            return BASEvolutionPromotionGateVerdict(allowsPromotion: true)
        }

        let reasonCodes = blockedReasonCodes(for: governanceSummary)
        guard reasonCodes.isEmpty == false else {
            return BASEvolutionPromotionGateVerdict(allowsPromotion: true)
        }

        return BASEvolutionPromotionGateVerdict(
            allowsPromotion: false,
            reasonCodes: reasonCodes,
            primaryReason: reasonCodes.first
        )
    }

    public static func blockedReasonCodes(
        for governanceSummary: BASEvolutionLineageSummary.GovernanceSummary
    ) -> [String] {
        if governanceSummary.blockedPromotionReasonCodes.isEmpty == false {
            return governanceSummary.blockedPromotionReasonCodes
        }

        var reasons: [String] = []
        if governanceSummary.failedShadowTrialCount > 0 {
            reasons.append("evolution.shadow_trial_failed")
        }
        if governanceSummary.pendingShadowTrialCount > 0 {
            reasons.append("evolution.shadow_trial_pending")
        }
        if governanceSummary.deniedSealCount > 0 {
            reasons.append("evolution.seal_denied")
        }
        if governanceSummary.pendingSealCount > 0 {
            reasons.append("evolution.seal_pending")
        }
        if governanceSummary.pendingRetractionCount > 0 {
            reasons.append("evolution.retraction_pending")
        }
        return reasons
    }

    public static func operatorFacingRequirementLabels(
        for reasonCodes: [String]
    ) -> [String] {
        reasonCodes.compactMap { reasonCode in
            switch reasonCode {
            case "evolution.shadow_trial_failed":
                "shadow trial failure"
            case "evolution.shadow_trial_pending":
                "shadow trial"
            case "evolution.seal_denied":
                "evolution seal denial"
            case "evolution.seal_pending":
                "evolution seal review"
            case "evolution.retraction_pending":
                "retraction cleanup"
            default:
                nil
            }
        }
    }
}
