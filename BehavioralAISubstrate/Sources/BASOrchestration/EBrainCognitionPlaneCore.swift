import Foundation
import BASMemory
import BASPolicy
import BASRuntimeCore

public enum BASContextTaskType: String, Codable, CaseIterable, Sendable {
    case chat
    case task
    case choice
    case conflict
    case highPressure
    case manipulationRisk
    case highConsequence
}

public struct BASContextFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var utterance: String
    public var taskType: BASContextTaskType
    public var emotionalLoad: Double
    public var timePressure: Double
    public var relationPattern: String
    public var ambiguityScore: Double
    public var consequenceLevel: Double
    public var manipulationHints: [String]
    public var hostRelevance: Double

    public init(
        schemaVersion: String = BASContextFrame.currentSchemaVersion,
        utterance: String,
        taskType: BASContextTaskType,
        emotionalLoad: Double,
        timePressure: Double,
        relationPattern: String,
        ambiguityScore: Double,
        consequenceLevel: Double,
        manipulationHints: [String] = [],
        hostRelevance: Double
    ) {
        self.schemaVersion = schemaVersion
        self.utterance = utterance
        self.taskType = taskType
        self.emotionalLoad = min(max(emotionalLoad, 0), 1)
        self.timePressure = min(max(timePressure, 0), 1)
        self.relationPattern = relationPattern
        self.ambiguityScore = min(max(ambiguityScore, 0), 1)
        self.consequenceLevel = min(max(consequenceLevel, 0), 1)
        self.manipulationHints = manipulationHints
        self.hostRelevance = min(max(hostRelevance, 0), 1)
    }
}

public struct BASDecomposeFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var facts: [String]
    public var goals: [String]
    public var emotions: [String]
    public var unknowns: [String]
    public var contradictions: [String]
    public var pressureSignals: [String]
    public var manipulationSignals: [String]
    public var mirrorText: String

    public init(
        schemaVersion: String = BASDecomposeFrame.currentSchemaVersion,
        facts: [String] = [],
        goals: [String] = [],
        emotions: [String] = [],
        unknowns: [String] = [],
        contradictions: [String] = [],
        pressureSignals: [String] = [],
        manipulationSignals: [String] = [],
        mirrorText: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.facts = facts
        self.goals = goals
        self.emotions = emotions
        self.unknowns = unknowns
        self.contradictions = contradictions
        self.pressureSignals = pressureSignals
        self.manipulationSignals = manipulationSignals
        self.mirrorText = mirrorText
    }
}

public struct BASCandidatePath: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var title: String
    public var actionSummary: String
    public var requiredEvidence: [String]
    public var expectedBenefit: Double
    public var expectedCost: Double
    public var reversibility: Double
    public var confidence: Double

    public init(
        schemaVersion: String = BASCandidatePath.currentSchemaVersion,
        candidateID: String,
        title: String,
        actionSummary: String,
        requiredEvidence: [String] = [],
        expectedBenefit: Double,
        expectedCost: Double,
        reversibility: Double,
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.title = title
        self.actionSummary = actionSummary
        self.requiredEvidence = requiredEvidence
        self.expectedBenefit = expectedBenefit
        self.expectedCost = expectedCost
        self.reversibility = reversibility
        self.confidence = confidence
    }
}

public struct BASForecastItem: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var shortTermOutcome: String
    public var midTermOutcome: String
    public var worstCase: String
    public var uncertainty: Double
    public var affectedRelations: [String]

    public init(
        schemaVersion: String = BASForecastItem.currentSchemaVersion,
        candidateID: String,
        shortTermOutcome: String,
        midTermOutcome: String,
        worstCase: String,
        uncertainty: Double,
        affectedRelations: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.shortTermOutcome = shortTermOutcome
        self.midTermOutcome = midTermOutcome
        self.worstCase = worstCase
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.affectedRelations = affectedRelations
    }
}

public enum BASCritiqueType: String, Codable, CaseIterable, Sendable {
    case evidenceGap
    case manipulationRisk
    case emotionalBias
    case boundaryConflict
}

public struct BASCritiqueItem: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var critiqueType: BASCritiqueType
    public var critiqueText: String
    public var severity: Double

    public init(
        schemaVersion: String = BASCritiqueItem.currentSchemaVersion,
        candidateID: String,
        critiqueType: BASCritiqueType,
        critiqueText: String,
        severity: Double
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.critiqueType = critiqueType
        self.critiqueText = critiqueText
        self.severity = min(max(severity, 0), 1)
    }
}

public struct BASTriSelfScore: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var idScore: Double
    public var egoScore: Double
    public var superegoScore: Double
    public var mergedScore: Double
    public var veto: Bool

    public init(
        schemaVersion: String = BASTriSelfScore.currentSchemaVersion,
        candidateID: String,
        idScore: Double,
        egoScore: Double,
        superegoScore: Double,
        mergedScore: Double,
        veto: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.idScore = idScore
        self.egoScore = egoScore
        self.superegoScore = superegoScore
        self.mergedScore = mergedScore
        self.veto = veto
    }
}

public struct BASMergedChoice: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var title: String
    public var actionSummary: String
    public var vetoApplied: Bool
    public var vetoReasonCodes: [String]

    public init(
        schemaVersion: String = BASMergedChoice.currentSchemaVersion,
        candidateID: String,
        title: String,
        actionSummary: String,
        vetoApplied: Bool = false,
        vetoReasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.title = title
        self.actionSummary = actionSummary
        self.vetoApplied = vetoApplied
        self.vetoReasonCodes = vetoReasonCodes
    }
}

public enum BASThoughtStopReason: String, Codable, CaseIterable, Sendable {
    case candidateStable
    case riskConverged
    case uncertaintyBelowThreshold
    case maxLoopsReached
    case blocked
    case replaced
}

public struct BASThoughtFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var stepIndex: Int
    public var decomposeRef: String
    public var memoryRefs: [String]
    public var candidates: [BASCandidatePath]
    public var forecasts: [BASForecastItem]
    public var critiques: [BASCritiqueItem]
    public var triScores: [BASTriSelfScore]
    public var riskCard: BASRiskCard?
    public var actionPermit: BASActionPermit?
    public var stabilityScore: Double
    public var stopReason: BASThoughtStopReason?

    public init(
        schemaVersion: String = BASThoughtFrame.currentSchemaVersion,
        stepIndex: Int,
        decomposeRef: String,
        memoryRefs: [String] = [],
        candidates: [BASCandidatePath] = [],
        forecasts: [BASForecastItem] = [],
        critiques: [BASCritiqueItem] = [],
        triScores: [BASTriSelfScore] = [],
        riskCard: BASRiskCard? = nil,
        actionPermit: BASActionPermit? = nil,
        stabilityScore: Double = 0,
        stopReason: BASThoughtStopReason? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.stepIndex = stepIndex
        self.decomposeRef = decomposeRef
        self.memoryRefs = memoryRefs
        self.candidates = candidates
        self.forecasts = forecasts
        self.critiques = critiques
        self.triScores = triScores
        self.riskCard = riskCard
        self.actionPermit = actionPermit
        self.stabilityScore = min(max(stabilityScore, 0), 1)
        self.stopReason = stopReason
    }
}

public struct BASThoughtFold: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var foldID: String
    public var compactSlots: [String: String]
    public var candidateSignatures: [String]
    public var riskSnapshot: BASRiskCard?
    public var hostEffectSummary: String
    public var restorePointer: String
    public var checksum: String

    public init(
        schemaVersion: String = BASThoughtFold.currentSchemaVersion,
        foldID: String,
        compactSlots: [String: String] = [:],
        candidateSignatures: [String] = [],
        riskSnapshot: BASRiskCard? = nil,
        hostEffectSummary: String,
        restorePointer: String,
        checksum: String
    ) {
        self.schemaVersion = schemaVersion
        self.foldID = foldID
        self.compactSlots = compactSlots
        self.candidateSignatures = candidateSignatures
        self.riskSnapshot = riskSnapshot
        self.hostEffectSummary = hostEffectSummary
        self.restorePointer = restorePointer
        self.checksum = checksum
    }
}

public struct BASRenderedOutput: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var mode: BASActionPermitMode
    public var headline: String
    public var body: String
    public var alternativeActions: [String]
    public var explanationCodes: [String]

    public init(
        schemaVersion: String = BASRenderedOutput.currentSchemaVersion,
        mode: BASActionPermitMode,
        headline: String,
        body: String,
        alternativeActions: [String] = [],
        explanationCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.headline = headline
        self.body = body
        self.alternativeActions = alternativeActions
        self.explanationCodes = explanationCodes
    }
}
