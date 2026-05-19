import CryptoKit
import Foundation
// chapter 七百二 native-port — Rust SHA256 primitive。 Legacy
// CryptoKit body preserved as `/* ... */` per 全comment 不要删除。
import BASRustHashCore

public struct BASProjectionGovernedMemoryInput: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var headline: String
    public var confidence: Double
    public var sourceID: String
    public var lastConfirmedAt: Date?
    public var lifecycleStateID: String
    public var tierID: String
    public var provenanceSummary: String

    public init(
        id: String,
        typeID: String,
        headline: String,
        confidence: Double,
        sourceID: String,
        lastConfirmedAt: Date?,
        lifecycleStateID: String,
        tierID: String,
        provenanceSummary: String
    ) {
        self.id = id
        self.typeID = typeID
        self.headline = headline
        self.confidence = confidence
        self.sourceID = sourceID
        self.lastConfirmedAt = lastConfirmedAt
        self.lifecycleStateID = lifecycleStateID
        self.tierID = tierID
        self.provenanceSummary = provenanceSummary
    }
}

public struct BASProjectionCandidateInput: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var headline: String
    public var confidence: Double
    public var priority: Double
    public var sourceID: String
    public var retrievalTags: [String]
    public var lastObservedAt: Date
    public var decayPolicyID: String
    public var statusID: String
    public var governanceDecisionID: String
    public var evidenceCount: Int
    public var provenanceSummary: String

    public init(
        id: String,
        typeID: String,
        headline: String,
        confidence: Double,
        priority: Double,
        sourceID: String,
        retrievalTags: [String],
        lastObservedAt: Date,
        decayPolicyID: String,
        statusID: String,
        governanceDecisionID: String,
        evidenceCount: Int,
        provenanceSummary: String
    ) {
        self.id = id
        self.typeID = typeID
        self.headline = headline
        self.confidence = confidence
        self.priority = priority
        self.sourceID = sourceID
        self.retrievalTags = retrievalTags
        self.lastObservedAt = lastObservedAt
        self.decayPolicyID = decayPolicyID
        self.statusID = statusID
        self.governanceDecisionID = governanceDecisionID
        self.evidenceCount = evidenceCount
        self.provenanceSummary = provenanceSummary
    }
}

public struct BASProjectionEventInput: Codable, Equatable, Sendable {
    public var id: String
    public var note: String
    public var fallbackContent: String
    public var createdAt: Date
    public var scenarioID: String?
    public var actionID: String?
    public var reflectionOutcomeID: String?
    public var entrySourceID: String?

    public init(
        id: String,
        note: String,
        fallbackContent: String,
        createdAt: Date,
        scenarioID: String? = nil,
        actionID: String? = nil,
        reflectionOutcomeID: String? = nil,
        entrySourceID: String? = nil
    ) {
        self.id = id
        self.note = note
        self.fallbackContent = fallbackContent
        self.createdAt = createdAt
        self.scenarioID = scenarioID
        self.actionID = actionID
        self.reflectionOutcomeID = reflectionOutcomeID
        self.entrySourceID = entrySourceID
    }
}

public struct BASProjectionGovernanceInput: Codable, Equatable, Sendable {
    public var totalRecordCount: Int
    public var totalCandidateCount: Int
    public var pendingCandidateCount: Int
    public var promotedCandidateCount: Int
    public var deferredCandidateCount: Int
    public var admittedCandidateCount: Int
    public var externallyRefreshedCandidateCount: Int
    public var quarantinedObservationCount: Int
    public var evidenceCaveatedCandidateCount: Int

    public init(
        totalRecordCount: Int,
        totalCandidateCount: Int,
        pendingCandidateCount: Int,
        promotedCandidateCount: Int,
        deferredCandidateCount: Int,
        admittedCandidateCount: Int,
        externallyRefreshedCandidateCount: Int = 0,
        quarantinedObservationCount: Int = 0,
        evidenceCaveatedCandidateCount: Int = 0
    ) {
        self.totalRecordCount = totalRecordCount
        self.totalCandidateCount = totalCandidateCount
        self.pendingCandidateCount = pendingCandidateCount
        self.promotedCandidateCount = promotedCandidateCount
        self.deferredCandidateCount = deferredCandidateCount
        self.admittedCandidateCount = admittedCandidateCount
        self.externallyRefreshedCandidateCount = externallyRefreshedCandidateCount
        self.quarantinedObservationCount = quarantinedObservationCount
        self.evidenceCaveatedCandidateCount = evidenceCaveatedCandidateCount
    }
}

public struct BASBrainProjectionCompileRequest: Codable, Equatable, Sendable {
    public var records: [BASProjectionGovernedMemoryInput]
    public var candidates: [BASProjectionCandidateInput]
    public var events: [BASProjectionEventInput]
    public var embeddingScoresByID: [String: Double]
    public var governanceSnapshot: BASProjectionGovernanceInput?
    public var taskGraphHint: BASBrainTaskGraphHint?
    public var activeTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var memoryTrustBehavior: BASMemoryTrustBehavior

    public init(
        records: [BASProjectionGovernedMemoryInput],
        candidates: [BASProjectionCandidateInput],
        events: [BASProjectionEventInput],
        embeddingScoresByID: [String: Double] = [:],
        governanceSnapshot: BASProjectionGovernanceInput? = nil,
        taskGraphHint: BASBrainTaskGraphHint? = nil,
        activeTemplateIDs: [String] = [],
        failureGuardIDs: [String] = [],
        memoryTrustBehavior: BASMemoryTrustBehavior = .generic
    ) {
        self.records = records
        self.candidates = candidates
        self.events = events
        self.embeddingScoresByID = embeddingScoresByID
        self.governanceSnapshot = governanceSnapshot
        self.taskGraphHint = taskGraphHint
        self.activeTemplateIDs = activeTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.memoryTrustBehavior = memoryTrustBehavior
    }
}

public enum BASBrainProjectionCompiler {
    public static func compile(_ request: BASBrainProjectionCompileRequest) -> BASBrainProjection {
        BASBrainProjection(
            records: request.records.map(governedMemory(from:)),
            candidates: request.candidates.map { candidate(from: $0, behavior: request.memoryTrustBehavior) },
            recentEvents: request.events.map(event(from:)),
            embeddingScoresByID: request.embeddingScoresByID,
            governanceSnapshot: request.governanceSnapshot.map(governanceState(from:)),
            taskGraphHint: request.taskGraphHint,
            activeTemplateIDs: request.activeTemplateIDs,
            failureGuardIDs: request.failureGuardIDs
        )
    }

    private static func governedMemory(from input: BASProjectionGovernedMemoryInput) -> BASGovernedMemory {
        BASGovernedMemory(
            id: stableUUID(for: input.id),
            kind: memoryKind(from: input.typeID),
            content: input.headline,
            scope: memoryScope(from: input.typeID),
            sensitivity: memorySensitivity(from: input.typeID),
            tier: memoryTier(from: input.tierID),
            confidence: input.confidence,
            sourceType: input.sourceID,
            lastConfirmedAt: input.lastConfirmedAt,
            decayScore: decayScore(for: input.lifecycleStateID),
            governanceStatus: .governed,
            provenanceSummary: input.provenanceSummary
        )
    }

    private static func candidate(
        from input: BASProjectionCandidateInput,
        behavior: BASMemoryTrustBehavior
    ) -> BASMemoryEligibilityCandidate {
        let source = memorySource(from: input.sourceID)
        let governanceStatus = memoryLoadStatus(
            statusID: input.statusID,
            governanceDecisionID: input.governanceDecisionID
        )
        let decayPolicy = memoryDecayPolicy(from: input.decayPolicyID)
        let isPending = input.statusID == "pending"
        let trustProfile = BASMemoryTrustEngine.profile(
            source: source,
            evidenceCount: input.evidenceCount,
            decayPolicy: decayPolicy,
            governanceStatus: governanceStatus,
            isPending: isPending,
            provenanceSummary: input.provenanceSummary,
            behavior: behavior
        )

        return BASMemoryEligibilityCandidate(
            id: input.id,
            role: memoryRole(from: input.typeID),
            kind: memoryKind(from: input.typeID),
            headline: input.headline,
            source: source,
            scope: memoryScope(from: input.typeID),
            sensitivity: memorySensitivity(from: input.typeID),
            confidence: input.confidence,
            priority: input.priority,
            retrievalTags: input.retrievalTags,
            lastConfirmedAt: input.lastObservedAt,
            decayPolicy: decayPolicy,
            lifecycleState: input.statusID,
            governanceStatus: governanceStatus,
            isPending: isPending,
            provenanceSummary: input.provenanceSummary,
            sourceTrustScore: trustProfile.score,
            sourceTrustTier: trustProfile.tier,
            effectiveConfidence: BASMemoryTrustEngine.effectiveConfidence(
                rawConfidence: input.confidence,
                trustProfile: trustProfile
            ),
            provenanceRisk: trustProfile.provenanceRisk
        )
    }

    private static func event(from input: BASProjectionEventInput) -> BASEventRecord {
        BASEventRecord(
            id: stableUUID(for: input.id),
            kind: .episodic,
            content: input.note.isEmpty ? input.fallbackContent : input.note,
            timestamp: input.createdAt,
            tags: uniqueOrdered(
                [
                    input.scenarioID,
                    input.actionID,
                    input.entrySourceID
                ].compactMap { $0 } + lexicalTags(from: input.note)
            ),
            scenarioID: input.scenarioID,
            actionID: input.actionID,
            reflectionOutcomeID: input.reflectionOutcomeID,
            entrySourceID: input.entrySourceID
        )
    }

    private static func governanceState(from input: BASProjectionGovernanceInput) -> BASMemoryGovernanceState {
        BASMemoryGovernanceState(
            totalRecordCount: input.totalRecordCount,
            totalCandidateCount: input.totalCandidateCount,
            pendingCandidateCount: input.pendingCandidateCount,
            promotedCandidateCount: input.promotedCandidateCount,
            loadedPromotedMemoryCount: 0,
            loadedPendingMemoryCount: 0,
            deferredCandidateCount: input.deferredCandidateCount,
            admittedCandidateCount: input.admittedCandidateCount,
            externallyRefreshedCandidateCount: input.externallyRefreshedCandidateCount,
            quarantinedObservationCount: input.quarantinedObservationCount,
            evidenceCaveatedCandidateCount: input.evidenceCaveatedCandidateCount
        )
    }

    private static func memoryKind(from typeID: String) -> BASMemoryKind {
        switch typeID {
        case "identity", "preference":
            .profile
        case "goal":
            .goal
        case "situational":
            .situational
        case "support":
            .support
        case "template":
            .template
        case "failurePattern":
            .failurePattern
        default:
            .semantic
        }
    }

    private static func memoryRole(from typeID: String) -> BASBrainMemoryRole {
        switch typeID {
        case "identity", "preference":
            .profile
        case "goal":
            .goal
        default:
            .relevant
        }
    }

    private static func memoryScope(from typeID: String) -> BASMemoryScope {
        switch typeID {
        case "situational":
            .session
        case "support":
            .task
        default:
            .user
        }
    }

    private static func memorySensitivity(from typeID: String) -> BASMemorySensitivity {
        switch typeID {
        case "identity", "goal":
            .high
        case "preference", "situational", "support":
            .medium
        default:
            .low
        }
    }

    private static func memoryTier(from tierID: String) -> BASMemoryTier {
        BASMemoryTier(rawValue: tierID) ?? .warm
    }

    private static func memorySource(from sourceID: String) -> BASMemorySource {
        BASMemorySource(identifier: sourceID) ?? .archive
    }

    private static func memoryLoadStatus(
        statusID: String,
        governanceDecisionID: String
    ) -> BASMemoryLoadStatus {
        if statusID != "pending" {
            return .pending
        }

        switch governanceDecisionID {
        case "admit":
            return .admitted
        case "deferred":
            return .deferred
        default:
            return .pending
        }
    }

    private static func memoryDecayPolicy(from decayPolicyID: String) -> BASMemoryDecayPolicy {
        BASMemoryDecayPolicy(rawValue: decayPolicyID) ?? .medium
    }

    private static func decayScore(for lifecycleStateID: String) -> Double {
        switch lifecycleStateID {
        case "aging":
            0.18
        case "retired":
            0.82
        default:
            0
        }
    }

    private static func lexicalTags(from text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    private static func stableUUID(for value: String) -> UUID {
        if let uuid = UUID(uuidString: value) {
            return uuid
        }

        // chapter 七百二 native-port — Rust-sourced stable UUID;
        // legacy CryptoKit body preserved per 全comment 不要删除。
        let valueData = Data(value.utf8)
        let bytes: [UInt8]
        if let rust = try? BASRustLedgerCore.sha256(
            valueData)
        {
            bytes = Array(rust.prefix(16))
        } else {
            /*
             * Pre-chapter-702 Swift implementation:
             *     let digest = SHA256.hash(data: Data(value.utf8))
             *     let bytes = Array(digest.prefix(16))
             */
            let digest = SHA256.hash(data: valueData)
            bytes = Array(digest.prefix(16))
        }
        let encoded = bytes.enumerated().map { index, byte in
            let separator: String = switch index {
            case 4, 6, 8, 10:
                "-"
            default:
                ""
            }
            return separator + String(format: "%02x", byte)
        }.joined()

        return UUID(uuidString: encoded) ?? UUID()
    }
}
