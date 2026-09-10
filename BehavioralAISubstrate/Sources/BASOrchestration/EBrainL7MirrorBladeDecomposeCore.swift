// MARK: - EBrainL7MirrorBladeDecomposeCore — chapter 二百七十九 / M766
//
// Phase Alpha 第五刀:从 EBrainCognitionPlaneCore.swift 抽出 L7
// mirror-blade + decompose cluster。chapter 一百七十七 vision L7 =
// "镜刃" — problem decomposer / contradiction detector / fantasy
// risk scorer / intent / affect / unknown / pressure / manipulation
// / boundary / mirror / canonical-cognitive-frame / candidate path
// / forecast / critique。
//
// 抽出 ~30 types(M112 L7 whitepaper §5 parity cluster + decompose
// schemas):
//   - BASIntentVector / BASAffectLayer / BASUnknownSet (3)
//   - BASContradictionNode typealias
//   - BASCognitiveDissectionFrame (decompose aggregator)
//   - BASDecomposeFrame (BASSchemaVersioned)
//   - BASCandidatePath / BASForecastItem (2)
//   - BASCritiqueType / BASCritiqueItem (2)
//   - BASThoughtStopReason / BASThoughtFrame (2)
//   - BASThermalExchangeFrame / BASIntegrityWeaveFrame (2)
//   - BASOrganPackage / BASOrganDeltaPlan (2)
//
// **0 behavior change**:types literal-identical to pre-extraction
// versions。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百十一 single-source-of-truth

import Foundation
import BASMemory
import BASObservability
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

// MARK: - M112 L7 whitepaper §5 parity

/// L7 whitepaper §5 `IntentVector` — captures the explicit /
/// latent / steering intents of one utterance, with a confidence
/// score. Parallel object-family to `BASDecomposeFrame`'s inline
/// shards; ships as a separate whitepaper-literal schema so
/// cross-layer consumers (L9 dream / L10 tribunal / L11 risk)
/// can reference it by the whitepaper-named field.
public struct BASIntentVector: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var vectorID: String
    /// What the speaker says they want ("please send the report").
    public var explicitIntent: String
    /// What the speaker actually seems to be pursuing beneath the
    /// surface ("want the meeting moved so they don't have to
    /// present").
    public var latentIntent: String
    /// What the speaker may be trying to shape YOUR next move
    /// toward ("make you volunteer to present in their place").
    public var steeringIntent: String
    /// [0, 1] confidence in the inferred latent / steering
    /// decomposition.
    public var confidence: Double

    public init(
        schemaVersion: String = BASIntentVector.currentSchemaVersion,
        vectorID: String,
        explicitIntent: String = "",
        latentIntent: String = "",
        steeringIntent: String = "",
        confidence: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.vectorID = vectorID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.explicitIntent = explicitIntent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.latentIntent = latentIntent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.steeringIntent = steeringIntent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = min(1, max(0, confidence))
    }
}

/// L7 whitepaper §5 `AffectLayer` — one emotion layer observed in
/// an utterance, scored for volatility + spillover + coupling to
/// host goals.
public struct BASAffectLayer: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var tone: String
    public var intensity: Double
    public var volatility: Double
    public var spilloverRisk: Double
    public var coupledGoalRefs: [String]

    public init(
        schemaVersion: String = BASAffectLayer.currentSchemaVersion,
        tone: String,
        intensity: Double,
        volatility: Double,
        spilloverRisk: Double,
        coupledGoalRefs: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.tone = tone
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.intensity = min(1, max(0, intensity))
        self.volatility = min(1, max(0, volatility))
        self.spilloverRisk = min(1, max(0, spilloverRisk))
        self.coupledGoalRefs = coupledGoalRefs
    }
}

/// L7 whitepaper §5 `UnknownSet` — aggregator of the missing
/// knowledge the turn cannot resolve without explicit clarification.
/// Distinct from `BASUnknownRecord` which is per-item; this one is
/// the whitepaper-literal 5-list container keyed by "what kind of
/// gap this is".
public struct BASUnknownSet: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var missingFacts: [String]
    public var missingRoles: [String]
    public var missingConstraints: [String]
    public var unresolvedPermissions: [String]
    public var ambiguityNotes: [String]

    public init(
        schemaVersion: String = BASUnknownSet.currentSchemaVersion,
        missingFacts: [String] = [],
        missingRoles: [String] = [],
        missingConstraints: [String] = [],
        unresolvedPermissions: [String] = [],
        ambiguityNotes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.missingFacts = missingFacts
        self.missingRoles = missingRoles
        self.missingConstraints = missingConstraints
        self.unresolvedPermissions = unresolvedPermissions
        self.ambiguityNotes = ambiguityNotes
    }

    /// Empty baseline — no gaps identified yet.
    public static let empty = BASUnknownSet()

    /// True iff at least one list is non-empty.
    public var hasAny: Bool {
        !missingFacts.isEmpty
            || !missingRoles.isEmpty
            || !missingConstraints.isEmpty
            || !unresolvedPermissions.isEmpty
            || !ambiguityNotes.isEmpty
    }
}

/// L7 whitepaper §5 `ContradictionNode` typealias. Substrate uses
/// `BASContradictionRecord` (node_id→nodeID, contradiction_type→
/// kind, both named structurally the same but "Record" is the
/// substrate's canonical naming). Shape match is close enough
/// that a typealias suffices for whitepaper-literal parity.
public typealias BASContradictionNode = BASContradictionRecord

/// L7 whitepaper §5 `CognitiveDissectionFrame` — aggregator that
/// binds the full L7 decomposition of one turn (fact shards +
/// claim shards + intent vectors + goal spine + affect layers +
/// unknown set + contradictions + pressure vectors + manipulation
/// patterns + boundary touches + provenance + mirror draft +
/// canonical frame + confidence band).
///
/// Parallel to `BASDecomposeFrame` (substrate's authoritative
/// runtime frame): `BASCognitiveDissectionFrame` exposes the
/// whitepaper-literal shape for audit / cross-layer serialization.
/// Both can co-exist; callers choose based on use case.
public struct BASCognitiveDissectionFrame: BASSchemaVersioned,
    Equatable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var frameID: String
    public var situationRef: String?
    public var factShards: [BASFactShard]
    public var claimShards: [BASClaimShard]
    public var intentVectors: [BASIntentVector]
    public var goalSpineLocal: BASGoalSpineLocal?
    public var affectLayers: [BASAffectLayer]
    public var unknownSet: BASUnknownSet
    public var contradictionNodes: [BASContradictionNode]
    public var pressureVectors: [BASPressureVector]
    public var manipulationPatterns: [BASManipulationPattern]
    public var boundaryTouches: [BASBoundaryTouch]
    public var provenanceMap: [String: String]
    public var mirrorDraftRef: String?
    public var canonicalFrameRef: String?
    public var confidenceBand: Double

    public init(
        schemaVersion: String
            = BASCognitiveDissectionFrame.currentSchemaVersion,
        frameID: String,
        situationRef: String? = nil,
        factShards: [BASFactShard] = [],
        claimShards: [BASClaimShard] = [],
        intentVectors: [BASIntentVector] = [],
        goalSpineLocal: BASGoalSpineLocal? = nil,
        affectLayers: [BASAffectLayer] = [],
        unknownSet: BASUnknownSet = .empty,
        contradictionNodes: [BASContradictionNode] = [],
        pressureVectors: [BASPressureVector] = [],
        manipulationPatterns: [BASManipulationPattern] = [],
        boundaryTouches: [BASBoundaryTouch] = [],
        provenanceMap: [String: String] = [:],
        mirrorDraftRef: String? = nil,
        canonicalFrameRef: String? = nil,
        confidenceBand: Double = 0
    ) {
        self.schemaVersion = schemaVersion
        self.frameID = frameID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.situationRef = situationRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.factShards = factShards
        self.claimShards = claimShards
        self.intentVectors = intentVectors
        self.goalSpineLocal = goalSpineLocal
        self.affectLayers = affectLayers
        self.unknownSet = unknownSet
        self.contradictionNodes = contradictionNodes
        self.pressureVectors = pressureVectors
        self.manipulationPatterns = manipulationPatterns
        self.boundaryTouches = boundaryTouches
        self.provenanceMap = provenanceMap
        self.mirrorDraftRef = mirrorDraftRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.canonicalFrameRef = canonicalFrameRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidenceBand = min(1, max(0, confidenceBand))
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

// chapter 二百七十五 / M762 — L2 Neural Organ Runtime types
// (BASNeuralOrgan / BASNeuralMorph / BASNeuralPrecisionTier /
// BASNeuralRoutingPolicy / BASNeuralOrganPrecision /
// BASNeuralOrganMap / BASCortexPacket) extracted to
// `EBrainL2NeuralOrganCore.swift`. Phase Alpha first cut of
// god-file deconstruction (5347 LOC → split). 0 behavior change;
// types literal-identical to pre-extraction versions.

// chapter 二百七十六 / M763 — L9 dream-loop schema cluster
// (BASThoughtLoopStopReason / BASCandidatePathStatus /
// BASSovereignBreakSuggestedAction / BASThoughtLoopState /
// BASCounterfactualBranch / BASOutcomeProjection /
// BASAdversarialBrief / BASHostAlignmentMap /
// BASCandidateFrontier / BASCounterfactualBundle /
// BASCritiqueBundle / BASUncertaintyLedger / BASEvidenceDebt /
// BASConvergenceStoppingMode / BASConvergenceCertificate /
// BASLoopLeaseReceipt / BASSovereignBreakpointSuggestedAction /
// BASSovereignBreakpointHint) extracted to
// `EBrainL9DreamLoopCore.swift`. Phase Alpha second cut. 0
// behavior change.

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

// chapter 二百七十五 / M762 — `BASLatentTissueState` +
// `BASNeuralCoreFrame` extracted to `EBrainL2NeuralOrganCore.swift`
// (L2 neural organ runtime cluster). 0 behavior change.

// chapter 二百七十七 / M764 — L10 tribunal schema cluster
// (BASTriSelfScore / BASCourtVetoType / BASVetoMark /
// BASTradeoffLedger / BASAgencyReservationMode /
// BASAgencyReservation / BASRemandOrder /
// BASCourtDecisionDraft / BASIdImpulseProfile /
// BASEgoRealityAssessment / BASSuperegoJudgment /
// BASArbitrationFrame / BASMergedChoice) extracted to
// `EBrainL10TribunalCore.swift`. Phase Alpha third cut.
// 0 behavior change.


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
    public static let currentSchemaVersion = "1.14.0"

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
    /// M89 — L10 tribunal id-voice profile. See
    /// `BASIdImpulseProfile`. `nil` on frames that predate M89 or
    /// when the id voice was explicitly skipped (fast-track paths).
    public var idImpulseProfile: BASIdImpulseProfile?
    /// M89 — L10 tribunal ego-voice assessment. See
    /// `BASEgoRealityAssessment`. `nil` on frames that predate M89
    /// or when the ego voice was explicitly skipped.
    public var egoRealityAssessment: BASEgoRealityAssessment?
    /// M89 — L10 tribunal superego-voice judgment. See
    /// `BASSuperegoJudgment`. `nil` on frames that predate M89 or
    /// when the superego voice was explicitly skipped.
    public var superegoJudgment: BASSuperegoJudgment?
    /// M89 — L10 tribunal integrated arbitration frame. Aggregates
    /// the three voices above plus refs to vetoes / remands /
    /// decision draft / agency reservation / tradeoff ledgers. `nil`
    /// on frames that predate M89 or when `.aggregate(...)` was
    /// never called.
    public var arbitrationFrame: BASArbitrationFrame?
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
    /// M62 — L3 思纹层 per-turn thought-fold observation bundle
    /// derived from the turn's `BASThoughtFold`. Up to seven kinds
    /// emit in a fixed order — foldSealed always fires (baseline
    /// anchor); snapshotAnchored / rollbackAnchored / resumeAnchored
    /// / integrityBound gate on non-empty ref fields; organPackageBound
    /// iterates `organPackageRefs`; degradationFlagged iterates
    /// `degradedReasonCodes`. Shape classification is turn-level
    /// (degraded / orphan / integrityBound / snapshotted / quiet).
    /// Load-bearing consumers (future L3 coverage refinements, L14
    /// audit surface) read this field directly; coherent-by-
    /// construction with the fold on the same turn.
    public var thoughtFoldObservationBundle:
        BASThoughtFoldObservationBundle?
    /// M63 — L8 海马层 per-turn hippocampal memory observation
    /// bundle derived from the turn's `BASMemoryBundle` (the
    /// working-memory window retrieved + normalized at the start of
    /// the turn). Up to eight kinds emit in a fixed order —
    /// bundleRetrieved always fires (baseline); per-atom signals
    /// (atomAdmitted / atomCandidate / atomFrozen / atomRetired)
    /// classify each atom in `bundle.atoms` by promotion state and
    /// frozen flag; conflictFlagged iterates top-level
    /// `conflictRefs`; quarantineRecorded iterates
    /// `temporalField.quarantineRecords`; forgetCascadeBound
    /// iterates `temporalField.forgetCascades`. Shape classification
    /// is turn-level (forgetting / quarantined / conflicted / empty /
    /// quiet). Load-bearing consumers (future L8 coverage refinements,
    /// L14 audit surface) read this field directly;
    /// coherent-by-construction with the memory bundle on the same
    /// turn.
    public var hippocampalMemoryObservationBundle:
        BASHippocampalMemoryObservationBundle?
    /// M64 — L2 神经器官层 per-turn neural-organ-registry
    /// observation bundle derived from the turn's finalized
    /// `BASNeuralOrganMap` (post `applySovereignNeuralContract`).
    /// Up to six kinds emit in a fixed order — organMapSealed
    /// always fires (baseline anchor); organActive iterates
    /// `activeOrgans`; precisionSet iterates `precisionMap`;
    /// routingPolicyApplied always fires when the map is sealed;
    /// sovereignConstraintActive iterates `sovereignConstraints`
    /// (empty / whitespace entries skipped); headGuaranteeActive
    /// iterates `headGuarantees` (empty / whitespace entries
    /// skipped). Shape classification is turn-level (quarantined /
    /// rebuilding / stubOnly / guarded / quiet / absent).
    /// Load-bearing consumers (future L2 coverage refinements, L14
    /// audit surface) read this field directly; coherent-by-
    /// construction with the organ map on the same turn.
    public var neuralOrganObservationBundle:
        BASNeuralOrganObservationBundle?

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
        idImpulseProfile: BASIdImpulseProfile? = nil,
        egoRealityAssessment: BASEgoRealityAssessment? = nil,
        superegoJudgment: BASSuperegoJudgment? = nil,
        arbitrationFrame: BASArbitrationFrame? = nil,
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
            BASHostConstitutionObservationBundle? = nil,
        thoughtFoldObservationBundle:
            BASThoughtFoldObservationBundle? = nil,
        hippocampalMemoryObservationBundle:
            BASHippocampalMemoryObservationBundle? = nil,
        neuralOrganObservationBundle:
            BASNeuralOrganObservationBundle? = nil
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
        self.idImpulseProfile = idImpulseProfile
        self.egoRealityAssessment = egoRealityAssessment
        self.superegoJudgment = superegoJudgment
        self.arbitrationFrame = arbitrationFrame
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
        self.thoughtFoldObservationBundle =
            thoughtFoldObservationBundle
        self.hippocampalMemoryObservationBundle =
            hippocampalMemoryObservationBundle
        self.neuralOrganObservationBundle =
            neuralOrganObservationBundle
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

    /// M62 — Return a copy of this frame with a freshly derived
    /// `thoughtFoldObservationBundle` attached. Pure function: no
    /// I/O, no actor hop, deterministic for the same (fold, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the thought
    /// fold has been built — after `buildThoughtFold` has produced
    /// the canonical compaction + checksum + ark refs — so the
    /// bundle flows into the same turn-audit record that the L14
    /// surface later signs.
    ///
    /// Unlike the tribunal / risk / soft-hand / world-prior / lease
    /// / host-constitution derivations, this one takes the fold as
    /// an explicit argument because the thought frame itself does
    /// not carry the fold — the fold is a sibling value on the turn
    /// result that the coordinator constructs from the same inputs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals",
    /// not "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedThoughtFoldObservationBundle(
        fold: BASThoughtFold,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.thoughtFoldObservationBundle =
            BASThoughtFoldObservationBundle.derive(
                fromThoughtFold: fold,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M63 — Return a copy of this frame with a freshly derived
    /// `hippocampalMemoryObservationBundle` attached. Pure function:
    /// no I/O, no actor hop, deterministic for the same (memoryBundle,
    /// turnID, sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the memory
    /// bundle has been retrieved and normalized — after
    /// `memoryService.retrieve` + `normalizeMemoryBundle` — so the
    /// bundle flows into the same turn-audit record that the L14
    /// surface later signs.
    ///
    /// Unlike the tribunal / risk / soft-hand / world-prior / lease
    /// / host-constitution / thought-fold derivations, this one takes
    /// the memory bundle as an explicit argument because the thought
    /// frame itself does not carry the memory bundle — the bundle is
    /// a sibling value on the turn result that the coordinator
    /// normalizes from the same inputs.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals",
    /// not "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedHippocampalMemoryObservationBundle(
        memoryBundle: BASMemoryBundle?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.hippocampalMemoryObservationBundle =
            BASHippocampalMemoryObservationBundle.derive(
                fromMemoryBundle: memoryBundle,
                turnID: turnID,
                sessionID: sessionID,
                emittedAt: emittedAt)
        return copy
    }

    /// M64 — Return a copy of this frame with a freshly derived
    /// `neuralOrganObservationBundle` attached. Pure function: no
    /// I/O, no actor hop, deterministic for the same (map, turnID,
    /// sessionID, emittedAt) tuple.
    ///
    /// The coordinator calls this at the seam where the neural
    /// organ map has been finalized — after the early seal on
    /// `thoughtFrame.organMap` and any sovereign neural contract
    /// mutation (`applySovereignNeuralContract`) — so the bundle
    /// flows into the same turn-audit record that the L14 surface
    /// later signs.
    ///
    /// Unlike the tribunal / risk / soft-hand / world-prior
    /// derivations, this one reads `self.organMap` directly because
    /// the thought frame carries the L2 state as a top-level field.
    /// A `nil` map produces an empty observation bundle — the
    /// legitimate "no-neural-plane-this-turn" signal.
    ///
    /// Existing frames with a non-nil bundle are overwritten — the
    /// intent of this method is "re-derive from current signals",
    /// not "merge". Callers that want to preserve an upstream bundle
    /// should skip this helper and set the field directly.
    public func withDerivedNeuralOrganObservationBundle(
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> BASThoughtFrame {
        var copy = self
        copy.neuralOrganObservationBundle =
            BASNeuralOrganObservationBundle.derive(
                fromOrganMap: self.organMap,
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

