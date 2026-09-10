import Foundation
import BASRuntimeCore

public enum BASDraftPromotionPolicy: Codable, Equatable, Sendable {
    case immediate
    case repeated(minConfirmationCount: Int, minEvidenceCount: Int)
    case candidateOnly
}

public struct BASDerivedMemoryDraft: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var topic: String
    public var headline: String
    public var value: String
    public var confidence: Double
    public var priority: Double
    public var sourceID: String
    public var lastConfirmedAt: Date
    public var decayPolicyID: String
    public var retrievalTags: [String]
    public var evidenceCount: Int
    public var provenanceSummary: String
    public var promotionPolicy: BASDraftPromotionPolicy
    public var tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        sourceID: String,
        lastConfirmedAt: Date,
        decayPolicyID: String,
        retrievalTags: [String],
        evidenceCount: Int,
        provenanceSummary: String,
        promotionPolicy: BASDraftPromotionPolicy,
        tierID: String = "warm"
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceID = sourceID
        self.lastConfirmedAt = lastConfirmedAt
        self.decayPolicyID = decayPolicyID
        self.retrievalTags = retrievalTags
        self.evidenceCount = evidenceCount
        self.provenanceSummary = provenanceSummary
        self.promotionPolicy = promotionPolicy
        self.tierID = tierID
    }
}

public struct BASCueMemoryInput: Codable, Equatable, Sendable {
    public var content: String
    public var lastUsedAt: Date

    public init(content: String, lastUsedAt: Date) {
        self.content = content
        self.lastUsedAt = lastUsedAt
    }
}

public struct BASCheckEventMemoryInput: Codable, Equatable, Sendable {
    public var id: String
    public var scenarioID: String
    public var scenarioTitle: String
    public var actionID: String
    public var actionTitle: String
    public var note: String
    public var createdAt: Date

    public init(
        id: String,
        scenarioID: String,
        scenarioTitle: String,
        actionID: String,
        actionTitle: String,
        note: String,
        createdAt: Date
    ) {
        self.id = id
        self.scenarioID = scenarioID
        self.scenarioTitle = scenarioTitle
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.note = note
        self.createdAt = createdAt
    }
}

public struct BASComparativeMemoryInput: Codable, Equatable, Sendable {
    public var prompt: String
    public var longTerm: String
    public var updatedAt: Date

    public init(prompt: String, longTerm: String, updatedAt: Date) {
        self.prompt = prompt
        self.longTerm = longTerm
        self.updatedAt = updatedAt
    }

    public init(workspace: BASWorkspaceMemoryInput) {
        self.prompt = workspace.prompt
        self.longTerm = workspace.longTerm
        self.updatedAt = workspace.updatedAt
    }

    public var workspaceInput: BASWorkspaceMemoryInput {
        BASWorkspaceMemoryInput(
            workflowID: BASDecisionMode.comparativeID,
            prompt: prompt,
            longTerm: longTerm,
            updatedAt: updatedAt
        )
    }
}

public struct BASReflectiveMemoryInput: Codable, Equatable, Sendable {
    public var prompt: String
    public var longTerm: String
    public var updatedAt: Date

    public init(prompt: String, longTerm: String, updatedAt: Date) {
        self.prompt = prompt
        self.longTerm = longTerm
        self.updatedAt = updatedAt
    }

    public init(workspace: BASWorkspaceMemoryInput) {
        self.prompt = workspace.prompt
        self.longTerm = workspace.longTerm
        self.updatedAt = workspace.updatedAt
    }

    public var workspaceInput: BASWorkspaceMemoryInput {
        BASWorkspaceMemoryInput(
            workflowID: BASDecisionMode.reflectiveID,
            prompt: prompt,
            longTerm: longTerm,
            updatedAt: updatedAt
        )
    }
}

public struct BASWorkspaceMemoryInput: Codable, Equatable, Sendable {
    public var workflowID: String
    public var prompt: String
    public var longTerm: String
    public var updatedAt: Date

    public init(
        workflowID: String,
        prompt: String,
        longTerm: String,
        updatedAt: Date
    ) {
        self.workflowID = workflowID
        self.prompt = prompt
        self.longTerm = longTerm
        self.updatedAt = updatedAt
    }
}

public struct BASSituationalDraftBehavior: Codable, Equatable, Sendable {
    public var draftID: String
    public var topic: String
    public var primaryHeadlinePrefix: String
    public var fallbackHeadlinePrefix: String?
    public var provenanceSummary: String
    public var baseTags: [String]

    public init(
        draftID: String,
        topic: String,
        primaryHeadlinePrefix: String,
        fallbackHeadlinePrefix: String? = nil,
        provenanceSummary: String,
        baseTags: [String]
    ) {
        self.draftID = draftID
        self.topic = topic
        self.primaryHeadlinePrefix = primaryHeadlinePrefix
        self.fallbackHeadlinePrefix = fallbackHeadlinePrefix
        self.provenanceSummary = provenanceSummary
        self.baseTags = baseTags
    }
}

public struct BASWorkspaceSituationalDraftBehavior: Codable, Equatable, Sendable {
    public var workflowIDs: [String]
    public var draft: BASSituationalDraftBehavior
    public var confidence: Double
    public var priority: Double

    public init(
        workflowIDs: [String],
        draft: BASSituationalDraftBehavior,
        confidence: Double,
        priority: Double
    ) {
        self.workflowIDs = workflowIDs
        self.draft = draft
        self.confidence = confidence
        self.priority = priority
    }
}

public struct BASSupportActionDraftBehavior: Codable, Equatable, Sendable {
    public var headline: String
    public var tags: [String]
    public var provenanceSummary: String?

    public init(
        headline: String,
        tags: [String],
        provenanceSummary: String? = nil
    ) {
        self.headline = headline
        self.tags = tags
        self.provenanceSummary = provenanceSummary
    }
}

public struct BASPatternDraftBehavior: Codable, Equatable, Sendable {
    public var id: String
    public var typeID: String
    public var topic: String
    public var headline: String
    public var value: String
    public var confidence: Double
    public var priority: Double
    public var sourceID: String
    public var decayPolicyID: String
    public var retrievalTags: [String]
    public var provenanceSummary: String
    public var promotionPolicy: BASDraftPromotionPolicy
    public var tierID: String

    public init(
        id: String,
        typeID: String,
        topic: String,
        headline: String,
        value: String,
        confidence: Double,
        priority: Double,
        sourceID: String,
        decayPolicyID: String,
        retrievalTags: [String],
        provenanceSummary: String,
        promotionPolicy: BASDraftPromotionPolicy,
        tierID: String = "warm"
    ) {
        self.id = id
        self.typeID = typeID
        self.topic = topic
        self.headline = headline
        self.value = value
        self.confidence = confidence
        self.priority = priority
        self.sourceID = sourceID
        self.decayPolicyID = decayPolicyID
        self.retrievalTags = retrievalTags
        self.provenanceSummary = provenanceSummary
        self.promotionPolicy = promotionPolicy
        self.tierID = tierID
    }

    public func makeDraft(
        lastConfirmedAt: Date,
        evidenceCount: Int
    ) -> BASDerivedMemoryDraft {
        BASDerivedMemoryDraft(
            id: id,
            typeID: typeID,
            topic: topic,
            headline: headline,
            value: value,
            confidence: confidence,
            priority: priority,
            sourceID: sourceID,
            lastConfirmedAt: lastConfirmedAt,
            decayPolicyID: decayPolicyID,
            retrievalTags: retrievalTags,
            evidenceCount: evidenceCount,
            provenanceSummary: provenanceSummary,
            promotionPolicy: promotionPolicy,
            tierID: tierID
        )
    }
}

public struct BASMemoryDerivationBehavior: Codable, Equatable, Sendable {
    public static let generic = BASMemoryDerivationBehavior(
        situationalBehaviorsByModeID: [:],
        primarySituational: BASSituationalDraftBehavior(
            draftID: "situational.active.recent",
            topic: "recent_context",
            primaryHeadlinePrefix: "Recent active context",
            fallbackHeadlinePrefix: "Recent returning context",
            provenanceSummary: "Candidate memory staged from a recent active context.",
            baseTags: ["active", "recent"]
        ),
        comparativeSituational: BASSituationalDraftBehavior(
            draftID: "situational.compare.recent",
            topic: "recent_comparison_context",
            primaryHeadlinePrefix: "Recent trade-off context",
            provenanceSummary: "Candidate memory staged from a recent trade-off context.",
            baseTags: ["comparison", "recent"]
        ),
        reflectiveSituational: BASSituationalDraftBehavior(
            draftID: "situational.pattern.recent",
            topic: "recent_pattern_context",
            primaryHeadlinePrefix: "Recent pattern context",
            provenanceSummary: "Candidate memory staged from a recent pattern-reading context.",
            baseTags: ["pattern", "recent"]
        ),
        workspaceWorkflowIDsByModeID: [:],
        comparativeWorkspaceIDs: [],
        reflectiveWorkspaceIDs: [],
        workspaceSituationalBehaviors: [],
        supportActionsByID: [:],
        concisePreferencePattern: BASPatternDraftBehavior(
            id: "preference.communication.concise",
            typeID: "preference",
            topic: "communication_style",
            headline: "Short, direct guidance tends to land better.",
            value: "Prefer brief, concrete phrasing over longer explanations.",
            confidence: 0.78,
            priority: 0.92,
            sourceID: BASMemorySource.pattern.rawValue,
            decayPolicyID: "slow",
            retrievalTags: ["style", "communication", "concise", "direct"],
            provenanceSummary: "Derived from repeated short cues and recent structured interaction note length.",
            promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        ),
        lateSessionPattern: BASPatternDraftBehavior(
            id: "semantic.pattern.late_session",
            typeID: "semantic",
            topic: "late_session_regulation",
            headline: "Late sessions usually benefit from lower-load guidance.",
            value: "late_session_support",
            confidence: 0.73,
            priority: 0.77,
            sourceID: BASMemorySource.pattern.rawValue,
            decayPolicyID: "slow",
            retrievalTags: ["night", "late", "fatigue", "support"],
            provenanceSummary: "Derived from repeated late-session structured interaction archive evidence.",
            promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        ),
        fallbackSupportTags: ["action_support", "repeat_support"],
        fallbackSupportProvenanceSummary: "Derived from repeated support actions in the current integration."
    )

    public var situationalBehaviorsByModeID: [String: BASSituationalDraftBehavior]
    public var primarySituational: BASSituationalDraftBehavior
    public var comparativeSituational: BASSituationalDraftBehavior
    public var reflectiveSituational: BASSituationalDraftBehavior
    public var workspaceWorkflowIDsByModeID: [String: [String]]
    public var comparativeWorkspaceIDs: [String]
    public var reflectiveWorkspaceIDs: [String]
    public var workspaceSituationalBehaviors: [BASWorkspaceSituationalDraftBehavior]
    public var supportActionsByID: [String: BASSupportActionDraftBehavior]
    public var concisePreferencePattern: BASPatternDraftBehavior?
    public var lateSessionPattern: BASPatternDraftBehavior?
    public var fallbackSupportTags: [String]
    public var fallbackSupportProvenanceSummary: String

    private enum CodingKeys: String, CodingKey {
        case situationalBehaviorsByModeID
        case primarySituational
        case comparativeSituational
        case reflectiveSituational
        case workspaceWorkflowIDsByModeID
        case comparativeWorkspaceIDs
        case reflectiveWorkspaceIDs
        case workspaceSituationalBehaviors
        case supportActionsByID
        case concisePreferencePattern
        case lateSessionPattern
        case fallbackSupportTags
        case fallbackSupportProvenanceSummary
    }

    @available(*, unavailable, message: "Use .generic or provide explicit memory derivation behavior.")
    public init() {
        fatalError("Unavailable")
    }

    public init(
        situationalBehaviorsByModeID: [String: BASSituationalDraftBehavior] = [:],
        primarySituational: BASSituationalDraftBehavior = BASSituationalDraftBehavior(
            draftID: "situational.active.recent",
            topic: "recent_context",
            primaryHeadlinePrefix: "Recent active context",
            fallbackHeadlinePrefix: "Recent returning context",
            provenanceSummary: "Candidate memory staged from a recent active context.",
            baseTags: ["active", "recent"]
        ),
        comparativeSituational: BASSituationalDraftBehavior = BASSituationalDraftBehavior(
            draftID: "situational.compare.recent",
            topic: "recent_comparison_context",
            primaryHeadlinePrefix: "Recent trade-off context",
            provenanceSummary: "Candidate memory staged from a recent trade-off context.",
            baseTags: ["comparison", "recent"]
        ),
        reflectiveSituational: BASSituationalDraftBehavior = BASSituationalDraftBehavior(
            draftID: "situational.pattern.recent",
            topic: "recent_pattern_context",
            primaryHeadlinePrefix: "Recent pattern context",
            provenanceSummary: "Candidate memory staged from a recent pattern-reading context.",
            baseTags: ["pattern", "recent"]
        ),
        workspaceWorkflowIDsByModeID: [String: [String]] = [:],
        comparativeWorkspaceIDs: [String] = [],
        reflectiveWorkspaceIDs: [String] = [],
        workspaceSituationalBehaviors: [BASWorkspaceSituationalDraftBehavior] = [],
        supportActionsByID: [String: BASSupportActionDraftBehavior] = [:],
        concisePreferencePattern: BASPatternDraftBehavior? = BASPatternDraftBehavior(
            id: "preference.communication.concise",
            typeID: "preference",
            topic: "communication_style",
            headline: "Short, direct guidance tends to land better.",
            value: "Prefer brief, concrete phrasing over longer explanations.",
            confidence: 0.78,
            priority: 0.92,
            sourceID: BASMemorySource.pattern.rawValue,
            decayPolicyID: "slow",
            retrievalTags: ["style", "communication", "concise", "direct"],
            provenanceSummary: "Derived from repeated short cues and recent structured interaction note length.",
            promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        ),
        lateSessionPattern: BASPatternDraftBehavior? = BASPatternDraftBehavior(
            id: "semantic.pattern.late_session",
            typeID: "semantic",
            topic: "late_session_regulation",
            headline: "Late sessions usually benefit from lower-load guidance.",
            value: "late_session_support",
            confidence: 0.73,
            priority: 0.77,
            sourceID: BASMemorySource.pattern.rawValue,
            decayPolicyID: "slow",
            retrievalTags: ["night", "late", "fatigue", "support"],
            provenanceSummary: "Derived from repeated late-session structured interaction archive evidence.",
            promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 3)
        ),
        fallbackSupportTags: [String] = ["action_support", "repeat_support"],
        fallbackSupportProvenanceSummary: String = "Derived from repeated support actions in the current integration."
    ) {
        self.situationalBehaviorsByModeID = situationalBehaviorsByModeID
        self.primarySituational = primarySituational
        self.comparativeSituational = comparativeSituational
        self.reflectiveSituational = reflectiveSituational
        self.workspaceWorkflowIDsByModeID = workspaceWorkflowIDsByModeID
        self.comparativeWorkspaceIDs = comparativeWorkspaceIDs
        self.reflectiveWorkspaceIDs = reflectiveWorkspaceIDs
        self.workspaceSituationalBehaviors = workspaceSituationalBehaviors
        self.supportActionsByID = supportActionsByID
        self.concisePreferencePattern = concisePreferencePattern
        self.lateSessionPattern = lateSessionPattern
        self.fallbackSupportTags = fallbackSupportTags
        self.fallbackSupportProvenanceSummary = fallbackSupportProvenanceSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = BASMemoryDerivationBehavior.generic
        situationalBehaviorsByModeID = try container.decodeIfPresent([String: BASSituationalDraftBehavior].self, forKey: .situationalBehaviorsByModeID)
            ?? fallback.situationalBehaviorsByModeID
        primarySituational = try container.decodeIfPresent(BASSituationalDraftBehavior.self, forKey: .primarySituational)
            ?? fallback.primarySituational
        comparativeSituational = try container.decodeIfPresent(BASSituationalDraftBehavior.self, forKey: .comparativeSituational)
            ?? fallback.comparativeSituational
        reflectiveSituational = try container.decodeIfPresent(BASSituationalDraftBehavior.self, forKey: .reflectiveSituational)
            ?? fallback.reflectiveSituational
        workspaceWorkflowIDsByModeID = try container.decodeIfPresent([String: [String]].self, forKey: .workspaceWorkflowIDsByModeID)
            ?? fallback.workspaceWorkflowIDsByModeID
        comparativeWorkspaceIDs = try container.decodeIfPresent([String].self, forKey: .comparativeWorkspaceIDs)
            ?? fallback.comparativeWorkspaceIDs
        reflectiveWorkspaceIDs = try container.decodeIfPresent([String].self, forKey: .reflectiveWorkspaceIDs)
            ?? fallback.reflectiveWorkspaceIDs
        workspaceSituationalBehaviors = try container.decodeIfPresent([BASWorkspaceSituationalDraftBehavior].self, forKey: .workspaceSituationalBehaviors)
            ?? []
        supportActionsByID = try container.decodeIfPresent([String: BASSupportActionDraftBehavior].self, forKey: .supportActionsByID)
            ?? fallback.supportActionsByID
        concisePreferencePattern = try container.decodeIfPresent(BASPatternDraftBehavior.self, forKey: .concisePreferencePattern)
            ?? fallback.concisePreferencePattern
        lateSessionPattern = try container.decodeIfPresent(BASPatternDraftBehavior.self, forKey: .lateSessionPattern)
            ?? fallback.lateSessionPattern
        fallbackSupportTags = try container.decodeIfPresent([String].self, forKey: .fallbackSupportTags)
            ?? fallback.fallbackSupportTags
        fallbackSupportProvenanceSummary = try container.decodeIfPresent(String.self, forKey: .fallbackSupportProvenanceSummary)
            ?? fallback.fallbackSupportProvenanceSummary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(situationalBehaviorsByModeID, forKey: .situationalBehaviorsByModeID)
        try container.encode(primarySituational, forKey: .primarySituational)
        try container.encode(comparativeSituational, forKey: .comparativeSituational)
        try container.encode(reflectiveSituational, forKey: .reflectiveSituational)
        try container.encode(workspaceWorkflowIDsByModeID, forKey: .workspaceWorkflowIDsByModeID)
        try container.encode(comparativeWorkspaceIDs, forKey: .comparativeWorkspaceIDs)
        try container.encode(reflectiveWorkspaceIDs, forKey: .reflectiveWorkspaceIDs)
        try container.encode(workspaceSituationalBehaviors, forKey: .workspaceSituationalBehaviors)
        try container.encode(supportActionsByID, forKey: .supportActionsByID)
        try container.encodeIfPresent(concisePreferencePattern, forKey: .concisePreferencePattern)
        try container.encodeIfPresent(lateSessionPattern, forKey: .lateSessionPattern)
        try container.encode(fallbackSupportTags, forKey: .fallbackSupportTags)
        try container.encode(fallbackSupportProvenanceSummary, forKey: .fallbackSupportProvenanceSummary)
    }

    public var resolvedWorkspaceSituationalBehaviors: [BASWorkspaceSituationalDraftBehavior] {
        if workspaceSituationalBehaviors.isEmpty == false {
            return workspaceSituationalBehaviors
        }

        if workspaceWorkflowIDsByModeID.isEmpty == false {
            return workspaceWorkflowIDsByModeID
                .keys
                .sorted()
                .compactMap { modeID in
                    guard let draft = resolvedSituationalBehavior(for: modeID) else {
                        return nil
                    }
                    guard let workflowIDs = workspaceWorkflowIDsByModeID[modeID], workflowIDs.isEmpty == false else {
                        return nil
                    }
                    let priority = modeID == BASDecisionMode.reflectiveID ? 0.82 : 0.76
                    let confidence = modeID == BASDecisionMode.reflectiveID ? 0.78 : 0.74
                    return BASWorkspaceSituationalDraftBehavior(
                        workflowIDs: workflowIDs,
                        draft: draft,
                        confidence: confidence,
                        priority: priority
                    )
                }
        }

        var compatibilityBehaviors: [BASWorkspaceSituationalDraftBehavior] = []
        if comparativeWorkspaceIDs.isEmpty == false {
            compatibilityBehaviors.append(
                BASWorkspaceSituationalDraftBehavior(
                    workflowIDs: comparativeWorkspaceIDs,
                    draft: comparativeSituational,
                    confidence: 0.74,
                    priority: 0.76
                )
            )
        }
        if reflectiveWorkspaceIDs.isEmpty == false {
            compatibilityBehaviors.append(
                BASWorkspaceSituationalDraftBehavior(
                    workflowIDs: reflectiveWorkspaceIDs,
                    draft: reflectiveSituational,
                    confidence: 0.78,
                    priority: 0.82
                )
            )
        }
        return compatibilityBehaviors
    }

    public var defaultSituationalBehavior: BASSituationalDraftBehavior {
        resolvedSituationalBehavior(for: BASDecisionMode.primaryID) ?? primarySituational
    }

    public func workspaceIDs(for modeID: String) -> [String] {
        for candidate in modeLookupCandidates(for: modeID) {
            if let workflowIDs = workspaceWorkflowIDsByModeID[candidate], workflowIDs.isEmpty == false {
                return workflowIDs
            }
        }

        guard let mode = BASDecisionMode(identifier: modeID) else {
            return []
        }
        switch mode {
        case .primary:
            return []
        case .comparative:
            return comparativeWorkspaceIDs
        case .reflective:
            return reflectiveWorkspaceIDs
        }
    }

    public func resolvedSituationalBehavior(for modeID: String) -> BASSituationalDraftBehavior? {
        for candidate in modeLookupCandidates(for: modeID) {
            if let behavior = situationalBehaviorsByModeID[candidate] {
                return behavior
            }
        }

        guard let mode = BASDecisionMode(identifier: modeID) else {
            return nil
        }
        switch mode {
        case .primary:
            return primarySituational
        case .comparative:
            return comparativeSituational
        case .reflective:
            return reflectiveSituational
        }
    }

    private func modeLookupCandidates(for modeID: String) -> [String] {
        guard let mode = BASDecisionMode(identifier: modeID) else {
            return [modeID]
        }
        return Array(Set([modeID, mode.identifier])).sorted()
    }
}

public struct BASMemoryDerivationRequest: Codable, Equatable, Sendable {
    public var cues: [BASCueMemoryInput]
    public var checkEvents: [BASCheckEventMemoryInput]
    public var workspaceRecords: [BASWorkspaceMemoryInput]
    public var comparativeRecords: [BASComparativeMemoryInput]
    public var reflectiveRecords: [BASReflectiveMemoryInput]
    public var now: Date
    public var behavior: BASMemoryDerivationBehavior

    private enum CodingKeys: String, CodingKey {
        case cues
        case checkEvents
        case workspaceRecords
        case comparativeRecords
        case reflectiveRecords
        case now
        case behavior
    }

    public init(
        cues: [BASCueMemoryInput],
        checkEvents: [BASCheckEventMemoryInput],
        workspaceRecords: [BASWorkspaceMemoryInput],
        now: Date,
        behavior: BASMemoryDerivationBehavior = .generic
    ) {
        self.cues = cues
        self.checkEvents = checkEvents
        self.workspaceRecords = workspaceRecords
        let comparativeWorkflowIDs = Set(behavior.workspaceIDs(for: BASDecisionMode.comparativeID))
        let reflectiveWorkflowIDs = Set(behavior.workspaceIDs(for: BASDecisionMode.reflectiveID))
        self.comparativeRecords = workspaceRecords
            .filter { comparativeWorkflowIDs.contains($0.workflowID) }
            .map(BASComparativeMemoryInput.init(workspace:))
        self.reflectiveRecords = workspaceRecords
            .filter { reflectiveWorkflowIDs.contains($0.workflowID) }
            .map(BASReflectiveMemoryInput.init(workspace:))
        self.now = now
        self.behavior = behavior
    }

    public init(
        cues: [BASCueMemoryInput],
        checkEvents: [BASCheckEventMemoryInput],
        comparativeRecords: [BASComparativeMemoryInput],
        reflectiveRecords: [BASReflectiveMemoryInput],
        now: Date,
        behavior: BASMemoryDerivationBehavior = .generic
    ) {
        self.cues = cues
        self.checkEvents = checkEvents
        self.workspaceRecords = (
            comparativeRecords.map(\.workspaceInput) +
            reflectiveRecords.map(\.workspaceInput)
        )
        self.comparativeRecords = comparativeRecords
        self.reflectiveRecords = reflectiveRecords
        self.now = now
        self.behavior = behavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cues = try container.decode([BASCueMemoryInput].self, forKey: .cues)
        checkEvents = try container.decode([BASCheckEventMemoryInput].self, forKey: .checkEvents)
        let decodedComparative = try container.decodeIfPresent([BASComparativeMemoryInput].self, forKey: .comparativeRecords) ?? []
        let decodedReflective = try container.decodeIfPresent([BASReflectiveMemoryInput].self, forKey: .reflectiveRecords) ?? []
        comparativeRecords = decodedComparative
        reflectiveRecords = decodedReflective
        workspaceRecords = try container.decodeIfPresent([BASWorkspaceMemoryInput].self, forKey: .workspaceRecords) ??
            (decodedComparative.map(\.workspaceInput) + decodedReflective.map(\.workspaceInput))
        now = try container.decode(Date.self, forKey: .now)
        behavior = try container.decodeIfPresent(BASMemoryDerivationBehavior.self, forKey: .behavior) ?? .generic
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cues, forKey: .cues)
        try container.encode(checkEvents, forKey: .checkEvents)
        try container.encode(workspaceRecords, forKey: .workspaceRecords)
        try container.encode(comparativeRecords, forKey: .comparativeRecords)
        try container.encode(reflectiveRecords, forKey: .reflectiveRecords)
        try container.encode(now, forKey: .now)
        try container.encode(behavior, forKey: .behavior)
    }
}

public enum BASMemoryDraftCompiler {
    public static func derive(_ request: BASMemoryDerivationRequest) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        drafts += preferenceDrafts(
            cues: request.cues,
            checkEvents: request.checkEvents,
            now: request.now,
            behavior: request.behavior
        )
        drafts += goalDrafts(
            workspaceRecords: request.workspaceRecords
        )
        drafts += situationalDrafts(
            checkEvents: request.checkEvents,
            workspaceRecords: request.workspaceRecords,
            behavior: request.behavior
        )
        drafts += semanticDrafts(
            checkEvents: request.checkEvents,
            now: request.now,
            behavior: request.behavior
        )
        drafts += supportDrafts(
            checkEvents: request.checkEvents,
            behavior: request.behavior
        )

        var unique: [String: BASDerivedMemoryDraft] = [:]
        for draft in drafts {
            if let existing = unique[draft.id], memorySort(existing, draft) {
                continue
            }
            unique[draft.id] = draft
        }

        return Array(unique.values)
    }

    private static func preferenceDrafts(
        cues: [BASCueMemoryInput],
        checkEvents: [BASCheckEventMemoryInput],
        now: Date,
        behavior: BASMemoryDerivationBehavior
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        let cueLengths = cues.map { $0.content.count }
        let noteLengths = checkEvents
            .map(\.note)
            .map { normalized($0) }
            .filter { !$0.isEmpty }
            .map(\.count)
        let allLengths = cueLengths + noteLengths

        if allLengths.count >= 3 {
            let averageLength = Double(allLengths.reduce(0, +)) / Double(allLengths.count)
            if averageLength <= 96, let pattern = behavior.concisePreferencePattern {
                drafts.append(
                    pattern.makeDraft(
                        lastConfirmedAt: maxDate(
                            cues.map(\.lastUsedAt) + checkEvents.map(\.createdAt),
                            fallback: now
                        ),
                        evidenceCount: allLengths.count
                    )
                )
            }
        }

        return drafts
    }

    private static func goalDrafts(
        workspaceRecords: [BASWorkspaceMemoryInput]
    ) -> [BASDerivedMemoryDraft] {
        let workspaceGoals = workspaceRecords.compactMap { record -> (String, Date)? in
            let value = normalized(record.longTerm)
            return value.isEmpty ? nil : (value, record.updatedAt)
        }

        let grouped = Dictionary(grouping: workspaceGoals, by: \.0)
        return grouped
            .sorted { lhs, rhs in
                let lhsDate = lhs.value.map(\.1).max() ?? .distantPast
                let rhsDate = rhs.value.map(\.1).max() ?? .distantPast
                return lhsDate > rhsDate
            }
            .prefix(3)
            .enumerated()
            .map { index, pair in
                let goal = pair.key
                let items = pair.value
                let lastConfirmedAt = items.map(\.1).max() ?? .now

                return BASDerivedMemoryDraft(
                    id: "goal.\(slug(goal))",
                    typeID: "goal",
                    topic: "active_goal_\(index + 1)",
                    headline: clipped(goal, limit: 120),
                    value: goal,
                    confidence: 0.82,
                    priority: max(0.65, 0.95 - (Double(index) * 0.08)),
                    sourceID: BASMemorySource.archive.rawValue,
                    lastConfirmedAt: lastConfirmedAt,
                    decayPolicyID: "medium",
                    retrievalTags: tags(from: goal) + ["goal", "long_term"],
                    evidenceCount: items.count,
                    provenanceSummary: "Promoted from repeated long-term fields across structured workspaces.",
                    promotionPolicy: .immediate
                )
            }
    }

    private static func situationalDrafts(
        checkEvents: [BASCheckEventMemoryInput],
        workspaceRecords: [BASWorkspaceMemoryInput],
        behavior: BASMemoryDerivationBehavior
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        let defaultSituational = behavior.defaultSituationalBehavior

        if let event = checkEvents.first {
            let note = normalized(event.note)
            let headline: String
            if note.isEmpty, let fallbackPrefix = defaultSituational.fallbackHeadlinePrefix {
                headline = "\(fallbackPrefix) \(event.scenarioTitle.lowercased()) pressure."
            } else {
                headline = "\(defaultSituational.primaryHeadlinePrefix): \(clipped(note.isEmpty ? event.scenarioTitle : note, limit: 96))"
            }

            drafts.append(
                BASDerivedMemoryDraft(
                    id: defaultSituational.draftID,
                    typeID: "situational",
                    topic: defaultSituational.topic,
                    headline: headline,
                    value: note.isEmpty ? event.scenarioTitle : note,
                    confidence: 0.7,
                    priority: 0.72,
                    sourceID: BASMemorySource.archive.rawValue,
                    lastConfirmedAt: event.createdAt,
                    decayPolicyID: "fast",
                    retrievalTags: [event.scenarioID] + defaultSituational.baseTags + tags(from: note),
                    evidenceCount: 1,
                    provenanceSummary: defaultSituational.provenanceSummary,
                    promotionPolicy: .candidateOnly
                )
            )
        }

        for workspaceBehavior in behavior.resolvedWorkspaceSituationalBehaviors {
            guard let record = firstWorkspace(
                in: workspaceRecords,
                matching: workspaceBehavior.workflowIDs
            ) else {
                continue
            }
            let prompt = normalized(record.prompt)
            guard !prompt.isEmpty else { continue }

            drafts.append(
                BASDerivedMemoryDraft(
                    id: workspaceBehavior.draft.draftID,
                    typeID: "situational",
                    topic: workspaceBehavior.draft.topic,
                    headline: "\(workspaceBehavior.draft.primaryHeadlinePrefix): \(clipped(prompt, limit: 96))",
                    value: prompt,
                    confidence: workspaceBehavior.confidence,
                    priority: workspaceBehavior.priority,
                    sourceID: BASMemorySource.archive.rawValue,
                    lastConfirmedAt: record.updatedAt,
                    decayPolicyID: "fast",
                    retrievalTags: workspaceBehavior.draft.baseTags + tags(from: prompt),
                    evidenceCount: 1,
                    provenanceSummary: workspaceBehavior.draft.provenanceSummary,
                    promotionPolicy: .candidateOnly
                )
            )
        }

        return drafts
    }

    private static func semanticDrafts(
        checkEvents: [BASCheckEventMemoryInput],
        now: Date,
        behavior: BASMemoryDerivationBehavior
    ) -> [BASDerivedMemoryDraft] {
        var drafts: [BASDerivedMemoryDraft] = []
        let scenarioGroups = Dictionary(grouping: checkEvents, by: \.scenarioID)

        if let dominantScenario = scenarioGroups
            .filter({ $0.value.count >= 2 })
            .max(by: { $0.value.count < $1.value.count }),
           let firstEvent = dominantScenario.value.first {
            drafts.append(
                BASDerivedMemoryDraft(
                    id: "semantic.scenario.\(dominantScenario.key)",
                    typeID: "semantic",
                    topic: "repeat_scenario",
                    headline: "\(firstEvent.scenarioTitle) pressure keeps recurring.",
                    value: firstEvent.scenarioTitle,
                    confidence: 0.75,
                    priority: 0.8,
                    sourceID: "pattern",
                    lastConfirmedAt: dominantScenario.value.map(\.createdAt).max() ?? now,
                    decayPolicyID: "slow",
                    retrievalTags: [dominantScenario.key, "pattern", "repeat"],
                    evidenceCount: dominantScenario.value.count,
                    provenanceSummary: "Derived from repeated structured events in the same scenario.",
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                )
            )
        }

        let lateNightEvents = checkEvents.filter { event in
            let hour = Calendar.current.component(.hour, from: event.createdAt)
            return hour >= 21 || hour < 6
        }
        if lateNightEvents.count >= 3,
           lateNightEvents.count * 2 >= checkEvents.count,
           let pattern = behavior.lateSessionPattern {
            drafts.append(
                pattern.makeDraft(
                    lastConfirmedAt: lateNightEvents.map(\.createdAt).max() ?? now,
                    evidenceCount: lateNightEvents.count
                )
            )
        }

        return drafts
    }

    private static func supportDrafts(
        checkEvents: [BASCheckEventMemoryInput],
        behavior: BASMemoryDerivationBehavior
    ) -> [BASDerivedMemoryDraft] {
        let actionGroups = Dictionary(grouping: checkEvents, by: \.actionID)

        return actionGroups
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(2)
            .compactMap { actionID, events in
                guard let first = events.first else { return nil }
                let configured = behavior.supportActionsByID[actionID]
                let headline = configured?.headline ?? "\(first.actionTitle) has repeatedly helped stabilize this situation."
                let tags = configured?.tags ?? (behavior.fallbackSupportTags + [actionID])
                let provenanceSummary = configured?.provenanceSummary ?? behavior.fallbackSupportProvenanceSummary

                return BASDerivedMemoryDraft(
                    id: "support.action.\(actionID)",
                    typeID: "support",
                    topic: "action_support",
                    headline: headline,
                    value: first.actionTitle,
                    confidence: 0.72,
                    priority: 0.79,
                    sourceID: BASMemorySource.archive.rawValue,
                    lastConfirmedAt: events.map(\.createdAt).max() ?? .now,
                    decayPolicyID: "medium",
                    retrievalTags: tags + [actionID],
                    evidenceCount: events.count,
                    provenanceSummary: provenanceSummary,
                    promotionPolicy: .repeated(minConfirmationCount: 2, minEvidenceCount: 2)
                )
            }
    }

    private static func firstWorkspace(
        in records: [BASWorkspaceMemoryInput],
        matching workflowIDs: [String]
    ) -> BASWorkspaceMemoryInput? {
        records
            .filter { workflowIDs.contains($0.workflowID) }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.workflowID < rhs.workflowID
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    private static func memorySort(_ lhs: BASDerivedMemoryDraft, _ rhs: BASDerivedMemoryDraft) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.lastConfirmedAt > rhs.lastConfirmedAt
        }
        return lhs.priority > rhs.priority
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func clipped(_ value: String, limit: Int) -> String {
        let normalizedValue = normalized(value)
        guard normalizedValue.count > limit else { return normalizedValue }
        return String(normalizedValue.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let lowered = normalized(value).lowercased()
        let scalarView = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(scalarView)
            .split(separator: "-")
            .prefix(8)
            .joined(separator: "-")
        return slug.isEmpty ? "memory" : slug
    }

    private static func tags(from text: String) -> [String] {
        let stopwords: Set<String> = [
            "the", "and", "for", "that", "with", "this", "from", "into",
            "have", "just", "been", "than", "then", "they", "them",
            "want", "need", "feel", "will", "your", "about", "after",
            "before", "would", "should", "could", "again", "really",
            "maybe", "because", "when", "what", "where", "while", "into"
        ]

        let languageMode = BASLanguageMode.detect(sampleTexts: [text])
        let latinTokens = normalized(text)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopwords.contains($0) }

        let tags = languageMode.retrievalTags +
            Array(latinTokens.prefix(6)) +
            hanTokens(from: text)

        return orderedUnique(Array(tags.prefix(10)))
    }

    private static func hanTokens(from text: String) -> [String] {
        let characters = Array(
            normalized(text)
                .filter { character in
                    character.unicodeScalars.contains(where: { $0.properties.isIdeographic })
                }
        )

        guard !characters.isEmpty else { return [] }

        var tokens: [String] = []
        let joined = String(characters)
        if joined.count <= 8 {
            tokens.append(joined)
        }

        if characters.count >= 2 {
            for index in 0..<(characters.count - 1) {
                tokens.append(String(characters[index...index + 1]))
            }
        }

        if characters.count >= 3 {
            for index in 0..<(characters.count - 2) {
                tokens.append(String(characters[index...index + 2]))
            }
        }

        return Array(orderedUnique(tokens).prefix(6))
    }

    private static func maxDate(_ values: [Date], fallback: Date) -> Date {
        values.max() ?? fallback
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
