import Foundation
import BASMemory

extension DecisionMemorySource {
    var basSource: BASMemorySource {
        switch self {
        case .history:
            .history
        case .reflection:
            .reflection
        case .reminder:
            .reminder
        case .pattern:
            .pattern
        }
    }
}

extension DecisionMemoryDecayPolicy {
    var basDecayPolicy: BASMemoryDecayPolicy {
        switch self {
        case .stable:
            .stable
        case .slow:
            .slow
        case .medium:
            .medium
        case .fast:
            .fast
        }
    }
}

extension DecisionMemoryGovernanceDecision {
    init(_ decision: BASMemoryGovernanceDecision) {
        switch decision {
        case .admit:
            self = .admit
        case .deferred:
            self = .deferred
        case .reject:
            self = .reject
        }
    }
}

extension DecisionMemoryLifecycleState {
    init(_ state: BASMemoryLifecycleState) {
        switch state {
        case .active:
            self = .active
        case .aging:
            self = .aging
        case .retired:
            self = .retired
        }
    }
}

extension DecisionMemoryDraft {
    var governanceDraftInput: BASMemoryGovernanceDraftInput {
        BASMemoryGovernanceDraftInput(
            id: id,
            typeID: type.rawValue,
            topic: topic,
            headline: headline,
            value: value,
            confidence: confidence,
            priority: priority,
            source: source.basSource,
            lastConfirmedAt: lastConfirmedAt,
            decayPolicy: decayPolicy.basDecayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: evidenceCount,
            provenanceSummary: provenanceSummary,
            promotionPolicy: promotionPolicy,
            tierID: tier.rawValue
        )
    }
}

extension DecisionMemoryRecord {
    var lifecycleReviewInput: BASMemoryLifecycleReviewInput {
        BASMemoryLifecycleReviewInput(
            source: source.basSource,
            evidenceCount: evidenceCount,
            decayPolicy: decayPolicy.basDecayPolicy,
            provenanceSummary: provenanceSummary,
            lastConfirmedAt: lastConfirmedAt,
            reviewNow: reviewedAt
        )
    }
}
