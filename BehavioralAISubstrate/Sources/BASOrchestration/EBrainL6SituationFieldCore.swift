// MARK: - EBrainL6SituationFieldCore — chapter 二百七十八 / M765
//
// Phase Alpha 第四刀:从 EBrainCognitionPlaneCore.swift 抽出 L6
// situation-field types。chapter 一百七十七 vision L6 = "临场眼"
// — emotion / context / power-gradient / urgency-truth /
// consequence-horizon / manipulation-trace / host-resonance /
// continuity / route-hint detectors。
//
// 抽出 ~14 types(M111 L6 whitepaper §5 parity cluster + pre-L6
// context plane scaffolding):
//   - BASContextTaskType / BASContextSceneType (2 enums)
//   - BASRoleGeometry / BASPowerGradient / BASEmotionalWeather
//   - BASUrgencyTruth / BASConsequenceHorizon / BASManipulationTrace
//   - BASHostResonance / BASContinuityAnchor / BASContextRouteHint
//   - BASSituationField (BASSchemaVersioned aggregator)
//   - BASRouteHint typealias
//   - BASContextFrame (BASSchemaVersioned)
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保:纯 file org refactor
//   - 红线 7 watcher hint only:types are schema definitions
//   - chapter 二百十一 single-source-of-truth

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
    /// M111 — L6 whitepaper §5 `RoleGeometry.edges[]` coverage.
    /// Edge tuples like "alice:coworker:bob" or similar string
    /// encodings describing pairwise relations between `actors[]`.
    /// Distinct from `relationClass` (single summary string) — edges
    /// capture the full pairwise graph when present. Defaults `[]`
    /// for backward-compat; custom decoder uses decodeIfPresent so
    /// pre-M111 JSON decodes unchanged.
    public var edges: [String]

    public init(
        schemaVersion: String = BASRoleGeometry.currentSchemaVersion,
        actors: [String] = [],
        roleTypes: [String] = [],
        relationClass: String,
        asymmetryFlags: [String] = [],
        intimacyDistance: Double = 0.5,
        edges: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.actors = actors
        self.roleTypes = roleTypes
        self.relationClass = relationClass.trimmingCharacters(in: .whitespacesAndNewlines)
        self.asymmetryFlags = asymmetryFlags
        self.intimacyDistance = min(max(intimacyDistance, 0), 1)
        self.edges = edges
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case actors
        case roleTypes
        case relationClass
        case asymmetryFlags
        case intimacyDistance
        case edges
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decodeIfPresent(
            String.self, forKey: .schemaVersion)
            ?? BASRoleGeometry.currentSchemaVersion
        self.actors = try c.decodeIfPresent(
            [String].self, forKey: .actors) ?? []
        self.roleTypes = try c.decodeIfPresent(
            [String].self, forKey: .roleTypes) ?? []
        self.relationClass = try c.decode(
            String.self, forKey: .relationClass)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.asymmetryFlags = try c.decodeIfPresent(
            [String].self, forKey: .asymmetryFlags) ?? []
        self.intimacyDistance = min(max(
            try c.decodeIfPresent(
                Double.self, forKey: .intimacyDistance) ?? 0.5,
            0), 1)
        // M111 — new field; decodeIfPresent keeps pre-M111 JSON
        // backward-compat (missing key → []).
        self.edges = try c.decodeIfPresent(
            [String].self, forKey: .edges) ?? []
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

// MARK: - M111 L6 whitepaper §5 parity

/// L6 whitepaper §5 `SituationField` — the aggregator schema that
/// binds scene + channel + role + power + emotion + urgency +
/// consequence + manipulation + host-resonance + continuity +
/// ambiguity + confidence refs into one field. Distinct from
/// `BASContextFrame` (which carries the same semantics via
/// direct struct refs rather than string IDs): `BASSituationField`
/// is the ID-refs shape the whitepaper §5 specifies literally,
/// suitable for audit trail / cross-layer serialization that
/// only needs IDs. Use `BASContextFrame` when you need the
/// inline sub-structs; use `BASSituationField` when you need
/// whitepaper-literal ID refs for ledger / audit.
public struct BASSituationField: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sceneID: String
    public var utteranceRef: String?
    public var channelType: String
    public var sceneType: String
    public var actorSet: [String]
    public var roleGeometryRef: String?
    public var powerGradientRef: String?
    public var emotionalWeatherRef: String?
    public var urgencyTruthRef: String?
    public var consequenceHorizonRef: String?
    public var ambiguityBand: Double
    public var manipulationTraceRef: String?
    public var hostResonanceRef: String?
    public var continuityAnchorRef: String?
    public var confidenceBand: Double

    public init(
        schemaVersion: String
            = BASSituationField.currentSchemaVersion,
        sceneID: String,
        utteranceRef: String? = nil,
        channelType: String,
        sceneType: String,
        actorSet: [String] = [],
        roleGeometryRef: String? = nil,
        powerGradientRef: String? = nil,
        emotionalWeatherRef: String? = nil,
        urgencyTruthRef: String? = nil,
        consequenceHorizonRef: String? = nil,
        ambiguityBand: Double = 0,
        manipulationTraceRef: String? = nil,
        hostResonanceRef: String? = nil,
        continuityAnchorRef: String? = nil,
        confidenceBand: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.sceneID = sceneID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.utteranceRef = utteranceRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.channelType = channelType
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sceneType = sceneType
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.actorSet = actorSet
        self.roleGeometryRef = roleGeometryRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.powerGradientRef = powerGradientRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.emotionalWeatherRef = emotionalWeatherRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.urgencyTruthRef = urgencyTruthRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.consequenceHorizonRef = consequenceHorizonRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ambiguityBand = min(1, max(0, ambiguityBand))
        self.manipulationTraceRef = manipulationTraceRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostResonanceRef = hostResonanceRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.continuityAnchorRef = continuityAnchorRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidenceBand = min(1, max(0, confidenceBand))
    }
}

/// M111 — L6 whitepaper §5 `RouteHint` typealias. Provides the
/// whitepaper-literal name as a compile-time alias for the
/// substrate's `BASContextRouteHint`; both names refer to the
/// same type. Matches the M108 alias pattern for field-name
/// drift.
public typealias BASRouteHint = BASContextRouteHint

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

