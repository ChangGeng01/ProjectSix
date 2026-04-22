import Foundation
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public enum BASContextTaskType: String, Codable, CaseIterable, Sendable {
    case chat
    case task
    case choice
    case conflict
    case highPressure
    case manipulationRisk
    case highConsequence
}

public enum BASContextSceneType: String, Codable, CaseIterable, Sendable, BASSchemaVersioned {
    case chat
    case task
    case choice
    case conflict
    case highPressureConflict
    case manipulationRisk
    case highConsequenceDecision

    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String { Self.currentSchemaVersion }

    public static func defaultValue(for taskType: BASContextTaskType) -> BASContextSceneType {
        switch taskType {
        case .chat:
            .chat
        case .task:
            .task
        case .choice:
            .choice
        case .conflict:
            .conflict
        case .highPressure:
            .highPressureConflict
        case .manipulationRisk:
            .manipulationRisk
        case .highConsequence:
            .highConsequenceDecision
        }
    }
}

public struct BASRoleGeometry: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var actors: [String]
    public var roleTypes: [String]
    public var relationClass: String
    public var asymmetryFlags: [String]
    public var intimacyDistance: Double

    public init(
        schemaVersion: String = BASRoleGeometry.currentSchemaVersion,
        actors: [String] = [],
        roleTypes: [String] = [],
        relationClass: String,
        asymmetryFlags: [String] = [],
        intimacyDistance: Double = 0.5
    ) {
        self.schemaVersion = schemaVersion
        self.actors = actors
        self.roleTypes = roleTypes
        self.relationClass = relationClass.trimmingCharacters(in: .whitespacesAndNewlines)
        self.asymmetryFlags = asymmetryFlags
        self.intimacyDistance = min(max(intimacyDistance, 0), 1)
    }
}

public struct BASPowerGradient: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var direction: String
    public var strength: Double
    public var sources: [String]
    public var confidence: Double

    public init(
        schemaVersion: String = BASPowerGradient.currentSchemaVersion,
        direction: String,
        strength: Double,
        sources: [String] = [],
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.direction = direction.trimmingCharacters(in: .whitespacesAndNewlines)
        self.strength = min(max(strength, 0), 1)
        self.sources = sources
        self.confidence = min(max(confidence, 0), 1)
    }
}

public struct BASEmotionalWeather: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var dominantTones: [String]
    public var intensity: Double
    public var volatility: Double
    public var pressureCoupling: Double
    public var judgmentDistortionRisk: Double

    public init(
        schemaVersion: String = BASEmotionalWeather.currentSchemaVersion,
        dominantTones: [String] = [],
        intensity: Double,
        volatility: Double,
        pressureCoupling: Double,
        judgmentDistortionRisk: Double
    ) {
        self.schemaVersion = schemaVersion
        self.dominantTones = dominantTones
        self.intensity = min(max(intensity, 0), 1)
        self.volatility = min(max(volatility, 0), 1)
        self.pressureCoupling = min(max(pressureCoupling, 0), 1)
        self.judgmentDistortionRisk = min(max(judgmentDistortionRisk, 0), 1)
    }
}

public struct BASUrgencyTruth: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var statedUrgency: Double
    public var inferredUrgency: Double
    public var authenticityScore: Double
    public var canDelay: Bool
    public var windowDecay: Double

    public init(
        schemaVersion: String = BASUrgencyTruth.currentSchemaVersion,
        statedUrgency: Double,
        inferredUrgency: Double,
        authenticityScore: Double,
        canDelay: Bool,
        windowDecay: Double
    ) {
        self.schemaVersion = schemaVersion
        self.statedUrgency = min(max(statedUrgency, 0), 1)
        self.inferredUrgency = min(max(inferredUrgency, 0), 1)
        self.authenticityScore = min(max(authenticityScore, 0), 1)
        self.canDelay = canDelay
        self.windowDecay = min(max(windowDecay, 0), 1)
    }
}

public struct BASConsequenceHorizon: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var impactScope: String
    public var reversibility: Double
    public var publicPrivateDomain: String
    public var shortTermRisk: Double
    public var longTermTrace: Double

    public init(
        schemaVersion: String = BASConsequenceHorizon.currentSchemaVersion,
        impactScope: String,
        reversibility: Double,
        publicPrivateDomain: String,
        shortTermRisk: Double,
        longTermTrace: Double
    ) {
        self.schemaVersion = schemaVersion
        self.impactScope = impactScope.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reversibility = min(max(reversibility, 0), 1)
        self.publicPrivateDomain = publicPrivateDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        self.shortTermRisk = min(max(shortTermRisk, 0), 1)
        self.longTermTrace = min(max(longTermTrace, 0), 1)
    }
}

public struct BASManipulationTrace: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var traceID: String?
    public var signals: [String]
    public var gaslightPrecursor: Bool
    public var shamePressure: Double
    public var authorityMask: Bool
    public var timeCoercion: Double
    public var relationalLeverage: [String]
    public var confidence: Double

    public init(
        schemaVersion: String = BASManipulationTrace.currentSchemaVersion,
        traceID: String? = nil,
        signals: [String] = [],
        gaslightPrecursor: Bool = false,
        shamePressure: Double = 0,
        authorityMask: Bool = false,
        timeCoercion: Double = 0,
        relationalLeverage: [String] = [],
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.traceID = traceID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.signals = signals
        self.gaslightPrecursor = gaslightPrecursor
        self.shamePressure = min(max(shamePressure, 0), 1)
        self.authorityMask = authorityMask
        self.timeCoercion = min(max(timeCoercion, 0), 1)
        self.relationalLeverage = relationalLeverage
        self.confidence = min(max(confidence, 0), 1)
    }
}

public struct BASHostResonance: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var relatedGoals: [String]
    public var touchedBoundaries: [String]
    public var highConsequenceRelationRefs: [String]
    public var rhythmStateRef: String?
    public var vulnerabilityGuardFlags: [String]
    public var intensity: Double

    public init(
        schemaVersion: String = BASHostResonance.currentSchemaVersion,
        relatedGoals: [String] = [],
        touchedBoundaries: [String] = [],
        highConsequenceRelationRefs: [String] = [],
        rhythmStateRef: String? = nil,
        vulnerabilityGuardFlags: [String] = [],
        intensity: Double
    ) {
        self.schemaVersion = schemaVersion
        self.relatedGoals = relatedGoals
        self.touchedBoundaries = touchedBoundaries
        self.highConsequenceRelationRefs = highConsequenceRelationRefs
        self.rhythmStateRef = rhythmStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.vulnerabilityGuardFlags = vulnerabilityGuardFlags
        self.intensity = min(max(intensity, 0), 1)
    }
}

public struct BASContinuityAnchor: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var anchorID: String
    public var linkedTurns: [String]
    public var sceneArc: String
    public var escalationPattern: String?
    public var unresolvedThreads: [String]

    public init(
        schemaVersion: String = BASContinuityAnchor.currentSchemaVersion,
        anchorID: String,
        linkedTurns: [String] = [],
        sceneArc: String,
        escalationPattern: String? = nil,
        unresolvedThreads: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.anchorID = anchorID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.linkedTurns = linkedTurns
        self.sceneArc = sceneArc.trimmingCharacters(in: .whitespacesAndNewlines)
        self.escalationPattern = escalationPattern?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unresolvedThreads = unresolvedThreads
    }
}

public struct BASContextRouteHint: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var preferredMode: String
    public var needMemory: Bool
    public var needMirror: Bool
    public var needDoublePath: Bool
    public var needGuard: Bool
    public var sovereignHintLevel: String

    public init(
        schemaVersion: String = BASContextRouteHint.currentSchemaVersion,
        preferredMode: String,
        needMemory: Bool = false,
        needMirror: Bool = false,
        needDoublePath: Bool = false,
        needGuard: Bool = false,
        sovereignHintLevel: String = "low"
    ) {
        self.schemaVersion = schemaVersion
        self.preferredMode = preferredMode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.needMemory = needMemory
        self.needMirror = needMirror
        self.needDoublePath = needDoublePath
        self.needGuard = needGuard
        self.sovereignHintLevel = sovereignHintLevel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASContextFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.2.0"

    public var schemaVersion: String
    public var utterance: String
    public var taskType: BASContextTaskType
    public var sceneType: BASContextSceneType
    public var emotionalLoad: Double
    public var timePressure: Double
    public var relationPattern: String
    public var ambiguityScore: Double
    public var consequenceLevel: Double
    public var manipulationHints: [String]
    public var hostRelevance: Double
    public var roleGeometry: BASRoleGeometry?
    public var powerGradient: BASPowerGradient?
    public var emotionalWeather: BASEmotionalWeather?
    public var urgencyTruth: BASUrgencyTruth?
    public var consequenceHorizon: BASConsequenceHorizon?
    public var manipulationTrace: BASManipulationTrace?
    public var hostResonance: BASHostResonance?
    public var continuityAnchor: BASContinuityAnchor?
    public var routeHint: BASContextRouteHint?
    public var confidenceBand: Double?
    /// M53 — L6 presence-eye per-channel observation bundle derived
    /// from this frame's signals. `nil` when the frame was
    /// constructed by a caller that predates M53 (legacy path) or
    /// when an explicit `derive(...)` call was skipped. Load-bearing
    /// consumers (M32 L6 coverage projection, L14 audit surface)
    /// read this field directly; coherent-by-construction with the
    /// rest of the frame when populated.
    public var presenceObservationBundle: BASPresenceObservationBundle?

    public init(
        schemaVersion: String = BASContextFrame.currentSchemaVersion,
        utterance: String,
        taskType: BASContextTaskType,
        sceneType: BASContextSceneType? = nil,
        emotionalLoad: Double,
        timePressure: Double,
        relationPattern: String,
        ambiguityScore: Double,
        consequenceLevel: Double,
        manipulationHints: [String] = [],
        hostRelevance: Double,
        roleGeometry: BASRoleGeometry? = nil,
        powerGradient: BASPowerGradient? = nil,
        emotionalWeather: BASEmotionalWeather? = nil,
        urgencyTruth: BASUrgencyTruth? = nil,
        consequenceHorizon: BASConsequenceHorizon? = nil,
        manipulationTrace: BASManipulationTrace? = nil,
        hostResonance: BASHostResonance? = nil,
        continuityAnchor: BASContinuityAnchor? = nil,
        routeHint: BASContextRouteHint? = nil,
        confidenceBand: Double? = nil,
        presenceObservationBundle: BASPresenceObservationBundle? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.utterance = utterance
        self.taskType = taskType
        self.sceneType = sceneType ?? BASContextSceneType.defaultValue(for: taskType)
        self.emotionalLoad = min(max(emotionalLoad, 0), 1)
        self.timePressure = min(max(timePressure, 0), 1)
        self.relationPattern = relationPattern
        self.ambiguityScore = min(max(ambiguityScore, 0), 1)
        self.consequenceLevel = min(max(consequenceLevel, 0), 1)
        self.manipulationHints = manipulationHints
        self.hostRelevance = min(max(hostRelevance, 0), 1)
        self.roleGeometry = roleGeometry
        self.powerGradient = powerGradient
        self.emotionalWeather = emotionalWeather
        self.urgencyTruth = urgencyTruth
        self.consequenceHorizon = consequenceHorizon
        self.manipulationTrace = manipulationTrace
        self.hostResonance = hostResonance
        self.continuityAnchor = continuityAnchor
        self.routeHint = routeHint
        self.confidenceBand = confidenceBand.map { min(max($0, 0), 1) }
        self.presenceObservationBundle = presenceObservationBundle
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case utterance
        case taskType
        case sceneType
        case emotionalLoad
        case timePressure
        case relationPattern
        case ambiguityScore
        case consequenceLevel
        case manipulationHints
        case hostRelevance
        case roleGeometry
        case powerGradient
        case emotionalWeather
        case urgencyTruth
        case consequenceHorizon
        case manipulationTrace
        case hostResonance
        case continuityAnchor
        case routeHint
        case confidenceBand
        case presenceObservationBundle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTaskType = try container.decode(BASContextTaskType.self, forKey: .taskType)

        self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASContextFrame.currentSchemaVersion
        self.utterance = try container.decode(String.self, forKey: .utterance)
        self.taskType = decodedTaskType
        self.sceneType = try container.decodeIfPresent(BASContextSceneType.self, forKey: .sceneType)
            ?? BASContextSceneType.defaultValue(for: decodedTaskType)
        self.emotionalLoad = min(max(try container.decode(Double.self, forKey: .emotionalLoad), 0), 1)
        self.timePressure = min(max(try container.decode(Double.self, forKey: .timePressure), 0), 1)
        self.relationPattern = try container.decode(String.self, forKey: .relationPattern)
        self.ambiguityScore = min(max(try container.decode(Double.self, forKey: .ambiguityScore), 0), 1)
        self.consequenceLevel = min(max(try container.decode(Double.self, forKey: .consequenceLevel), 0), 1)
        self.manipulationHints = try container.decodeIfPresent([String].self, forKey: .manipulationHints) ?? []
        self.hostRelevance = min(max(try container.decode(Double.self, forKey: .hostRelevance), 0), 1)
        self.roleGeometry = try container.decodeIfPresent(BASRoleGeometry.self, forKey: .roleGeometry)
        self.powerGradient = try container.decodeIfPresent(BASPowerGradient.self, forKey: .powerGradient)
        self.emotionalWeather = try container.decodeIfPresent(BASEmotionalWeather.self, forKey: .emotionalWeather)
        self.urgencyTruth = try container.decodeIfPresent(BASUrgencyTruth.self, forKey: .urgencyTruth)
        self.consequenceHorizon = try container.decodeIfPresent(BASConsequenceHorizon.self, forKey: .consequenceHorizon)
        self.manipulationTrace = try container.decodeIfPresent(BASManipulationTrace.self, forKey: .manipulationTrace)
        self.hostResonance = try container.decodeIfPresent(BASHostResonance.self, forKey: .hostResonance)
        self.continuityAnchor = try container.decodeIfPresent(BASContinuityAnchor.self, forKey: .continuityAnchor)
        self.routeHint = try container.decodeIfPresent(BASContextRouteHint.self, forKey: .routeHint)
        self.confidenceBand = try container.decodeIfPresent(Double.self, forKey: .confidenceBand).map {
            min(max($0, 0), 1)
        }
        self.presenceObservationBundle = try container.decodeIfPresent(
            BASPresenceObservationBundle.self,
            forKey: .presenceObservationBundle)
    }
}

extension BASContextFrame {
    /// M53 — Return a copy of this frame with a freshly derived
    /// `presenceObservationBundle` attached. Pure function: no I/O,
    /// no actor hop, deterministic for the same (frame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where both turn and
    /// session identity are known (`EBrainRuntimeCoordinator` after
    /// `contextService.analyzeContext(...)` returns) so the bundle
    /// can flow into the same turn-audit record that the L14 surface
    /// later signs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals",
    /// not "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedPresenceObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASContextFrame {
        var copy = self
        copy.presenceObservationBundle = BASPresenceObservationBundle.derive(
            from: self,
            turnID: turnID,
            sessionID: sessionID,
            emittedAt: emittedAt)
        return copy
    }
}

public enum BASFactStatus: String, Codable, CaseIterable, Sendable {
    case observed
    case reported
    case inferred
    case unverified
}

public enum BASDecomposeSourceKind: String, Codable, CaseIterable, Sendable {
    case currentInput
    case sessionDetail
    case workflowState
    case hostConstitution
    case memoryProjection
    case systemInference
}

public struct BASFactShard: Codable, Equatable, Sendable {
    public var shardID: String
    public var text: String
    public var status: BASFactStatus
    public var sourceKind: BASDecomposeSourceKind
    public var certainty: Double
    public var timeScope: String?

    public init(
        shardID: String,
        text: String,
        status: BASFactStatus,
        sourceKind: BASDecomposeSourceKind,
        certainty: Double,
        timeScope: String? = nil
    ) {
        self.shardID = shardID
        self.text = text
        self.status = status
        self.sourceKind = sourceKind
        self.certainty = min(max(certainty, 0), 1)
        self.timeScope = timeScope
    }
}

public enum BASClaimType: String, Codable, CaseIterable, Sendable {
    case factClaim
    case valueClaim
    case command
    case prediction
    case accusation
}

public struct BASClaimShard: Codable, Equatable, Sendable {
    public var claimID: String
    public var text: String
    public var claimType: BASClaimType
    public var supportLevel: Double
    public var sourceKind: BASDecomposeSourceKind
    public var sourceRef: String

    public init(
        claimID: String,
        text: String,
        claimType: BASClaimType,
        supportLevel: Double,
        sourceKind: BASDecomposeSourceKind,
        sourceRef: String
    ) {
        self.claimID = claimID
        self.text = text
        self.claimType = claimType
        self.supportLevel = min(max(supportLevel, 0), 1)
        self.sourceKind = sourceKind
        self.sourceRef = sourceRef
    }
}

public struct BASGoalSpineLocal: Codable, Equatable, Sendable {
    public var surfaceGoals: [String]
    public var midGoals: [String]
    public var deepGoals: [String]
    public var conflicts: [String]
    public var hostAlignmentScore: Double

    public init(
        surfaceGoals: [String] = [],
        midGoals: [String] = [],
        deepGoals: [String] = [],
        conflicts: [String] = [],
        hostAlignmentScore: Double
    ) {
        self.surfaceGoals = surfaceGoals
        self.midGoals = midGoals
        self.deepGoals = deepGoals
        self.conflicts = conflicts
        self.hostAlignmentScore = min(max(hostAlignmentScore, 0), 1)
    }
}

public enum BASUnknownKind: String, Codable, CaseIterable, Sendable {
    case missingFact
    case missingRole
    case missingConstraint
    case unresolvedPermission
    case ambiguity
}

public struct BASUnknownRecord: Codable, Equatable, Sendable {
    public var unknownID: String
    public var kind: BASUnknownKind
    public var summary: String
    public var sourceKind: BASDecomposeSourceKind
    public var blocking: Bool

    public init(
        unknownID: String,
        kind: BASUnknownKind,
        summary: String,
        sourceKind: BASDecomposeSourceKind,
        blocking: Bool
    ) {
        self.unknownID = unknownID
        self.kind = kind
        self.summary = summary
        self.sourceKind = sourceKind
        self.blocking = blocking
    }
}

public enum BASContradictionKind: String, Codable, CaseIterable, Sendable {
    case textual
    case historical
    case evidential
    case role
}

public struct BASContradictionRecord: Codable, Equatable, Sendable {
    public var nodeID: String
    public var kind: BASContradictionKind
    public var summary: String
    public var refs: [String]
    public var severity: Double
    public var unresolved: Bool

    public init(
        nodeID: String,
        kind: BASContradictionKind,
        summary: String,
        refs: [String] = [],
        severity: Double,
        unresolved: Bool
    ) {
        self.nodeID = nodeID
        self.kind = kind
        self.summary = summary
        self.refs = refs
        self.severity = min(max(severity, 0), 1)
        self.unresolved = unresolved
    }
}

public enum BASPressureKind: String, Codable, CaseIterable, Sendable {
    case time
    case relationship
    case shame
    case consequence
    case resource
    case responsibility
}

public enum BASPressureDirection: String, Codable, CaseIterable, Sendable {
    case compressing
    case leveraging
    case amplifying
    case constraining
}

public struct BASPressureVector: Codable, Equatable, Sendable {
    public var vectorID: String
    public var kind: BASPressureKind
    public var direction: BASPressureDirection
    public var strength: Double
    public var authenticity: Double
    public var sourceRef: String

    public init(
        vectorID: String,
        kind: BASPressureKind,
        direction: BASPressureDirection,
        strength: Double,
        authenticity: Double,
        sourceRef: String
    ) {
        self.vectorID = vectorID
        self.kind = kind
        self.direction = direction
        self.strength = min(max(strength, 0), 1)
        self.authenticity = min(max(authenticity, 0), 1)
        self.sourceRef = sourceRef
    }
}

public enum BASManipulationKind: String, Codable, CaseIterable, Sendable {
    case gaslightPrecursor
    case shame
    case authorityMask
    case coerciveUrgency
    case relationalLeverage
}

public struct BASManipulationPattern: Codable, Equatable, Sendable {
    public var patternID: String
    public var kind: BASManipulationKind
    public var summary: String
    public var refs: [String]
    public var confidence: Double

    public init(
        patternID: String,
        kind: BASManipulationKind,
        summary: String,
        refs: [String] = [],
        confidence: Double
    ) {
        self.patternID = patternID
        self.kind = kind
        self.summary = summary
        self.refs = refs
        self.confidence = min(max(confidence, 0), 1)
    }
}

public enum BASBoundaryDomain: String, Codable, CaseIterable, Sendable {
    case host
    case system
    case sovereign
}

public enum BASBoundaryTouchLevel: String, Codable, CaseIterable, Sendable {
    case brush
    case approach
    case breachRisk
}

public struct BASBoundaryTouch: Codable, Equatable, Sendable {
    public var touchID: String
    public var domain: BASBoundaryDomain
    public var level: BASBoundaryTouchLevel
    public var summary: String
    public var refs: [String]

    public init(
        touchID: String,
        domain: BASBoundaryDomain,
        level: BASBoundaryTouchLevel,
        summary: String,
        refs: [String] = []
    ) {
        self.touchID = touchID
        self.domain = domain
        self.level = level
        self.summary = summary
        self.refs = refs
    }
}

public enum BASMirrorMode: String, Codable, CaseIterable, Sendable {
    case silent
    case soft
    case hard
}

public struct BASMirrorDraft: Codable, Equatable, Sendable {
    public var draftID: String
    public var mode: BASMirrorMode
    public var summary: String
    public var calibrationPoints: [String]
    public var omittedSpeculations: [String]
    public var toneGuard: String

    public init(
        draftID: String,
        mode: BASMirrorMode,
        summary: String,
        calibrationPoints: [String] = [],
        omittedSpeculations: [String] = [],
        toneGuard: String
    ) {
        self.draftID = draftID
        self.mode = mode
        self.summary = summary
        self.calibrationPoints = calibrationPoints
        self.omittedSpeculations = omittedSpeculations
        self.toneGuard = toneGuard
    }
}

public struct BASCanonicalCognitiveFrame: Codable, Equatable, Sendable {
    public var ccfID: String
    public var stableFacts: [String]
    public var activeGoals: [String]
    public var activeUnknowns: [String]
    public var keyPressures: [String]
    public var keyContradictions: [String]
    public var manipulationWatch: [String]
    public var boundaryWatch: [String]
    public var routeHint: String

    public init(
        ccfID: String,
        stableFacts: [String] = [],
        activeGoals: [String] = [],
        activeUnknowns: [String] = [],
        keyPressures: [String] = [],
        keyContradictions: [String] = [],
        manipulationWatch: [String] = [],
        boundaryWatch: [String] = [],
        routeHint: String
    ) {
        self.ccfID = ccfID
        self.stableFacts = stableFacts
        self.activeGoals = activeGoals
        self.activeUnknowns = activeUnknowns
        self.keyPressures = keyPressures
        self.keyContradictions = keyContradictions
        self.manipulationWatch = manipulationWatch
        self.boundaryWatch = boundaryWatch
        self.routeHint = routeHint
    }
}

public struct BASDecomposeFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.2.0"

    public var schemaVersion: String
    public var facts: [String]
    public var goals: [String]
    public var emotions: [String]
    public var unknowns: [String]
    public var contradictions: [String]
    public var pressureSignals: [String]
    public var manipulationSignals: [String]
    public var mirrorText: String
    public var factShards: [BASFactShard]
    public var claimShards: [BASClaimShard]
    public var goalSpineLocal: BASGoalSpineLocal?
    public var unknownRecords: [BASUnknownRecord]
    public var contradictionRecords: [BASContradictionRecord]
    public var pressureVectors: [BASPressureVector]
    public var manipulationPatterns: [BASManipulationPattern]
    public var boundaryTouches: [BASBoundaryTouch]
    public var mirrorDraft: BASMirrorDraft?
    public var canonicalFrame: BASCanonicalCognitiveFrame?
    /// M54 — L7 mirror-blade per-signal observation bundle derived
    /// from this frame's records. `nil` when the frame was constructed
    /// by a caller that predates M54 (legacy path) or when an explicit
    /// `derive(...)` call was skipped. Load-bearing consumers (M32 L7
    /// coverage projection, L14 audit surface) read this field
    /// directly; coherent-by-construction with the rest of the frame
    /// when populated.
    public var decompositionObservationBundle:
        BASDecompositionObservationBundle?

    public init(
        schemaVersion: String = BASDecomposeFrame.currentSchemaVersion,
        facts: [String] = [],
        goals: [String] = [],
        emotions: [String] = [],
        unknowns: [String] = [],
        contradictions: [String] = [],
        pressureSignals: [String] = [],
        manipulationSignals: [String] = [],
        mirrorText: String = "",
        factShards: [BASFactShard]? = nil,
        claimShards: [BASClaimShard]? = nil,
        goalSpineLocal: BASGoalSpineLocal? = nil,
        unknownRecords: [BASUnknownRecord]? = nil,
        contradictionRecords: [BASContradictionRecord]? = nil,
        pressureVectors: [BASPressureVector]? = nil,
        manipulationPatterns: [BASManipulationPattern]? = nil,
        boundaryTouches: [BASBoundaryTouch]? = nil,
        mirrorDraft: BASMirrorDraft? = nil,
        canonicalFrame: BASCanonicalCognitiveFrame? = nil,
        decompositionObservationBundle:
            BASDecompositionObservationBundle? = nil
    ) {
        let resolvedFacts = facts.isEmpty ? (factShards?.map(\.text) ?? []) : facts
        let resolvedGoals = goals.isEmpty ? BASDecomposeFrame.flattenedGoals(from: goalSpineLocal) : goals
        let resolvedUnknowns = unknowns.isEmpty ? (unknownRecords?.map(\.summary) ?? []) : unknowns
        let resolvedContradictions = contradictions.isEmpty ? (contradictionRecords?.map(\.summary) ?? []) : contradictions
        let resolvedPressures = pressureSignals.isEmpty ? BASDecomposeFrame.unique((pressureVectors ?? []).map { $0.kind.rawValue }) : pressureSignals
        let resolvedManipulation = manipulationSignals.isEmpty ? BASDecomposeFrame.unique((manipulationPatterns ?? []).map { $0.kind.rawValue }) : manipulationSignals
        let resolvedMirrorText = mirrorText.isEmpty ? (mirrorDraft?.summary ?? "") : mirrorText

        self.schemaVersion = schemaVersion
        self.facts = resolvedFacts
        self.goals = resolvedGoals
        self.emotions = emotions
        self.unknowns = resolvedUnknowns
        self.contradictions = resolvedContradictions
        self.pressureSignals = resolvedPressures
        self.manipulationSignals = resolvedManipulation
        self.mirrorText = resolvedMirrorText
        self.factShards = factShards ?? BASDecomposeFrame.defaultFactShards(from: resolvedFacts)
        self.claimShards = claimShards ?? []
        self.goalSpineLocal = goalSpineLocal ?? BASDecomposeFrame.defaultGoalSpine(
            from: resolvedGoals,
            contradictions: resolvedContradictions
        )
        self.unknownRecords = unknownRecords ?? BASDecomposeFrame.defaultUnknownRecords(from: resolvedUnknowns)
        self.contradictionRecords = contradictionRecords ?? BASDecomposeFrame.defaultContradictionRecords(from: resolvedContradictions)
        self.pressureVectors = pressureVectors ?? BASDecomposeFrame.defaultPressureVectors(from: resolvedPressures)
        self.manipulationPatterns = manipulationPatterns ?? BASDecomposeFrame.defaultManipulationPatterns(from: resolvedManipulation)
        self.boundaryTouches = boundaryTouches ?? []
        self.mirrorDraft = mirrorDraft ?? BASDecomposeFrame.defaultMirrorDraft(
            mirrorText: resolvedMirrorText,
            unknowns: resolvedUnknowns
        )
        self.canonicalFrame = canonicalFrame ?? BASDecomposeFrame.defaultCanonicalFrame(
            facts: resolvedFacts,
            goals: resolvedGoals,
            unknowns: resolvedUnknowns,
            contradictions: resolvedContradictions,
            pressureSignals: resolvedPressures,
            manipulationSignals: resolvedManipulation,
            boundaryTouches: self.boundaryTouches
        )
        self.decompositionObservationBundle = decompositionObservationBundle
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case facts
        case goals
        case emotions
        case unknowns
        case contradictions
        case pressureSignals
        case manipulationSignals
        case mirrorText
        case factShards
        case claimShards
        case goalSpineLocal
        case unknownRecords
        case contradictionRecords
        case pressureVectors
        case manipulationPatterns
        case boundaryTouches
        case mirrorDraft
        case canonicalFrame
        case decompositionObservationBundle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(String.self, forKey: .schemaVersion)
                ?? BASDecomposeFrame.currentSchemaVersion,
            facts: try container.decodeIfPresent([String].self, forKey: .facts) ?? [],
            goals: try container.decodeIfPresent([String].self, forKey: .goals) ?? [],
            emotions: try container.decodeIfPresent([String].self, forKey: .emotions) ?? [],
            unknowns: try container.decodeIfPresent([String].self, forKey: .unknowns) ?? [],
            contradictions: try container.decodeIfPresent([String].self, forKey: .contradictions) ?? [],
            pressureSignals: try container.decodeIfPresent([String].self, forKey: .pressureSignals) ?? [],
            manipulationSignals: try container.decodeIfPresent([String].self, forKey: .manipulationSignals) ?? [],
            mirrorText: try container.decodeIfPresent(String.self, forKey: .mirrorText) ?? "",
            factShards: try container.decodeIfPresent([BASFactShard].self, forKey: .factShards),
            claimShards: try container.decodeIfPresent([BASClaimShard].self, forKey: .claimShards),
            goalSpineLocal: try container.decodeIfPresent(BASGoalSpineLocal.self, forKey: .goalSpineLocal),
            unknownRecords: try container.decodeIfPresent([BASUnknownRecord].self, forKey: .unknownRecords),
            contradictionRecords: try container.decodeIfPresent([BASContradictionRecord].self, forKey: .contradictionRecords),
            pressureVectors: try container.decodeIfPresent([BASPressureVector].self, forKey: .pressureVectors),
            manipulationPatterns: try container.decodeIfPresent([BASManipulationPattern].self, forKey: .manipulationPatterns),
            boundaryTouches: try container.decodeIfPresent([BASBoundaryTouch].self, forKey: .boundaryTouches),
            mirrorDraft: try container.decodeIfPresent(BASMirrorDraft.self, forKey: .mirrorDraft),
            canonicalFrame: try container.decodeIfPresent(BASCanonicalCognitiveFrame.self, forKey: .canonicalFrame),
            decompositionObservationBundle: try container.decodeIfPresent(
                BASDecompositionObservationBundle.self,
                forKey: .decompositionObservationBundle)
        )
    }

    private static func flattenedGoals(
        from goalSpineLocal: BASGoalSpineLocal?
    ) -> [String] {
        guard let goalSpineLocal else { return [] }
        return unique(goalSpineLocal.surfaceGoals + goalSpineLocal.midGoals + goalSpineLocal.deepGoals)
    }

    private static func defaultFactShards(
        from facts: [String]
    ) -> [BASFactShard] {
        facts.enumerated().map { index, fact in
            BASFactShard(
                shardID: "fact-\(index + 1)",
                text: fact,
                status: .reported,
                sourceKind: inferredSourceKind(for: fact),
                certainty: inferredSourceKind(for: fact) == .systemInference ? 0.62 : 0.82,
                timeScope: "current_turn"
            )
        }
    }

    private static func defaultGoalSpine(
        from goals: [String],
        contradictions: [String]
    ) -> BASGoalSpineLocal? {
        guard goals.isEmpty == false else { return nil }

        let surfaceGoals = Array(goals.prefix(2))
        let midGoals = goals.count > 2 ? [goals[2]] : surfaceGoals
        let deepGoals = [goals.last ?? surfaceGoals.first ?? "Keep the next move bounded."]
        return BASGoalSpineLocal(
            surfaceGoals: unique(surfaceGoals),
            midGoals: unique(midGoals),
            deepGoals: unique(deepGoals),
            conflicts: contradictions,
            hostAlignmentScore: contradictions.isEmpty ? 0.74 : 0.61
        )
    }

    private static func defaultUnknownRecords(
        from unknowns: [String]
    ) -> [BASUnknownRecord] {
        unknowns.enumerated().map { index, unknown in
            BASUnknownRecord(
                unknownID: "unknown-\(index + 1)",
                kind: inferredUnknownKind(for: unknown),
                summary: unknown,
                sourceKind: .systemInference,
                blocking: true
            )
        }
    }

    private static func defaultContradictionRecords(
        from contradictions: [String]
    ) -> [BASContradictionRecord] {
        contradictions.enumerated().map { index, contradiction in
            BASContradictionRecord(
                nodeID: "contradiction-\(index + 1)",
                kind: inferredContradictionKind(for: contradiction),
                summary: contradiction,
                refs: ["legacy"],
                severity: 0.66,
                unresolved: true
            )
        }
    }

    private static func defaultPressureVectors(
        from pressureSignals: [String]
    ) -> [BASPressureVector] {
        pressureSignals.enumerated().map { index, signal in
            BASPressureVector(
                vectorID: "pressure-\(index + 1)",
                kind: inferredPressureKind(for: signal),
                direction: .compressing,
                strength: 0.72,
                authenticity: 0.68,
                sourceRef: signal
            )
        }
    }

    private static func defaultManipulationPatterns(
        from manipulationSignals: [String]
    ) -> [BASManipulationPattern] {
        manipulationSignals.enumerated().map { index, signal in
            BASManipulationPattern(
                patternID: "manipulation-\(index + 1)",
                kind: inferredManipulationKind(for: signal),
                summary: signal,
                refs: ["legacy"],
                confidence: 0.67
            )
        }
    }

    private static func defaultMirrorDraft(
        mirrorText: String,
        unknowns: [String]
    ) -> BASMirrorDraft? {
        guard mirrorText.isEmpty == false else { return nil }
        return BASMirrorDraft(
            draftID: "mirror-1",
            mode: .soft,
            summary: mirrorText,
            calibrationPoints: [],
            omittedSpeculations: unknowns,
            toneGuard: "calibration_only"
        )
    }

    private static func defaultCanonicalFrame(
        facts: [String],
        goals: [String],
        unknowns: [String],
        contradictions: [String],
        pressureSignals: [String],
        manipulationSignals: [String],
        boundaryTouches: [BASBoundaryTouch]
    ) -> BASCanonicalCognitiveFrame? {
        guard facts.isEmpty == false
            || goals.isEmpty == false
            || unknowns.isEmpty == false
            || contradictions.isEmpty == false
            || pressureSignals.isEmpty == false
            || manipulationSignals.isEmpty == false
            || boundaryTouches.isEmpty == false else {
            return nil
        }

        let routeHint: String
        if contradictions.isEmpty == false && pressureSignals.isEmpty == false {
            routeHint = "mirror_before_commit"
        } else if unknowns.isEmpty == false {
            routeHint = "clarify_unknowns"
        } else {
            routeHint = "bounded_continue"
        }

        return BASCanonicalCognitiveFrame(
            ccfID: "ccf-1",
            stableFacts: facts,
            activeGoals: goals,
            activeUnknowns: unknowns,
            keyPressures: pressureSignals,
            keyContradictions: contradictions,
            manipulationWatch: manipulationSignals,
            boundaryWatch: boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" },
            routeHint: routeHint
        )
    }

    private static func inferredSourceKind(
        for fact: String
    ) -> BASDecomposeSourceKind {
        if fact.hasPrefix("Host request:") {
            return .currentInput
        }
        if fact.hasPrefix("Detail:") {
            return .sessionDetail
        }
        if fact.hasPrefix("Workflow:") {
            return .workflowState
        }
        if fact.hasPrefix("Constitution ")
            || fact.hasPrefix("High-consequence relations:")
            || fact.hasPrefix("Goal spine stage:") {
            return .hostConstitution
        }
        return .systemInference
    }

    private static func inferredUnknownKind(
        for unknown: String
    ) -> BASUnknownKind {
        let normalized = unknown.lowercased()
        if normalized.contains("permission") || normalized.contains("authorized") {
            return .unresolvedPermission
        }
        if normalized.contains("constraint") {
            return .missingConstraint
        }
        if normalized.contains("role") || normalized.contains("other side") {
            return .missingRole
        }
        if normalized.contains("ambig") || normalized.contains("uncertain") {
            return .ambiguity
        }
        return .missingFact
    }

    private static func inferredContradictionKind(
        for contradiction: String
    ) -> BASContradictionKind {
        let normalized = contradiction.lowercased()
        if normalized.contains("history") {
            return .historical
        }
        if normalized.contains("evidence") || normalized.contains("support") {
            return .evidential
        }
        if normalized.contains("role") || normalized.contains("boundary") {
            return .role
        }
        return .textual
    }

    private static func inferredPressureKind(
        for pressureSignal: String
    ) -> BASPressureKind {
        let normalized = pressureSignal.lowercased()
        if normalized.contains("relationship") || normalized.contains("relation") {
            return .relationship
        }
        if normalized.contains("shame") {
            return .shame
        }
        if normalized.contains("consequence") {
            return .consequence
        }
        if normalized.contains("resource") {
            return .resource
        }
        if normalized.contains("responsibility") || normalized.contains("authority") {
            return .responsibility
        }
        return .time
    }

    private static func inferredManipulationKind(
        for manipulationSignal: String
    ) -> BASManipulationKind {
        let normalized = manipulationSignal.lowercased()
        if normalized.contains("gaslight") {
            return .gaslightPrecursor
        }
        if normalized.contains("shame") {
            return .shame
        }
        if normalized.contains("authority") {
            return .authorityMask
        }
        if normalized.contains("relation") {
            return .relationalLeverage
        }
        return .coerciveUrgency
    }

    private static func unique(
        _ values: [String]
    ) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

extension BASDecomposeFrame {
    /// M54 — Return a copy of this frame with a freshly derived
    /// `decompositionObservationBundle` attached. Pure function: no
    /// I/O, no actor hop, deterministic for the same (frame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where both turn and
    /// session identity are known — after `decomposeService.decompose`
    /// + `mirror` + `checkContradiction` have filled in mirror text
    /// and contradictions — so the bundle flows into the same
    /// turn-audit record that the L14 surface later signs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedDecompositionObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASDecomposeFrame {
        var copy = self
        copy.decompositionObservationBundle =
            BASDecompositionObservationBundle.derive(
                from: self,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
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

public enum BASNeuralOrgan: String, Codable, CaseIterable, Sendable {
    case scoutStrip
    case coreCortex
    case simuRing
    case criticBlade
    case riskSpine
    case permitKnot
    case memoryCodecRidge
    case hostModulationMesh
    case toolIntentMesh
    case consistencyLattice
    case stubCore
    case tissueRouter
}

public enum BASNeuralMorph: String, Codable, CaseIterable, Sendable {
    case scout
    case engage
    case compare
    case deepLoop
    case `guard`
    case stub
    case quarantine
    case rollbackRebuild
}

public enum BASNeuralPrecisionTier: String, Codable, CaseIterable, Sendable {
    case minimal
    case balanced
    case protected
    case full
}

public enum BASNeuralRoutingPolicy: String, Codable, CaseIterable, Sendable {
    case scoutProbe
    case conversationalBalance
    case comparativeFanout
    case deepLoopConvergence
    case protectiveThrottle
    case quarantineIsolation
    case rollbackRecovery
    case stubOnly
}

public struct BASNeuralOrganPrecision: Codable, Equatable, Sendable {
    public var organ: BASNeuralOrgan
    public var tier: BASNeuralPrecisionTier

    public init(
        organ: BASNeuralOrgan,
        tier: BASNeuralPrecisionTier
    ) {
        self.organ = organ
        self.tier = tier
    }
}

public struct BASNeuralOrganMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var morph: BASNeuralMorph
    public var activeOrgans: [BASNeuralOrgan]
    public var precisionMap: [BASNeuralOrganPrecision]
    public var routingPolicy: BASNeuralRoutingPolicy
    public var leaseRef: String?
    public var sovereignConstraints: [String]
    public var headGuarantees: [String]

    public init(
        schemaVersion: String = BASNeuralOrganMap.currentSchemaVersion,
        morph: BASNeuralMorph,
        activeOrgans: [BASNeuralOrgan],
        precisionMap: [BASNeuralOrganPrecision] = [],
        routingPolicy: BASNeuralRoutingPolicy,
        leaseRef: String? = nil,
        sovereignConstraints: [String] = [],
        headGuarantees: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.morph = morph
        self.activeOrgans = activeOrgans
        self.precisionMap = precisionMap
        self.routingPolicy = routingPolicy
        self.leaseRef = leaseRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignConstraints = sovereignConstraints
        self.headGuarantees = headGuarantees
    }
}

public struct BASCandidateFrontier: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var candidateIDs: [String]
    public var dominanceOrder: [String]
    public var reversiblePaths: [String]
    public var guardPaths: [String]
    public var frontierWidth: Int
    public var diversityScore: Double
    public var delayedPaths: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case candidateIDs
        case dominanceOrder
        case reversiblePaths
        case guardPaths
        case frontierWidth
        case diversityScore
        case delayedPaths
    }

    public init(
        schemaVersion: String = BASCandidateFrontier.currentSchemaVersion,
        candidateIDs: [String],
        dominanceOrder: [String],
        reversiblePaths: [String] = [],
        guardPaths: [String] = [],
        frontierWidth: Int,
        diversityScore: Double = 0,
        delayedPaths: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateIDs = candidateIDs
        self.dominanceOrder = dominanceOrder
        self.reversiblePaths = reversiblePaths
        self.guardPaths = guardPaths
        self.frontierWidth = max(0, frontierWidth)
        self.diversityScore = min(max(diversityScore, 0), 1)
        self.delayedPaths = delayedPaths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let candidateIDs = try container.decodeIfPresent([String].self, forKey: .candidateIDs) ?? []

        self.init(
            schemaVersion: try container.decodeIfPresent(String.self, forKey: .schemaVersion)
                ?? "1.0.0",
            candidateIDs: candidateIDs,
            dominanceOrder: try container.decodeIfPresent([String].self, forKey: .dominanceOrder) ?? [],
            reversiblePaths: try container.decodeIfPresent([String].self, forKey: .reversiblePaths) ?? [],
            guardPaths: try container.decodeIfPresent([String].self, forKey: .guardPaths) ?? [],
            frontierWidth: try container.decodeIfPresent(Int.self, forKey: .frontierWidth) ?? candidateIDs.count,
            diversityScore: try container.decodeIfPresent(Double.self, forKey: .diversityScore) ?? 0,
            delayedPaths: try container.decodeIfPresent([String].self, forKey: .delayedPaths) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(candidateIDs, forKey: .candidateIDs)
        try container.encode(dominanceOrder, forKey: .dominanceOrder)
        try container.encode(reversiblePaths, forKey: .reversiblePaths)
        try container.encode(guardPaths, forKey: .guardPaths)
        try container.encode(frontierWidth, forKey: .frontierWidth)
        try container.encode(diversityScore, forKey: .diversityScore)
        try container.encode(delayedPaths, forKey: .delayedPaths)
    }
}

public struct BASCounterfactualBundle: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var shortTerm: String
    public var midTerm: String
    public var worstCase: String
    public var uncertainty: Double
    public var affectedDomains: [String]

    public init(
        schemaVersion: String = BASCounterfactualBundle.currentSchemaVersion,
        candidateID: String,
        shortTerm: String,
        midTerm: String,
        worstCase: String,
        uncertainty: Double,
        affectedDomains: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.shortTerm = shortTerm
        self.midTerm = midTerm
        self.worstCase = worstCase
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.affectedDomains = affectedDomains
    }
}

public struct BASCritiqueBundle: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var evidenceGap: Double
    public var manipulationRisk: Double
    public var emotionalBias: Double
    public var boundaryConflict: Double
    public var critiqueStrength: Double

    public init(
        schemaVersion: String = BASCritiqueBundle.currentSchemaVersion,
        candidateID: String,
        evidenceGap: Double,
        manipulationRisk: Double,
        emotionalBias: Double,
        boundaryConflict: Double,
        critiqueStrength: Double
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.evidenceGap = min(max(evidenceGap, 0), 1)
        self.manipulationRisk = min(max(manipulationRisk, 0), 1)
        self.emotionalBias = min(max(emotionalBias, 0), 1)
        self.boundaryConflict = min(max(boundaryConflict, 0), 1)
        self.critiqueStrength = min(max(critiqueStrength, 0), 1)
    }
}

public struct BASUncertaintyLedger: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var ledgerID: String
    public var unresolvedUnknowns: [String]
    public var weakPredictions: [String]
    public var highSensitivityPoints: [String]
    public var confidenceFloor: Double

    public init(
        schemaVersion: String = BASUncertaintyLedger.currentSchemaVersion,
        ledgerID: String,
        unresolvedUnknowns: [String] = [],
        weakPredictions: [String] = [],
        highSensitivityPoints: [String] = [],
        confidenceFloor: Double
    ) {
        self.schemaVersion = schemaVersion
        self.ledgerID = ledgerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unresolvedUnknowns = unresolvedUnknowns
        self.weakPredictions = weakPredictions
        self.highSensitivityPoints = highSensitivityPoints
        self.confidenceFloor = min(max(confidenceFloor, 0), 1)
    }
}

public struct BASEvidenceDebt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var debtID: String
    public var candidateID: String
    public var missingEvidence: [String]
    public var validationActions: [String]
    public var debtWeight: Double

    public init(
        schemaVersion: String = BASEvidenceDebt.currentSchemaVersion,
        debtID: String,
        candidateID: String,
        missingEvidence: [String] = [],
        validationActions: [String] = [],
        debtWeight: Double
    ) {
        self.schemaVersion = schemaVersion
        self.debtID = debtID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateID = candidateID
        self.missingEvidence = missingEvidence
        self.validationActions = validationActions
        self.debtWeight = min(max(debtWeight, 0), 1)
    }
}

public enum BASConvergenceStoppingMode: String, Codable, CaseIterable, Sendable {
    case converged
    case leaseEnd
    case sovereignCut
    case guardTakeover
}

public struct BASConvergenceCertificate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var certID: String
    public var frontierID: String
    public var stabilityScore: Double
    public var stoppingMode: BASConvergenceStoppingMode
    public var recommendedNextStep: String

    public init(
        schemaVersion: String = BASConvergenceCertificate.currentSchemaVersion,
        certID: String,
        frontierID: String,
        stabilityScore: Double,
        stoppingMode: BASConvergenceStoppingMode,
        recommendedNextStep: String
    ) {
        self.schemaVersion = schemaVersion
        self.certID = certID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frontierID = frontierID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stabilityScore = min(max(stabilityScore, 0), 1)
        self.stoppingMode = stoppingMode
        self.recommendedNextStep = recommendedNextStep.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASLoopLeaseReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var receiptID: String
    public var leaseID: String
    public var loopsUsed: Int
    public var candidatesUsed: Int
    public var projectionsUsed: Int
    public var degraded: Bool

    public init(
        schemaVersion: String = BASLoopLeaseReceipt.currentSchemaVersion,
        receiptID: String,
        leaseID: String,
        loopsUsed: Int,
        candidatesUsed: Int,
        projectionsUsed: Int,
        degraded: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.receiptID = receiptID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.leaseID = leaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.loopsUsed = max(0, loopsUsed)
        self.candidatesUsed = max(0, candidatesUsed)
        self.projectionsUsed = max(0, projectionsUsed)
        self.degraded = degraded
    }
}

public enum BASSovereignBreakpointSuggestedAction: String, Codable, CaseIterable, Sendable {
    case shrink
    case cut
    case freeze
    case stop
}

public struct BASSovereignBreakpointHint: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hintID: String
    public var sourceRef: String
    public var reasonCodes: [String]
    public var affectedCandidates: [String]
    public var suggestedAction: BASSovereignBreakpointSuggestedAction

    public init(
        schemaVersion: String = BASSovereignBreakpointHint.currentSchemaVersion,
        hintID: String,
        sourceRef: String,
        reasonCodes: [String] = [],
        affectedCandidates: [String] = [],
        suggestedAction: BASSovereignBreakpointSuggestedAction
    ) {
        self.schemaVersion = schemaVersion
        self.hintID = hintID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRef = sourceRef.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reasonCodes = reasonCodes
        self.affectedCandidates = affectedCandidates
        self.suggestedAction = suggestedAction
    }
}

public struct BASToolIntentEnvelope: BASSchemaVersioned {
    public static let currentSchemaVersion = "2.0.0"

    public var schemaVersion: String
    public var intentID: String
    public var candidateID: String
    public var permitMode: BASActionPermitMode
    public var summary: String
    public var requestedDomains: [String]
    public var blockedDomains: [String]
    public var stackedModes: [BASActionPermitMode]
    public var assertionCeiling: String?
    public var toolScope: String?
    public var memoryScope: String?
    public var requireSecondCheck: Bool
    public var tonePolicy: String
    public var templatePolicy: String
    public var reasonCodes: [String]
    public var delayType: String?
    public var substituteType: String?
    public var sovereignHintLevel: String?
    public var sovereignBound: Bool

    public init(
        schemaVersion: String = BASToolIntentEnvelope.currentSchemaVersion,
        intentID: String,
        candidateID: String,
        permitMode: BASActionPermitMode,
        summary: String,
        requestedDomains: [String] = [],
        blockedDomains: [String] = [],
        stackedModes: [BASActionPermitMode] = [],
        assertionCeiling: String? = nil,
        toolScope: String? = nil,
        memoryScope: String? = nil,
        requireSecondCheck: Bool,
        tonePolicy: String,
        templatePolicy: String,
        reasonCodes: [String] = [],
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil,
        sovereignBound: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.intentID = intentID
        self.candidateID = candidateID
        self.permitMode = permitMode
        self.summary = summary
        self.requestedDomains = requestedDomains
        self.blockedDomains = blockedDomains
        self.stackedModes = stackedModes.filter { $0 != permitMode }
        self.assertionCeiling = assertionCeiling?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolScope = toolScope?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryScope = memoryScope?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requireSecondCheck = requireSecondCheck
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
        self.reasonCodes = reasonCodes
        self.delayType = delayType?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.substituteType = substituteType?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignHintLevel = sovereignHintLevel?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignBound = sovereignBound
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case intentID
        case candidateID
        case permitMode
        case summary
        case requestedDomains
        case blockedDomains
        case stackedModes
        case assertionCeiling
        case toolScope
        case memoryScope
        case requireSecondCheck
        case tonePolicy
        case templatePolicy
        case reasonCodes
        case delayType
        case substituteType
        case sovereignHintLevel
        case sovereignBound
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(String.self, forKey: .schemaVersion)
                ?? "1.0.0",
            intentID: try container.decode(String.self, forKey: .intentID),
            candidateID: try container.decode(String.self, forKey: .candidateID),
            permitMode: try container.decode(BASActionPermitMode.self, forKey: .permitMode),
            summary: try container.decode(String.self, forKey: .summary),
            requestedDomains: try container.decodeIfPresent([String].self, forKey: .requestedDomains) ?? [],
            blockedDomains: try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? [],
            stackedModes: try container.decodeIfPresent([BASActionPermitMode].self, forKey: .stackedModes) ?? [],
            assertionCeiling: try container.decodeIfPresent(String.self, forKey: .assertionCeiling),
            toolScope: try container.decodeIfPresent(String.self, forKey: .toolScope),
            memoryScope: try container.decodeIfPresent(String.self, forKey: .memoryScope),
            requireSecondCheck: try container.decodeIfPresent(Bool.self, forKey: .requireSecondCheck) ?? false,
            tonePolicy: try container.decodeIfPresent(String.self, forKey: .tonePolicy) ?? "grounded_clear",
            templatePolicy: try container.decodeIfPresent(String.self, forKey: .templatePolicy) ?? "default",
            reasonCodes: try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? [],
            delayType: try container.decodeIfPresent(String.self, forKey: .delayType),
            substituteType: try container.decodeIfPresent(String.self, forKey: .substituteType),
            sovereignHintLevel: try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel),
            sovereignBound: try container.decodeIfPresent(Bool.self, forKey: .sovereignBound) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(intentID, forKey: .intentID)
        try container.encode(candidateID, forKey: .candidateID)
        try container.encode(permitMode, forKey: .permitMode)
        try container.encode(summary, forKey: .summary)
        try container.encode(requestedDomains, forKey: .requestedDomains)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encodeIfPresent(assertionCeiling, forKey: .assertionCeiling)
        try container.encodeIfPresent(toolScope, forKey: .toolScope)
        try container.encodeIfPresent(memoryScope, forKey: .memoryScope)
        try container.encode(requireSecondCheck, forKey: .requireSecondCheck)
        try container.encode(tonePolicy, forKey: .tonePolicy)
        try container.encode(templatePolicy, forKey: .templatePolicy)
        try container.encode(reasonCodes, forKey: .reasonCodes)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
        try container.encode(sovereignBound, forKey: .sovereignBound)
    }
}

public struct BASRiskPermitBinding: BASSchemaVersioned {
    public static let currentSchemaVersion = "2.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var riskLevel: BASBrainRiskLevel
    public var totalRisk: Double
    public var uncertainty: Double
    public var irreversibility: Double
    public var manipulationStrength: Double
    public var gsiScore: Double
    public var recommendedMode: BASActionPermitMode
    public var permitMode: BASActionPermitMode
    public var stackedModes: [BASActionPermitMode]
    public var assertionCeiling: String?
    public var toolScope: String?
    public var memoryScope: String?
    public var requireSecondCheck: Bool
    public var outputLengthCap: Int
    public var tonePolicy: String
    public var templatePolicy: String
    public var reasonCodes: [String]
    public var allowedDomains: [String]
    public var forbiddenDomains: [String]
    public var delayType: String?
    public var substituteType: String?
    public var sovereignHintLevel: String?

    public init(
        schemaVersion: String = BASRiskPermitBinding.currentSchemaVersion,
        candidateID: String,
        riskLevel: BASBrainRiskLevel,
        totalRisk: Double,
        uncertainty: Double,
        irreversibility: Double,
        manipulationStrength: Double,
        gsiScore: Double,
        recommendedMode: BASActionPermitMode,
        permitMode: BASActionPermitMode,
        stackedModes: [BASActionPermitMode] = [],
        assertionCeiling: String? = nil,
        toolScope: String? = nil,
        memoryScope: String? = nil,
        requireSecondCheck: Bool,
        outputLengthCap: Int,
        tonePolicy: String,
        templatePolicy: String,
        reasonCodes: [String] = [],
        allowedDomains: [String] = [],
        forbiddenDomains: [String] = [],
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.riskLevel = riskLevel
        self.totalRisk = min(max(totalRisk, 0), 1)
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.irreversibility = min(max(irreversibility, 0), 1)
        self.manipulationStrength = min(max(manipulationStrength, 0), 1)
        self.gsiScore = min(max(gsiScore, 0), 1)
        self.recommendedMode = recommendedMode
        self.permitMode = permitMode
        self.stackedModes = stackedModes.filter { $0 != permitMode }
        self.assertionCeiling = assertionCeiling?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolScope = toolScope?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryScope = memoryScope?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requireSecondCheck = requireSecondCheck
        self.outputLengthCap = max(0, outputLengthCap)
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
        self.reasonCodes = reasonCodes
        self.allowedDomains = allowedDomains
        self.forbiddenDomains = forbiddenDomains
        self.delayType = delayType?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.substituteType = substituteType?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sovereignHintLevel = sovereignHintLevel?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case candidateID
        case riskLevel
        case totalRisk
        case uncertainty
        case irreversibility
        case manipulationStrength
        case gsiScore
        case recommendedMode
        case permitMode
        case stackedModes
        case assertionCeiling
        case toolScope
        case memoryScope
        case requireSecondCheck
        case outputLengthCap
        case tonePolicy
        case templatePolicy
        case reasonCodes
        case allowedDomains
        case forbiddenDomains
        case delayType
        case substituteType
        case sovereignHintLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(String.self, forKey: .schemaVersion)
                ?? "1.0.0",
            candidateID: try container.decode(String.self, forKey: .candidateID),
            riskLevel: try container.decode(BASBrainRiskLevel.self, forKey: .riskLevel),
            totalRisk: try container.decode(Double.self, forKey: .totalRisk),
            uncertainty: try container.decode(Double.self, forKey: .uncertainty),
            irreversibility: try container.decode(Double.self, forKey: .irreversibility),
            manipulationStrength: try container.decode(Double.self, forKey: .manipulationStrength),
            gsiScore: try container.decode(Double.self, forKey: .gsiScore),
            recommendedMode: try container.decode(BASActionPermitMode.self, forKey: .recommendedMode),
            permitMode: try container.decode(BASActionPermitMode.self, forKey: .permitMode),
            stackedModes: try container.decodeIfPresent([BASActionPermitMode].self, forKey: .stackedModes) ?? [],
            assertionCeiling: try container.decodeIfPresent(String.self, forKey: .assertionCeiling),
            toolScope: try container.decodeIfPresent(String.self, forKey: .toolScope),
            memoryScope: try container.decodeIfPresent(String.self, forKey: .memoryScope),
            requireSecondCheck: try container.decodeIfPresent(Bool.self, forKey: .requireSecondCheck) ?? false,
            outputLengthCap: try container.decodeIfPresent(Int.self, forKey: .outputLengthCap) ?? 0,
            tonePolicy: try container.decodeIfPresent(String.self, forKey: .tonePolicy) ?? "grounded_clear",
            templatePolicy: try container.decodeIfPresent(String.self, forKey: .templatePolicy) ?? "default",
            reasonCodes: try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? [],
            allowedDomains: try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? [],
            forbiddenDomains: try container.decodeIfPresent([String].self, forKey: .forbiddenDomains) ?? [],
            delayType: try container.decodeIfPresent(String.self, forKey: .delayType),
            substituteType: try container.decodeIfPresent(String.self, forKey: .substituteType),
            sovereignHintLevel: try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(candidateID, forKey: .candidateID)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(totalRisk, forKey: .totalRisk)
        try container.encode(uncertainty, forKey: .uncertainty)
        try container.encode(irreversibility, forKey: .irreversibility)
        try container.encode(manipulationStrength, forKey: .manipulationStrength)
        try container.encode(gsiScore, forKey: .gsiScore)
        try container.encode(recommendedMode, forKey: .recommendedMode)
        try container.encode(permitMode, forKey: .permitMode)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encodeIfPresent(assertionCeiling, forKey: .assertionCeiling)
        try container.encodeIfPresent(toolScope, forKey: .toolScope)
        try container.encodeIfPresent(memoryScope, forKey: .memoryScope)
        try container.encode(requireSecondCheck, forKey: .requireSecondCheck)
        try container.encode(outputLengthCap, forKey: .outputLengthCap)
        try container.encode(tonePolicy, forKey: .tonePolicy)
        try container.encode(templatePolicy, forKey: .templatePolicy)
        try container.encode(reasonCodes, forKey: .reasonCodes)
        try container.encode(allowedDomains, forKey: .allowedDomains)
        try container.encode(forbiddenDomains, forKey: .forbiddenDomains)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
    }
}

public extension BASRiskPermitBinding {
    var actionPermit: BASActionPermit {
        BASActionPermit(
            mode: permitMode,
            stackedModes: stackedModes,
            reasonCodes: reasonCodes,
            allowedDomains: allowedDomains,
            blockedDomains: forbiddenDomains,
            assertionCeiling: assertionCeiling ?? "guarded",
            toolScope: toolScope ?? "bounded",
            memoryScope: memoryScope ?? "standard",
            requireMirror: stackedModes.contains(.mirror),
            requireCompare: stackedModes.contains(.compare),
            requireSecondCheck: requireSecondCheck,
            outputLengthCap: outputLengthCap,
            tonePolicy: tonePolicy,
            templatePolicy: templatePolicy,
            delayWindow: delayType,
            substituteRequired: substituteType != nil,
            escalationHintRef: sovereignHintLevel
        )
    }

    var riskCard: BASRiskCard {
        BASRiskCard(
            totalRisk: totalRisk,
            riskLevel: riskLevel,
            factors: reasonCodes,
            uncertainty: uncertainty,
            irreversibility: irreversibility,
            manipulationStrength: manipulationStrength,
            gsiScore: gsiScore,
            recommendedMode: recommendedMode,
            stackedModes: stackedModes,
            assertionCeiling: assertionCeiling ?? "standard",
            delayType: delayType,
            substituteType: substituteType,
            sovereignHintLevel: sovereignHintLevel
        )
    }
}

public struct BASNeuralLeaseReceipt: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var leaseID: String?
    public var organsUsed: [BASNeuralOrgan]
    public var loopsUsed: Int
    public var energyUsed: Double
    public var decodeTokensUsed: Int
    public var degraded: Bool

    public init(
        schemaVersion: String = BASNeuralLeaseReceipt.currentSchemaVersion,
        leaseID: String? = nil,
        organsUsed: [BASNeuralOrgan] = [],
        loopsUsed: Int,
        energyUsed: Double,
        decodeTokensUsed: Int,
        degraded: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.leaseID = leaseID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organsUsed = organsUsed
        self.loopsUsed = max(0, loopsUsed)
        self.energyUsed = min(max(energyUsed, 0), 1)
        self.decodeTokensUsed = max(0, decodeTokensUsed)
        self.degraded = degraded
    }
}

public enum BASBreathMode: String, Codable, CaseIterable, Sendable {
    case light
    case structured
    case deepExchange
    case `guard`
    case quarantine
    case lockdown
}

public enum BASBreathPhase: String, Codable, CaseIterable, Sendable {
    case inhale
    case exchange
    case fold
    case rest
    case resume
}

public enum BASResumeFallbackMode: String, Codable, CaseIterable, Sendable {
    case shallowRetry
    case rollbackAnchor
    case safeHotPack
    case lockdownShell
}

public struct BASMorphGraph: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var graphID: String
    public var activeOrgans: [BASNeuralOrgan]
    public var executionOrder: [String]
    public var precisionMap: [BASNeuralOrganPrecision]
    public var deviceRouteMap: [String: String]
    public var thermalProfile: [String]
    public var sovereignConstraints: [String]

    public init(
        schemaVersion: String = BASMorphGraph.currentSchemaVersion,
        graphID: String,
        activeOrgans: [BASNeuralOrgan],
        executionOrder: [String],
        precisionMap: [BASNeuralOrganPrecision] = [],
        deviceRouteMap: [String: String] = [:],
        thermalProfile: [String] = [],
        sovereignConstraints: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.graphID = graphID
        self.activeOrgans = activeOrgans
        self.executionOrder = executionOrder
        self.precisionMap = precisionMap
        self.deviceRouteMap = deviceRouteMap
        self.thermalProfile = thermalProfile
        self.sovereignConstraints = sovereignConstraints
    }
}

public struct BASHotColdMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hotOrgans: [BASNeuralOrgan]
    public var warmOrgans: [BASNeuralOrgan]
    public var coldOrgans: [BASNeuralOrgan]
    public var preloadPolicy: String
    public var evictionPolicy: String

    public init(
        schemaVersion: String = BASHotColdMap.currentSchemaVersion,
        hotOrgans: [BASNeuralOrgan] = [],
        warmOrgans: [BASNeuralOrgan] = [],
        coldOrgans: [BASNeuralOrgan] = [],
        preloadPolicy: String,
        evictionPolicy: String
    ) {
        self.schemaVersion = schemaVersion
        self.hotOrgans = hotOrgans
        self.warmOrgans = warmOrgans
        self.coldOrgans = coldOrgans
        self.preloadPolicy = preloadPolicy.trimmingCharacters(in: .whitespacesAndNewlines)
        self.evictionPolicy = evictionPolicy.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASPrecisionProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var organPrecisions: [BASNeuralOrganPrecision]
    public var lockedPrecisions: [BASNeuralOrgan]
    public var degradationOrder: [BASNeuralPrecisionTier]
    public var guardSafeFloor: BASNeuralPrecisionTier

    public init(
        schemaVersion: String = BASPrecisionProfile.currentSchemaVersion,
        organPrecisions: [BASNeuralOrganPrecision] = [],
        lockedPrecisions: [BASNeuralOrgan] = [],
        degradationOrder: [BASNeuralPrecisionTier] = [],
        guardSafeFloor: BASNeuralPrecisionTier
    ) {
        self.schemaVersion = schemaVersion
        self.organPrecisions = organPrecisions
        self.lockedPrecisions = lockedPrecisions
        self.degradationOrder = degradationOrder
        self.guardSafeFloor = guardSafeFloor
    }
}

public struct BASResumeFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var resumeID: String
    public var sourceFoldID: String
    public var resumeDepth: Int
    public var requiredOrgans: [BASNeuralOrgan]
    public var consistencyChecks: [String]
    public var fallbackMode: BASResumeFallbackMode

    public init(
        schemaVersion: String = BASResumeFrame.currentSchemaVersion,
        resumeID: String,
        sourceFoldID: String,
        resumeDepth: Int,
        requiredOrgans: [BASNeuralOrgan] = [],
        consistencyChecks: [String] = [],
        fallbackMode: BASResumeFallbackMode
    ) {
        self.schemaVersion = schemaVersion
        self.resumeID = resumeID
        self.sourceFoldID = sourceFoldID
        self.resumeDepth = max(0, resumeDepth)
        self.requiredOrgans = requiredOrgans
        self.consistencyChecks = consistencyChecks
        self.fallbackMode = fallbackMode
    }
}

public struct BASRollbackAnchor: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var anchorID: String
    public var safeSnapshotRef: String
    public var foldRefs: [String]
    public var hostVersionRef: String?
    public var cacheStateRef: String?
    public var integrityHash: String

    public init(
        schemaVersion: String = BASRollbackAnchor.currentSchemaVersion,
        anchorID: String,
        safeSnapshotRef: String,
        foldRefs: [String] = [],
        hostVersionRef: String? = nil,
        cacheStateRef: String? = nil,
        integrityHash: String
    ) {
        self.schemaVersion = schemaVersion
        self.anchorID = anchorID
        self.safeSnapshotRef = safeSnapshotRef
        self.foldRefs = foldRefs
        self.hostVersionRef = hostVersionRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cacheStateRef = cacheStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityHash = integrityHash
    }
}

public struct BASLungState: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var breathMode: BASBreathMode
    public var breathPhase: BASBreathPhase
    public var thermalPressure: Int
    public var cachePressure: Int
    public var restoreReadiness: Double
    public var rollbackAnchorRef: String?

    public init(
        schemaVersion: String = BASLungState.currentSchemaVersion,
        breathMode: BASBreathMode,
        breathPhase: BASBreathPhase,
        thermalPressure: Int,
        cachePressure: Int,
        restoreReadiness: Double,
        rollbackAnchorRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.breathMode = breathMode
        self.breathPhase = breathPhase
        self.thermalPressure = max(0, min(thermalPressure, 100))
        self.cachePressure = max(0, min(cachePressure, 100))
        self.restoreReadiness = min(max(restoreReadiness, 0), 1)
        self.rollbackAnchorRef = rollbackAnchorRef?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASBreathSchedulerFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var schedulerID: String
    public var cadenceTag: String
    public var checkpointCadence: String
    public var microSleepWindowMs: Int
    public var backgroundMaintenanceWindowMs: Int
    public var allowsBackgroundMaintenance: Bool
    public var allowsMicroSleep: Bool
    public var resumeBudgetClass: String
    public var schedulerReasonCodes: [String]

    public init(
        schemaVersion: String = BASBreathSchedulerFrame.currentSchemaVersion,
        schedulerID: String,
        cadenceTag: String,
        checkpointCadence: String,
        microSleepWindowMs: Int,
        backgroundMaintenanceWindowMs: Int,
        allowsBackgroundMaintenance: Bool,
        allowsMicroSleep: Bool,
        resumeBudgetClass: String,
        schedulerReasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.schedulerID = schedulerID
        self.cadenceTag = cadenceTag.trimmingCharacters(in: .whitespacesAndNewlines)
        self.checkpointCadence = checkpointCadence.trimmingCharacters(in: .whitespacesAndNewlines)
        self.microSleepWindowMs = max(0, microSleepWindowMs)
        self.backgroundMaintenanceWindowMs = max(0, backgroundMaintenanceWindowMs)
        self.allowsBackgroundMaintenance = allowsBackgroundMaintenance
        self.allowsMicroSleep = allowsMicroSleep
        self.resumeBudgetClass = resumeBudgetClass.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schedulerReasonCodes = schedulerReasonCodes
    }
}

public struct BASLatentTissueState: Equatable, Sendable {
    public var scoutState: String?
    public var cortexState: String?
    public var simuState: String?
    public var criticState: String?
    public var riskState: String?
    public var permitState: String?
    public var memoryCodecState: String?
    public var hostModState: String?
    public var toolIntentState: String?
    public var consistencyState: String?
    public var stubState: String?

    public init(
        scoutState: String? = nil,
        cortexState: String? = nil,
        simuState: String? = nil,
        criticState: String? = nil,
        riskState: String? = nil,
        permitState: String? = nil,
        memoryCodecState: String? = nil,
        hostModState: String? = nil,
        toolIntentState: String? = nil,
        consistencyState: String? = nil,
        stubState: String? = nil
    ) {
        self.scoutState = scoutState
        self.cortexState = cortexState
        self.simuState = simuState
        self.criticState = criticState
        self.riskState = riskState
        self.permitState = permitState
        self.memoryCodecState = memoryCodecState
        self.hostModState = hostModState
        self.toolIntentState = toolIntentState
        self.consistencyState = consistencyState
        self.stubState = stubState
    }
}

public struct BASNeuralCoreFrame: Equatable, Sendable {
    public var organMap: BASNeuralOrganMap
    public var tissueState: BASLatentTissueState
    public var degradedReasonCodes: [String]

    public init(
        organMap: BASNeuralOrganMap,
        tissueState: BASLatentTissueState = BASLatentTissueState(),
        degradedReasonCodes: [String] = []
    ) {
        self.organMap = organMap
        self.tissueState = tissueState
        self.degradedReasonCodes = degradedReasonCodes
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

public enum BASCourtVetoType: String, Codable, CaseIterable, Sendable {
    case boundary
    case dignity
    case hostConstitution
    case irreversibility
    case sovereignPrecondition
    case calibration
}

public struct BASVetoMark: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var vetoType: BASCourtVetoType
    public var reasonCodes: [String]
    public var compensable: Bool

    public init(
        schemaVersion: String = BASVetoMark.currentSchemaVersion,
        candidateID: String,
        vetoType: BASCourtVetoType,
        reasonCodes: [String] = [],
        compensable: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.vetoType = vetoType
        self.reasonCodes = reasonCodes
        self.compensable = compensable
    }
}

public struct BASTradeoffLedger: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var candidateID: String
    public var gains: [String]
    public var costs: [String]
    public var sacrifices: [String]
    public var unresolvedTensions: [String]

    public init(
        schemaVersion: String = BASTradeoffLedger.currentSchemaVersion,
        candidateID: String,
        gains: [String] = [],
        costs: [String] = [],
        sacrifices: [String] = [],
        unresolvedTensions: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.gains = gains
        self.costs = costs
        self.sacrifices = sacrifices
        self.unresolvedTensions = unresolvedTensions
    }
}

public enum BASAgencyReservationMode: String, Codable, CaseIterable, Sendable {
    case retainChoice
    case compareOnly
    case delayRight
    case noAutoMerge
}

public struct BASAgencyReservation: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var mode: BASAgencyReservationMode
    public var reasons: [String]
    public var expiresWith: String?

    public init(
        schemaVersion: String = BASAgencyReservation.currentSchemaVersion,
        mode: BASAgencyReservationMode,
        reasons: [String] = [],
        expiresWith: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.reasons = reasons
        self.expiresWith = expiresWith?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASRemandOrder: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var targetLayer: String
    public var requiredWork: [String]
    public var reasonCodes: [String]

    public init(
        schemaVersion: String = BASRemandOrder.currentSchemaVersion,
        targetLayer: String,
        requiredWork: [String] = [],
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.targetLayer = targetLayer.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiredWork = requiredWork
        self.reasonCodes = reasonCodes
    }
}

public struct BASCourtDecisionDraft: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var preferredCandidateID: String
    public var fallbackCandidateIDs: [String]
    public var guardCandidateID: String?
    public var requiredDisclosures: [String]
    public var unresolvedCosts: [String]
    public var agencyMode: BASAgencyReservationMode?
    public var readinessLevel: String

    public init(
        schemaVersion: String = BASCourtDecisionDraft.currentSchemaVersion,
        preferredCandidateID: String,
        fallbackCandidateIDs: [String] = [],
        guardCandidateID: String? = nil,
        requiredDisclosures: [String] = [],
        unresolvedCosts: [String] = [],
        agencyMode: BASAgencyReservationMode? = nil,
        readinessLevel: String
    ) {
        self.schemaVersion = schemaVersion
        self.preferredCandidateID = preferredCandidateID
        self.fallbackCandidateIDs = fallbackCandidateIDs
        self.guardCandidateID = guardCandidateID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiredDisclosures = requiredDisclosures
        self.unresolvedCosts = unresolvedCosts
        self.agencyMode = agencyMode
        self.readinessLevel = readinessLevel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASMergedChoice: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var candidateID: String
    public var title: String
    public var actionSummary: String
    public var vetoApplied: Bool
    public var vetoReasonCodes: [String]
    public var vetoMarks: [BASVetoMark]?
    public var tradeoffLedgers: [BASTradeoffLedger]?
    public var agencyReservation: BASAgencyReservation?
    public var remandOrders: [BASRemandOrder]?
    public var courtDecisionDraft: BASCourtDecisionDraft?

    public init(
        schemaVersion: String = BASMergedChoice.currentSchemaVersion,
        candidateID: String,
        title: String,
        actionSummary: String,
        vetoApplied: Bool = false,
        vetoReasonCodes: [String] = [],
        vetoMarks: [BASVetoMark]? = nil,
        tradeoffLedgers: [BASTradeoffLedger]? = nil,
        agencyReservation: BASAgencyReservation? = nil,
        remandOrders: [BASRemandOrder]? = nil,
        courtDecisionDraft: BASCourtDecisionDraft? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
        self.title = title
        self.actionSummary = actionSummary
        self.vetoApplied = vetoApplied
        self.vetoReasonCodes = vetoReasonCodes
        self.vetoMarks = vetoMarks
        self.tradeoffLedgers = tradeoffLedgers
        self.agencyReservation = agencyReservation
        self.remandOrders = remandOrders
        self.courtDecisionDraft = courtDecisionDraft
    }
}

public enum BASThoughtStopReason: String, Codable, CaseIterable, Sendable {
    case candidateStable
    case riskConverged
    case uncertaintyBelowThreshold
    case maxLoopsReached
    case blocked
    case replaced
    case guardTakeover
}

public struct BASThoughtFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.11.0"

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
    public var organMap: BASNeuralOrganMap?
    public var candidateFrontier: BASCandidateFrontier?
    public var counterfactualBundles: [BASCounterfactualBundle]?
    public var critiqueBundles: [BASCritiqueBundle]?
    public var uncertaintyLedger: BASUncertaintyLedger?
    public var evidenceDebts: [BASEvidenceDebt]?
    public var convergenceCertificate: BASConvergenceCertificate?
    public var loopLeaseReceipt: BASLoopLeaseReceipt?
    public var sovereignBreakpointHints: [BASSovereignBreakpointHint]?
    public var vetoMarks: [BASVetoMark]?
    public var tradeoffLedgers: [BASTradeoffLedger]?
    public var agencyReservation: BASAgencyReservation?
    public var remandOrders: [BASRemandOrder]?
    public var courtDecisionDraft: BASCourtDecisionDraft?
    public var riskBindings: [BASRiskPermitBinding]?
    public var riskDecisionPackage: BASRiskDecisionPackage?
    public var toolIntentEnvelope: BASToolIntentEnvelope?
    public var neuralLeaseReceipt: BASNeuralLeaseReceipt?
    public var stabilityScore: Double
    public var stopReason: BASThoughtStopReason?
    /// M55 — L10 tri-self tribunal per-voice observation bundle
    /// derived from this frame's triScores / vetoMarks / remandOrders
    /// / courtDecisionDraft. `nil` when the frame was constructed by a
    /// caller that predates M55 (legacy path) or when an explicit
    /// `derive(...)` call was skipped. Load-bearing consumers (M32 L10
    /// coverage projection, L14 audit surface) read this field
    /// directly; coherent-by-construction with the rest of the frame
    /// when populated.
    public var tribunalObservationBundle:
        BASTribunalObservationBundle?
    /// M56 — L11 risk climate per-candidate / per-package observation
    /// bundle derived from this frame's `riskBindings` (preferred, one
    /// binding per candidate) or `riskDecisionPackage` (fallback when
    /// no bindings materialized). Six-kind signal surface (hazard,
    /// irreversibility, harmPotential always emitted; consequence
    /// horizon / novelty / gate pressure gated by package presence,
    /// uncertainty, and manipulation/mode-shift respectively).
    /// Load-bearing consumers (M32 L11 coverage projection, L14 audit
    /// surface) read this field directly; coherent-by-construction
    /// with `riskBindings` / `riskDecisionPackage` when populated.
    public var riskObservationBundle:
        BASRiskObservationBundle?
    /// M57 — L12 gentle-hand per-subject render observation bundle
    /// derived from this frame's `riskBindings` (preferred, one binding
    /// per candidate) or `riskDecisionPackage` (fallback) combined with
    /// the final `BASRenderedOutput` the action service produced. Six
    /// kinds (suggestion, selection, render, deferral, downgrade,
    /// escalation) emit only when their structural precondition holds
    /// — an empty-body render yields no `render` kind, a permit mode
    /// equal to its recommendation yields no direction kind, a sovereign
    /// hint yields an unconditional `escalation`. Load-bearing consumers
    /// (M32 L12 coverage projection, L14 audit surface) read this field
    /// directly; coherent-by-construction with `riskBindings` and the
    /// rendered output on the same turn.
    public var softHandObservationBundle:
        BASSoftHandObservationBundle?
    /// M58 — L13 evolution per-ticket update observation bundle
    /// derived from the turn's finalized `[BASUpdateTicket]` list
    /// (the governed tickets, post `buildEvolutionGovernanceArtifacts`).
    /// Six kinds (submission, hostChangeProposed, memoryWriteProposed,
    /// ruleCandidateProposed, conflictDetected, reviewRequired) emit
    /// only when their structural precondition holds — a ticket with
    /// only a memory-write suggestion yields one submission and one
    /// memoryWriteProposed; a conflicted host-change ticket that
    /// requires review yields four signals. A turn with zero tickets
    /// yields a bundle with zero observations — the legitimate
    /// "no-evolution turn" signal. Load-bearing consumers (M32 L13
    /// coverage projection, L14 audit surface) read this field
    /// directly; coherent-by-construction with the governed ticket
    /// list on the same turn.
    public var updateTicketObservationBundle:
        BASUpdateTicketObservationBundle?
    /// M59 — L4 world-prior per-candidate / per-signal observation
    /// bundle derived from this frame's `candidates`,
    /// `counterfactualBundles`, `critiqueBundles`, and
    /// `uncertaintyLedger`. Six kinds (templateMatched,
    /// counterfactualSeeded, domainBridgeCrossed,
    /// boundaryBedrockConsulted, evidenceRevised, priorContradiction)
    /// emit only when their structural precondition holds — a
    /// candidate without a counterfactual bundle yields only one
    /// templateMatched; a counterfactual crossing two domains yields
    /// counterfactualSeeded plus domainBridgeCrossed; a critique with
    /// both high boundaryConflict AND high critiqueStrength yields
    /// priorContradiction on top of boundaryBedrockConsulted. A turn
    /// with zero candidates yields a bundle with zero observations —
    /// the legitimate "no-L4-turn" signal. Load-bearing consumers
    /// (M32 L4 coverage projection, L14 audit surface) read this
    /// field directly; coherent-by-construction with the populated
    /// thought frame on the same turn.
    public var worldPriorObservationBundle:
        BASWorldPriorObservationBundle?
    /// M60 — L1 灯芯层 per-turn kernel observation bundle derived from
    /// the turn's finalized `BASBudgetFrame` (the routed budget, post
    /// `powerClockService.planBudget` + `normalizeBudget` + device
    /// routing + maintenance scheduling). Up to six kinds
    /// (leaseGranted, runModeDetermined, thermalReadingObserved,
    /// guardLevelEscalated, maintenanceClassified, deviceRouteSelected)
    /// emit in a fixed order — four are unconditional, two gate on
    /// structural precondition (guard level above nominal / a
    /// non-none maintenance class with maintenance allowed). Shape
    /// classification is turn-level (lockdown / dormant / emergency /
    /// throttled / maintenance / nominal). Load-bearing consumers
    /// (future L1 coverage refinements, L14 audit surface) read this
    /// field directly; coherent-by-construction with the routed budget
    /// on the same turn.
    public var leaseLifeObservationBundle:
        BASLeaseLifeObservationBundle?
    /// M61 — L5 宿纹层 per-turn host-constitution governance
    /// observation bundle derived from the turn's active
    /// `BASHostConstitution`, `BASHostVersionTree`, and optional
    /// `BASForgetRequest`. Up to six kinds emit in a fixed order —
    /// anchorActive XOR constitutionUnbootstrapped (exactly one of
    /// the two always present), followed by versionCommitted /
    /// candidatePending / versionFrozen iterations over the version
    /// tree, and a single forgetInFlight when a delete cascade is
    /// active. Shape classification is turn-level (unbootstrapped /
    /// forgetting / frozen / governing / quiet). Load-bearing
    /// consumers (M40 L5 coverage projection parity, L14 audit
    /// surface) read this field directly; coherent-by-construction
    /// with the L5 vault state on the same turn.
    public var hostConstitutionObservationBundle:
        BASHostConstitutionObservationBundle?

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
        organMap: BASNeuralOrganMap? = nil,
        candidateFrontier: BASCandidateFrontier? = nil,
        counterfactualBundles: [BASCounterfactualBundle]? = nil,
        critiqueBundles: [BASCritiqueBundle]? = nil,
        uncertaintyLedger: BASUncertaintyLedger? = nil,
        evidenceDebts: [BASEvidenceDebt]? = nil,
        convergenceCertificate: BASConvergenceCertificate? = nil,
        loopLeaseReceipt: BASLoopLeaseReceipt? = nil,
        sovereignBreakpointHints: [BASSovereignBreakpointHint]? = nil,
        vetoMarks: [BASVetoMark]? = nil,
        tradeoffLedgers: [BASTradeoffLedger]? = nil,
        agencyReservation: BASAgencyReservation? = nil,
        remandOrders: [BASRemandOrder]? = nil,
        courtDecisionDraft: BASCourtDecisionDraft? = nil,
        riskBindings: [BASRiskPermitBinding]? = nil,
        riskDecisionPackage: BASRiskDecisionPackage? = nil,
        toolIntentEnvelope: BASToolIntentEnvelope? = nil,
        neuralLeaseReceipt: BASNeuralLeaseReceipt? = nil,
        stabilityScore: Double = 0,
        stopReason: BASThoughtStopReason? = nil,
        tribunalObservationBundle:
            BASTribunalObservationBundle? = nil,
        riskObservationBundle:
            BASRiskObservationBundle? = nil,
        softHandObservationBundle:
            BASSoftHandObservationBundle? = nil,
        updateTicketObservationBundle:
            BASUpdateTicketObservationBundle? = nil,
        worldPriorObservationBundle:
            BASWorldPriorObservationBundle? = nil,
        leaseLifeObservationBundle:
            BASLeaseLifeObservationBundle? = nil,
        hostConstitutionObservationBundle:
            BASHostConstitutionObservationBundle? = nil
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
        self.organMap = organMap
        self.candidateFrontier = candidateFrontier
        self.counterfactualBundles = counterfactualBundles
        self.critiqueBundles = critiqueBundles
        self.uncertaintyLedger = uncertaintyLedger
        self.evidenceDebts = evidenceDebts
        self.convergenceCertificate = convergenceCertificate
        self.loopLeaseReceipt = loopLeaseReceipt
        self.sovereignBreakpointHints = sovereignBreakpointHints
        self.vetoMarks = vetoMarks
        self.tradeoffLedgers = tradeoffLedgers
        self.agencyReservation = agencyReservation
        self.remandOrders = remandOrders
        self.courtDecisionDraft = courtDecisionDraft
        self.riskBindings = riskBindings
        self.riskDecisionPackage = riskDecisionPackage
        self.toolIntentEnvelope = toolIntentEnvelope
        self.neuralLeaseReceipt = neuralLeaseReceipt
        self.stabilityScore = min(max(stabilityScore, 0), 1)
        self.stopReason = stopReason
        self.tribunalObservationBundle = tribunalObservationBundle
        self.riskObservationBundle = riskObservationBundle
        self.softHandObservationBundle = softHandObservationBundle
        self.updateTicketObservationBundle =
            updateTicketObservationBundle
        self.worldPriorObservationBundle =
            worldPriorObservationBundle
        self.leaseLifeObservationBundle =
            leaseLifeObservationBundle
        self.hostConstitutionObservationBundle =
            hostConstitutionObservationBundle
    }
}

extension BASThoughtFrame {
    /// M55 — Return a copy of this frame with a freshly derived
    /// `tribunalObservationBundle` attached. Pure function: no I/O, no
    /// actor hop, deterministic for the same (frame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the tribunal has
    /// settled — after `triSelfService.mergeChoice` (and any
    /// reconciliation rerun) has filled in triScores / vetoMarks /
    /// tradeoffLedgers / remandOrders / courtDecisionDraft — so the
    /// bundle flows into the same turn-audit record that the L14
    /// surface later signs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedTribunalObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.tribunalObservationBundle =
            BASTribunalObservationBundle.derive(
                from: self,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M56 — Return a copy of this frame with a freshly derived
    /// `riskObservationBundle` attached. Pure function: no I/O, no
    /// actor hop, deterministic for the same (frame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the L11 risk
    /// climate has settled — after `riskService.buildRiskDecisionPackage`
    /// plus `normalizeRiskDecision` / `materializeRiskBindings` have
    /// populated `riskBindings` / `riskDecisionPackage` — so the bundle
    /// flows into the same turn-audit record that the L14 surface
    /// later signs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedRiskObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.riskObservationBundle =
            BASRiskObservationBundle.derive(
                from: self,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M57 — Return a copy of this frame with a freshly derived
    /// `softHandObservationBundle` attached. Pure function: no I/O, no
    /// actor hop, deterministic for the same (frame, renderedOutput,
    /// turnID, sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the L12 gentle
    /// hand has finished rendering — after `actionService.render` +
    /// `projectedRenderedOutput` produce the final `BASRenderedOutput`
    /// — so the bundle flows into the same turn-audit record that the
    /// L14 surface later signs.
    ///
    /// Unlike the tribunal / risk derivations, this one takes the
    /// rendered output as an explicit argument because the render is
    /// the primary source of `selection` / `render` / `deferral`
    /// evidence; the thought frame alone (with its `riskBindings` /
    /// `riskDecisionPackage`) carries the suggestion side.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedSoftHandObservationBundle(
        renderedOutput: BASRenderedOutput,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.softHandObservationBundle =
            BASSoftHandObservationBundle.derive(
                from: self,
                renderedOutput: renderedOutput,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M58 — Return a copy of this frame with a freshly derived
    /// `updateTicketObservationBundle` attached. Pure function: no I/O,
    /// no actor hop, deterministic for the same (tickets, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the L13 evolution
    /// service has finalized its ticket list — after
    /// `evolutionService.buildTickets` + `normalizeUpdateTickets` +
    /// `buildEvolutionGovernanceArtifacts` have settled the governed
    /// ticket list — so the bundle flows into the same turn-audit
    /// record that the L14 surface later signs.
    ///
    /// Unlike the tribunal / risk / soft-hand derivations, this one
    /// takes the finalized ticket list as an explicit argument because
    /// the tickets live outside the thought frame (on
    /// `evolutionGovernance.updateTickets`). Tickets are the only
    /// source of submission / mutation-proposal / conflict / review
    /// evidence; the frame provides only the turn coordinates.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedUpdateTicketObservationBundle(
        updateTickets: [BASUpdateTicket],
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.updateTicketObservationBundle =
            BASUpdateTicketObservationBundle.derive(
                fromUpdateTickets: updateTickets,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M59 — Return a copy of this frame with a freshly derived
    /// `worldPriorObservationBundle` attached. Pure function: no I/O,
    /// no actor hop, deterministic for the same (frame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where
    /// `materializeThoughtArtifacts` has filled in counterfactual
    /// bundles / critique bundles / uncertainty ledger — after
    /// `publicProjection` merges and before the tri-self tribunal
    /// reads the frame — so the bundle flows into the same turn-audit
    /// record that the L14 surface later signs, and downstream layers
    /// (L10 tribunal, L11 risk climate, L12 soft hand, L13 evolution)
    /// can reconcile their own per-candidate signals against the
    /// L4 reasoning that fired on the same candidate.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedWorldPriorObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.worldPriorObservationBundle =
            BASWorldPriorObservationBundle.derive(
                fromThoughtFrame: self,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M60 — Return a copy of this frame with a freshly derived
    /// `leaseLifeObservationBundle` attached. Pure function: no I/O,
    /// no actor hop, deterministic for the same (budgetFrame, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the routed
    /// `BASBudgetFrame` has been finalized (post
    /// `powerClockService.planBudget` + `normalizeBudget` + device
    /// routing + maintenance scheduling) — right after the M53 derived
    /// sessionID / turnID is available, so the bundle shares
    /// coordinates with the L4..L13 bundles on the same turn. This
    /// keeps L1 observations coherent-by-construction with the L14
    /// audit record.
    ///
    /// Unlike the tribunal / risk / soft-hand / world-prior
    /// derivations, this one takes the budget frame as an explicit
    /// argument because the thought frame itself does not carry L1
    /// kernel state — the budget is the single source of truth for
    /// run mode / guard level / maintenance / device route on this
    /// turn.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedLeaseLifeObservationBundle(
        budgetFrame: BASBudgetFrame,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.leaseLifeObservationBundle =
            BASLeaseLifeObservationBundle.derive(
                fromBudgetFrame: budgetFrame,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M61 — Return a copy of this frame with a freshly derived
    /// `hostConstitutionObservationBundle` attached. Pure function:
    /// no I/O, no actor hop, deterministic for the same
    /// (constitution, versionTree, forgetRequest, turnID, sessionID,
    /// emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the L5 vault
    /// state for the turn is frozen — the coordinator already carries
    /// `hostConstitution` / `hostVersionTree` / `hostForgetRequest`
    /// as static reference fields, and M61 surfaces them as typed
    /// per-subject evidence into the same turn-audit record the L14
    /// surface later signs.
    ///
    /// Unlike the tribunal / risk / soft-hand / world-prior
    /// derivations, this one takes the vault triple as explicit
    /// arguments because the thought frame itself does not carry L5
    /// governance state — the coordinator's three fields are the
    /// single source of truth for active version / committed tree /
    /// frozen IDs / pending candidates / forget request on this turn.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals", not
    /// "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedHostConstitutionObservationBundle(
        constitution: BASHostConstitution?,
        versionTree: BASHostVersionTree?,
        forgetRequest: BASForgetRequest?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.hostConstitutionObservationBundle =
            BASHostConstitutionObservationBundle.derive(
                fromHostConstitution: constitution,
                versionTree: versionTree,
                forgetRequest: forgetRequest,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }
}

public struct BASThermalExchangeFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var exchangeID: String
    public var exchangeMode: String
    public var predictedThermalBand: String
    public var coolingActions: [String]
    public var suppressedOrgans: [BASNeuralOrgan]
    public var reroutedOrgans: [BASNeuralOrgan]
    public var rerouteTargets: [String: String]
    public var precisionDowngradePlan: [BASNeuralOrganPrecision]
    public var exchangeReasonCodes: [String]

    public init(
        schemaVersion: String = BASThermalExchangeFrame.currentSchemaVersion,
        exchangeID: String,
        exchangeMode: String,
        predictedThermalBand: String,
        coolingActions: [String] = [],
        suppressedOrgans: [BASNeuralOrgan] = [],
        reroutedOrgans: [BASNeuralOrgan] = [],
        rerouteTargets: [String: String] = [:],
        precisionDowngradePlan: [BASNeuralOrganPrecision] = [],
        exchangeReasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exchangeID = exchangeID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.exchangeMode = exchangeMode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.predictedThermalBand = predictedThermalBand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coolingActions = coolingActions
        self.suppressedOrgans = suppressedOrgans
        self.reroutedOrgans = reroutedOrgans
        self.rerouteTargets = rerouteTargets.reduce(into: [:]) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false, value.isEmpty == false else { return }
            result[key] = value
        }
        self.precisionDowngradePlan = precisionDowngradePlan
        self.exchangeReasonCodes = exchangeReasonCodes
    }
}

public struct BASIntegrityWeaveFrame: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var weaveID: String
    public var foldChecksum: String
    public var rollbackIntegrityHash: String
    public var requiredChecks: [String]
    public var completedChecks: [String]
    public var failedChecks: [String]
    public var purityState: String
    public var contaminationRefs: [String]
    public var trustedSnapshotRef: String?
    public var verificationHash: String

    public init(
        schemaVersion: String = BASIntegrityWeaveFrame.currentSchemaVersion,
        weaveID: String,
        foldChecksum: String,
        rollbackIntegrityHash: String,
        requiredChecks: [String] = [],
        completedChecks: [String] = [],
        failedChecks: [String] = [],
        purityState: String,
        contaminationRefs: [String] = [],
        trustedSnapshotRef: String? = nil,
        verificationHash: String
    ) {
        self.schemaVersion = schemaVersion
        self.weaveID = weaveID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.foldChecksum = foldChecksum.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rollbackIntegrityHash = rollbackIntegrityHash.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiredChecks = requiredChecks
        self.completedChecks = completedChecks
        self.failedChecks = failedChecks
        self.purityState = purityState.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contaminationRefs = contaminationRefs
        self.trustedSnapshotRef = trustedSnapshotRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.verificationHash = verificationHash.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASOrganPackage: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var packageID: String
    public var organType: BASNeuralOrgan
    public var sizeMB: Int
    public var precisionOptions: [BASNeuralPrecisionTier]
    public var loadTimeMs: Int
    public var thermalCost: Int
    public var sovereignClass: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case packageID
        case organType
        case sizeMB
        case precisionOptions
        case loadTimeMs
        case thermalCost
        case sovereignClass
    }

    public init(
        schemaVersion: String = BASOrganPackage.currentSchemaVersion,
        packageID: String,
        organType: BASNeuralOrgan,
        sizeMB: Int,
        precisionOptions: [BASNeuralPrecisionTier] = [],
        loadTimeMs: Int,
        thermalCost: Int,
        sovereignClass: String
    ) {
        self.schemaVersion = schemaVersion
        self.packageID = packageID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organType = organType
        self.sizeMB = max(0, sizeMB)
        self.precisionOptions = precisionOptions
        self.loadTimeMs = max(0, loadTimeMs)
        self.thermalCost = max(0, thermalCost)
        self.sovereignClass = sovereignClass.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASOrganPackage.currentSchemaVersion
        packageID = try container.decode(String.self, forKey: .packageID)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        organType = try container.decode(BASNeuralOrgan.self, forKey: .organType)
        sizeMB = max(0, try container.decodeIfPresent(Int.self, forKey: .sizeMB) ?? 0)
        precisionOptions = try container.decodeIfPresent(
            [BASNeuralPrecisionTier].self,
            forKey: .precisionOptions
        ) ?? []
        loadTimeMs = max(0, try container.decodeIfPresent(Int.self, forKey: .loadTimeMs) ?? 0)
        thermalCost = max(0, try container.decodeIfPresent(Int.self, forKey: .thermalCost) ?? 0)
        sovereignClass = try container.decodeIfPresent(String.self, forKey: .sovereignClass)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

public struct BASOrganDeltaPlan: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var planID: String
    public var deltaMode: String
    public var activatePackageIDs: [String]
    public var preloadPackageIDs: [String]
    public var evictPackageIDs: [String]
    public var retainPackageIDs: [String]
    public var rollbackSafeRetainedPackageIDs: [String]
    public var triggeredActuationKinds: [BASSovereignActuationKind]
    public var reasonCodes: [String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case planID
        case deltaMode
        case activatePackageIDs
        case preloadPackageIDs
        case evictPackageIDs
        case retainPackageIDs
        case rollbackSafeRetainedPackageIDs
        case triggeredActuationKinds
        case reasonCodes
    }

    public init(
        schemaVersion: String = BASOrganDeltaPlan.currentSchemaVersion,
        planID: String,
        deltaMode: String,
        activatePackageIDs: [String] = [],
        preloadPackageIDs: [String] = [],
        evictPackageIDs: [String] = [],
        retainPackageIDs: [String] = [],
        rollbackSafeRetainedPackageIDs: [String] = [],
        triggeredActuationKinds: [BASSovereignActuationKind] = [],
        reasonCodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.planID = planID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.deltaMode = deltaMode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.activatePackageIDs = activatePackageIDs
        self.preloadPackageIDs = preloadPackageIDs
        self.evictPackageIDs = evictPackageIDs
        self.retainPackageIDs = retainPackageIDs
        self.rollbackSafeRetainedPackageIDs = rollbackSafeRetainedPackageIDs
        self.triggeredActuationKinds = triggeredActuationKinds
        self.reasonCodes = reasonCodes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASOrganDeltaPlan.currentSchemaVersion
        planID = try container.decode(String.self, forKey: .planID)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        deltaMode = try container.decodeIfPresent(String.self, forKey: .deltaMode)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        activatePackageIDs = try container.decodeIfPresent([String].self, forKey: .activatePackageIDs) ?? []
        preloadPackageIDs = try container.decodeIfPresent([String].self, forKey: .preloadPackageIDs) ?? []
        evictPackageIDs = try container.decodeIfPresent([String].self, forKey: .evictPackageIDs) ?? []
        retainPackageIDs = try container.decodeIfPresent([String].self, forKey: .retainPackageIDs) ?? []
        rollbackSafeRetainedPackageIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .rollbackSafeRetainedPackageIDs
        ) ?? []
        triggeredActuationKinds = try container.decodeIfPresent(
            [BASSovereignActuationKind].self,
            forKey: .triggeredActuationKinds
        ) ?? []
        reasonCodes = try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? []
    }
}

public struct BASThoughtFold: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.7.0"

    public var schemaVersion: String
    public var foldID: String
    public var compactSlots: [String: String]
    public var candidateSignatures: [String]
    public var riskSnapshot: BASRiskCard?
    public var hostEffectSummary: String
    public var restorePointer: String
    public var checksum: String
    public var morphID: String?
    public var organChecksum: String?
    public var frontierChecksum: String?
    public var bindingChecksum: String?
    public var degradedReasonCodes: [String]
    public var tissueSignature: String?
    public var snapshotRef: String?
    public var resumeFrameRef: String?
    public var rollbackAnchorRef: String?
    public var morphGraphRef: String?
    public var hotColdMapRef: String?
    public var precisionProfileRef: String?
    public var lungStateRef: String?
    public var breathSchedulerRef: String?
    public var thermalExchangeRef: String?
    public var integrityWeaveRef: String?
    public var organPackageRefs: [String]
    public var organDeltaPlanRef: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case foldID
        case compactSlots
        case candidateSignatures
        case riskSnapshot
        case hostEffectSummary
        case restorePointer
        case checksum
        case morphID
        case organChecksum
        case frontierChecksum
        case bindingChecksum
        case degradedReasonCodes
        case tissueSignature
        case snapshotRef
        case resumeFrameRef
        case rollbackAnchorRef
        case morphGraphRef
        case hotColdMapRef
        case precisionProfileRef
        case lungStateRef
        case breathSchedulerRef
        case thermalExchangeRef
        case integrityWeaveRef
        case organPackageRefs
        case organDeltaPlanRef
    }

    public init(
        schemaVersion: String = BASThoughtFold.currentSchemaVersion,
        foldID: String,
        compactSlots: [String: String] = [:],
        candidateSignatures: [String] = [],
        riskSnapshot: BASRiskCard? = nil,
        hostEffectSummary: String,
        restorePointer: String,
        checksum: String,
        morphID: String? = nil,
        organChecksum: String? = nil,
        frontierChecksum: String? = nil,
        bindingChecksum: String? = nil,
        degradedReasonCodes: [String] = [],
        tissueSignature: String? = nil,
        snapshotRef: String? = nil,
        resumeFrameRef: String? = nil,
        rollbackAnchorRef: String? = nil,
        morphGraphRef: String? = nil,
        hotColdMapRef: String? = nil,
        precisionProfileRef: String? = nil,
        lungStateRef: String? = nil,
        breathSchedulerRef: String? = nil,
        thermalExchangeRef: String? = nil,
        integrityWeaveRef: String? = nil,
        organPackageRefs: [String] = [],
        organDeltaPlanRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.foldID = foldID
        self.compactSlots = compactSlots
        self.candidateSignatures = candidateSignatures
        self.riskSnapshot = riskSnapshot
        self.hostEffectSummary = hostEffectSummary
        self.restorePointer = restorePointer
        self.checksum = checksum
        self.morphID = morphID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organChecksum = organChecksum?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frontierChecksum = frontierChecksum?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bindingChecksum = bindingChecksum?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.degradedReasonCodes = degradedReasonCodes
        self.tissueSignature = tissueSignature?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.snapshotRef = snapshotRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.resumeFrameRef = resumeFrameRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rollbackAnchorRef = rollbackAnchorRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.morphGraphRef = morphGraphRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hotColdMapRef = hotColdMapRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.precisionProfileRef = precisionProfileRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lungStateRef = lungStateRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.breathSchedulerRef = breathSchedulerRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.thermalExchangeRef = thermalExchangeRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.integrityWeaveRef = integrityWeaveRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.organPackageRefs = organPackageRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.organDeltaPlanRef = organDeltaPlanRef?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            ?? BASThoughtFold.currentSchemaVersion
        foldID = try container.decode(String.self, forKey: .foldID)
        compactSlots = try container.decodeIfPresent([String: String].self, forKey: .compactSlots) ?? [:]
        candidateSignatures = try container.decodeIfPresent([String].self, forKey: .candidateSignatures) ?? []
        riskSnapshot = try container.decodeIfPresent(BASRiskCard.self, forKey: .riskSnapshot)
        hostEffectSummary = try container.decode(String.self, forKey: .hostEffectSummary)
        restorePointer = try container.decode(String.self, forKey: .restorePointer)
        checksum = try container.decode(String.self, forKey: .checksum)
        morphID = try container.decodeIfPresent(String.self, forKey: .morphID)
        organChecksum = try container.decodeIfPresent(String.self, forKey: .organChecksum)
        frontierChecksum = try container.decodeIfPresent(String.self, forKey: .frontierChecksum)
        bindingChecksum = try container.decodeIfPresent(String.self, forKey: .bindingChecksum)
        degradedReasonCodes = try container.decodeIfPresent([String].self, forKey: .degradedReasonCodes) ?? []
        tissueSignature = try container.decodeIfPresent(String.self, forKey: .tissueSignature)
        snapshotRef = try container.decodeIfPresent(String.self, forKey: .snapshotRef)
        resumeFrameRef = try container.decodeIfPresent(String.self, forKey: .resumeFrameRef)
        rollbackAnchorRef = try container.decodeIfPresent(String.self, forKey: .rollbackAnchorRef)
        morphGraphRef = try container.decodeIfPresent(String.self, forKey: .morphGraphRef)
        hotColdMapRef = try container.decodeIfPresent(String.self, forKey: .hotColdMapRef)
        precisionProfileRef = try container.decodeIfPresent(String.self, forKey: .precisionProfileRef)
        lungStateRef = try container.decodeIfPresent(String.self, forKey: .lungStateRef)
        breathSchedulerRef = try container.decodeIfPresent(String.self, forKey: .breathSchedulerRef)
        thermalExchangeRef = try container.decodeIfPresent(String.self, forKey: .thermalExchangeRef)
        integrityWeaveRef = try container.decodeIfPresent(String.self, forKey: .integrityWeaveRef)
        organPackageRefs = try container.decodeIfPresent([String].self, forKey: .organPackageRefs) ?? []
        organDeltaPlanRef = try container.decodeIfPresent(String.self, forKey: .organDeltaPlanRef)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(foldID, forKey: .foldID)
        try container.encode(compactSlots, forKey: .compactSlots)
        try container.encode(candidateSignatures, forKey: .candidateSignatures)
        try container.encodeIfPresent(riskSnapshot, forKey: .riskSnapshot)
        try container.encode(hostEffectSummary, forKey: .hostEffectSummary)
        try container.encode(restorePointer, forKey: .restorePointer)
        try container.encode(checksum, forKey: .checksum)
        try container.encodeIfPresent(morphID, forKey: .morphID)
        try container.encodeIfPresent(organChecksum, forKey: .organChecksum)
        try container.encodeIfPresent(frontierChecksum, forKey: .frontierChecksum)
        try container.encodeIfPresent(bindingChecksum, forKey: .bindingChecksum)
        try container.encode(degradedReasonCodes, forKey: .degradedReasonCodes)
        try container.encodeIfPresent(tissueSignature, forKey: .tissueSignature)
        try container.encodeIfPresent(snapshotRef, forKey: .snapshotRef)
        try container.encodeIfPresent(resumeFrameRef, forKey: .resumeFrameRef)
        try container.encodeIfPresent(rollbackAnchorRef, forKey: .rollbackAnchorRef)
        try container.encodeIfPresent(morphGraphRef, forKey: .morphGraphRef)
        try container.encodeIfPresent(hotColdMapRef, forKey: .hotColdMapRef)
        try container.encodeIfPresent(precisionProfileRef, forKey: .precisionProfileRef)
        try container.encodeIfPresent(lungStateRef, forKey: .lungStateRef)
        try container.encodeIfPresent(breathSchedulerRef, forKey: .breathSchedulerRef)
        try container.encodeIfPresent(thermalExchangeRef, forKey: .thermalExchangeRef)
        try container.encodeIfPresent(integrityWeaveRef, forKey: .integrityWeaveRef)
        try container.encode(organPackageRefs, forKey: .organPackageRefs)
        try container.encodeIfPresent(organDeltaPlanRef, forKey: .organDeltaPlanRef)
    }
}

public struct BASRenderedBoundaryGuide: Codable, Equatable, Sendable {
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    public var toolScope: String
    public var memoryScope: String
    public var escalationHintRef: String?

    public init(
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        toolScope: String,
        memoryScope: String,
        escalationHintRef: String? = nil
    ) {
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.toolScope = toolScope
        self.memoryScope = memoryScope
        self.escalationHintRef = escalationHintRef
    }
}

public struct BASRenderedAgencyGuide: Codable, Equatable, Sendable {
    public var requiresCompare: Bool
    public var requiresSecondCheck: Bool
    public var delayAvailable: Bool
    public var chooseLaterAllowed: Bool
    public var prefersDraftOnly: Bool
    public var localOnlyPreferred: Bool
    public var reservationMode: BASAgencyReservationMode?
    public var reservationReasons: [String]?

    public init(
        requiresCompare: Bool,
        requiresSecondCheck: Bool,
        delayAvailable: Bool,
        chooseLaterAllowed: Bool,
        prefersDraftOnly: Bool,
        localOnlyPreferred: Bool,
        reservationMode: BASAgencyReservationMode? = nil,
        reservationReasons: [String]? = nil
    ) {
        self.requiresCompare = requiresCompare
        self.requiresSecondCheck = requiresSecondCheck
        self.delayAvailable = delayAvailable
        self.chooseLaterAllowed = chooseLaterAllowed
        self.prefersDraftOnly = prefersDraftOnly
        self.localOnlyPreferred = localOnlyPreferred
        self.reservationMode = reservationMode
        self.reservationReasons = reservationReasons
    }
}

public struct BASRenderedDisclosureGuide: Codable, Equatable, Sendable {
    public var assertionCeiling: String
    public var explanationCodes: [String]
    public var uncertaintyVisible: Bool
    public var requiredDisclosures: [String]?
    public var unresolvedCosts: [String]?
    public var remandTargets: [String]?

    public init(
        assertionCeiling: String,
        explanationCodes: [String] = [],
        uncertaintyVisible: Bool,
        requiredDisclosures: [String]? = nil,
        unresolvedCosts: [String]? = nil,
        remandTargets: [String]? = nil
    ) {
        self.assertionCeiling = assertionCeiling
        self.explanationCodes = explanationCodes
        self.uncertaintyVisible = uncertaintyVisible
        self.requiredDisclosures = requiredDisclosures
        self.unresolvedCosts = unresolvedCosts
        self.remandTargets = remandTargets
    }
}

public struct BASRenderedSurfaceGuide: Codable, Equatable, Sendable {
    public var stackedModes: [BASActionPermitMode]
    public var tonePolicy: String
    public var templatePolicy: String
    public var outputLengthCap: Int
    public var boundary: BASRenderedBoundaryGuide
    public var agency: BASRenderedAgencyGuide
    public var disclosure: BASRenderedDisclosureGuide
    public var delayWindow: String?
    public var delayReservation: BASDelayReservation?
    public var protectiveSubstitute: BASProtectiveSubstitute?
    public var sovereignEscalationHint: BASSovereignEscalationHint?

    public init(
        stackedModes: [BASActionPermitMode] = [],
        tonePolicy: String,
        templatePolicy: String,
        outputLengthCap: Int,
        boundary: BASRenderedBoundaryGuide,
        agency: BASRenderedAgencyGuide,
        disclosure: BASRenderedDisclosureGuide,
        delayWindow: String? = nil,
        delayReservation: BASDelayReservation? = nil,
        protectiveSubstitute: BASProtectiveSubstitute? = nil,
        sovereignEscalationHint: BASSovereignEscalationHint? = nil
    ) {
        self.stackedModes = stackedModes
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
        self.outputLengthCap = max(0, outputLengthCap)
        self.boundary = boundary
        self.agency = agency
        self.disclosure = disclosure
        self.delayWindow = delayWindow
        self.delayReservation = delayReservation
        self.protectiveSubstitute = protectiveSubstitute
        self.sovereignEscalationHint = sovereignEscalationHint
    }
}

public struct BASRenderedOutput: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var mode: BASActionPermitMode
    public var headline: String
    public var body: String
    public var alternativeActions: [String]
    public var explanationCodes: [String]
    public var surfaceGuide: BASRenderedSurfaceGuide?

    public init(
        schemaVersion: String = BASRenderedOutput.currentSchemaVersion,
        mode: BASActionPermitMode,
        headline: String,
        body: String,
        alternativeActions: [String] = [],
        explanationCodes: [String] = [],
        surfaceGuide: BASRenderedSurfaceGuide? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.headline = headline
        self.body = body
        self.alternativeActions = alternativeActions
        self.explanationCodes = explanationCodes
        self.surfaceGuide = surfaceGuide
    }
}
