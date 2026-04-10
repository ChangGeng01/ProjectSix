import Foundation
import BASAppleAdapters
import BASMemory

extension DecisionMemorySource {
    init(_ source: BASMemorySource) {
        switch source {
        case .history:
            self = .history
        case .reflection:
            self = .reflection
        case .reminder:
            self = .reminder
        case .pattern:
            self = .pattern
        }
    }

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
    init(_ policy: BASMemoryDecayPolicy) {
        switch policy {
        case .stable:
            self = .stable
        case .slow:
            self = .slow
        case .medium:
            self = .medium
        case .fast:
            self = .fast
        }
    }

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

extension DecisionMemoryType {
    init(basRawValue: String) {
        self = DecisionMemoryType(rawValue: basRawValue) ?? .semantic
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

extension DecisionMemoryTier {
    init(basRawValue: String?) {
        self = DecisionMemoryTier(rawValue: basRawValue ?? "") ?? .warm
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

extension SelfReminder: BASAppleReminderMemoryEntity {
    var basReminderMemoryInput: BASSelfReminderMemoryInput {
        BASSelfReminderMemoryInput(
            content: content,
            lastUsedAt: lastUsedAt
        )
    }
}

extension CheckEvent: BASAppleCheckEventMemoryEntity {
    var basCheckEventMemoryInput: BASCheckEventMemoryInput {
        BASCheckEventMemoryInput(
            id: id.uuidString,
            scenarioID: scenario.rawValue,
            scenarioTitle: scenario.title,
            actionID: finalAction.rawValue,
            actionTitle: finalAction.title,
            note: note,
            createdAt: createdAt
        )
    }
}

extension CheckEvent: BASAppleProjectionEventSource {
    var basProjectionEventInput: BASProjectionEventInput {
        BASProjectionEventInput(
            id: id.uuidString,
            note: note,
            fallbackContent: scenario.title,
            createdAt: createdAt,
            scenarioID: scenario.rawValue,
            actionID: finalAction.rawValue,
            reflectionOutcomeID: reflectionOutcome?.rawValue,
            entrySourceID: entrySource.rawValue
        )
    }
}

extension BalanceDecisionRecord: BASAppleBalanceMemoryEntity {
    var basBalanceMemoryInput: BASBalanceMemoryInput {
        BASBalanceMemoryInput(
            prompt: prompt,
            longTerm: longTerm,
            updatedAt: updatedAt
        )
    }
}

extension MirrorDecisionRecord: BASAppleMirrorMemoryEntity {
    var basMirrorMemoryInput: BASMirrorMemoryInput {
        BASMirrorMemoryInput(
            prompt: prompt,
            longTerm: longTerm,
            updatedAt: updatedAt
        )
    }
}
