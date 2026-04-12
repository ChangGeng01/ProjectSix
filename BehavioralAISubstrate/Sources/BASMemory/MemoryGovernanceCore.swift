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
        let continuityProtected =
            draft.typeID == "goal" ||
            draft.typeID == "identity" ||
            draft.promotionPolicy.isImmediate

        let trustProfile = BASMemoryTrustEngine.profile(
            source: draft.source,
            evidenceCount: draft.evidenceCount,
            decayPolicy: draft.decayPolicy,
            governanceStatus: .pending,
            isPending: draft.promotionPolicy.isCandidateOnly || draft.typeID == "situational",
            provenanceSummary: draft.provenanceSummary,
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

        if draft.confidence < 0.58, draft.evidenceCount <= 1 {
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
}
