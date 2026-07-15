import Foundation
import BASMemory

public protocol BASAppleGovernedMemoryMutable: AnyObject {
    var basID: String { get }
    var basTypeID: String { get set }
    var basTopic: String { get set }
    var basHeadline: String { get set }
    var basValue: String { get set }
    var basConfidence: Double { get set }
    var basPriority: Double { get set }
    var basSource: BASMemorySource { get set }
    var basLastConfirmedAt: Date { get set }
    var basDecayPolicy: BASMemoryDecayPolicy { get set }
    var basRetrievalTags: [String] { get set }
    var basEvidenceCount: Int { get set }
    var basObservationCount: Int { get set }
    var basProvenanceSummary: String { get set }
    var basLifecycleState: BASMemoryLifecycleState { get set }
    var basLastReviewedAt: Date { get set }
    var basTierID: String { get set }
}

public protocol BASAppleCandidateMemoryMutable: AnyObject {
    var basID: String { get }
    var basTypeID: String { get set }
    var basTopic: String { get set }
    var basHeadline: String { get set }
    var basValue: String { get set }
    var basConfidence: Double { get set }
    var basPriority: Double { get set }
    var basSource: BASMemorySource { get set }
    var basFirstObservedAt: Date { get set }
    var basLastObservedAt: Date { get set }
    var basDecayPolicy: BASMemoryDecayPolicy { get set }
    var basRetrievalTags: [String] { get set }
    var basEvidenceCount: Int { get set }
    var basConfirmationCount: Int { get set }
    var basLastObservationFingerprint: String { get set }
    var basStatus: BASMemoryCandidateStatus { get set }
    var basProvenanceSummary: String { get set }
    var basLastWriteOperation: BASMemoryWriteOperation { get set }
    var basLastGovernanceDecision: BASMemoryGovernanceDecision { get set }
    var basGovernanceReason: String { get set }
    var basTierID: String { get set }
}

public enum BASAppleMemoryMutationWriter {
    @discardableResult
    public static func apply<Record: BASAppleGovernedMemoryMutable>(
        _ mutation: BASAppleGovernedMemoryMutation,
        existing: Record?,
        make: (BASGovernedMemoryStoredFields) -> Record
    ) -> Record? {
        switch mutation.operation {
        case .delete:
            return nil
        case .add, .update, .noop:
            guard let fields = mutation.fields else { return existing }
            if let existing {
                apply(fields, to: existing)
                return existing
            }
            return make(fields)
        }
    }

    @discardableResult
    public static func apply<Record: BASAppleCandidateMemoryMutable>(
        _ mutation: BASAppleCandidateMemoryMutation,
        existing: Record?,
        make: (BASCandidateMemoryStoredFields) -> Record
    ) -> Record? {
        switch mutation.operation {
        case .delete:
            return nil
        case .add, .update, .noop:
            guard let fields = mutation.fields else { return existing }
            if let existing {
                apply(fields, to: existing)
                return existing
            }
            return make(fields)
        }
    }

    private static func apply<Record: BASAppleGovernedMemoryMutable>(
        _ fields: BASGovernedMemoryStoredFields,
        to record: Record
    ) {
        record.basTypeID = fields.typeID
        record.basTopic = fields.topic
        record.basHeadline = fields.headline
        record.basValue = fields.value
        record.basConfidence = fields.confidence
        record.basPriority = fields.priority
        record.basSource = fields.source
        record.basLastConfirmedAt = fields.lastConfirmedAt
        record.basDecayPolicy = fields.decayPolicy
        record.basRetrievalTags = fields.retrievalTags
        record.basEvidenceCount = fields.evidenceCount
        record.basObservationCount = fields.observationCount
        record.basProvenanceSummary = fields.provenanceSummary
        record.basLifecycleState = fields.lifecycleState
        record.basLastReviewedAt = fields.lastReviewedAt
        record.basTierID = fields.tierID
    }

    private static func apply<Record: BASAppleCandidateMemoryMutable>(
        _ fields: BASCandidateMemoryStoredFields,
        to candidate: Record
    ) {
        candidate.basTypeID = fields.typeID
        candidate.basTopic = fields.topic
        candidate.basHeadline = fields.headline
        candidate.basValue = fields.value
        candidate.basConfidence = fields.confidence
        candidate.basPriority = fields.priority
        candidate.basSource = fields.source
        candidate.basFirstObservedAt = fields.firstObservedAt
        candidate.basLastObservedAt = fields.lastObservedAt
        candidate.basDecayPolicy = fields.decayPolicy
        candidate.basRetrievalTags = fields.retrievalTags
        candidate.basEvidenceCount = fields.evidenceCount
        candidate.basConfirmationCount = fields.confirmationCount
        candidate.basLastObservationFingerprint = fields.lastObservationFingerprint
        candidate.basStatus = fields.status
        candidate.basProvenanceSummary = fields.provenanceSummary
        candidate.basLastWriteOperation = fields.lastWriteOperation
        candidate.basLastGovernanceDecision = fields.lastGovernanceDecision
        candidate.basGovernanceReason = fields.governanceReason
        candidate.basTierID = fields.tierID
    }
}
