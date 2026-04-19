import Foundation

public enum BASMemoryVolatileClaimWriteMode: String, Codable, Sendable {
    case admitDirectly
    case stageCandidate
}

public enum BASMemoryContaminatedWriteMode: String, Codable, Sendable {
    case reject
    case quarantineCandidate
}

public enum BASMemoryHorizonClaimStability: String, Codable, Sendable {
    case invariant
    case semiStable
    case volatile
}

public enum BASMemoryHorizonClaimContaminationState: String, Codable, Sendable {
    case isolated
    case quarantined
}

public enum BASMemoryHorizonClaimEvidenceState: String, Codable, Sendable {
    case durable
    case caveated
}

public struct BASMemoryHorizonClaimDescriptor: Codable, Equatable, Sendable {
    public var stabilityTierID: String
    public var stability: BASMemoryHorizonClaimStability
    public var requiresExternalRefresh: Bool
    public var contaminationState: BASMemoryHorizonClaimContaminationState
    public var evidenceState: BASMemoryHorizonClaimEvidenceState
    public var minimumDurableEvidenceCount: Int
    public var releaseRequirements: [String]

    public init(
        stabilityTierID: String,
        stability: BASMemoryHorizonClaimStability,
        requiresExternalRefresh: Bool,
        contaminationState: BASMemoryHorizonClaimContaminationState,
        evidenceState: BASMemoryHorizonClaimEvidenceState,
        minimumDurableEvidenceCount: Int,
        releaseRequirements: [String]
    ) {
        self.stabilityTierID = stabilityTierID
        self.stability = stability
        self.requiresExternalRefresh = requiresExternalRefresh
        self.contaminationState = contaminationState
        self.evidenceState = evidenceState
        self.minimumDurableEvidenceCount = minimumDurableEvidenceCount
        self.releaseRequirements = releaseRequirements
    }
}

public struct BASMemoryHorizonPersistencePolicy: Codable, Equatable, Sendable {
    public static let unrestricted = BASMemoryHorizonPersistencePolicy()

    public var volatileClaimWriteMode: BASMemoryVolatileClaimWriteMode
    public var contaminatedWriteMode: BASMemoryContaminatedWriteMode
    public var minimumDurableEvidenceCount: Int
    public var volatileClaimSignals: [String]
    public var volatileClaimRetrievalTags: [String]
    public var quarantineRetrievalTags: [String]
    public var evidencePendingRetrievalTags: [String]
    public var volatileTierID: String
    public var forceStageNonContinuityDrafts: Bool

    private enum CodingKeys: String, CodingKey {
        case volatileClaimWriteMode
        case contaminatedWriteMode
        case minimumDurableEvidenceCount
        case volatileClaimSignals
        case volatileClaimRetrievalTags
        case quarantineRetrievalTags
        case evidencePendingRetrievalTags
        case volatileTierID
        case forceStageNonContinuityDrafts
    }

    public init(
        volatileClaimWriteMode: BASMemoryVolatileClaimWriteMode = .admitDirectly,
        contaminatedWriteMode: BASMemoryContaminatedWriteMode = .reject,
        minimumDurableEvidenceCount: Int = 0,
        volatileClaimSignals: [String] = [
            "latest",
            "current",
            "today",
            "tonight",
            "market",
            "price",
            "pricing",
            "policy",
            "version",
            "release",
            "news",
            "quote",
            "rate",
            "ticker",
            "breaking"
        ],
        volatileClaimRetrievalTags: [String] = [
            "external_refresh",
            "volatile"
        ],
        quarantineRetrievalTags: [String] = [
            "quarantined",
            "tool_observation"
        ],
        evidencePendingRetrievalTags: [String] = [
            "evidence_caveat"
        ],
        volatileTierID: String = "volatile",
        forceStageNonContinuityDrafts: Bool = false
    ) {
        self.volatileClaimWriteMode = volatileClaimWriteMode
        self.contaminatedWriteMode = contaminatedWriteMode
        self.minimumDurableEvidenceCount = minimumDurableEvidenceCount
        self.volatileClaimSignals = volatileClaimSignals
        self.volatileClaimRetrievalTags = volatileClaimRetrievalTags
        self.quarantineRetrievalTags = quarantineRetrievalTags
        self.evidencePendingRetrievalTags = evidencePendingRetrievalTags
        self.volatileTierID = volatileTierID
        self.forceStageNonContinuityDrafts = forceStageNonContinuityDrafts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
            volatileClaimWriteMode: try container.decodeIfPresent(
                BASMemoryVolatileClaimWriteMode.self,
                forKey: .volatileClaimWriteMode
            ) ?? .admitDirectly,
            contaminatedWriteMode: try container.decodeIfPresent(
                BASMemoryContaminatedWriteMode.self,
                forKey: .contaminatedWriteMode
            ) ?? .reject,
            minimumDurableEvidenceCount: try container.decodeIfPresent(
                Int.self,
                forKey: .minimumDurableEvidenceCount
            ) ?? 0,
            volatileClaimSignals: try container.decodeIfPresent(
                [String].self,
                forKey: .volatileClaimSignals
            ) ?? BASMemoryHorizonPersistencePolicy.unrestricted.volatileClaimSignals,
            volatileClaimRetrievalTags: try container.decodeIfPresent(
                [String].self,
                forKey: .volatileClaimRetrievalTags
            ) ?? BASMemoryHorizonPersistencePolicy.unrestricted.volatileClaimRetrievalTags,
            quarantineRetrievalTags: try container.decodeIfPresent(
                [String].self,
                forKey: .quarantineRetrievalTags
            ) ?? BASMemoryHorizonPersistencePolicy.unrestricted.quarantineRetrievalTags,
            evidencePendingRetrievalTags: try container.decodeIfPresent(
                [String].self,
                forKey: .evidencePendingRetrievalTags
            ) ?? BASMemoryHorizonPersistencePolicy.unrestricted.evidencePendingRetrievalTags,
            volatileTierID: try container.decodeIfPresent(
                String.self,
                forKey: .volatileTierID
            ) ?? "volatile",
            forceStageNonContinuityDrafts: try container.decodeIfPresent(
                Bool.self,
                forKey: .forceStageNonContinuityDrafts
            ) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(volatileClaimWriteMode, forKey: .volatileClaimWriteMode)
        try container.encode(contaminatedWriteMode, forKey: .contaminatedWriteMode)
        try container.encode(minimumDurableEvidenceCount, forKey: .minimumDurableEvidenceCount)
        try container.encode(volatileClaimSignals, forKey: .volatileClaimSignals)
        try container.encode(volatileClaimRetrievalTags, forKey: .volatileClaimRetrievalTags)
        try container.encode(quarantineRetrievalTags, forKey: .quarantineRetrievalTags)
        try container.encode(evidencePendingRetrievalTags, forKey: .evidencePendingRetrievalTags)
        try container.encode(volatileTierID, forKey: .volatileTierID)
        try container.encode(forceStageNonContinuityDrafts, forKey: .forceStageNonContinuityDrafts)
    }
}

extension BASMemoryHorizonPersistencePolicy {
    var stagesVolatileClaims: Bool {
        volatileClaimWriteMode == .stageCandidate
    }

    var quarantinesContaminatedProvenance: Bool {
        contaminatedWriteMode == .quarantineCandidate
    }

    func marksVolatileClaim(
        _ draft: BASMemoryGovernanceDraftInput
    ) -> Bool {
        guard stagesVolatileClaims else {
            return false
        }

        if hasRetrievalTag(
            in: draft.retrievalTags,
            matching: volatileClaimRetrievalTags
        ) {
            return true
        }

        if draft.tierID.compare(volatileTierID, options: .caseInsensitive) == .orderedSame {
            return true
        }

        let normalizedBody = [
            draft.topic,
            draft.headline,
            draft.value,
            draft.provenanceSummary,
            draft.retrievalTags.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        return volatileClaimSignals.contains { signal in
            normalizedBody.contains(signal.lowercased())
        }
    }

    func marksQuarantinedObservation(
        _ draft: BASMemoryGovernanceDraftInput
    ) -> Bool {
        guard quarantinesContaminatedProvenance else {
            return false
        }

        return hasRetrievalTag(
            in: draft.retrievalTags,
            matching: quarantineRetrievalTags
        )
    }

    public func classify(
        _ draft: BASMemoryGovernanceDraftInput,
        continuityProtected: Bool,
        provenanceRisk: Bool
    ) -> BASMemoryHorizonClaimDescriptor {
        let requiresExternalRefresh =
            marksVolatileClaim(draft) ||
            (
                stagesVolatileClaims &&
                forceStageNonContinuityDrafts &&
                !continuityProtected
            )
        let contaminationState: BASMemoryHorizonClaimContaminationState =
            quarantinesContaminatedProvenance &&
            (provenanceRisk || marksQuarantinedObservation(draft))
            ? .quarantined
            : .isolated
        let evidenceState: BASMemoryHorizonClaimEvidenceState =
            minimumDurableEvidenceCount > 0 &&
            !continuityProtected &&
            !draft.promotionPolicy.isCandidateOnly &&
            draft.evidenceCount < minimumDurableEvidenceCount
            ? .caveated
            : .durable

        let stabilityTierID: String
        let stability: BASMemoryHorizonClaimStability
        if requiresExternalRefresh || contaminationState == .quarantined {
            stabilityTierID = volatileTierID
            stability = .volatile
        } else {
            let normalizedTierID = draft.tierID.trimmingCharacters(in: .whitespacesAndNewlines)
            stabilityTierID = normalizedTierID.isEmpty ? "warm" : normalizedTierID
            switch stabilityTierID.lowercased() {
            case "invariant":
                stability = .invariant
            case "volatile":
                stability = .volatile
            default:
                stability = evidenceState == .caveated ? .semiStable : .semiStable
            }
        }

        var releaseRequirements: [String] = []
        if requiresExternalRefresh {
            releaseRequirements.append("external refresh completes")
        }
        if contaminationState == .quarantined {
            releaseRequirements.append("the quarantined observation receives non-tool evidence")
        }
        if evidenceState == .caveated {
            releaseRequirements.append(
                "at least \(minimumDurableEvidenceCount) corroborating evidence signals are available"
            )
        }

        return BASMemoryHorizonClaimDescriptor(
            stabilityTierID: stabilityTierID,
            stability: stability,
            requiresExternalRefresh: requiresExternalRefresh,
            contaminationState: contaminationState,
            evidenceState: evidenceState,
            minimumDurableEvidenceCount: evidenceState == .caveated ? minimumDurableEvidenceCount : 0,
            releaseRequirements: releaseRequirements
        )
    }

    public func classify(
        retrievalTags: [String],
        evidenceCount: Int
    ) -> BASMemoryHorizonClaimDescriptor {
        let normalizedTags = Set(retrievalTags.map { $0.lowercased() })
        let requiresExternalRefresh =
            normalizedTags.contains("external_refresh") ||
            normalizedTags.contains("volatile")
        let contaminationState: BASMemoryHorizonClaimContaminationState =
            normalizedTags.contains("quarantined") || normalizedTags.contains("tool_observation")
            ? .quarantined
            : .isolated
        let evidenceState: BASMemoryHorizonClaimEvidenceState =
            normalizedTags.contains("evidence_caveat")
            ? .caveated
            : .durable
        let stability: BASMemoryHorizonClaimStability =
            requiresExternalRefresh || contaminationState == .quarantined
            ? .volatile
            : .semiStable
        var releaseRequirements: [String] = []
        if requiresExternalRefresh {
            releaseRequirements.append("external refresh completes")
        }
        if contaminationState == .quarantined {
            releaseRequirements.append("the quarantined observation receives non-tool evidence")
        }
        if evidenceState == .caveated {
            let threshold = max(minimumDurableEvidenceCount, evidenceCount + 1)
            releaseRequirements.append(
                "at least \(threshold) corroborating evidence signals are available"
            )
        }

        return BASMemoryHorizonClaimDescriptor(
            stabilityTierID: stability == .volatile ? volatileTierID : "warm",
            stability: stability,
            requiresExternalRefresh: requiresExternalRefresh,
            contaminationState: contaminationState,
            evidenceState: evidenceState,
            minimumDurableEvidenceCount: evidenceState == .caveated
                ? max(minimumDurableEvidenceCount, evidenceCount + 1)
                : 0,
            releaseRequirements: releaseRequirements
        )
    }

    private func hasRetrievalTag(
        in draftTags: [String],
        matching policyTags: [String]
    ) -> Bool {
        let normalizedDraftTags = Set(draftTags.map { $0.lowercased() })
        return policyTags.contains { tag in
            normalizedDraftTags.contains(tag.lowercased())
        }
    }
}
