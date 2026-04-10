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

extension DecisionMemoryCandidateStatus {
    init(_ status: BASMemoryCandidateStatus) {
        switch status {
        case .pending:
            self = .pending
        case .promoted:
            self = .promoted
        }
    }
}

extension DecisionMemoryWriteOperation {
    init(_ operation: BASMemoryWriteOperation) {
        switch operation {
        case .add:
            self = .add
        case .update:
            self = .update
        case .delete:
            self = .delete
        case .noop:
            self = .noop
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

    var reconciliationDraftInput: BASMemoryReconciliationDraftInput {
        BASMemoryReconciliationDraftInput(
            draft: governanceDraftInput,
            fingerprint: fingerprint
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

    var basSnapshot: BASExistingGovernedMemorySnapshot {
        BASExistingGovernedMemorySnapshot(
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
            observationCount: observationCount,
            provenanceSummary: provenanceSummary,
            lifecycleState: BASMemoryLifecycleState(rawValue: lifecycleState.rawValue) ?? .active,
            lastReviewedAt: reviewedAt,
            tierID: tier.rawValue
        )
    }
}

extension DecisionMemoryCandidateRecord {
    var basSnapshot: BASExistingCandidateMemorySnapshot {
        BASExistingCandidateMemorySnapshot(
            id: id,
            typeID: type.rawValue,
            topic: topic,
            headline: headline,
            value: value,
            confidence: confidence,
            priority: priority,
            source: source.basSource,
            firstObservedAt: firstObservedAt,
            lastObservedAt: lastObservedAt,
            decayPolicy: decayPolicy.basDecayPolicy,
            retrievalTags: retrievalTags,
            evidenceCount: evidenceCount,
            confirmationCount: confirmationCount,
            lastObservationFingerprint: lastObservationFingerprint,
            status: BASMemoryCandidateStatus(rawValue: status.rawValue) ?? .pending,
            provenanceSummary: provenanceSummary,
            lastWriteOperation: BASMemoryWriteOperation(rawValue: lastWriteOperation.rawValue) ?? .noop,
            lastGovernanceDecision: BASMemoryGovernanceDecision(rawValue: lastGovernanceDecision.rawValue) ?? .deferred,
            governanceReason: governanceReason,
            tierID: tier.rawValue
        )
    }
}
