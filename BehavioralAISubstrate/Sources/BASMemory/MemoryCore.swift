import Foundation

public enum BASMemoryKind: String, Codable, Sendable {
    case episodic
    case semantic
    case profile
    case template
    case failurePattern
}

public enum BASMemoryScope: String, Codable, Sendable {
    case user
    case device
    case session
    case task
}

public enum BASMemorySensitivity: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum BASMemoryTier: String, Codable, Sendable {
    case hot
    case warm
    case cold
}

public enum BASMemoryGovernanceStatus: String, Codable, Sendable {
    case candidate
    case governed
    case quarantined
    case rejected
    case archived
}

public struct BASReactionWeights: Codable, Sendable, Equatable {
    public var warmth: Double
    public var directness: Double
    public var brevity: Double
    public var actionBias: Double

    public init(warmth: Double, directness: Double, brevity: Double, actionBias: Double) {
        self.warmth = warmth
        self.directness = directness
        self.brevity = brevity
        self.actionBias = actionBias
    }
}

public struct BASEventRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: BASMemoryKind
    public var content: String
    public var timestamp: Date
    public var tags: [String]

    public init(id: UUID = UUID(), kind: BASMemoryKind, content: String, timestamp: Date = .now, tags: [String] = []) {
        self.id = id
        self.kind = kind
        self.content = content
        self.timestamp = timestamp
        self.tags = tags
    }
}

public struct BASMemoryCandidate: Codable, Sendable, Equatable {
    public var id: UUID
    public var event: BASEventRecord
    public var scope: BASMemoryScope
    public var sensitivity: BASMemorySensitivity
    public var confidence: Double
    public var sourceType: String
    public var preferredTier: BASMemoryTier

    public init(
        id: UUID = UUID(),
        event: BASEventRecord,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        confidence: Double,
        sourceType: String,
        preferredTier: BASMemoryTier
    ) {
        self.id = id
        self.event = event
        self.scope = scope
        self.sensitivity = sensitivity
        self.confidence = confidence
        self.sourceType = sourceType
        self.preferredTier = preferredTier
    }
}

public struct BASGovernedMemory: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: BASMemoryKind
    public var content: String
    public var scope: BASMemoryScope
    public var sensitivity: BASMemorySensitivity
    public var tier: BASMemoryTier
    public var confidence: Double
    public var sourceType: String
    public var lastConfirmedAt: Date?
    public var decayScore: Double
    public var governanceStatus: BASMemoryGovernanceStatus
    public var provenanceSummary: String

    public init(
        id: UUID = UUID(),
        kind: BASMemoryKind,
        content: String,
        scope: BASMemoryScope,
        sensitivity: BASMemorySensitivity,
        tier: BASMemoryTier,
        confidence: Double,
        sourceType: String,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        governanceStatus: BASMemoryGovernanceStatus,
        provenanceSummary: String
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.scope = scope
        self.sensitivity = sensitivity
        self.tier = tier
        self.confidence = confidence
        self.sourceType = sourceType
        self.lastConfirmedAt = lastConfirmedAt
        self.decayScore = decayScore
        self.governanceStatus = governanceStatus
        self.provenanceSummary = provenanceSummary
    }
}

public struct BASRetrievedEvidence: Codable, Sendable, Equatable {
    public var memoryID: UUID
    public var summary: String
    public var sourceLabel: String
    public var confidence: Double
    public var tier: BASMemoryTier
    public var scope: BASMemoryScope

    public init(memoryID: UUID, summary: String, sourceLabel: String, confidence: Double, tier: BASMemoryTier, scope: BASMemoryScope) {
        self.memoryID = memoryID
        self.summary = summary
        self.sourceLabel = sourceLabel
        self.confidence = confidence
        self.tier = tier
        self.scope = scope
    }
}

public struct BASCurrentBrainState: Codable, Sendable, Equatable {
    public var mode: String
    public var dominantGoals: [String]
    public var activeConstraints: [String]
    public var reactionWeights: BASReactionWeights
    public var activeTemplateIDs: [UUID]
    public var recentFailurePatternIDs: [UUID]
    public var retrievalTags: [String]
    public var verificationSnapshot: String

    public init(
        mode: String,
        dominantGoals: [String],
        activeConstraints: [String],
        reactionWeights: BASReactionWeights,
        activeTemplateIDs: [UUID],
        recentFailurePatternIDs: [UUID],
        retrievalTags: [String],
        verificationSnapshot: String
    ) {
        self.mode = mode
        self.dominantGoals = dominantGoals
        self.activeConstraints = activeConstraints
        self.reactionWeights = reactionWeights
        self.activeTemplateIDs = activeTemplateIDs
        self.recentFailurePatternIDs = recentFailurePatternIDs
        self.retrievalTags = retrievalTags
        self.verificationSnapshot = verificationSnapshot
    }
}

public struct BASInterventionTemplate: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var triggerTags: [String]
    public var recommendedTone: String
    public var steps: [String]

    public init(id: UUID = UUID(), name: String, triggerTags: [String], recommendedTone: String, steps: [String]) {
        self.id = id
        self.name = name
        self.triggerTags = triggerTags
        self.recommendedTone = recommendedTone
        self.steps = steps
    }
}

public struct BASFailurePattern: Codable, Sendable, Equatable {
    public var id: UUID
    public var description: String
    public var suppressedTone: String
    public var suppressedCadence: String
    public var confidence: Double
    public var lastSeenAt: Date?

    public init(
        id: UUID = UUID(),
        description: String,
        suppressedTone: String,
        suppressedCadence: String,
        confidence: Double,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.description = description
        self.suppressedTone = suppressedTone
        self.suppressedCadence = suppressedCadence
        self.confidence = confidence
        self.lastSeenAt = lastSeenAt
    }
}

public struct BASMemoryTierFilter: Sendable {
    public static func isFrontstageEligible(_ tier: BASMemoryTier) -> Bool {
        tier != .cold
    }

    public static func prioritizedTiers(for scope: BASMemoryScope, sensitivity: BASMemorySensitivity) -> [BASMemoryTier] {
        switch (scope, sensitivity) {
        case (.session, .high), (.task, .high):
            return [.hot, .warm]
        case (.user, .high):
            return [.hot, .warm, .cold]
        case (.device, _), (_, .low):
            return [.hot, .warm, .cold]
        default:
            return [.hot, .warm]
        }
    }

    public static func frontstageEligibleMemories(_ memories: [BASGovernedMemory]) -> [BASGovernedMemory] {
        memories.filter { isFrontstageEligible($0.tier) && $0.governanceStatus == .governed }
    }

    public static func filter(
        _ memories: [BASGovernedMemory],
        allowedTiers: [BASMemoryTier],
        scope: BASMemoryScope? = nil,
        sensitivity: BASMemorySensitivity? = nil
    ) -> [BASGovernedMemory] {
        memories.filter { memory in
            guard allowedTiers.contains(memory.tier) else { return false }
            if let scope, memory.scope != scope { return false }
            if let sensitivity, memory.sensitivity != sensitivity { return false }
            return memory.governanceStatus == .governed
        }
        .sorted {
            if $0.tier != $1.tier {
                return $0.tier.priority > $1.tier.priority
            }
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public struct BASMemoryGovernance: Sendable {
    public static func shouldAdmit(candidate: BASMemoryCandidate, minimumConfidence: Double = 0.6) -> Bool {
        candidate.confidence >= minimumConfidence
    }

    public static func promote(
        candidate: BASMemoryCandidate,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        provenanceSummary: String? = nil,
        governanceStatus: BASMemoryGovernanceStatus = .governed
    ) -> BASGovernedMemory {
        BASGovernedMemory(
            kind: candidate.event.kind,
            content: candidate.event.content,
            scope: candidate.scope,
            sensitivity: candidate.sensitivity,
            tier: candidate.preferredTier,
            confidence: candidate.confidence,
            sourceType: candidate.sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: decayScore,
            governanceStatus: governanceStatus,
            provenanceSummary: provenanceSummary ?? "promoted from candidate:\(candidate.sourceType)"
        )
    }

    public static func resolveConflict(primary: BASGovernedMemory, challenger: BASGovernedMemory) -> BASGovernedMemory {
        guard primary.kind == challenger.kind, primary.scope == challenger.scope else {
            return primary
        }

        if challenger.confidence > primary.confidence {
            return challenger
        }

        if challenger.confidence == primary.confidence, challenger.decayScore < primary.decayScore {
            return challenger
        }

        return primary
    }
}

public struct BASCurrentBrainBootstrap: Sendable {
    public static func bootstrap(
        from memories: [BASGovernedMemory],
        goalHints: [String] = [],
        constraintHints: [String] = [],
        mode: String = "balanced",
        verificationSnapshot: String = "bootstrap"
    ) -> BASCurrentBrainState {
        let frontstage = BASMemoryTierFilter.frontstageEligibleMemories(memories)
            .sorted {
                if $0.tier != $1.tier {
                    return $0.tier.priority > $1.tier.priority
                }
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.id.uuidString < $1.id.uuidString
            }

        let profileGoals = frontstage
            .filter { $0.kind == .profile }
            .map(\.content)
            .filter { !$0.isEmpty }

        let dominantGoals = Self.uniqueOrdered(goalHints + profileGoals)

        let highSensitivityConstraints = frontstage
            .filter { $0.sensitivity == .high }
            .map { "sensitive:\($0.scope.rawValue)" }

        let activeConstraints = Self.uniqueOrdered(constraintHints + highSensitivityConstraints)

        let activeTemplateIDs = frontstage
            .filter { $0.kind == .template }
            .map(\.id)

        let recentFailurePatternIDs = frontstage
            .filter { $0.kind == .failurePattern }
            .map(\.id)

        let retrievalTags = Self.uniqueOrdered(frontstage.flatMap { memory in
            [
                "tier:\(memory.tier.rawValue)",
                "scope:\(memory.scope.rawValue)",
                "kind:\(memory.kind.rawValue)",
                "source:\(memory.sourceType)"
            ]
        })

        return BASCurrentBrainState(
            mode: mode,
            dominantGoals: dominantGoals,
            activeConstraints: activeConstraints,
            reactionWeights: BASReactionWeights(warmth: 0.5, directness: 0.5, brevity: 0.5, actionBias: 0.5),
            activeTemplateIDs: activeTemplateIDs,
            recentFailurePatternIDs: recentFailurePatternIDs,
            retrievalTags: retrievalTags,
            verificationSnapshot: verificationSnapshot
        )
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

private extension BASMemoryTier {
    var priority: Int {
        switch self {
        case .hot: return 3
        case .warm: return 2
        case .cold: return 1
        }
    }
}
