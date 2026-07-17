// MARK: - BASLayerCascadeRunner — chapter 三百一二 / M799
//
// Phase Delta 第三刀:typed cascade runner that walks a layer's
// slot list in priority order,invoking each head until confidence
// ≥ floor (or all exhausted)。Encodes chapter 一百七十七 cascading
// inference doctrine into testable code。
//
// chapter 一百七十七 vision § 10 cascading inference describes
// rules → small ML → big ML → AFM → cloud LLM as the typical
// stack。Layer actors don't need to manually walk this stack —
// the cascade runner does it given a registry + a layer ID + an
// input frame。
//
// ## 这一刀 ship 什么
//
// 3 typed primitives:
//
//   - `BASLayerCascadeOutcome` (4-case enum) — typed runner result:
//     headMatched / floorMet / fallenThrough / noHeadsRegistered
//   - `BASLayerCascadeResult` (BASSchemaVersioned 1.0.0) — full
//     typed runner output: outcome + matched headID +
//     output frame + cascade audit trail (which heads tried)
//   - `BASLayerCascadeRunner` — typed namespace exposing static
//     `run(input:registry:layerID:)` async function。Does NOT
//     hold state — pure dispatcher。
//
// ## Why a stateless runner (not a layer-actor field)
//
// Cascade is pure dispatch logic over a registry's slot list。
// Embedding it in `BASLayerActor` protocol would couple every
// layer's process() implementation to one specific cascade
// strategy。A standalone runner lets:
// 1) Future Phase Delta cuts ship alternative cascade strategies
//    (parallel inference / quorum vote / etc) without breaking
//    actor protocol
// 2) Tests verify cascade behavior without constructing full
//    layer actor stack
// 3) Layer actors call the runner from inside their process()
//    without inheriting cascade-specific state
//
// **0 behavior change**:purely additive new file。No layer actor
// currently invokes the runner。
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — runner is dispatch logic, not
//     verdict authority
//   - 红线 7 watcher hint only — runner walks ML head outputs
//     (hints), layer actor decides whether to act on the
//     winning hint
//   - 单提交口 (L11/L14) 不变 — runner doesn't issue permits
//   - chapter 二百一一 single-source-of-truth: ONE runner for
//     cascading inference (vs scattered cascade loops in
//     each layer actor)
//   - chapter 一百八十五 anti-magic-number: outcome enum 4 cases,
//     all error paths typed
//   - chapter 一百三 schema-version: 1.0.0 invariant for
//     BASLayerCascadeResult
//   - chapter 一百三十 BASLearnabilityClass: cascade audit trail
//     is observability metadata, semi-learnable
//   - chapter 三百 BASLayerMLHead protocol: runner consumes
//     `(any BASLayerMLHead, BASLayerMLHeadSlot)` pairs from
//     registry's enabledHeads()
//   - chapter 三百一一 BASRulesBasedLayerMLHead: rules-tier heads
//     are typical priority-0 cascade entries

import Foundation

// MARK: - Collaboration and bounded control-loop values

public enum BASCollaborationVerb:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case query
    case fanOutJoin = "fan-out-join"
    case proposalCritique = "proposal-critique"
    case remand
    case commitSaga = "commit-saga"
}

public enum BASControlRingTerminalState:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case converged
    case degradedWithCoverage = "degraded-with-coverage"
    case deferred
    case rejected
    case needsConfirmation = "needs-confirmation"
    case indeterminateNeedsReconciliation =
        "indeterminate-needs-reconciliation"
}

public enum BASJoinPolicy:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case all
    case quorum
    case bestEffortWithCoverage = "best-effort-with-coverage"
}

public enum BASControlLoopProgressKind:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case newRequiredLaneCoverage = "new-required-lane-coverage"
    case strictDeficiencyReduction = "strict-deficiency-reduction"
    case strictConflictReduction = "strict-conflict-reduction"
    case resourceSafeTransition = "resource-safe-transition"
    case effectSagaRankAdvance = "effect-saga-rank-advance"
}

public enum BASControlLoopTerminationReason:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case convergedVerified = "converged-verified"
    case coverageBound = "coverage-bound"
    case resourceDeferred = "resource-deferred"
    case policyRejected = "policy-rejected"
    case confirmationRequired = "confirmation-required"
    case cycleDetected = "cycle-detected"
    case budgetExhausted = "budget-exhausted"
    case noProgress = "no-progress"
    case staleEpoch = "stale-epoch"
    case illegalRemand = "illegal-remand"
    case effectReconciliationIndeterminate =
        "effect-reconciliation-indeterminate"
}

public enum BASCancellationReason:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case userRequested = "user-requested"
    case deadlineExceeded = "deadline-exceeded"
    case resourcePressure = "resource-pressure"
    case authorityRevoked = "authority-revoked"
    case superseded
    case shutdown
}

public enum BASCancellationDispatchBoundary:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case preDispatch = "pre-dispatch"
    case postDispatchPossible = "post-dispatch-possible"
    case postDispatchTerminal = "post-dispatch-terminal"
}

public enum BASBackpressureDisposition:
    String, Codable, Sendable, Hashable, CaseIterable
{
    case accepted
    case deferred
    case rejected
}

/// Validation failures for the immutable collaboration/control-loop values.
/// These errors classify malformed evidence; they own no policy or state.
public enum BASControlLoopValueError: Error, Sendable, Equatable {
    case invalidArtifactID(field: String)
    case invalidCollectionCount(
        field: String, actual: Int, minimum: Int, maximum: Int)
    case duplicateValue(field: String)
    case invalidJoinPartition
    case unstableJoinSubsequence(field: String)
    case invalidQuorum
    case incompleteAllJoin
    case insufficientReceivedForQuorum
    case missingBestEffortCoverageEvidence
    case unsupportedBudgetProjectionSchema(found: String)
    case invalidBudgetProjection
    case invalidSchemaID
    case missingEvidenceOverlapsOtherEvidence
    case invalidRound
    case invalidHop
    case invalidReasonCode
    case invalidDigest(field: String)
    case invalidDeadline
    case invalidLogicalInvocationKey
    case invalidBootSessionID
    case incompleteChildGroup
    case invalidRootShape
    case invalidChildShape
    case depthExceedsMaximum
    case invalidBranchBounds
    case invalidProgressMeasure
    case nonImprovingProgress
    case artifactIDsNotDistinct
    case invalidTerminalPair
    case branchParentMismatch
    case invalidMonotonicSequence
    case invalidConcurrencyLimit
    case activeConcurrencyExceedsLimit
    case invalidBackpressureRetry
    case resultDispositionMismatch
}

private enum BASControlLoopValueValidator {
    static let maximumArtifactVectorCount = 64

    static func artifactID(
        _ artifactID: BASArtifactID,
        field: String
    ) throws {
        do {
            _ = try artifactID.storageScalar
        } catch {
            throw BASControlLoopValueError.invalidArtifactID(field: field)
        }
    }

    static func artifactIDs(
        _ artifactIDs: [BASArtifactID],
        field: String,
        minimum: Int = 0,
        maximum: Int = maximumArtifactVectorCount
    ) throws {
        guard (minimum...maximum).contains(artifactIDs.count) else {
            throw BASControlLoopValueError.invalidCollectionCount(
                field: field,
                actual: artifactIDs.count,
                minimum: minimum,
                maximum: maximum)
        }
        for artifactID in artifactIDs {
            try self.artifactID(artifactID, field: field)
        }
        guard Set(artifactIDs).count == artifactIDs.count else {
            throw BASControlLoopValueError.duplicateValue(field: field)
        }
    }

    static func digest(_ digest: String, field: String) throws {
        let bytes = Array(digest.utf8)
        guard bytes.count == 64,
              bytes.allSatisfy({ byte in
                  (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)
              })
        else {
            throw BASControlLoopValueError.invalidDigest(field: field)
        }
    }

    static func budgetProjection(_ projection: BASLayerSlice) throws {
        guard projection.schemaVersion == BASLayerSlice.currentSchemaVersion
        else {
            throw BASControlLoopValueError
                .unsupportedBudgetProjectionSchema(
                    found: projection.schemaVersion)
        }
        do {
            let validated = try projection.attenuated()
            guard validated == projection else {
                throw BASControlLoopValueError.invalidBudgetProjection
            }
        } catch {
            throw BASControlLoopValueError.invalidBudgetProjection
        }
    }

    static func isStableSubsequence<T: Equatable>(
        _ subsequence: [T],
        of sequence: [T]
    ) -> Bool {
        var index = sequence.startIndex
        for candidate in subsequence {
            guard let match = sequence[index...].firstIndex(of: candidate) else {
                return false
            }
            index = sequence.index(after: match)
        }
        return true
    }

    static func boundedUTF8(_ value: String, minimum: Int, maximum: Int) -> Bool {
        (minimum...maximum).contains(value.utf8.count)
    }

    static func isLogicalInvocationKey(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...256).contains(bytes.count),
              let first = bytes.first,
              isLowerAlphaNumeric(first)
        else {
            return false
        }
        return bytes.dropFirst().allSatisfy { byte in
            isLowerAlphaNumeric(byte)
                || byte == 46 || byte == 95 || byte == 58
                || byte == 47 || byte == 45
        }
    }

    static func isReasonCode(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        guard (1...128).contains(bytes.count),
              let first = bytes.first,
              isLowerAlphaNumeric(first)
        else {
            return false
        }
        return bytes.dropFirst().allSatisfy { byte in
            isLowerAlphaNumeric(byte) || byte == 46 || byte == 45
        }
    }

    private static func isLowerAlphaNumeric(_ byte: UInt8) -> Bool {
        (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
    }
}

/// Self-ID-free evidence that a bounded fan-out has joined.
public struct BASJoinArtifact: BASSchemaVersioned, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let parentArtifactID: BASArtifactID
    public let orderedExpectedInputArtifactIDs: [BASArtifactID]
    public let orderedReceivedInputArtifactIDs: [BASArtifactID]
    public let orderedMissingInputArtifactIDs: [BASArtifactID]
    public let policy: BASJoinPolicy
    public let quorum: UInt64
    public let orderedConflictArtifactIDs: [BASArtifactID]
    public let orderedEvidenceArtifactIDs: [BASArtifactID]
    public let remainingBudget: BASLayerSlice
    public let budgetLeaseArtifactID: BASArtifactID
    public let priorBudgetUseReceiptArtifactID: BASArtifactID
    public let progressWitnessArtifactID: BASArtifactID
    public let controlLoopEnvelopeArtifactID: BASArtifactID
    public let monotonicDeadlineNanos: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        parentArtifactID: BASArtifactID,
        orderedExpectedInputArtifactIDs: [BASArtifactID],
        orderedReceivedInputArtifactIDs: [BASArtifactID],
        orderedMissingInputArtifactIDs: [BASArtifactID],
        policy: BASJoinPolicy,
        quorum: UInt64,
        orderedConflictArtifactIDs: [BASArtifactID],
        orderedEvidenceArtifactIDs: [BASArtifactID],
        remainingBudget: BASLayerSlice,
        budgetLeaseArtifactID: BASArtifactID,
        priorBudgetUseReceiptArtifactID: BASArtifactID,
        progressWitnessArtifactID: BASArtifactID,
        controlLoopEnvelopeArtifactID: BASArtifactID,
        monotonicDeadlineNanos: UInt64
    ) throws {
        self.schemaVersion = schemaVersion
        self.parentArtifactID = parentArtifactID
        self.orderedExpectedInputArtifactIDs = orderedExpectedInputArtifactIDs
        self.orderedReceivedInputArtifactIDs = orderedReceivedInputArtifactIDs
        self.orderedMissingInputArtifactIDs = orderedMissingInputArtifactIDs
        self.policy = policy
        self.quorum = quorum
        self.orderedConflictArtifactIDs = orderedConflictArtifactIDs
        self.orderedEvidenceArtifactIDs = orderedEvidenceArtifactIDs
        self.remainingBudget = remainingBudget
        self.budgetLeaseArtifactID = budgetLeaseArtifactID
        self.priorBudgetUseReceiptArtifactID = priorBudgetUseReceiptArtifactID
        self.progressWitnessArtifactID = progressWitnessArtifactID
        self.controlLoopEnvelopeArtifactID = controlLoopEnvelopeArtifactID
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.budgetProjection(remainingBudget)
        try BASControlLoopValueValidator.artifactID(
            parentArtifactID, field: "parentArtifactID")
        try BASControlLoopValueValidator.artifactIDs(
            orderedExpectedInputArtifactIDs,
            field: "orderedExpectedInputArtifactIDs",
            minimum: 1)
        try BASControlLoopValueValidator.artifactIDs(
            orderedReceivedInputArtifactIDs,
            field: "orderedReceivedInputArtifactIDs")
        try BASControlLoopValueValidator.artifactIDs(
            orderedMissingInputArtifactIDs,
            field: "orderedMissingInputArtifactIDs")
        try BASControlLoopValueValidator.artifactIDs(
            orderedConflictArtifactIDs,
            field: "orderedConflictArtifactIDs")
        try BASControlLoopValueValidator.artifactIDs(
            orderedEvidenceArtifactIDs,
            field: "orderedEvidenceArtifactIDs")
        for (field, artifactID) in [
            ("budgetLeaseArtifactID", budgetLeaseArtifactID),
            ("priorBudgetUseReceiptArtifactID", priorBudgetUseReceiptArtifactID),
            ("progressWitnessArtifactID", progressWitnessArtifactID),
            ("controlLoopEnvelopeArtifactID", controlLoopEnvelopeArtifactID),
        ] {
            try BASControlLoopValueValidator.artifactID(
                artifactID, field: field)
        }

        let expected = Set(orderedExpectedInputArtifactIDs)
        let received = Set(orderedReceivedInputArtifactIDs)
        let missing = Set(orderedMissingInputArtifactIDs)
        guard received.isDisjoint(with: missing),
              received.union(missing) == expected,
              orderedReceivedInputArtifactIDs.count
                  + orderedMissingInputArtifactIDs.count
                  == orderedExpectedInputArtifactIDs.count
        else {
            throw BASControlLoopValueError.invalidJoinPartition
        }
        guard BASControlLoopValueValidator.isStableSubsequence(
            orderedReceivedInputArtifactIDs,
            of: orderedExpectedInputArtifactIDs)
        else {
            throw BASControlLoopValueError.unstableJoinSubsequence(
                field: "orderedReceivedInputArtifactIDs")
        }
        guard BASControlLoopValueValidator.isStableSubsequence(
            orderedMissingInputArtifactIDs,
            of: orderedExpectedInputArtifactIDs)
        else {
            throw BASControlLoopValueError.unstableJoinSubsequence(
                field: "orderedMissingInputArtifactIDs")
        }
        guard quorum > 0,
              quorum <= UInt64(orderedExpectedInputArtifactIDs.count)
        else {
            throw BASControlLoopValueError.invalidQuorum
        }
        switch policy {
        case .all:
            guard orderedReceivedInputArtifactIDs
                    == orderedExpectedInputArtifactIDs,
                  orderedMissingInputArtifactIDs.isEmpty,
                  quorum == UInt64(orderedExpectedInputArtifactIDs.count)
            else {
                throw BASControlLoopValueError.incompleteAllJoin
            }
        case .quorum, .bestEffortWithCoverage:
            guard UInt64(orderedReceivedInputArtifactIDs.count) >= quorum else {
                throw BASControlLoopValueError.insufficientReceivedForQuorum
            }
            if policy == .bestEffortWithCoverage,
               orderedEvidenceArtifactIDs.isEmpty
            {
                throw BASControlLoopValueError
                    .missingBestEffortCoverageEvidence
            }
        }
        guard monotonicDeadlineNanos > 0 else {
            throw BASControlLoopValueError.invalidDeadline
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, parentArtifactID
        case orderedExpectedInputArtifactIDs
        case orderedReceivedInputArtifactIDs
        case orderedMissingInputArtifactIDs
        case policy, quorum, orderedConflictArtifactIDs
        case orderedEvidenceArtifactIDs, remainingBudget
        case budgetLeaseArtifactID, priorBudgetUseReceiptArtifactID
        case progressWitnessArtifactID, controlLoopEnvelopeArtifactID
        case monotonicDeadlineNanos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            parentArtifactID: container.decode(
                BASArtifactID.self, forKey: .parentArtifactID),
            orderedExpectedInputArtifactIDs: container.decode(
                [BASArtifactID].self,
                forKey: .orderedExpectedInputArtifactIDs),
            orderedReceivedInputArtifactIDs: container.decode(
                [BASArtifactID].self,
                forKey: .orderedReceivedInputArtifactIDs),
            orderedMissingInputArtifactIDs: container.decode(
                [BASArtifactID].self,
                forKey: .orderedMissingInputArtifactIDs),
            policy: container.decode(BASJoinPolicy.self, forKey: .policy),
            quorum: container.decode(UInt64.self, forKey: .quorum),
            orderedConflictArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedConflictArtifactIDs),
            orderedEvidenceArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedEvidenceArtifactIDs),
            remainingBudget: container.decode(
                BASLayerSlice.self, forKey: .remainingBudget),
            budgetLeaseArtifactID: container.decode(
                BASArtifactID.self, forKey: .budgetLeaseArtifactID),
            priorBudgetUseReceiptArtifactID: container.decode(
                BASArtifactID.self, forKey: .priorBudgetUseReceiptArtifactID),
            progressWitnessArtifactID: container.decode(
                BASArtifactID.self, forKey: .progressWitnessArtifactID),
            controlLoopEnvelopeArtifactID: container.decode(
                BASArtifactID.self, forKey: .controlLoopEnvelopeArtifactID),
            monotonicDeadlineNanos: container.decode(
                UInt64.self, forKey: .monotonicDeadlineNanos))
    }
}

/// Self-ID-free request to return bounded work to one semantic layer.
public struct BASRemandArtifact: BASSchemaVersioned, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let parentArtifactID: BASArtifactID
    public let inputArtifactID: BASArtifactID
    public let targetLayerID: BASSemanticLayerID
    public let orderedMissingEvidenceArtifactIDs: [BASArtifactID]
    public let orderedMissingSchemaIDs: [String]
    public let orderedConflictArtifactIDs: [BASArtifactID]
    public let orderedEvidenceArtifactIDs: [BASArtifactID]
    public let round: UInt64
    public let hop: UInt64
    public let visitedStateDecisionDigestSetCommitment: String
    public let remainingBudget: BASLayerSlice
    public let budgetLeaseArtifactID: BASArtifactID
    public let priorBudgetUseReceiptArtifactID: BASArtifactID
    public let progressWitnessArtifactID: BASArtifactID
    public let controlLoopEnvelopeArtifactID: BASArtifactID
    public let monotonicDeadlineNanos: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        parentArtifactID: BASArtifactID,
        inputArtifactID: BASArtifactID,
        targetLayerID: BASSemanticLayerID,
        orderedMissingEvidenceArtifactIDs: [BASArtifactID],
        orderedMissingSchemaIDs: [String],
        orderedConflictArtifactIDs: [BASArtifactID],
        orderedEvidenceArtifactIDs: [BASArtifactID],
        round: UInt64,
        hop: UInt64,
        visitedStateDecisionDigestSetCommitment: String,
        remainingBudget: BASLayerSlice,
        budgetLeaseArtifactID: BASArtifactID,
        priorBudgetUseReceiptArtifactID: BASArtifactID,
        progressWitnessArtifactID: BASArtifactID,
        controlLoopEnvelopeArtifactID: BASArtifactID,
        monotonicDeadlineNanos: UInt64
    ) throws {
        self.schemaVersion = schemaVersion
        self.parentArtifactID = parentArtifactID
        self.inputArtifactID = inputArtifactID
        self.targetLayerID = targetLayerID
        self.orderedMissingEvidenceArtifactIDs =
            orderedMissingEvidenceArtifactIDs
        self.orderedMissingSchemaIDs = orderedMissingSchemaIDs
        self.orderedConflictArtifactIDs = orderedConflictArtifactIDs
        self.orderedEvidenceArtifactIDs = orderedEvidenceArtifactIDs
        self.round = round
        self.hop = hop
        self.visitedStateDecisionDigestSetCommitment =
            visitedStateDecisionDigestSetCommitment
        self.remainingBudget = remainingBudget
        self.budgetLeaseArtifactID = budgetLeaseArtifactID
        self.priorBudgetUseReceiptArtifactID = priorBudgetUseReceiptArtifactID
        self.progressWitnessArtifactID = progressWitnessArtifactID
        self.controlLoopEnvelopeArtifactID = controlLoopEnvelopeArtifactID
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.budgetProjection(remainingBudget)
        for (field, artifactID) in [
            ("parentArtifactID", parentArtifactID),
            ("inputArtifactID", inputArtifactID),
            ("budgetLeaseArtifactID", budgetLeaseArtifactID),
            ("priorBudgetUseReceiptArtifactID", priorBudgetUseReceiptArtifactID),
            ("progressWitnessArtifactID", progressWitnessArtifactID),
            ("controlLoopEnvelopeArtifactID", controlLoopEnvelopeArtifactID),
        ] {
            try BASControlLoopValueValidator.artifactID(
                artifactID, field: field)
        }
        try BASControlLoopValueValidator.artifactIDs(
            orderedMissingEvidenceArtifactIDs,
            field: "orderedMissingEvidenceArtifactIDs")
        try BASControlLoopValueValidator.artifactIDs(
            orderedConflictArtifactIDs,
            field: "orderedConflictArtifactIDs")
        try BASControlLoopValueValidator.artifactIDs(
            orderedEvidenceArtifactIDs,
            field: "orderedEvidenceArtifactIDs")
        let missingEvidence = Set(orderedMissingEvidenceArtifactIDs)
        guard missingEvidence.isDisjoint(
                with: Set(orderedConflictArtifactIDs)),
              missingEvidence.isDisjoint(
                with: Set(orderedEvidenceArtifactIDs))
        else {
            throw BASControlLoopValueError
                .missingEvidenceOverlapsOtherEvidence
        }
        guard orderedMissingSchemaIDs.count
                <= BASControlLoopValueValidator.maximumArtifactVectorCount
        else {
            throw BASControlLoopValueError.invalidCollectionCount(
                field: "orderedMissingSchemaIDs",
                actual: orderedMissingSchemaIDs.count,
                minimum: 0,
                maximum: BASControlLoopValueValidator
                    .maximumArtifactVectorCount)
        }
        guard Set(orderedMissingSchemaIDs).count
                == orderedMissingSchemaIDs.count
        else {
            throw BASControlLoopValueError.duplicateValue(
                field: "orderedMissingSchemaIDs")
        }
        for schemaID in orderedMissingSchemaIDs {
            guard BASControlLoopValueValidator.boundedUTF8(
                schemaID, minimum: 1, maximum: 128)
            else {
                throw BASControlLoopValueError.invalidSchemaID
            }
        }
        guard !orderedMissingEvidenceArtifactIDs.isEmpty
                || !orderedMissingSchemaIDs.isEmpty
        else {
            throw BASControlLoopValueError.invalidCollectionCount(
                field: "missingEvidenceAndSchema",
                actual: 0,
                minimum: 1,
                maximum: 128)
        }
        guard (1...65_535).contains(round) else {
            throw BASControlLoopValueError.invalidRound
        }
        guard (1...65_535).contains(hop) else {
            throw BASControlLoopValueError.invalidHop
        }
        try BASControlLoopValueValidator.digest(
            visitedStateDecisionDigestSetCommitment,
            field: "visitedStateDecisionDigestSetCommitment")
        guard monotonicDeadlineNanos > 0 else {
            throw BASControlLoopValueError.invalidDeadline
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, parentArtifactID, inputArtifactID, targetLayerID
        case orderedMissingEvidenceArtifactIDs, orderedMissingSchemaIDs
        case orderedConflictArtifactIDs, orderedEvidenceArtifactIDs
        case round, hop, visitedStateDecisionDigestSetCommitment
        case remainingBudget, budgetLeaseArtifactID
        case priorBudgetUseReceiptArtifactID, progressWitnessArtifactID
        case controlLoopEnvelopeArtifactID, monotonicDeadlineNanos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            parentArtifactID: container.decode(
                BASArtifactID.self, forKey: .parentArtifactID),
            inputArtifactID: container.decode(
                BASArtifactID.self, forKey: .inputArtifactID),
            targetLayerID: container.decode(
                BASSemanticLayerID.self, forKey: .targetLayerID),
            orderedMissingEvidenceArtifactIDs: container.decode(
                [BASArtifactID].self,
                forKey: .orderedMissingEvidenceArtifactIDs),
            orderedMissingSchemaIDs: container.decode(
                [String].self, forKey: .orderedMissingSchemaIDs),
            orderedConflictArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedConflictArtifactIDs),
            orderedEvidenceArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedEvidenceArtifactIDs),
            round: container.decode(UInt64.self, forKey: .round),
            hop: container.decode(UInt64.self, forKey: .hop),
            visitedStateDecisionDigestSetCommitment: container.decode(
                String.self,
                forKey: .visitedStateDecisionDigestSetCommitment),
            remainingBudget: container.decode(
                BASLayerSlice.self, forKey: .remainingBudget),
            budgetLeaseArtifactID: container.decode(
                BASArtifactID.self, forKey: .budgetLeaseArtifactID),
            priorBudgetUseReceiptArtifactID: container.decode(
                BASArtifactID.self, forKey: .priorBudgetUseReceiptArtifactID),
            progressWitnessArtifactID: container.decode(
                BASArtifactID.self, forKey: .progressWitnessArtifactID),
            controlLoopEnvelopeArtifactID: container.decode(
                BASArtifactID.self, forKey: .controlLoopEnvelopeArtifactID),
            monotonicDeadlineNanos: container.decode(
                UInt64.self, forKey: .monotonicDeadlineNanos))
    }
}

/// Typed refusal evidence; it carries no self identity or mutation authority.
public struct BASRefusalArtifact: BASSchemaVersioned, Sendable, Hashable {
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let refusingLayerID: BASSemanticLayerID
    public let refusedArtifactID: BASArtifactID
    public let reasonCode: String
    public let orderedEvidenceArtifactIDs: [BASArtifactID]
    public let policyEpoch: UInt64
    public let monotonicDeadlineNanos: UInt64

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        refusingLayerID: BASSemanticLayerID,
        refusedArtifactID: BASArtifactID,
        reasonCode: String,
        orderedEvidenceArtifactIDs: [BASArtifactID],
        policyEpoch: UInt64,
        monotonicDeadlineNanos: UInt64
    ) throws {
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.refusingLayerID = refusingLayerID
        self.refusedArtifactID = refusedArtifactID
        self.reasonCode = reasonCode
        self.orderedEvidenceArtifactIDs = orderedEvidenceArtifactIDs
        self.policyEpoch = policyEpoch
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.artifactID(
            turnOperationRef.artifactID,
            field: "turnOperationRef.artifactID")
        try BASControlLoopValueValidator.artifactID(
            refusedArtifactID, field: "refusedArtifactID")
        try BASControlLoopValueValidator.artifactIDs(
            orderedEvidenceArtifactIDs,
            field: "orderedEvidenceArtifactIDs",
            minimum: 1)
        guard BASControlLoopValueValidator.isReasonCode(reasonCode) else {
            throw BASControlLoopValueError.invalidReasonCode
        }
        guard monotonicDeadlineNanos > 0 else {
            throw BASControlLoopValueError.invalidDeadline
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, turnOperationRef, refusingLayerID
        case refusedArtifactID, reasonCode, orderedEvidenceArtifactIDs
        case policyEpoch, monotonicDeadlineNanos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            turnOperationRef: container.decode(
                BASTurnOperationRef.self, forKey: .turnOperationRef),
            refusingLayerID: container.decode(
                BASSemanticLayerID.self, forKey: .refusingLayerID),
            refusedArtifactID: container.decode(
                BASArtifactID.self, forKey: .refusedArtifactID),
            reasonCode: container.decode(String.self, forKey: .reasonCode),
            orderedEvidenceArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedEvidenceArtifactIDs),
            policyEpoch: container.decode(UInt64.self, forKey: .policyEpoch),
            monotonicDeadlineNanos: container.decode(
                UInt64.self, forKey: .monotonicDeadlineNanos))
    }
}

/// Immutable, self-ID-free declaration for one bounded control-loop step.
public struct BASControlLoopEnvelopePayload:
    BASSchemaVersioned, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let ringID: BASControlRingID
    public let logicalInvocationKey: String
    public let parentInvocationArtifactID: BASArtifactID?
    public let semanticSnapshotArtifactID: BASArtifactID
    public let capabilityGrantArtifactID: BASArtifactID
    public let budgetLeaseArtifactID: BASArtifactID
    public let priorBudgetUseReceiptArtifactID: BASArtifactID?
    public let progressWitnessArtifactID: BASArtifactID?
    public let visitedStateDecisionDigestSetCommitment: String
    public let declaredEdge: BASCollaborationVerb?
    public let depth: UInt64
    public let maximumDepth: UInt64
    public let branchCount: UInt64
    public let maximumBranches: UInt64
    public let monotonicDeadlineNanos: UInt64
    public let policyEpoch: UInt64
    public let deletionEpoch: UInt64
    public let bootSessionID: String

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        ringID: BASControlRingID,
        logicalInvocationKey: String,
        parentInvocationArtifactID: BASArtifactID?,
        semanticSnapshotArtifactID: BASArtifactID,
        capabilityGrantArtifactID: BASArtifactID,
        budgetLeaseArtifactID: BASArtifactID,
        priorBudgetUseReceiptArtifactID: BASArtifactID?,
        progressWitnessArtifactID: BASArtifactID?,
        visitedStateDecisionDigestSetCommitment: String,
        declaredEdge: BASCollaborationVerb?,
        depth: UInt64,
        maximumDepth: UInt64,
        branchCount: UInt64,
        maximumBranches: UInt64,
        monotonicDeadlineNanos: UInt64,
        policyEpoch: UInt64,
        deletionEpoch: UInt64,
        bootSessionID: String
    ) throws {
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.attemptRefArtifactID = attemptRefArtifactID
        self.generationVectorArtifactID = generationVectorArtifactID
        self.ringID = ringID
        self.logicalInvocationKey = logicalInvocationKey
        self.parentInvocationArtifactID = parentInvocationArtifactID
        self.semanticSnapshotArtifactID = semanticSnapshotArtifactID
        self.capabilityGrantArtifactID = capabilityGrantArtifactID
        self.budgetLeaseArtifactID = budgetLeaseArtifactID
        self.priorBudgetUseReceiptArtifactID = priorBudgetUseReceiptArtifactID
        self.progressWitnessArtifactID = progressWitnessArtifactID
        self.visitedStateDecisionDigestSetCommitment =
            visitedStateDecisionDigestSetCommitment
        self.declaredEdge = declaredEdge
        self.depth = depth
        self.maximumDepth = maximumDepth
        self.branchCount = branchCount
        self.maximumBranches = maximumBranches
        self.monotonicDeadlineNanos = monotonicDeadlineNanos
        self.policyEpoch = policyEpoch
        self.deletionEpoch = deletionEpoch
        self.bootSessionID = bootSessionID
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.artifactID(
            turnOperationRef.artifactID,
            field: "turnOperationRef.artifactID")
        for (field, artifactID) in [
            ("attemptRefArtifactID", attemptRefArtifactID),
            ("generationVectorArtifactID", generationVectorArtifactID),
            ("semanticSnapshotArtifactID", semanticSnapshotArtifactID),
            ("capabilityGrantArtifactID", capabilityGrantArtifactID),
            ("budgetLeaseArtifactID", budgetLeaseArtifactID),
        ] {
            try BASControlLoopValueValidator.artifactID(
                artifactID, field: field)
        }
        for (field, artifactID) in [
            ("parentInvocationArtifactID", parentInvocationArtifactID),
            ("priorBudgetUseReceiptArtifactID",
             priorBudgetUseReceiptArtifactID),
            ("progressWitnessArtifactID", progressWitnessArtifactID),
        ] {
            if let artifactID {
                try BASControlLoopValueValidator.artifactID(
                    artifactID, field: field)
            }
        }
        guard BASControlLoopValueValidator.isLogicalInvocationKey(
            logicalInvocationKey)
        else {
            throw BASControlLoopValueError.invalidLogicalInvocationKey
        }
        try BASControlLoopValueValidator.digest(
            visitedStateDecisionDigestSetCommitment,
            field: "visitedStateDecisionDigestSetCommitment")

        let optionCount =
            (parentInvocationArtifactID == nil ? 0 : 1)
            + (priorBudgetUseReceiptArtifactID == nil ? 0 : 1)
            + (progressWitnessArtifactID == nil ? 0 : 1)
            + (declaredEdge == nil ? 0 : 1)
        guard optionCount == 0 || optionCount == 4 else {
            throw BASControlLoopValueError.incompleteChildGroup
        }
        if optionCount == 0 {
            guard depth == 0, branchCount == 1 else {
                throw BASControlLoopValueError.invalidRootShape
            }
        } else {
            guard depth > 0, branchCount > 1 else {
                throw BASControlLoopValueError.invalidChildShape
            }
        }
        guard depth <= maximumDepth else {
            throw BASControlLoopValueError.depthExceedsMaximum
        }
        guard maximumBranches > 0,
              branchCount > 0,
              branchCount <= maximumBranches
        else {
            throw BASControlLoopValueError.invalidBranchBounds
        }
        guard monotonicDeadlineNanos > 0 else {
            throw BASControlLoopValueError.invalidDeadline
        }
        guard BASControlLoopValueValidator.boundedUTF8(
            bootSessionID, minimum: 1, maximum: 256)
        else {
            throw BASControlLoopValueError.invalidBootSessionID
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, turnOperationRef, attemptRefArtifactID
        case generationVectorArtifactID, ringID, logicalInvocationKey
        case parentInvocationArtifactID, semanticSnapshotArtifactID
        case capabilityGrantArtifactID, budgetLeaseArtifactID
        case priorBudgetUseReceiptArtifactID, progressWitnessArtifactID
        case visitedStateDecisionDigestSetCommitment, declaredEdge
        case depth, maximumDepth, branchCount, maximumBranches
        case monotonicDeadlineNanos, policyEpoch, deletionEpoch, bootSessionID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            turnOperationRef: container.decode(
                BASTurnOperationRef.self, forKey: .turnOperationRef),
            attemptRefArtifactID: container.decode(
                BASArtifactID.self, forKey: .attemptRefArtifactID),
            generationVectorArtifactID: container.decode(
                BASArtifactID.self, forKey: .generationVectorArtifactID),
            ringID: container.decode(BASControlRingID.self, forKey: .ringID),
            logicalInvocationKey: container.decode(
                String.self, forKey: .logicalInvocationKey),
            parentInvocationArtifactID: container.decodeIfPresent(
                BASArtifactID.self, forKey: .parentInvocationArtifactID),
            semanticSnapshotArtifactID: container.decode(
                BASArtifactID.self, forKey: .semanticSnapshotArtifactID),
            capabilityGrantArtifactID: container.decode(
                BASArtifactID.self, forKey: .capabilityGrantArtifactID),
            budgetLeaseArtifactID: container.decode(
                BASArtifactID.self, forKey: .budgetLeaseArtifactID),
            priorBudgetUseReceiptArtifactID: container.decodeIfPresent(
                BASArtifactID.self,
                forKey: .priorBudgetUseReceiptArtifactID),
            progressWitnessArtifactID: container.decodeIfPresent(
                BASArtifactID.self, forKey: .progressWitnessArtifactID),
            visitedStateDecisionDigestSetCommitment: container.decode(
                String.self,
                forKey: .visitedStateDecisionDigestSetCommitment),
            declaredEdge: container.decodeIfPresent(
                BASCollaborationVerb.self, forKey: .declaredEdge),
            depth: container.decode(UInt64.self, forKey: .depth),
            maximumDepth: container.decode(
                UInt64.self, forKey: .maximumDepth),
            branchCount: container.decode(UInt64.self, forKey: .branchCount),
            maximumBranches: container.decode(
                UInt64.self, forKey: .maximumBranches),
            monotonicDeadlineNanos: container.decode(
                UInt64.self, forKey: .monotonicDeadlineNanos),
            policyEpoch: container.decode(UInt64.self, forKey: .policyEpoch),
            deletionEpoch: container.decode(
                UInt64.self, forKey: .deletionEpoch),
            bootSessionID: container.decode(
                String.self, forKey: .bootSessionID))
    }
}

/// Structural evidence of strict, phase-specific monotonic progress.
public struct BASControlLoopProgressWitnessPayload:
    BASSchemaVersioned, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let kind: BASControlLoopProgressKind
    public let priorEvidenceArtifactID: BASArtifactID
    public let currentEvidenceArtifactID: BASArtifactID
    public let priorCanonicalMeasure: [UInt64]
    public let currentCanonicalMeasure: [UInt64]
    public let verifierReceiptArtifactID: BASArtifactID

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        kind: BASControlLoopProgressKind,
        priorEvidenceArtifactID: BASArtifactID,
        currentEvidenceArtifactID: BASArtifactID,
        priorCanonicalMeasure: [UInt64],
        currentCanonicalMeasure: [UInt64],
        verifierReceiptArtifactID: BASArtifactID
    ) throws {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.priorEvidenceArtifactID = priorEvidenceArtifactID
        self.currentEvidenceArtifactID = currentEvidenceArtifactID
        self.priorCanonicalMeasure = priorCanonicalMeasure
        self.currentCanonicalMeasure = currentCanonicalMeasure
        self.verifierReceiptArtifactID = verifierReceiptArtifactID
        try validate()
    }

    private func validate() throws {
        let artifactIDs = [
            priorEvidenceArtifactID,
            currentEvidenceArtifactID,
            verifierReceiptArtifactID,
        ]
        for (index, artifactID) in artifactIDs.enumerated() {
            try BASControlLoopValueValidator.artifactID(
                artifactID, field: "progressArtifactID[\(index)]")
        }
        guard Set(artifactIDs).count == artifactIDs.count else {
            throw BASControlLoopValueError.artifactIDsNotDistinct
        }
        guard priorCanonicalMeasure.count == currentCanonicalMeasure.count,
              (1...8).contains(priorCanonicalMeasure.count)
        else {
            throw BASControlLoopValueError.invalidProgressMeasure
        }
        let isImprovement: Bool
        switch kind {
        case .newRequiredLaneCoverage,
             .resourceSafeTransition,
             .effectSagaRankAdvance:
            isImprovement = priorCanonicalMeasure.lexicographicallyPrecedes(
                currentCanonicalMeasure)
        case .strictDeficiencyReduction, .strictConflictReduction:
            isImprovement = currentCanonicalMeasure.lexicographicallyPrecedes(
                priorCanonicalMeasure)
        }
        guard isImprovement else {
            throw BASControlLoopValueError.nonImprovingProgress
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, kind, priorEvidenceArtifactID
        case currentEvidenceArtifactID, priorCanonicalMeasure
        case currentCanonicalMeasure, verifierReceiptArtifactID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            kind: container.decode(
                BASControlLoopProgressKind.self, forKey: .kind),
            priorEvidenceArtifactID: container.decode(
                BASArtifactID.self, forKey: .priorEvidenceArtifactID),
            currentEvidenceArtifactID: container.decode(
                BASArtifactID.self, forKey: .currentEvidenceArtifactID),
            priorCanonicalMeasure: container.decode(
                [UInt64].self, forKey: .priorCanonicalMeasure),
            currentCanonicalMeasure: container.decode(
                [UInt64].self, forKey: .currentCanonicalMeasure),
            verifierReceiptArtifactID: container.decode(
                BASArtifactID.self, forKey: .verifierReceiptArtifactID))
    }
}

/// Immutable terminal disclosure for one control-loop invocation.
public struct BASControlLoopTerminalReceiptPayload:
    BASSchemaVersioned, Sendable, Hashable
{
    public static let currentSchemaVersion = "1.0.0"

    public let schemaVersion: String
    public let turnOperationRef: BASTurnOperationRef
    public let invocationArtifactID: BASArtifactID
    public let controlLoopEnvelopeArtifactID: BASArtifactID
    public let budgetUseReceiptArtifactID: BASArtifactID
    public let terminalState: BASControlRingTerminalState
    public let terminationReason: BASControlLoopTerminationReason
    public let finalStateDecisionDigest: String
    public let orderedEvidenceArtifactIDs: [BASArtifactID]

    public var isAdoptable: Bool {
        terminalState == .converged
            && terminationReason == .convergedVerified
    }

    public init(
        schemaVersion: String = Self.currentSchemaVersion,
        turnOperationRef: BASTurnOperationRef,
        invocationArtifactID: BASArtifactID,
        controlLoopEnvelopeArtifactID: BASArtifactID,
        budgetUseReceiptArtifactID: BASArtifactID,
        terminalState: BASControlRingTerminalState,
        terminationReason: BASControlLoopTerminationReason,
        finalStateDecisionDigest: String,
        orderedEvidenceArtifactIDs: [BASArtifactID]
    ) throws {
        self.schemaVersion = schemaVersion
        self.turnOperationRef = turnOperationRef
        self.invocationArtifactID = invocationArtifactID
        self.controlLoopEnvelopeArtifactID = controlLoopEnvelopeArtifactID
        self.budgetUseReceiptArtifactID = budgetUseReceiptArtifactID
        self.terminalState = terminalState
        self.terminationReason = terminationReason
        self.finalStateDecisionDigest = finalStateDecisionDigest
        self.orderedEvidenceArtifactIDs = orderedEvidenceArtifactIDs
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.artifactID(
            turnOperationRef.artifactID,
            field: "turnOperationRef.artifactID")
        for (field, artifactID) in [
            ("invocationArtifactID", invocationArtifactID),
            ("controlLoopEnvelopeArtifactID", controlLoopEnvelopeArtifactID),
            ("budgetUseReceiptArtifactID", budgetUseReceiptArtifactID),
        ] {
            try BASControlLoopValueValidator.artifactID(
                artifactID, field: field)
        }
        try BASControlLoopValueValidator.artifactIDs(
            orderedEvidenceArtifactIDs,
            field: "orderedEvidenceArtifactIDs",
            minimum: 1)
        try BASControlLoopValueValidator.digest(
            finalStateDecisionDigest,
            field: "finalStateDecisionDigest")
        guard Self.isAllowed(
            state: terminalState,
            reason: terminationReason)
        else {
            throw BASControlLoopValueError.invalidTerminalPair
        }
    }

    private static func isAllowed(
        state: BASControlRingTerminalState,
        reason: BASControlLoopTerminationReason
    ) -> Bool {
        switch state {
        case .converged:
            return reason == .convergedVerified
        case .degradedWithCoverage:
            return reason == .coverageBound
        case .deferred:
            return reason == .resourceDeferred || reason == .budgetExhausted
        case .rejected:
            return reason == .policyRejected
                || reason == .cycleDetected
                || reason == .noProgress
                || reason == .staleEpoch
                || reason == .illegalRemand
        case .needsConfirmation:
            return reason == .confirmationRequired
        case .indeterminateNeedsReconciliation:
            return reason == .effectReconciliationIndeterminate
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, turnOperationRef, invocationArtifactID
        case controlLoopEnvelopeArtifactID, budgetUseReceiptArtifactID
        case terminalState, terminationReason, finalStateDecisionDigest
        case orderedEvidenceArtifactIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(String.self, forKey: .schemaVersion),
            turnOperationRef: container.decode(
                BASTurnOperationRef.self, forKey: .turnOperationRef),
            invocationArtifactID: container.decode(
                BASArtifactID.self, forKey: .invocationArtifactID),
            controlLoopEnvelopeArtifactID: container.decode(
                BASArtifactID.self, forKey: .controlLoopEnvelopeArtifactID),
            budgetUseReceiptArtifactID: container.decode(
                BASArtifactID.self, forKey: .budgetUseReceiptArtifactID),
            terminalState: container.decode(
                BASControlRingTerminalState.self, forKey: .terminalState),
            terminationReason: container.decode(
                BASControlLoopTerminationReason.self,
                forKey: .terminationReason),
            finalStateDecisionDigest: container.decode(
                String.self, forKey: .finalStateDecisionDigest),
            orderedEvidenceArtifactIDs: container.decode(
                [BASArtifactID].self, forKey: .orderedEvidenceArtifactIDs))
    }
}

/// Cancellation body carried by the existing low-entropy frame envelope.
public struct BASCancellationBody: Codable, Sendable, Hashable {
    public let turnOperationRef: BASTurnOperationRef
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let targetBranchRef: BASTurnBranchRef?
    public let reason: BASCancellationReason
    public let dispatchBoundary: BASCancellationDispatchBoundary
    public let monotonicSequence: UInt64

    public init(
        turnOperationRef: BASTurnOperationRef,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        targetBranchRef: BASTurnBranchRef?,
        reason: BASCancellationReason,
        dispatchBoundary: BASCancellationDispatchBoundary,
        monotonicSequence: UInt64
    ) throws {
        self.turnOperationRef = turnOperationRef
        self.attemptRefArtifactID = attemptRefArtifactID
        self.generationVectorArtifactID = generationVectorArtifactID
        self.targetBranchRef = targetBranchRef
        self.reason = reason
        self.dispatchBoundary = dispatchBoundary
        self.monotonicSequence = monotonicSequence
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.artifactID(
            turnOperationRef.artifactID,
            field: "turnOperationRef.artifactID")
        try BASControlLoopValueValidator.artifactID(
            attemptRefArtifactID, field: "attemptRefArtifactID")
        try BASControlLoopValueValidator.artifactID(
            generationVectorArtifactID,
            field: "generationVectorArtifactID")
        if let targetBranchRef,
           targetBranchRef.turnOperationRef != turnOperationRef
        {
            throw BASControlLoopValueError.branchParentMismatch
        }
        guard monotonicSequence > 0 else {
            throw BASControlLoopValueError.invalidMonotonicSequence
        }
    }

    private enum CodingKeys: String, CodingKey {
        case turnOperationRef, attemptRefArtifactID
        case generationVectorArtifactID, targetBranchRef
        case reason, dispatchBoundary, monotonicSequence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            turnOperationRef: container.decode(
                BASTurnOperationRef.self, forKey: .turnOperationRef),
            attemptRefArtifactID: container.decode(
                BASArtifactID.self, forKey: .attemptRefArtifactID),
            generationVectorArtifactID: container.decode(
                BASArtifactID.self, forKey: .generationVectorArtifactID),
            targetBranchRef: container.decodeIfPresent(
                BASTurnBranchRef.self, forKey: .targetBranchRef),
            reason: container.decode(
                BASCancellationReason.self, forKey: .reason),
            dispatchBoundary: container.decode(
                BASCancellationDispatchBoundary.self,
                forKey: .dispatchBoundary),
            monotonicSequence: container.decode(
                UInt64.self, forKey: .monotonicSequence))
    }
}

public typealias BASCancellationSignal =
    BASFrameEnvelope<BASCancellationBody>

/// Backpressure observation carried by the existing result primitive.
public struct BASBackpressureBody: Codable, Sendable, Hashable {
    public let turnOperationRef: BASTurnOperationRef
    public let attemptRefArtifactID: BASArtifactID
    public let generationVectorArtifactID: BASArtifactID
    public let queueBytes: UInt64
    public let activeConcurrency: UInt64
    public let concurrencyLimit: UInt64
    public let resourceDebtMicrounits: UInt64
    public let disposition: BASBackpressureDisposition
    public let retryAfterMonotonicNanos: UInt64?
    public let monotonicSequence: UInt64

    public init(
        turnOperationRef: BASTurnOperationRef,
        attemptRefArtifactID: BASArtifactID,
        generationVectorArtifactID: BASArtifactID,
        queueBytes: UInt64,
        activeConcurrency: UInt64,
        concurrencyLimit: UInt64,
        resourceDebtMicrounits: UInt64,
        disposition: BASBackpressureDisposition,
        retryAfterMonotonicNanos: UInt64?,
        monotonicSequence: UInt64
    ) throws {
        self.turnOperationRef = turnOperationRef
        self.attemptRefArtifactID = attemptRefArtifactID
        self.generationVectorArtifactID = generationVectorArtifactID
        self.queueBytes = queueBytes
        self.activeConcurrency = activeConcurrency
        self.concurrencyLimit = concurrencyLimit
        self.resourceDebtMicrounits = resourceDebtMicrounits
        self.disposition = disposition
        self.retryAfterMonotonicNanos = retryAfterMonotonicNanos
        self.monotonicSequence = monotonicSequence
        try validate()
    }

    private func validate() throws {
        try BASControlLoopValueValidator.artifactID(
            turnOperationRef.artifactID,
            field: "turnOperationRef.artifactID")
        try BASControlLoopValueValidator.artifactID(
            attemptRefArtifactID, field: "attemptRefArtifactID")
        try BASControlLoopValueValidator.artifactID(
            generationVectorArtifactID,
            field: "generationVectorArtifactID")
        guard concurrencyLimit > 0 else {
            throw BASControlLoopValueError.invalidConcurrencyLimit
        }
        guard activeConcurrency <= concurrencyLimit else {
            throw BASControlLoopValueError.activeConcurrencyExceedsLimit
        }
        switch disposition {
        case .deferred:
            guard let retryAfterMonotonicNanos,
                  retryAfterMonotonicNanos > 0
            else {
                throw BASControlLoopValueError.invalidBackpressureRetry
            }
        case .accepted, .rejected:
            guard retryAfterMonotonicNanos == nil else {
                throw BASControlLoopValueError.invalidBackpressureRetry
            }
        }
        guard monotonicSequence > 0 else {
            throw BASControlLoopValueError.invalidMonotonicSequence
        }
    }

    /// Construct the canonical result primitive only when its success bit
    /// agrees with the typed disposition.
    public func makeReceipt(
        success: Bool,
        diagnostics: [String] = []
    ) throws -> BASBackpressureReceipt {
        let receipt = BASResult(
            success: success,
            body: self,
            diagnostics: diagnostics)
        return try receipt.validatedBackpressureReceipt()
    }

    private enum CodingKeys: String, CodingKey {
        case turnOperationRef, attemptRefArtifactID
        case generationVectorArtifactID, queueBytes, activeConcurrency
        case concurrencyLimit, resourceDebtMicrounits, disposition
        case retryAfterMonotonicNanos, monotonicSequence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            turnOperationRef: container.decode(
                BASTurnOperationRef.self, forKey: .turnOperationRef),
            attemptRefArtifactID: container.decode(
                BASArtifactID.self, forKey: .attemptRefArtifactID),
            generationVectorArtifactID: container.decode(
                BASArtifactID.self, forKey: .generationVectorArtifactID),
            queueBytes: container.decode(UInt64.self, forKey: .queueBytes),
            activeConcurrency: container.decode(
                UInt64.self, forKey: .activeConcurrency),
            concurrencyLimit: container.decode(
                UInt64.self, forKey: .concurrencyLimit),
            resourceDebtMicrounits: container.decode(
                UInt64.self, forKey: .resourceDebtMicrounits),
            disposition: container.decode(
                BASBackpressureDisposition.self, forKey: .disposition),
            retryAfterMonotonicNanos: container.decodeIfPresent(
                UInt64.self, forKey: .retryAfterMonotonicNanos),
            monotonicSequence: container.decode(
                UInt64.self, forKey: .monotonicSequence))
    }
}

public typealias BASBackpressureReceipt = BASResult<BASBackpressureBody>

/// `BASBackpressureReceipt` remains a structural generic alias and is not an
/// authority boundary by itself. Consumers reopening or decoding the generic
/// result must call this validator before trusting its success bit.
public extension BASResult where Body == BASBackpressureBody {
    func validatedBackpressureReceipt() throws -> Self {
        guard success == (body.disposition == .accepted) else {
            throw BASControlLoopValueError.resultDispositionMismatch
        }
        return self
    }
}

// MARK: - Cascade outcome enum

/// 4-case typed cascade runner result classifier。Each case
/// matches a distinct decision path the runner can take。
public enum BASLayerCascadeOutcome:
    String,
    Sendable,
    Equatable,
    Hashable,
    Codable,
    CaseIterable
{
    /// At least one head returned `confidence >= floor`. The
    /// matched head's output is the runner's authoritative result.
    case headMatched = "head-matched"

    /// First head tried returned `confidence == floor` exactly
    /// (counts as match;included as separate case for diagnostic
    /// audit clarity — e.g. `.medium` floor matched by `.medium`).
    case floorMet = "floor-met"

    /// All registered heads tried, none returned `confidence >=
    /// floor`. Caller must fall back to layer's own rules logic
    /// (chapter 三百〇一 `mlHeadFallthrough` status).
    case fallenThrough = "fallen-through"

    /// Layer has no enabled heads in registry. Caller falls back
    /// to its hardcoded path. Diagnostic-only — distinguishes
    /// "registry empty" from "all heads tried + missed floor".
    case noHeadsRegistered = "no-heads-registered"
}

// MARK: - Cascade result record

/// Full typed runner output frame。Hosts emit this into audit
/// trail to show which heads were tried + which one won (if any)。
public struct BASLayerCascadeResult:
    BASSchemaVersioned, Sendable, Equatable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String

    /// Typed outcome classifier (4-case).
    public var outcome: BASLayerCascadeOutcome

    /// Layer the cascade ran for.
    public var layerID: BASMotherboardLayer14

    /// HeadID that won (only meaningful when outcome ==
    /// `.headMatched` or `.floorMet`).
    public var matchedHeadID: String?

    /// Inference output from the winning head, or nil for
    /// `.fallenThrough` / `.noHeadsRegistered`.
    public var matchedOutput: BASLayerInferenceOutput?

    /// Audit trail: list of (headID, confidence) pairs in the
    /// order they were tried. Includes ALL heads attempted, not
    /// just the winner. Useful for emitting cascade audit codes.
    public var triedHeads: [BASLayerCascadeAttempt]

    public init(
        schemaVersion: String
            = BASLayerCascadeResult.currentSchemaVersion,
        outcome: BASLayerCascadeOutcome,
        layerID: BASMotherboardLayer14,
        matchedHeadID: String? = nil,
        matchedOutput: BASLayerInferenceOutput? = nil,
        triedHeads: [BASLayerCascadeAttempt] = []
    ) {
        self.schemaVersion = schemaVersion
        self.outcome = outcome
        self.layerID = layerID
        self.matchedHeadID = matchedHeadID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.matchedOutput = matchedOutput
        self.triedHeads = triedHeads
    }
}

/// Per-attempt audit trail entry — head tried + confidence
/// returned。Lets audit emission show why earlier heads were
/// skipped (confidence < floor)。
public struct BASLayerCascadeAttempt:
    Sendable, Equatable, Hashable, Codable
{
    public let headID: String
    public let kind: BASLayerMLHeadKind
    public let confidence: BASLayerInferenceConfidence
    public let met: Bool

    public init(
        headID: String,
        kind: BASLayerMLHeadKind,
        confidence: BASLayerInferenceConfidence,
        met: Bool
    ) {
        self.headID = headID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.confidence = confidence
        self.met = met
    }
}

// MARK: - Cascade runner

/// Stateless typed dispatcher that walks a registry's slot list
/// for a given layer in priority order, calling each head's
/// `infer(input:)` until one returns `confidence >= floor`
/// (where floor is read from `input.confidenceFloor`)。
public enum BASLayerCascadeRunner {

    /// Walk the cascade。Returns typed result with outcome +
    /// matched head + audit trail。
    ///
    /// Confidence ordering (chapter 三百 BASLayerInferenceConfidence
    /// rank):
    ///   - `.high` = 3
    ///   - `.medium` = 2
    ///   - `.low` = 1
    ///   - `.unknown` = 0
    /// Match means `outputConfidence >= floor` per this ordering.
    /// `.unknown` only matches when floor is also `.unknown`.
    ///
    /// - Parameters:
    ///   - input: typed inference input (input.confidenceFloor
    ///     drives match)
    ///   - registry: source of slot bindings + head instances
    ///   - layerID: which layer's slots to walk (overrides
    ///     input.layerID for slot lookup; input.layerID still
    ///     reaches each head)
    /// - Returns: typed result. Outcome enum classifies which
    ///   path the cascade took.
    /// - Throws: re-throws caller's head error if any head's
    ///   infer() throws. Cascade aborts on first error (no
    ///   silent error swallowing).
    public static func run(
        input: BASLayerInferenceInput,
        registry: BASLayerMLHeadRegistry,
        layerID: BASMotherboardLayer14
    ) async throws -> BASLayerCascadeResult {
        let pairs = await registry.enabledHeads(
            forLayer: layerID)

        guard !pairs.isEmpty else {
            return BASLayerCascadeResult(
                outcome: .noHeadsRegistered,
                layerID: layerID)
        }

        let floor = input.confidenceFloor
        var trail: [BASLayerCascadeAttempt] = []

        for (head, slot) in pairs {
            let output = try await head.infer(input: input)
            let met = isConfidenceMet(
                output: output.confidence, floor: floor)
            let attempt = BASLayerCascadeAttempt(
                headID: head.headID,
                kind: slot.kind,
                confidence: output.confidence,
                met: met)
            trail.append(attempt)
            if met {
                let outcome: BASLayerCascadeOutcome =
                    output.confidence == floor
                        ? .floorMet
                        : .headMatched
                return BASLayerCascadeResult(
                    outcome: outcome,
                    layerID: layerID,
                    matchedHeadID: head.headID,
                    matchedOutput: output,
                    triedHeads: trail)
            }
            // confidence < floor → continue cascade
        }

        // All heads tried, none met floor.
        return BASLayerCascadeResult(
            outcome: .fallenThrough,
            layerID: layerID,
            triedHeads: trail)
    }

    /// Confidence ordering check:does `output` confidence meet
    /// or exceed `floor`?
    public static func isConfidenceMet(
        output: BASLayerInferenceConfidence,
        floor: BASLayerInferenceConfidence
    ) -> Bool {
        confidenceRank(output) >= confidenceRank(floor)
    }

    /// Map 4-case confidence enum to monotonic Int rank for
    /// comparison。`.unknown` is lowest (0),`.high` is highest
    /// (3)。
    public static func confidenceRank(
        _ confidence: BASLayerInferenceConfidence
    ) -> Int {
        switch confidence {
        case .unknown: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    /// Helper:emit canonical typed reason codes for a cascade
    /// result。Used by layer actors to feed cascade audit trail
    /// into their output.reasonCodes。
    public static func reasonCodes(
        for result: BASLayerCascadeResult
    ) -> [String] {
        var codes: [String] = [
            "cascade-outcome:\(result.outcome.rawValue)",
            "cascade-layer:\(result.layerID.rawValue)",
            "cascade-attempts:\(result.triedHeads.count)"
        ]
        if let matched = result.matchedHeadID {
            codes.append("cascade-matched-head:\(matched)")
        }
        return codes
    }
}
