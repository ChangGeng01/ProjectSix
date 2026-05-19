// MARK: - MemoryAtomBootstrapCore — chapter 二百八十三 / M770
//
// Phase Alpha 第九刀(BASMemory god file 3rd cut):从 MemoryCore.swift
// 抽出 atom records + governance / bootstrap cluster — Phase Alpha
// 第二个 god file 第三次拆分。
//
// 抽出 types:
//   - `BASEventRecord` — episodic / procedural / value 事件记录
//   - `BASMemoryCandidate` — pre-governance 候选 atom
//   - `BASGovernedMemory` — governed / quarantined / draft atom
//   - `BASRetrievedEvidence` — retrieval evidence wrapper
//   - `BASDecisionBrainState` — decision brain state aggregator
//   - `BASCurrentBrainState` — current brain state aggregator
//   - `BASInterventionTemplate` — intervention template
//   - `BASFailurePattern` — failure pattern record
//   - `BASMemoryTierFilter` — tier filter helper
//   - `BASMemoryGovernance` — governance helper struct + extension
//   - `BASCurrentBrainBootstrap` — current-brain bootstrap surface
//   - `extension BASMemoryGovernance` — governance helpers
//   - `extension BASMemoryTier` — tier ordering helpers
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。Module DAG 不变。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保

import CryptoKit
import Foundation
import BASRuntimeCore

public struct BASEventRecord: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: BASMemoryKind
    public var content: String
    public var timestamp: Date
    public var tags: [String]
    public var scenarioID: String?
    public var actionID: String?
    public var reflectionOutcomeID: String?
    public var entrySourceID: String?

    public init(
        id: UUID = UUID(),
        kind: BASMemoryKind,
        content: String,
        timestamp: Date = .now,
        tags: [String] = [],
        scenarioID: String? = nil,
        actionID: String? = nil,
        reflectionOutcomeID: String? = nil,
        entrySourceID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.timestamp = timestamp
        self.tags = tags
        self.scenarioID = scenarioID
        self.actionID = actionID
        self.reflectionOutcomeID = reflectionOutcomeID
        self.entrySourceID = entrySourceID
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

public struct BASDecisionBrainState: Codable, Equatable, Sendable {
    /// **M599 chapter 一百七十 — anti-magic-number** (chapter 一百六十六
    /// §166.5 backlog item 3 of 5): pending-memory-load rate
    /// threshold above which `highPendingInfluence` risk flag is
    /// raised. Pre-fix this `0.34` was inline at line ~2730.
    /// Doctrine: 0.34 ≈ 1/3 — when more than ~third of loaded
    /// memory is pending (not yet validated), substrate flags
    /// elevated risk of unverified influence.
    public static let
        highPendingInfluenceThreshold: Double = 0.34

    /// **M599 chapter 一百七十 — anti-magic-number**: low-trust
    /// memory load rate threshold above which `lowTrustLoad` risk
    /// flag is raised. Pre-fix this `0.25` was inline at line ~2733.
    /// Doctrine: 0.25 = 1/4 — when more than a quarter of loaded
    /// memory is from low-trust sources, substrate flags elevated
    /// risk of trust dilution.
    ///
    /// **Cross-reference**: low-trust threshold (0.25) is
    /// strictly stricter than pending threshold (0.34) — low-
    /// trust is more concerning than merely-pending. Tier
    /// ordering: trust > pending > clean.
    public static let
        lowTrustLoadThreshold: Double = 0.25

    public var memorySlices: [BASGovernedMemorySlice]
    public var sessionBiases: [String]
    public var retrievalTags: [String]
    public var reactionWeights: BASReactionWeights
    public var identityProfile: BASIdentityProfile
    public var boundaryPolicy: BASBoundaryPolicyState
    public var calibrationState: BASCalibrationState
    public var evolutionState: BASEvolutionState
    public var activeInterventionTemplateIDs: [String]
    public var failureGuardIDs: [String]
    public var memoryGovernance: BASMemoryGovernanceState = .empty
    public var loadedAt: Date

    public init(
        memorySlices: [BASGovernedMemorySlice],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: BASReactionWeights,
        identityProfile: BASIdentityProfile,
        boundaryPolicy: BASBoundaryPolicyState,
        calibrationState: BASCalibrationState = .stable(),
        evolutionState: BASEvolutionState = .empty,
        activeInterventionTemplateIDs: [String] = [],
        failureGuardIDs: [String] = [],
        memoryGovernance: BASMemoryGovernanceState = .empty,
        loadedAt: Date
    ) {
        self.memorySlices = memorySlices
        self.sessionBiases = sessionBiases
        self.retrievalTags = retrievalTags
        self.reactionWeights = reactionWeights
        self.identityProfile = identityProfile
        self.boundaryPolicy = boundaryPolicy
        self.calibrationState = calibrationState
        self.evolutionState = evolutionState
        self.activeInterventionTemplateIDs = activeInterventionTemplateIDs
        self.failureGuardIDs = failureGuardIDs
        self.memoryGovernance = memoryGovernance
        self.loadedAt = loadedAt
    }

    public init(
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String],
        sessionBiases: [String],
        retrievalTags: [String],
        reactionWeights: BASReactionWeights,
        identityProfile: BASIdentityProfile? = nil,
        boundaryPolicy: BASBoundaryPolicyState? = nil,
        calibrationState: BASCalibrationState = .stable(),
        evolutionState: BASEvolutionState = .empty,
        activeInterventionTemplateIDs: [String] = [],
        failureGuardIDs: [String] = [],
        memoryGovernance: BASMemoryGovernanceState = .empty,
        loadedAt: Date = .now
    ) {
        let resolvedIdentity = identityProfile ?? BASIdentityProfile.default(modeName: "generic")
        let resolvedBoundary = boundaryPolicy ?? BASBoundaryPolicyState.default(riskLevel: .low)
        self.init(
            memorySlices: Self.legacyMemorySlices(
                profileCore: profileCore,
                activeGoals: activeGoals,
                relevantMemories: relevantMemories
            ),
            sessionBiases: sessionBiases,
            retrievalTags: retrievalTags,
            reactionWeights: reactionWeights,
            identityProfile: resolvedIdentity,
            boundaryPolicy: resolvedBoundary,
            calibrationState: calibrationState,
            evolutionState: evolutionState,
            activeInterventionTemplateIDs: activeInterventionTemplateIDs,
            failureGuardIDs: failureGuardIDs,
            memoryGovernance: memoryGovernance,
            loadedAt: loadedAt
        )
    }

    public var profileCoreSlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .profile }
    }

    public var activeGoalSlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .goal }
    }

    public var relevantMemorySlices: [BASGovernedMemorySlice] {
        memorySlices.filter { $0.role == .relevant }
    }

    public var profileCore: [String] {
        profileCoreSlices.map(\.headline)
    }

    public var activeGoals: [String] {
        activeGoalSlices.map(\.headline)
    }

    public var relevantMemories: [String] {
        relevantMemorySlices.map(\.headline)
    }

    public var isEmpty: Bool {
        memorySlices.isEmpty &&
            sessionBiases.isEmpty &&
            retrievalTags.isEmpty &&
            activeInterventionTemplateIDs.isEmpty &&
            failureGuardIDs.isEmpty &&
            calibrationState.alerts.isEmpty &&
            evolutionState.checkpointCount == 0
    }

    public var verificationSnapshot: BASBrainStateSnapshot {
        // Snapshot risk should reflect the current frontstage brain, not a historical
        // governance seed that can dilute present low-trust density.
        let loadedMemoryCount = memorySlices.count
        let pendingMemoryCount = max(
            memorySlices.filter(\.isPending).count,
            memoryGovernance.loadedPendingMemoryCount
        )
        let lowTrustMemoryCount = memorySlices.filter { $0.sourceTrustTier == .low }.count

        let pendingMemoryLoadRate = loadedMemoryCount > 0
            ? min(1, Double(pendingMemoryCount) / Double(loadedMemoryCount))
            : 0
        let lowTrustMemoryLoadRate = loadedMemoryCount > 0
            ? min(1, Double(lowTrustMemoryCount) / Double(loadedMemoryCount))
            : 0
        let loadedRetrievalTags = Set(memorySlices.flatMap(\.retrievalTags))

        var riskFlags: [BASBrainStateRiskFlag] = []
        // M599 chapter 一百七十 — anti-magic-number: thresholds
        // sourced from named constants on BASDecisionBrainState.
        if pendingMemoryLoadRate >= Self
            .highPendingInfluenceThreshold {
            riskFlags.append(.highPendingInfluence)
        }
        if lowTrustMemoryLoadRate >= Self
            .lowTrustLoadThreshold {
            riskFlags.append(.lowTrustLoad)
        }
        if (memoryGovernance.screenedOutReasonCounts[.provenanceContamination] ?? 0) > 0 {
            riskFlags.append(.contaminationGuardTriggered)
        }
        if (memoryGovernance.screenedOutReasonCounts[.externalRefreshNoOverlap] ?? 0) > 0 {
            riskFlags.append(.externalRefreshGuardTriggered)
        }
        if loadedRetrievalTags.contains("quarantined") ||
            loadedRetrievalTags.contains("tool_observation") ||
            memoryGovernance.quarantinedObservationCount > 0 {
            riskFlags.append(.observationOnlyQuarantine)
        }
        if loadedRetrievalTags.contains("evidence_caveat") ||
            memoryGovernance.evidenceCaveatedCandidateCount > 0 {
            riskFlags.append(.evidenceCaveatLoad)
        }
        if memoryGovernance.screenedOutMemoryCount >= max(4, loadedMemoryCount) {
            riskFlags.append(.retrievalInstability)
        }
        if (memoryGovernance.screenedOutReasonCounts[.tagFloodNoOverlap] ?? 0) > 0 {
            riskFlags.append(.tagFloodBlocked)
        }

        let boundaryConstraintMaterial = boundaryPolicy.activeConstraints
            .map(\.rawValue)
            .sorted()
            .joined(separator: "|")
        let calibrationAlertMaterial = calibrationState.alerts
            .map(\.rawValue)
            .sorted()
            .joined(separator: "|")
        let memorySliceMaterial = memorySlices
            .sorted { $0.id < $1.id }
            .map { slice in
                [
                    slice.id,
                    slice.role.rawValue,
                    slice.headline,
                    slice.source,
                    String(format: "%.3f", slice.sourceTrustScore),
                    slice.sourceTrustTier.rawValue,
                    slice.governanceStatus.rawValue,
                    slice.isPending ? "pending" : "stable"
                ]
                .joined(separator: "::")
            }
            .joined(separator: "||")
        let riskFlagMaterial = riskFlags.map(\.rawValue).sorted().joined(separator: "|")

        let materialParts = [
            profileCore.sorted().joined(separator: "|"),
            activeGoals.sorted().joined(separator: "|"),
            relevantMemories.sorted().joined(separator: "|"),
            sessionBiases.sorted().joined(separator: "|"),
            retrievalTags.sorted().joined(separator: "|"),
            reactionWeights.dominantKey.rawValue,
            identityProfile.role.rawValue,
            identityProfile.posture.rawValue,
            identityProfile.initiative.rawValue,
            boundaryPolicy.mode.rawValue,
            boundaryConstraintMaterial,
            calibrationState.status.rawValue,
            calibrationAlertMaterial,
            memorySliceMaterial,
            riskFlagMaterial
        ]
        let material = materialParts.joined(separator: "###")

        // LEGACY (chapter 七百二十 第三刀 / M2273):
        //     let fingerprint = SHA256.hash(data: Data(material.utf8))
        //         .map { String(format: "%02x", $0) }
        //         .joined()
        //         .prefix(20)
        let digest = SHA256.hash(data: Data(material.utf8))
        let fingerprint = BASAutoRouteRanker
            .bytesToHexLower(Array(digest)).prefix(20)

        return BASBrainStateSnapshot(
            fingerprint: String(fingerprint),
            dominantReactionWeight: reactionWeights.dominantKey,
            loadedMemoryCount: loadedMemoryCount,
            pendingMemoryLoadRate: pendingMemoryLoadRate,
            lowTrustMemoryLoadRate: lowTrustMemoryLoadRate,
            riskFlags: riskFlags
        )
    }

    private static func legacyMemorySlices(
        profileCore: [String],
        activeGoals: [String],
        relevantMemories: [String]
    ) -> [BASGovernedMemorySlice] {
        let defaultEligibility = BASMemoryEligibilityDecision.allowed(.defaultAllowed)
        let defaultTags: [String] = []

        let profileSlices = profileCore.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.profile.\(index)",
                role: .profile,
                type: "preference",
                headline: headline,
                source: "pattern",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy profile core projection."
            )
        }

        let goalSlices = activeGoals.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.goal.\(index)",
                role: .goal,
                type: "goal",
                headline: headline,
                source: "archive",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy active-goal projection."
            )
        }

        let relevantSlices = relevantMemories.enumerated().map { index, headline in
            BASGovernedMemorySlice(
                id: "legacy.relevant.\(index)",
                role: .relevant,
                type: "semantic",
                headline: headline,
                source: "archive",
                confidence: 1,
                priority: 1,
                lifecycleState: "active",
                governanceStatus: .admitted,
                eligibility: defaultEligibility,
                sourceTrustScore: 1,
                sourceTrustTier: .high,
                retrievalTags: defaultTags,
                isPending: false,
                provenanceSummary: "Legacy relevant-memory projection."
            )
        }

        return profileSlices + goalSlices + relevantSlices
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

    public static func shouldAdmit(
        candidate: BASMemoryCandidate,
        under constitution: BASHostConstitution,
        minimumConfidence: Double = 0.6
    ) -> Bool {
        guard shouldAdmit(candidate: candidate, minimumConfidence: minimumConfidence) else {
            return false
        }

        let writeScope = constitution.consentLattice.memoryWriteScope
        if writeScope == "disabled" || writeScope == "none" {
            return false
        }

        return true
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

    public static func promote(
        candidate: BASMemoryCandidate,
        under constitution: BASHostConstitution,
        lastConfirmedAt: Date? = nil,
        decayScore: Double = 0.0,
        provenanceSummary: String? = nil,
        governanceStatus: BASMemoryGovernanceStatus = .governed
    ) -> BASGovernedMemory {
        let restrictedDomains = Set(constitution.boundaryVeil.restrictedMemoryDomains)
        let sensitiveDomains = Set(constitution.protectionRing.sensitiveDomains)
        let candidateTags = Set(candidate.event.tags)
        let touchesRestrictedDomain = !restrictedDomains.isDisjoint(with: candidateTags)
        let touchesSensitiveDomain = !sensitiveDomains.isDisjoint(with: candidateTags)
        let requiresReview = constitution.consentLattice.memoryPromotionScope == "review_required"
            || touchesRestrictedDomain
            || touchesSensitiveDomain

        let projectedTier: BASMemoryTier
        switch constitution.consentLattice.memoryWriteScope {
        case "warm_only":
            projectedTier = .warm
        case "cold_only":
            projectedTier = .cold
        default:
            projectedTier = candidate.preferredTier
        }

        let projectedStatus = requiresReview ? BASMemoryGovernanceStatus.candidate : governanceStatus
        let phase = constitution.narrativeLoom.currentPhase
        let projectedProvenance = provenanceSummary ?? Self.constitutionProvenanceSummary(
            candidate: candidate,
            constitutionVersion: constitution.activeVersion,
            phase: phase,
            promotionScope: constitution.consentLattice.memoryPromotionScope,
            restrictedDomainTriggered: touchesRestrictedDomain,
            sensitiveDomainTriggered: touchesSensitiveDomain
        )

        return BASGovernedMemory(
            kind: candidate.event.kind,
            content: candidate.event.content,
            scope: candidate.scope,
            sensitivity: candidate.sensitivity,
            tier: projectedTier,
            confidence: candidate.confidence,
            sourceType: candidate.sourceType,
            lastConfirmedAt: lastConfirmedAt,
            decayScore: decayScore,
            governanceStatus: projectedStatus,
            provenanceSummary: projectedProvenance
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
        constitution: BASHostConstitution? = nil,
        goalHints: [String] = [],
        constraintHints: [String] = [],
        mode: String = BASDecisionMode.primaryID,
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

        let constitutionGoals = constitution?.goalSpine.goals ?? []
        let dominantGoals = Self.uniqueOrdered(goalHints + constitutionGoals + profileGoals)

        let highSensitivityConstraints = frontstage
            .filter { $0.sensitivity == .high }
            .map { "sensitive:\($0.scope.rawValue)" }

        let constitutionConstraints = (constitution?.boundaryVeil.hardNoGo ?? [])
            + (constitution?.boundaryVeil.softCaution ?? [])
        let activeConstraints = Self.uniqueOrdered(
            constraintHints + constitutionConstraints + highSensitivityConstraints
        )

        let activeTemplateIDs = frontstage
            .filter { $0.kind == .template }
            .map(\.id)

        let recentFailurePatternIDs = frontstage
            .filter { $0.kind == .failurePattern }
            .map(\.id)

        var retrievalTags = Self.uniqueOrdered(frontstage.flatMap { memory in
            [
                "tier:\(memory.tier.rawValue)",
                "scope:\(memory.scope.rawValue)",
                "kind:\(memory.kind.rawValue)",
                "source:\(memory.sourceType)"
            ]
        })

        if let constitution {
            retrievalTags = Self.uniqueOrdered(
                retrievalTags + [
                    "constitution:\(constitution.activeVersion)",
                    "constitution_phase:\(constitution.narrativeLoom.currentPhase)",
                    "constitution_value_axes:\(constitution.valueAxes.axes.count)"
                ]
            )
        }

        let projectedVerificationSnapshot: String
        if let constitution {
            projectedVerificationSnapshot = Self.uniqueOrdered([
                verificationSnapshot,
                "constitution:\(constitution.activeVersion)",
                "phase:\(constitution.narrativeLoom.currentPhase)"
            ]).joined(separator: "|")
        } else {
            projectedVerificationSnapshot = verificationSnapshot
        }

        return BASCurrentBrainState(
            mode: mode,
            dominantGoals: dominantGoals,
            activeConstraints: activeConstraints,
            reactionWeights: BASReactionWeights(warmth: 0.5, directness: 0.5, brevity: 0.5, actionBias: 0.5),
            activeTemplateIDs: activeTemplateIDs,
            recentFailurePatternIDs: recentFailurePatternIDs,
            retrievalTags: retrievalTags,
            verificationSnapshot: projectedVerificationSnapshot
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

extension BASMemoryGovernance {
    private static func constitutionProvenanceSummary(
        candidate: BASMemoryCandidate,
        constitutionVersion: String,
        phase: String,
        promotionScope: String,
        restrictedDomainTriggered: Bool,
        sensitiveDomainTriggered: Bool
    ) -> String {
        var markers = [
            "promoted from candidate:\(candidate.sourceType)",
            "constitution:\(constitutionVersion)",
            "phase:\(phase)",
            "promotion_scope:\(promotionScope)"
        ]

        if restrictedDomainTriggered {
            markers.append("restricted_domain")
        }
        if sensitiveDomainTriggered {
            markers.append("sensitive_domain")
        }

        return markers.joined(separator: "|")
    }
}

extension BASMemoryTier {
    var priority: Int {
        switch self {
        case .hot: return 3
        case .warm: return 2
        case .cold: return 1
        }
    }
}
