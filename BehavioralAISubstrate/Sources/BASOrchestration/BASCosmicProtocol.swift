import Foundation
import BASRuntimeCore

/// M439 (chapter 一百十四) — schema parity for 7 Cthulhu/Abyssal
/// objects at L4/L7/L9/L10 that the user's 2026-05-04 audit
/// flagged as missing. Closes 7 of the 11 user-flagged
/// "structural blanks".
///
/// ## Why this exists
///
/// The user's 83-item audit (2026-05-04) listed these 7 typed
/// objects as ❌ MISSING after a 3-doc reading of:
///   1. `docs/QINAO_ABYSSAL_HUMAN_ANCHOR_PROTOCOL_TARGET_VINF.md`
///      §4.4 / §4.7 / §4.9 / §4.10
///   2. `docs/QINAO_CTHULHU_INSPIRATION_INTEGRATION_SPEC_V1.md`
///      §5.4 / §5.9
///   3. `docs/QINAO_SOVEREIGN_SECOND_BRAIN_PLATFORM_RND_TECH_OUTLINE_V1.md`
///
/// Phase 1 verification confirmed all 7 are genuinely missing
/// (in contrast with the audit's ~50% noise rate on other
/// claims — e.g. `BASAbyssalBranch` was claimed missing but
/// already exists at `BASAbyssalProtocol.swift:429`).
///
/// ## Scope (chapter 一百十四 / M439)
///
/// This file is **schema-only + helper enums**. It defines the
/// seven Swift value types and four supporting enums. Per
/// chapter 一百八七 / M287 pattern (the M287 Cthulhu schema
/// parity ship that introduced `BASAbyssalProtocol.swift`),
/// this file does NOT:
///
///  - mutate any existing substrate type;
///  - run a watcher agent (white-paper red line 7);
///  - drive a runtime path (e.g. modifying `BASActionPermit`
///    issuance — that's a future M-numbered follow-up).
///
/// Cross-layer integration (L4 worldview gating, L7 mirror-
/// blade emission, L9 dream-loop branching, L10 tribunal
/// consumption) is explicitly deferred.
///
/// ## Doctrine pins (chapter 一百十三 / M438 anti-magic-number
/// sweep applied)
///
/// - All `[0, 1]` numeric invariants enforced via `min(1, max(0, x))`
///   in init (chapter 一百三 / 一百十三 doctrine).
/// - All helper enums use stable kebab-case raw values
///   (chapter 八十七 / M287 pattern; cross-module string
///   consumers key on raw value not Swift case name).
/// - All struct field defaults route through enum cases or
///   named static constants (no inline numeric literals beyond
///   the `0.0` clamping floor / `1.0` ceiling).
///
/// ## Codable layout
///
/// Swift-native `Codable` derivation with camelCase field
/// names. White-paper field names use snake_case
/// (`dignity_bias`); Swift uses camelCase (`dignityBias`).
/// Stable serialization via:
///
///  - explicit `schemaVersion` field on every type;
///  - canonical raw values on every enum;
///  - parity-lock unit tests in `BASCosmicProtocolTests` that
///    pin every field, every raw value, and the round-trip
///    JSON shape.
///
/// ## DAG discipline
///
/// Imports `Foundation` and `BASRuntimeCore` only — no Qinao
/// reference, no upstream substrate-runtime dependency.

// MARK: - BASCosmicScaleHorizon (L4 horizon classifier)

/// One of six canonical horizon classifications used by L4
/// cosmic-scale views. Stable kebab-case raw values.
///
/// Per `Abyssal VINF §4.4 + Cthulhu Spec V1 §5.4`, a cosmic-
/// scale view classifies the **observed subject** along three
/// axes (temporal / spatial / agentic), each with a 2-level
/// granularity to start. Future expansions can add intermediate
/// levels additively.
///
/// Doctrine pin (red line 10 — "不把宇宙冷感做成宿主冷处理"):
/// these classifications are observational only — they do NOT
/// authorize the substrate to dilute host concerns by citing
/// "the universe is big". L10 `BASCosmicColdCounterweight`
/// (below) is the explicit mitigator.
public enum BASCosmicScaleHorizon:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case temporalShort = "temporal-short"
    case temporalMedium = "temporal-medium"
    case temporalDeep = "temporal-deep"
    case spatialLocal = "spatial-local"
    case spatialBroad = "spatial-broad"
    case spatialCosmic = "spatial-cosmic"
}

// MARK: - BASOntologyFogQuality (L4 fog quality)

/// Three-level grasp quality classifier for L4 ontology fog.
/// Stable kebab-case raw values.
///
/// Per `Cthulhu Spec V1 §5.4`, the L4 horizon layer must allow
/// "存在无法充分命名的对象" — the substrate explicitly admits
/// when something is at the edge of the host's namable
/// vocabulary. The three levels:
///
///  - `partialGrasp` — the subject is partially understood; the
///    host can refer to it through known anchors but cannot
///    fully describe it.
///  - `provisionalNaming` — a name has been proposed but is
///    explicitly provisional (subject to revision when more
///    evidence arrives).
///  - `unnameable` — the subject resists naming with current
///    vocabulary; the substrate notes its presence without
///    committing to a name.
public enum BASOntologyFogQuality:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case partialGrasp = "partial-grasp"
    case provisionalNaming = "provisional-naming"
    case unnameable = "unnameable"
}

// MARK: - BASOntologyShiftAxis (L7 mirror-blade axis)

/// Five canonical axes along which an L7 mirror-blade can mark
/// observed ontology shifts. Stable kebab-case raw values.
///
/// Per `Abyssal VINF §4.7` and `Cthulhu Spec V1 §7` (language
/// style), L7 mirror-blade observes shifts in narrative shape
/// (relation / power / narrative / intent / causality). Each
/// axis is independent; an `OntologyShiftMark` may flag any
/// non-empty subset.
///
/// Doctrine pin (red line 7 — watcher hints, not verdicts):
/// these axes are observational classifications only. The L11
/// wind gate or L14 sovereign make verdict decisions; L7 only
/// emits the typed mark.
public enum BASOntologyShiftAxis:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case relation = "relation"
    case power = "power"
    case narrative = "narrative"
    case intent = "intent"
    case causality = "causality"
}

// MARK: - BASNonEuclideanFailureMode (L9 candidate failure mode)

/// Four canonical failure modes for L9 non-Euclidean candidates
/// when grasped naively. Stable kebab-case raw values.
///
/// Per `Abyssal VINF §4.9` and `Cthulhu Spec V1 §5.9`, the L9
/// dream-loop layer occasionally generates candidates whose
/// internal logic is consistent under partial view but fails
/// when forced into Euclidean ("flat", "fully named") shape.
/// The four canonical failure modes:
///
///  - `collapsedOnGrasp` — candidate dissolves when described
///    in single-frame natural-language form.
///  - `boundaryViolation` — candidate's logic crosses a host-
///    constitution boundary the substrate would not normally
///    cross.
///  - `topologyDistortion` — candidate's structure cannot be
///    flattened without losing essential relations.
///  - `consistencyLoss` — candidate is internally consistent
///    but inconsistent with the host's stated values.
public enum BASNonEuclideanFailureMode:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    case collapsedOnGrasp = "collapsed-on-grasp"
    case boundaryViolation = "boundary-violation"
    case topologyDistortion = "topology-distortion"
    case consistencyLoss = "consistency-loss"
}

// MARK: - BASCosmicScaleView (L4 cosmic-scale view)

/// White paper §5.4 (Cthulhu Spec V1) + §4.4 (Abyssal VINF)
/// `CosmicScaleView` — typed readout of the cosmic-scale
/// classification of an observed subject along three horizon
/// axes (temporal / spatial / agentic).
///
/// L4 produces this for L9 dream-loop + L11 risk gate
/// consumers. L10 `BASCosmicColdCounterweight` is the explicit
/// mitigator (red line 10) so that "the universe is big" never
/// dilutes the host's concerns.
public struct BASCosmicScaleView:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"cosmic-scale-<turnID>"`).
    public var scaleID: String
    /// Reference to the subject this view classifies (a memory
    /// atom ref / candidate ref / situation ref).
    public var observedSubjectRef: String
    /// Temporal horizon classification (short / medium / deep).
    public var temporalHorizon: BASCosmicScaleHorizon
    /// Spatial horizon classification (local / broad / cosmic).
    public var spatialHorizon: BASCosmicScaleHorizon
    /// Agentic horizon — count of distinct agentic actors
    /// implicated. `[0, 1]` clamped: 0 = solo, 1 = full system
    /// scope.
    public var agenticHorizonScale: Double
    /// `true` when the cosmic framing risks diluting host
    /// concerns and L10 counterweight should fire (red line 10).
    public var consequenceDilutionWarning: Bool

    public init(
        schemaVersion: String =
            BASCosmicScaleView.currentSchemaVersion,
        scaleID: String,
        observedSubjectRef: String,
        temporalHorizon: BASCosmicScaleHorizon,
        spatialHorizon: BASCosmicScaleHorizon,
        agenticHorizonScale: Double,
        consequenceDilutionWarning: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.scaleID = scaleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.observedSubjectRef = observedSubjectRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.temporalHorizon = temporalHorizon
        self.spatialHorizon = spatialHorizon
        self.agenticHorizonScale =
            min(1, max(0, agenticHorizonScale))
        self.consequenceDilutionWarning =
            consequenceDilutionWarning
    }
}

// MARK: - BASTemporalDepthMap (L4 temporal depth)

/// White paper §5.4 `TemporalDepthMap` — typed readout of the
/// temporal-depth classification of an observed subject.
/// Sediment layers are an array of horizon classifications
/// (the substrate may have multiple layers if the subject
/// spans multiple temporal scales).
///
/// `non_simultaneity_marks` are reason codes for why some
/// timeline refs are not simultaneous in the host's frame
/// (e.g. one is a memory of an event, another is a planned
/// future commitment).
public struct BASTemporalDepthMap:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier.
    public var mapID: String
    /// Refs to all timeline anchors this map covers.
    public var timelineRefs: [String]
    /// Sediment layers — each is a horizon classification
    /// covering a span of timeline refs. Empty for shallow maps.
    public var sedimentLayers: [BASCosmicScaleHorizon]
    /// Reason codes for why some timeline refs are not
    /// simultaneous in the host's frame.
    public var nonSimultaneityMarks: [String]
    /// Free-text observation window (e.g. `"past-30-days"`,
    /// `"lifetime"`) — the consumer interprets.
    public var observationWindow: String

    public init(
        schemaVersion: String =
            BASTemporalDepthMap.currentSchemaVersion,
        mapID: String,
        timelineRefs: [String],
        sedimentLayers: [BASCosmicScaleHorizon],
        nonSimultaneityMarks: [String],
        observationWindow: String
    ) {
        self.schemaVersion = schemaVersion
        self.mapID = mapID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.timelineRefs = timelineRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.sedimentLayers = sedimentLayers
        self.nonSimultaneityMarks = nonSimultaneityMarks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.observationWindow = observationWindow
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - BASOntologyFog (L4 ontology fog)

/// White paper §5.4 `OntologyFog` — typed readout of the
/// substrate's admission that some subjects are at the edge of
/// or beyond the host's current naming vocabulary. Per Cthulhu
/// Spec V1 §5.4: "允许系统明确说目前只能知道到这里".
///
/// Red line 10 ("不把宇宙冷感做成宿主冷处理") + Cthulhu Spec
/// V1 §5.4 explicitly forbid using fog as cosmic-cold framing
/// against the host. The substrate emits fog as observational
/// only; the L12 surface layer must NEVER use fog to dismiss
/// host concerns.
public struct BASOntologyFog:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier.
    public var fogID: String
    /// Region descriptors (e.g. `"emotion-pattern-cluster-A"`,
    /// `"unobserved-relation-graph"`). Free-text reason codes.
    public var fogRegions: [String]
    /// Refs to nameable anchors the host can grab onto inside
    /// the fog — these must NOT be empty if the substrate is
    /// going to mention the fog at all (red line 10
    /// safeguard).
    public var nameableAnchors: [String]
    /// Marks of regions explicitly unnamed (the substrate
    /// commits to NOT inventing names here).
    public var unnameableMarks: [String]
    /// Quality of the host's grasp: partial / provisional /
    /// unnameable.
    public var partialGraspQuality: BASOntologyFogQuality

    public init(
        schemaVersion: String =
            BASOntologyFog.currentSchemaVersion,
        fogID: String,
        fogRegions: [String],
        nameableAnchors: [String],
        unnameableMarks: [String],
        partialGraspQuality: BASOntologyFogQuality
    ) {
        self.schemaVersion = schemaVersion
        self.fogID = fogID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.fogRegions = fogRegions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.nameableAnchors = nameableAnchors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.unnameableMarks = unnameableMarks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.partialGraspQuality = partialGraspQuality
    }
}

// MARK: - BASOntologyShiftMark (L7 mirror-blade shift mark)

/// White paper §4.7 (Abyssal VINF) `OntologyShiftMark` — typed
/// readout from L7 mirror-blade noting that the observed
/// subject's ontology has shifted along one or more axes.
///
/// Doctrine pin (red line 7 — watcher hints, not verdicts):
/// L7 emits typed marks; L11 / L14 decide what to do with
/// them.
public struct BASOntologyShiftMark:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier.
    public var markID: String
    /// Ref to the subject this mark observes.
    public var targetSubjectRef: String
    /// Axes along which the shift was observed (subset of the
    /// 5 canonical axes).
    public var observedShiftAxes: [BASOntologyShiftAxis]
    /// Refs to the pre/post anchors the mirror-blade compared
    /// to detect the shift. Pre/post are interleaved: even
    /// indices are pre-shift, odd indices are post-shift, in
    /// matched pairs.
    public var prePostAnchors: [String]
    /// Confidence the shift is genuine (not noise). `[0, 1]`.
    public var shiftConfidence: Double

    public init(
        schemaVersion: String =
            BASOntologyShiftMark.currentSchemaVersion,
        markID: String,
        targetSubjectRef: String,
        observedShiftAxes: [BASOntologyShiftAxis],
        prePostAnchors: [String],
        shiftConfidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.markID = markID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetSubjectRef = targetSubjectRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.observedShiftAxes = observedShiftAxes
        self.prePostAnchors = prePostAnchors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.shiftConfidence = min(1, max(0, shiftConfidence))
    }
}

// MARK: - BASNonEuclideanCandidate (L9 non-standard candidate)

/// White paper §4.9 (Abyssal VINF) + §5.9 (Cthulhu Spec V1)
/// `NonEuclideanCandidate` — typed readout marking an L9 dream-
/// loop candidate whose internal logic is consistent under
/// partial view but fails when grasped in single-frame
/// natural-language form.
///
/// L9 emits these to flag candidates that L11 / L12 must
/// surface very carefully (or not at all). Per Abyssal VINF
/// §4.9, these candidates are NOT to be auto-promoted; the
/// substrate marks them for compare-panel surface or guardian
/// branch routing.
public struct BASNonEuclideanCandidate:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier.
    public var candidateID: String
    /// Free-text descriptor of the non-standard topology
    /// (e.g. `"recursive-self-reference"`, `"multi-frame-overlap"`).
    public var nonStandardTopology: String
    /// `true` when the candidate is consistent within a single
    /// observational frame; `false` if the candidate requires
    /// cross-frame consistency it cannot deliver.
    public var consistentUnderPartialView: Bool
    /// Failure mode the substrate predicts when the candidate
    /// is grasped naively (one of 4 canonical modes).
    public var failureModeWhenGrasped: BASNonEuclideanFailureMode
    /// Refs to anchors that support the candidate's partial-
    /// view consistency. Empty when the substrate has no
    /// supporting anchors (high-risk case).
    public var supportingAnchors: [String]

    public init(
        schemaVersion: String =
            BASNonEuclideanCandidate.currentSchemaVersion,
        candidateID: String,
        nonStandardTopology: String,
        consistentUnderPartialView: Bool,
        failureModeWhenGrasped: BASNonEuclideanFailureMode,
        supportingAnchors: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.candidateID = candidateID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.nonStandardTopology = nonStandardTopology
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.consistentUnderPartialView =
            consistentUnderPartialView
        self.failureModeWhenGrasped = failureModeWhenGrasped
        self.supportingAnchors = supportingAnchors
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - BASUnknownRetentionLoop (L9 unknown-retention loop)

/// White paper §4.9 (Abyssal VINF) `UnknownRetentionLoop` —
/// typed readout describing an L9 dream-loop branch that
/// preserves unknowns rather than collapsing them prematurely.
/// Per Abyssal VINF §4.9: "在足够冷却前不强行归名".
///
/// `cooling_period` is in seconds; the loop should not be
/// re-evaluated for verdict before this period elapses unless
/// a `re_examine_trigger` fires. `safe_assertion_ceiling` is
/// `[0, 1]` clamped: 0 = no assertion allowed, 1 = full
/// assertion allowed.
public struct BASUnknownRetentionLoop:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier.
    public var loopID: String
    /// Refs to the unknowns this loop preserves (memory-atom
    /// refs / situation-field refs / etc).
    public var preservedUnknownRefs: [String]
    /// Cooling period in seconds before the loop can be
    /// re-evaluated. Negative values clamped to zero.
    public var coolingPeriodSeconds: Int
    /// Maximum confidence level the L11 / L14 verdict layer is
    /// allowed to assert about this loop's contents. `[0, 1]`.
    public var safeAssertionCeiling: Double
    /// Reason codes that, when fired, allow re-evaluating the
    /// loop before the cooling period elapses.
    public var reExamineTriggers: [String]

    public init(
        schemaVersion: String =
            BASUnknownRetentionLoop.currentSchemaVersion,
        loopID: String,
        preservedUnknownRefs: [String],
        coolingPeriodSeconds: Int,
        safeAssertionCeiling: Double,
        reExamineTriggers: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.loopID = loopID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.preservedUnknownRefs = preservedUnknownRefs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.coolingPeriodSeconds = max(0, coolingPeriodSeconds)
        self.safeAssertionCeiling =
            min(1, max(0, safeAssertionCeiling))
        self.reExamineTriggers = reExamineTriggers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - BASCosmicColdCounterweight (L10 tribunal counterweight)

/// White paper §4.10 (Abyssal VINF) `CosmicColdCounterweight` —
/// typed readout from L10 tri-self tribunal that counterweights
/// L4 cosmic-scale framing so the substrate never dilutes host
/// concerns by citing "the universe is big" (red line 10).
///
/// Four `[0, 1]` doubles per Abyssal VINF §4.10 (verbatim
/// field names):
///
///  - `dignity_bias` — bias toward preserving host dignity.
///  - `agency_floor` — minimum agency reservation for the
///    host even under cosmic-scale framing.
///  - `anti_fatalism` — counterweight against fatalistic
///    "nothing matters at this scale" framing.
///  - `anti_paternalism` — counterweight against paternalistic
///    "I see the bigger picture so I'll decide for you"
///    framing.
public struct BASCosmicColdCounterweight:
    BASSchemaVersioned, Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    /// Stable identifier (e.g. `"cosmic-cold-counterweight-<turnID>"`).
    public var counterweightID: String
    /// Bias toward preserving host dignity. `[0, 1]`.
    public var dignityBias: Double
    /// Minimum agency reservation for the host. `[0, 1]`.
    public var agencyFloor: Double
    /// Counterweight against fatalistic framing. `[0, 1]`.
    public var antiFatalism: Double
    /// Counterweight against paternalistic framing. `[0, 1]`.
    public var antiPaternalism: Double

    public init(
        schemaVersion: String =
            BASCosmicColdCounterweight.currentSchemaVersion,
        counterweightID: String,
        dignityBias: Double,
        agencyFloor: Double,
        antiFatalism: Double,
        antiPaternalism: Double
    ) {
        self.schemaVersion = schemaVersion
        self.counterweightID = counterweightID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.dignityBias = min(1, max(0, dignityBias))
        self.agencyFloor = min(1, max(0, agencyFloor))
        self.antiFatalism = min(1, max(0, antiFatalism))
        self.antiPaternalism = min(1, max(0, antiPaternalism))
    }

    /// Convenience: aggregate counterweight strength as the
    /// mean of the four doubles. Producers / consumers can
    /// use this for ordering / threshold checks without
    /// recomputing the formula. Pure mean — weighting belongs
    /// to the policy layer (chapter 一百八七 M287 doctrine).
    public var aggregateStrength: Double {
        let total = dignityBias
            + agencyFloor
            + antiFatalism
            + antiPaternalism
        return total / 4.0
    }
}
