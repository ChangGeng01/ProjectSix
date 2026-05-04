import Foundation

public enum BASMemoryGovernanceDecision: String, Codable, Sendable {
    case admit
    case deferred
    case reject
}

public enum BASMemoryLifecycleState: String, Codable, Sendable {
    case active
    case aging
    case retired
}

public struct BASMemoryGovernanceAssessment: Codable, Equatable, Sendable {
    public let decision: BASMemoryGovernanceDecision
    public let reason: String

    public init(decision: BASMemoryGovernanceDecision, reason: String) {
        self.decision = decision
        self.reason = reason
    }
}

public struct BASMemoryGovernanceDraftInput: Codable, Equatable, Sendable {
    public let id: String
    public let typeID: String
    public let topic: String
    public let headline: String
    public let value: String
    public let confidence: Double
    public let priority: Double
    public let source: BASMemorySource
    public let lastConfirmedAt: Date
    public let decayPolicy: BASMemoryDecayPolicy
    public let retrievalTags: [String]
    public let evidenceCount: Int
    public let provenanceSummary: String
    public let promotionPolicy: BASDraftPromotionPolicy
    public let tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        source: BASMemorySource,
        lastConfirmedAt: Date,
        decayPolicy: BASMemoryDecayPolicy,
        retrievalTags: [String],
        evidenceCount: Int,
        provenanceSummary: String,
        promotionPolicy: BASDraftPromotionPolicy,
        tierID: String
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.source = source
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicy = decayPolicy
        self.retrievalTags = retrievalTags
        self.evidenceCount = evidenceCount
        self.provenanceSummary = provenanceSummary
        self.promotionPolicy = promotionPolicy
        self.tierID = tierID
    }
}

public struct BASMemoryLifecycleReviewInput: Codable, Equatable, Sendable {
    public let source: BASMemorySource
    public let evidenceCount: Int
    public let decayPolicy: BASMemoryDecayPolicy
    public let provenanceSummary: String
    public let lastConfirmedAt: Date
    public let reviewNow: Date

    public init(
        source: BASMemorySource,
        evidenceCount: Int,
        decayPolicy: BASMemoryDecayPolicy,
        provenanceSummary: String,
        lastConfirmedAt: Date,
        reviewNow: Date
    ) {
        self.source = source
        self.evidenceCount = evidenceCount
        self.decayPolicy = decayPolicy
        self.provenanceSummary = provenanceSummary
        self.lastConfirmedAt = lastConfirmedAt
        self.reviewNow = reviewNow
    }
}

public struct BASPreparedMemoryGovernanceDraft: Equatable, Sendable {
    public let draft: BASMemoryGovernanceDraftInput
    public let assessment: BASMemoryGovernanceAssessment
    public let horizonDescriptor: BASMemoryHorizonClaimDescriptor

    public init(
        draft: BASMemoryGovernanceDraftInput,
        assessment: BASMemoryGovernanceAssessment,
        horizonDescriptor: BASMemoryHorizonClaimDescriptor
    ) {
        self.draft = draft
        self.assessment = assessment
        self.horizonDescriptor = horizonDescriptor
    }
}

public extension BASDraftPromotionPolicy {
    var isImmediate: Bool {
        if case .immediate = self {
            return true
        }
        return false
    }

    var isCandidateOnly: Bool {
        if case .candidateOnly = self {
            return true
        }
        return false
    }
}

public extension BASMemoryGovernance {
    static func assess(
        draft: BASMemoryGovernanceDraftInput,
        behavior: BASMemoryTrustBehavior = .generic
    ) -> BASMemoryGovernanceAssessment {
        baselineAssessment(
            draft: draft,
            behavior: behavior
        )
    }

    static func assess(
        draft: BASMemoryGovernanceDraftInput,
        behavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy
    ) -> BASMemoryGovernanceAssessment {
        prepare(
            draft: draft,
            behavior: behavior,
            persistencePolicy: persistencePolicy
        ).assessment
    }

    static func prepare(
        draft: BASMemoryGovernanceDraftInput,
        behavior: BASMemoryTrustBehavior = .generic,
        persistencePolicy: BASMemoryHorizonPersistencePolicy = .unrestricted
    ) -> BASPreparedMemoryGovernanceDraft {
        let continuityProtected = isContinuityProtected(draft)
        let trustProfile = trustProfile(
            for: draft,
            behavior: behavior
        )
        let horizonDescriptor = persistencePolicy.classify(
            draft,
            continuityProtected: continuityProtected,
            provenanceRisk: trustProfile.provenanceRisk
        )
        let shouldStageVolatileClaim = horizonDescriptor.requiresExternalRefresh
        let shouldQuarantineProvenance = horizonDescriptor.contaminationState == .quarantined
        let shouldRequireEvidenceCorroboration = horizonDescriptor.evidenceState == .caveated

        guard shouldStageVolatileClaim || shouldQuarantineProvenance || shouldRequireEvidenceCorroboration else {
            return BASPreparedMemoryGovernanceDraft(
                draft: draft,
                assessment: baselineAssessment(
                    draft: draft,
                    behavior: behavior
                ),
                horizonDescriptor: horizonDescriptor
            )
        }

        var retrievalTags = draft.retrievalTags
        var provenanceSummary = draft.provenanceSummary
        var adjustedDecayPolicy = draft.decayPolicy
        var adjustedTierID = draft.tierID

        if shouldStageVolatileClaim {
            retrievalTags.append(contentsOf: persistencePolicy.volatileClaimRetrievalTags)
            provenanceSummary = appendHorizonNote(
                "External refresh required before durable admission.",
                to: provenanceSummary
            )
            adjustedDecayPolicy = .fast
            adjustedTierID = persistencePolicy.volatileTierID
        }

        if shouldQuarantineProvenance {
            retrievalTags.append(contentsOf: persistencePolicy.quarantineRetrievalTags)
            provenanceSummary = appendHorizonNote(
                "Tool-shaped provenance quarantined as observation-only.",
                to: provenanceSummary
            )
            adjustedDecayPolicy = .fast
            adjustedTierID = persistencePolicy.volatileTierID
        }

        if shouldRequireEvidenceCorroboration {
            retrievalTags.append(contentsOf: persistencePolicy.evidencePendingRetrievalTags)
            provenanceSummary = appendHorizonNote(
                "Evidence caveat requires at least \(horizonDescriptor.minimumDurableEvidenceCount) corroborating signals before durable admission.",
                to: provenanceSummary
            )
        }

        let adjustedDraft = BASMemoryGovernanceDraftInput(
            id: draft.id,
            typeID: draft.typeID,
            topic: draft.topic,
            headline: draft.headline,
            value: draft.value,
            confidence: draft.confidence,
            priority: draft.priority,
            source: draft.source,
            lastConfirmedAt: draft.lastConfirmedAt,
            decayPolicy: adjustedDecayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: draft.evidenceCount,
            provenanceSummary: provenanceSummary,
            promotionPolicy: .candidateOnly,
            tierID: adjustedTierID
        )

        let reasonPrefix = shouldQuarantineProvenance
            ? "Claim remains quarantined until "
            : "Claim remains staged until "
        let reason = if horizonDescriptor.releaseRequirements.isEmpty {
            reasonPrefix + "corroborating evidence is available."
        } else {
            reasonPrefix + horizonDescriptor.releaseRequirements.joined(separator: " and ") + "."
        }

        return BASPreparedMemoryGovernanceDraft(
            draft: adjustedDraft,
            assessment: BASMemoryGovernanceAssessment(
                decision: .deferred,
                reason: reason
            ),
            horizonDescriptor: horizonDescriptor
        )
    }

    /// **M596 chapter 一百六十七 — anti-magic-number** (chapter 一百六十六
    /// backlog item): single-evidence-low-confidence rejection
    /// threshold. Below this confidence, a single-evidence draft
    /// fails the baseline admit gate (unless continuity-protected).
    /// Pre-fix this 0.58 was inline at line 282; extracted with
    /// doctrine derivation: 0.58 sits below the typical
    /// `confidenceCeiling: 0.64` (line 793 of MemoryCore.swift) so
    /// admit-gate threshold is strictly lower than typical ceiling
    /// — drafts that JUST cross the ceiling don't auto-fail this gate.
    fileprivate static let
        singleEvidenceLowConfidenceRejectionThreshold:
        Double = 0.58

    /// **M596 chapter 一百六十七 — anti-magic-number**: minimum
    /// evidence count above which the low-confidence rejection
    /// gate doesn't apply. `evidenceCount > 1` = multiple
    /// independent supporting signals → admit even at low
    /// confidence (multiple sources outweigh weak signal).
    fileprivate static let
        singleEvidenceCeilingForLowConfidenceGate: Int = 1

    static func baselineAssessment(
        draft: BASMemoryGovernanceDraftInput,
        behavior: BASMemoryTrustBehavior = .generic
    ) -> BASMemoryGovernanceAssessment {
        let continuityProtected = isContinuityProtected(draft)

        let trustProfile = trustProfile(
            for: draft,
            behavior: behavior
        )

        if trustProfile.provenanceRisk {
            return BASMemoryGovernanceAssessment(
                decision: .reject,
                reason: "Contaminated or tool-shaped provenance is blocked from the long-term memory path."
            )
        }

        if draft.promotionPolicy.isCandidateOnly || draft.typeID == "situational" {
            return BASMemoryGovernanceAssessment(
                decision: .deferred,
                reason: "Situational memory stays staged until a later session proves it matters."
            )
        }

        if draft.confidence < Self
            .singleEvidenceLowConfidenceRejectionThreshold,
            draft.evidenceCount <= Self
                .singleEvidenceCeilingForLowConfidenceGate {
            if continuityProtected {
                return BASMemoryGovernanceAssessment(
                    decision: .admit,
                    reason: "Continuity-critical memory gets preserved even when the first signal is sparse."
                )
            }
            return BASMemoryGovernanceAssessment(
                decision: .reject,
                reason: "Single low-confidence signal is not allowed into the long-term memory path."
            )
        }

        if trustProfile.tier == .low, draft.evidenceCount <= 1 {
            if continuityProtected {
                return BASMemoryGovernanceAssessment(
                    decision: .admit,
                    reason: "Continuity-critical memory bypasses low-trust singleton rejection."
                )
            }
            return BASMemoryGovernanceAssessment(
                decision: .reject,
                reason: "Low-trust singleton draft is treated as noise instead of durable memory."
            )
        }

        if draft.decayPolicy == .fast, draft.priority < 0.7, draft.evidenceCount <= 1 {
            if continuityProtected {
                return BASMemoryGovernanceAssessment(
                    decision: .admit,
                    reason: "Continuity-critical memory keeps a durable slot even under fast decay."
                )
            }
            return BASMemoryGovernanceAssessment(
                decision: .reject,
                reason: "Fast-decay low-priority draft is treated as noise instead of memory."
            )
        }

        if draft.typeID == "support", draft.evidenceCount < 2 {
            return BASMemoryGovernanceAssessment(
                decision: .deferred,
                reason: "Support patterns need repeated evidence before admission."
            )
        }

        return BASMemoryGovernanceAssessment(
            decision: .admit,
            reason: "Structured evidence is strong enough to participate in governed memory."
        )
    }

    static func isContinuityProtected(
        _ draft: BASMemoryGovernanceDraftInput
    ) -> Bool {
        draft.typeID == "goal" ||
            draft.typeID == "identity"
    }

    static func shouldPromote(
        policy: BASDraftPromotionPolicy,
        confirmationCount: Int,
        evidenceCount: Int
    ) -> Bool {
        switch policy {
        case .immediate:
            true
        case let .repeated(minConfirmationCount, minEvidenceCount):
            confirmationCount >= minConfirmationCount ||
                evidenceCount >= minEvidenceCount
        case .candidateOnly:
            false
        }
    }

    static func nextLifecycleState(
        for review: BASMemoryLifecycleReviewInput,
        behavior: BASMemoryTrustBehavior = .generic
    ) -> BASMemoryLifecycleState {
        let ageInDays = max(0, review.reviewNow.timeIntervalSince(review.lastConfirmedAt) / 86_400)
        let trustProfile = BASMemoryTrustEngine.profile(
            source: review.source,
            evidenceCount: review.evidenceCount,
            decayPolicy: review.decayPolicy,
            governanceStatus: .admitted,
            isPending: false,
            provenanceSummary: review.provenanceSummary,
            behavior: behavior
        )
        let stableDays = 365 * trustProfile.decayGraceMultiplier
        let slowAgingDays = 45 * trustProfile.decayGraceMultiplier
        let slowRetireDays = 120 * trustProfile.decayGraceMultiplier
        let mediumAgingDays = 14 * trustProfile.decayGraceMultiplier
        let mediumRetireDays = 45 * trustProfile.decayGraceMultiplier
        let fastAgingDays = 3 * trustProfile.decayGraceMultiplier
        let fastRetireDays = 10 * trustProfile.decayGraceMultiplier

        switch review.decayPolicy {
        case .stable:
            return ageInDays >= stableDays ? .aging : .active
        case .slow:
            return ageInDays >= slowRetireDays ? .retired : (ageInDays >= slowAgingDays ? .aging : .active)
        case .medium:
            return ageInDays >= mediumRetireDays ? .retired : (ageInDays >= mediumAgingDays ? .aging : .active)
        case .fast:
            return ageInDays >= fastRetireDays ? .retired : (ageInDays >= fastAgingDays ? .aging : .active)
        }
    }

    private static func trustProfile(
        for draft: BASMemoryGovernanceDraftInput,
        behavior: BASMemoryTrustBehavior
    ) -> BASMemoryTrustProfile {
        BASMemoryTrustEngine.profile(
            source: draft.source,
            evidenceCount: draft.evidenceCount,
            decayPolicy: draft.decayPolicy,
            governanceStatus: .pending,
            isPending: draft.promotionPolicy.isCandidateOnly || draft.typeID == "situational",
            provenanceSummary: draft.provenanceSummary,
            behavior: behavior
        )
    }

    private static func appendHorizonNote(
        _ note: String,
        to provenanceSummary: String
    ) -> String {
        if provenanceSummary.localizedCaseInsensitiveContains(note) {
            return provenanceSummary
        }
        if provenanceSummary.isEmpty {
            return note
        }
        return "\(provenanceSummary) Horizon: \(note)"
    }
}
